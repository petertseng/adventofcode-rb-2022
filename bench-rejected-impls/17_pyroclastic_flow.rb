require 'benchmark'

bench_candidates = []

WIDTH = 7

ROCKS_ARRAY = [
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
  ].map(&:freeze).freeze,
  [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, 2],
    [2, 1],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [2, 2],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [0, 1],
    [1, 0],
    [1, 1],
  ].map(&:freeze).freeze,
].map { |rock| [rock, rock.map(&:last).max, rock.map(&:first).max].freeze }.freeze

ROCKS_BIT = [
  [
    0b1111,
  ].map(&:freeze).freeze,
  [
    0b010,
    0b111,
    0b010,
  ].map(&:freeze).freeze,
  [
    # rocks are bottom to top and also right-to-left,
    # so this one is rotated 180 degrees, sorry.
    0b111,
    0b100,
    0b100,
  ].map(&:freeze).freeze,
  [
    1,
    1,
    1,
    1,
  ].map(&:freeze).freeze,
  [
    0b11,
    0b11,
  ].map(&:freeze).freeze,
].map { |rock| [rock, rock.map { |n| n.to_s(2).count(?1) - 1 }.max, rock.size - 1].freeze }.freeze


def drop(rocks, prepare, collision, lock, nrocks, wind)
  wind_i = -1
  tallest = 0

  nrocks.times.map { |rock_i|
    rock, rock_width, rock_height = rocks[rock_i % 5]
    prepare[rock, rock_height, tallest]
    rock_left = 2
    rock_bottom = 3 + tallest

    loop {
      wind_dir = wind[(wind_i += 1) % wind.size]
      if 0 <= rock_left + wind_dir && rock_left + rock_width + wind_dir < WIDTH && !collision[rock, rock_bottom, rock_left + wind_dir]
        rock_left += wind_dir
      end

      if rock_bottom == 0 || collision[rock, rock_bottom - 1, rock_left]
        lock[rock, rock_bottom, rock_left]
        break tallest = [tallest, rock_bottom + rock_height + 1].max
      else
        rock_bottom -= 1
      end
    }
  }
end

bench_candidates << def array(...)
  occupied = []
  drop(
    ROCKS_ARRAY,
    ->(_, _, _) {},
    ->(rock, rock_bottom, rock_left) {
      rock.any? { |y, x| occupied[(y + rock_bottom) * WIDTH + x + rock_left] }
    },
    ->(rock, rock_bottom, rock_left) {
      rock.each { |y, x| occupied[(y + rock_bottom) * WIDTH + x + rock_left] = true }
    },
    ...
  )
end

bench_candidates << def bitwise(...)
  occupied = []
  drop(
    ROCKS_BIT,
    ->(rock, rock_height, tallest) {
      occupied.fill(0, occupied.size..(3 + tallest + rock_height))
    },
    ->(rock, rock_bottom, rock_left) {
      rock.each_with_index.any? { |row, y| occupied[y + rock_bottom] & row << rock_left != 0 }
    },
    ->(rock, rock_bottom, rock_left) {
      rock.each_with_index { |row, y| occupied[y + rock_bottom] |= row << rock_left }
    },
    ...
  )
end

dir = {?> => 1, ?< => -1}.freeze
wind = ARGF.read.chomp.each_char.map { |c| dir.fetch(c) }.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 2.times { results[f] = send(f, 5000, wind) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
