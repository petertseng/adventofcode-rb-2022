require 'benchmark'

bench_candidates = []

# Unknown grid size
# we'll assume they won't exceed approx 1<<29 in each direction.
# Two coordinates; (1<<60).object_id indicates it is still Fixnum, not Bignum.
COORD = 30
Y = 1 << COORD
ORIGIN = (Y / 2) << COORD | (Y / 2)
DIRS_FLAT = {
  ?L => -1,
  ?R => 1,
  ?U => -Y,
  ?D => Y,
}.freeze

DIRS_ARRAY = {
  ?L => [1, -1],
  ?R => [1, 1],
  ?U => [0, -1],
  ?D => [0, 1]
}.each_value(&:freeze).freeze

bench_candidates << def ropewise_int_coord(insts)
  rope = Array.new(10, ORIGIN)

  visit2 = {ORIGIN => true}
  visit10 = {ORIGIN => true}

  insts.each { |dir, n|
    dir = DIRS_FLAT.fetch(dir)

    n.times { |x|
      rope[0] += dir
      (1..9).each { |i|
        y, x = rope[i].divmod(Y)
        prevy, prevx = rope[i - 1].divmod(Y)
        dy = prevy - y
        dx = prevx - x
        break if dy.abs <= 1 && dx.abs <= 1

        rope[i] += (dy.abs == 1 ? dy : dy / 2) * Y + (dx.abs == 1 ? dx : dx / 2)
      }

      visit2[rope[1]] = true
      visit10[rope[-1]] = true
    }
  }
  [visit2.size, visit10.size]
end

bench_candidates << def ropewise_array_coord(insts)
  rope = Array.new(10) { [0, 0] }.freeze

  visit2 = {0 => true}
  visit10 = {0 => true}

  insts.each { |dir, n|
    coord, delta = DIRS_ARRAY.fetch(dir)

    n.times { |x|
      rope[0][coord] += delta
      (1..9).each { |i|
        knot = rope[i]
        dy = rope[i - 1][0] - knot[0]
        dx = rope[i - 1][1] - knot[1]
        break if dy.abs <= 1 && dx.abs <= 1

        knot[0] += dy.abs == 1 ? dy : dy / 2
        knot[1] += dx.abs == 1 ? dx : dx / 2

        visit2[knot[1] * Y + knot[0]] = true if i == 1
        visit10[knot[1] * Y + knot[0]] = true if i == 9
      }
    }
  }

  [visit2.size, visit10.size].freeze
end

bench_candidates << def knotwise_int_coord(insts)
  pos = ORIGIN
  head_poses = insts.flat_map { |dir, n|
    dpos = DIRS_FLAT.fetch(dir)
    n.times.map { pos += dpos }
  }.freeze

  visits2 = nil
  visits10 = nil
  following = head_poses

  9.times { |i|
    my_y, my_x = ORIGIN.divmod(Y)
    following = following.filter_map { |f|
      prevy, prevx = f.divmod(Y)
      dy = prevy - my_y
      dx = prevx - my_x
      next if dy.abs <= 1 && dx.abs <= 1
      my_y += dy.abs == 1 ? dy : dy / 2
      my_x += dx.abs == 1 ? dx : dx / 2
      my_y * Y + my_x
    }.freeze
    visits2 = (following + [ORIGIN]).uniq.size if i == 0
    visits10 = (following + [ORIGIN]).uniq.size if i == 8
  }

  [visits2, visits10]
end

bench_candidates << def knotwise_array_coord(insts)
  pos = [0, 0]
  head_poses = insts.flat_map { |dir, n|
    coord, delta = DIRS_ARRAY.fetch(dir)
    n.times.map {
      pos[coord] += delta
      pos.dup.freeze
    }
  }.freeze

  visits2 = nil
  visits10 = nil
  following = head_poses

  9.times { |i|
    my_pos = [0, 0]
    following = following.filter_map { |prevy, prevx|
      dy = prevy - my_pos[0]
      dx = prevx - my_pos[1]
      next if dy.abs <= 1 && dx.abs <= 1
      my_pos[0] += dy.abs == 1 ? dy : dy / 2
      my_pos[1] += dx.abs == 1 ? dx : dx / 2
      my_pos.dup.freeze
    }.freeze
    visits2 = (following + [[0, 0]]).uniq.size if i == 0
    visits10 = (following + [[0, 0]]).uniq.size if i == 8
  }

  [visits2, visits10]
end

insts = ARGF.map { |line|
  dir, n = line.split
  [dir.freeze, Integer(n)].freeze
}.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = send(f, insts) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
