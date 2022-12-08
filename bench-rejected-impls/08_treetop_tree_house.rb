require 'benchmark'

bench_candidates = []

bench_candidates << def find_index_block(trees, height, width)
  trees.each_with_index.map { |row, y|
    row.each_with_index.map { |tree, x|
      hit_edge = false
      trees_in_dir = ->(range, &b) { range.find_index { b[_1] >= tree }&.succ || (hit_edge = true; range.size) }

      left  = trees_in_dir[(x - 1).downto(0)] { |xx| trees[y][xx] }
      right = trees_in_dir[(x + 1)...width]   { |xx| trees[y][xx] }
      up    = trees_in_dir[(y - 1).downto(0)] { |yy| trees[yy][x] }
      down  = trees_in_dir[(y + 1)...height]  { |yy| trees[yy][x] }

      [hit_edge, left * right * up * down].freeze
    }.freeze
  }.freeze
end

bench_candidates << def find_index_dig(trees, height, width)
  trees.each_with_index.map { |row, y|
    row.each_with_index.map { |tree, x|
      hit_edge = false
      trees_in_dir = ->(range, coord) {
        pos = [y, x]
        range.find_index { pos[coord] = _1; trees.dig(*pos) >= tree }&.succ || (hit_edge = true; range.size)
      }

      left  = trees_in_dir[(x - 1).downto(0), 1]
      right = trees_in_dir[(x + 1)...width, 1]
      up    = trees_in_dir[(y - 1).downto(0), 0]
      down  = trees_in_dir[(y + 1)...height, 0]

      [hit_edge, left * right * up * down].freeze
    }.freeze
  }.freeze
end

bench_candidates << def scan_one_write_many_reads(trees, height, width)
  vis_and_scores = trees.each_with_index.map { |row, y|
    row.each_with_index.map { |tree, x| [false, 1] }.freeze
  }.freeze

  trees.each_with_index { |row, y|
    prev_blocker = Array.new(10)

    row.each_with_index { |tree, x|
      left = if prev = prev_blocker[tree..].compact.max
        x - prev
      else
        vis_and_scores[y][x][0] = true
        x
      end
      prev_blocker[tree] = x
      vis_and_scores[y][x][1] *= left
    }

    prev_blocker = Array.new(10)

    row.reverse_each.with_index { |tree, rev_x|
      fwd_x = width - 1 - rev_x

      right = if prev = prev_blocker[tree..].compact.max
        rev_x - prev
      else
        vis_and_scores[y][fwd_x][0] = true
        rev_x
      end
      prev_blocker[tree] = rev_x
      vis_and_scores[y][fwd_x][1] *= right
    }
  }

  (0...width).each { |x|
    prev_blocker = Array.new(10)

    trees.each_with_index { |row, y|
      tree = row[x]

      up = if prev = prev_blocker[tree..].compact.max
        y - prev
      else
        vis_and_scores[y][x][0] = true
        y
      end
      prev_blocker[tree] = y
      vis_and_scores[y][x][1] *= up
    }

    prev_blocker = Array.new(10)

    trees.reverse_each.with_index { |row, rev_y|
      tree = row[x]
      fwd_y = height - 1 - rev_y

      down = if prev = prev_blocker[tree..].compact.max
        rev_y - prev
      else
        vis_and_scores[fwd_y][x][0] = true
        rev_y
      end
      prev_blocker[tree] = rev_y
      vis_and_scores[fwd_y][x][1] *= down
    }
  }

  vis_and_scores.each { _1.each(&:freeze) }
end

bench_candidates << def scan_one_read_many_writes(trees, height, width)
  vis_and_scores = trees.each_with_index.map { |row, y|
    row.each_with_index.map { |tree, x| [false, 1] }.freeze
  }.freeze

  trees.each_with_index { |row, y|
    prev_blocker = Array.new(10)

    row.each_with_index { |tree, x|
      left = if prev = prev_blocker[tree]
        x - prev
      else
        vis_and_scores[y][x][0] = true
        x
      end
      prev_blocker.fill(x, 0, tree + 1)
      vis_and_scores[y][x][1] *= left
    }

    prev_blocker = Array.new(10)

    row.reverse_each.with_index { |tree, rev_x|
      fwd_x = width - 1 - rev_x

      right = if prev = prev_blocker[tree]
        rev_x - prev
      else
        vis_and_scores[y][fwd_x][0] = true
        rev_x
      end
      prev_blocker.fill(rev_x, 0, tree + 1)
      vis_and_scores[y][fwd_x][1] *= right
    }
  }

  (0...width).each { |x|
    prev_blocker = Array.new(10)

    trees.each_with_index { |row, y|
      tree = row[x]

      up = if prev = prev_blocker[tree]
        y - prev
      else
        vis_and_scores[y][x][0] = true
        y
      end
      prev_blocker.fill(y, 0, tree + 1)
      vis_and_scores[y][x][1] *= up
    }

    prev_blocker = Array.new(10)

    trees.reverse_each.with_index { |row, rev_y|
      tree = row[x]
      fwd_y = height - 1 - rev_y

      down = if prev = prev_blocker[tree]
        rev_y - prev
      else
        vis_and_scores[fwd_y][x][0] = true
        rev_y
      end
      prev_blocker.fill(rev_y, 0, tree + 1)
      vis_and_scores[fwd_y][x][1] *= down
    }
  }

  vis_and_scores.each { _1.each(&:freeze) }
end

trees = ARGF.map { |line|
  line.map.chars.map(&method(:Integer)).freeze
}.freeze
height = trees.size
width = trees[0].size
raise "inconsistent width #{trees.map(&:size)}" if trees.any? { |row| row.size != width }

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 3.times { results[f] = send(f, trees, height, width) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
