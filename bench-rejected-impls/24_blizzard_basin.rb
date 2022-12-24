require_relative '../lib/search'

require 'benchmark'

bench_candidates = {}

left_bliz = []
right_bliz = []
up_bliz = []
down_bliz = []
add_bliz = ->(a, y, x) {
  a[y] ||= 0
  a[y] |= 1 << x
}

blizstart = ARGF.flat_map.with_index { |line, y|
  line.chomp.chars.filter_map.with_index { |c, x|
    case c
    when ?<
      add_bliz[left_bliz, y - 1, x - 1]
      [y - 1, x - 1, 0, -1].freeze
    when ?>
      add_bliz[right_bliz, y - 1, x - 1]
      [y - 1, x - 1, 0, 1].freeze
    when ?^
      add_bliz[up_bliz, y - 1, x - 1]
      [y - 1, x - 1, -1, 0].freeze
    when ?v
      add_bliz[down_bliz, y - 1, x - 1]
      [y - 1, x - 1, 1, 0].freeze
    when ?# # OK
    when ?. # OK
    else raise "bad char #{c}"
    end
  }
}.freeze
# oops this fails if there is no blizzard on the bottommost row oh well I don't care
height = blizstart.map(&:first).max + 1
# oops this fails if there is no blizzard on the rightmost column oh well I don't care
width = blizstart.map { |b| b[1] }.max + 1
size = height * width
wind_cycle = height.lcm(width)

leftmost = 1 << (width - 1)

[left_bliz, right_bliz, up_bliz, down_bliz].each { |bliz|
  height.times { |y| bliz[y] ||= 0 }
}

# The benchmarks just use the unified bliz_at_t,
# instead of the horiz/vert split,
# because the benchmarks aren't timing the time it takes to build bliz_at_t.
bliz_at_t = wind_cycle.times.map { |t|
  blizstart.to_h { |y, x, dy, dx|
    ny = (y + (t * dy)) % height
    nx = (x + (t * dx)) % width
    [ny * width + nx, true]
  }.freeze
}.freeze

neigh = Array.new(size) { |pos|
  [
    (pos - width if pos >= width || pos == 0),
    (pos + width if pos + width < size || pos == size - 1),
    (pos - 1 if pos % width != 0),
    (pos + 1 if (pos + 1) % width != 0),
    pos,
  ].compact.freeze
}
# Extend neigh such that neigh[-width] does not conflict with an existing element.
neigh[size + width] = nil
start = -width
goal = size + width - 1
neigh[start] = [start, 0].freeze
neigh[goal] = [size - 1, goal].freeze
neigh.freeze

neigh_pos_t_array = ->((pos, t)) {
  tnext = (t + 1) % wind_cycle
  neigh[pos].filter_map { |npos| [npos, tnext] unless bliz_at_t[tnext][npos] }
}

bench_candidates[:general_bfs_pos_t_array] = ->(a, b, t0) {
  r = Search.bfs([[a, t0]], neighbours: neigh_pos_t_array, goal: ->((pos, t)) { pos == b })
  raise 'not found' unless r[:found]
  r[:gen]
}

bench_candidates[:astar_pos_t_array] = ->(a, b, t0) {
  yb, xb = b.divmod(width)
  Search.astar_fixed_cost([[a, t0]], neigh_pos_t_array, ->((pos, _)) {
    y, x = pos.divmod(width)
    (y - yb).abs + (x - xb).abs
  }, ->((pos, t)) { pos == b })
}

time_bits = wind_cycle.bit_length
time_mask = (1 << time_bits) - 1

neigh_pos_t_int = ->post {
  t = post & time_mask
  tnext = (t + 1) % wind_cycle
  neigh[post >> time_bits].filter_map { |npos| npos << time_bits | tnext unless bliz_at_t[tnext][npos] }
}

bench_candidates[:general_bfs_pos_t_int] = ->(a, b, t0) {
  r = Search.bfs([a << time_bits | (t0 % wind_cycle)], neighbours: neigh_pos_t_int, goal: ->post { post >> time_bits == b })
  raise 'not found' unless r[:found]
  r[:gen]
}

bench_candidates[:astar_pos_t_int] = ->(a, b, t0) {
  yb, xb = b.divmod(width)
  Search.astar_fixed_cost([a << time_bits | (t0 % wind_cycle)], neigh_pos_t_int, ->post {
    y, x = (post >> time_bits).divmod(width)
    (y - yb).abs + (x - xb).abs
  }, ->post { post >> time_bits == b })
}

neigh_just_pos = ->(pos, t) {
  tnext = (t + 1) % wind_cycle
  neigh[pos].reject { |npos| bliz_at_t[tnext][npos] }
}

# Specialised BFS that maintains invariant that all in frontier are at same time step.
# That means you only need a frontier set and not a visited set.
bench_candidates[:special_bfs_hash] = ->(a, b, t0) {
  t = t0
  poses = {a => true}.freeze
  until poses.has_key?(b)
    poses = poses.keys.flat_map { |pos| neigh_just_pos[pos, t] }.to_h { |pos| [pos, true] }.freeze
    t += 1
  end
  # could just return t, but will subtract t0 to keep same interface as others.
  t - t0
}

# Interestingly, using an array is slightly faster!
bench_candidates[:special_bfs_array] = ->(a, b, t0) {
  t = t0
  poses = [a].freeze
  until poses.include?(b)
    poses = poses.flat_map { |pos| neigh_just_pos[pos, t] }.uniq.freeze
    t += 1
  end
  # could just return t, but will subtract t0 to keep same interface as others.
  t - t0
}

bench_candidates[:special_bfs_bits] = ->(a, b, t0) {
  # others are using -width and size + width - 1, so we need to correct.
  a += width if a < 0
  b += width if b < 0
  a -= width if a >= size
  b -= width if b >= size

  t = t0
  read_poses = Array.new(height, 0)
  write_poses = Array.new(height, 0)
  ya, xa = a.divmod(width)
  yb, xb = b.divmod(width)

  # A specialised BFS is faster than A* or a generalised BFS here.
  # No visited set necessary, just bitfields for positions at a given time.
  until read_poses[yb][xb] != 0
    # Neighbours of previous positions.
    read_poses.each_with_index { |row, y|
      write_poses[y] = (row & ~leftmost) << 1 | row | row >> 1 | (y == 0 ? 0 : read_poses[y - 1]) | (read_poses[y + 1] || 0)
    }
    # Can always wait at the opening (no wind there), and move to the corner next to it.
    write_poses[ya] |= 1 << xa

    # Remove positions with blizzards.
    write_poses.map!.with_index { |row, y|
      horiz_shift = (t + 1) % width
      # Don't get confused about blizzard movements (they shift in the opposite direction of movement).
      # Left is moving to lower X, which is less-significant bits (right shift).
      orig_left = left_bliz[y]
      new_left = (orig_left | orig_left << width) >> horiz_shift
      # Right is moving to higher X, which is more-significant bits (left shift).
      orig_right = right_bliz[y]
      new_right = orig_right << horiz_shift | orig_right >> (width - horiz_shift)

      row & ~new_left & ~new_right & ~up_bliz[(y + t + 1) % height] & ~down_bliz[(y - t - 1) % height]
    }

    read_poses, write_poses = write_poses, read_poses
    t += 1
  end

  # could just return t, but will subtract t0 to keep same interface as others.
  t - t0 + 1
}

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |name, f|
    # These were defined earlier, but as a reminder:
    start = -width
    goal = size + width - 1

    bm.report(name) { 1.times {
      t1 = f[start, goal, 0]
      t2 = f[goal, start, t1]
      t3 = f[start, goal, t1 + t2]
      results[name] = [t1, t2, t3].freeze
    }}
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end

p results.values.uniq[0]
