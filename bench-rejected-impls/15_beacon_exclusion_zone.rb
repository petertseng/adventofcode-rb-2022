require 'benchmark'

bench_candidates = []

def xy(candidates, sensors, max_coord)
  candidates.filter_map { |xplusy, xminusy|
    twice_x = xplusy + xminusy
    next unless twice_x.even?
    x = twice_x / 2
    next unless (0..max_coord).cover?(x)
    y = xplusy - x
    next unless (0..max_coord).cover?(y)
    [y, x].freeze
  }.uniq.select { |y1, x1|
    sensors.none? { |y2, x2, r| (y2 - y1).abs + (x2 - x1).abs <= r }
  }.freeze
end

bench_candidates << def cartesian_product(sensors, max_coord)
  plus, minus = [+1, -1].map { |ymult|
    minus_r = sensors.map { |y, x, r| x + y * ymult - r - 1 }.freeze
    plus_r = sensors.map { |y, x, r| x + y * ymult + r + 1 }.freeze
    (minus_r & plus_r).freeze
  }

  xy(plus.product(minus), sensors, max_coord)
end

# Assumes without checking that input intervals are sorted by start time.
def merge(intervals, merge_adjacent: true)
  prev_min, prev_max = intervals.first
  (intervals.each_with_object([]) { |r, merged|
    min, max = r
    if min > prev_max + (merge_adjacent ? 1 : 0)
      merged << [prev_min, prev_max].freeze
      prev_min, prev_max = r
    else
      prev_max = [prev_max, max].max
    end
  } << [prev_min, prev_max].freeze).freeze
end

bench_candidates << def sweep(sensors, max_coord)
  xplusy_events = sensors.flat_map { |y, x, r|
    xminusy_interval = [x - y - r, x - y + r].freeze
    [
      [x + y - r, :add, xminusy_interval],
      [x + y + r, :del, xminusy_interval],
    ].map(&:freeze)
  }.sort_by(&:first).freeze

  candidates = []
  # TODO: Consider a sorted collection
  active_xminusy_intervals = []

  xplusy_events.each { |xplusy, event, xminusy|
    case event
    when :add
      unless active_xminusy_intervals.empty?
        active_xminusy_intervals.sort!
        merged = merge(active_xminusy_intervals)
        candidates << [xplusy - 1, merged[0][1] + 1] if merged.size == 2 && merged[0][1] + 2 == merged[1][0]
      end
      active_xminusy_intervals << xminusy
    when :del
      active_xminusy_intervals.delete(xminusy)
    else raise "bad #{event}"
    end
  }

  xy(candidates, sensors, max_coord)
end

sensor = /\ASensor at x=(-?\d+), y=(-?\d+): closest beacon is at x=(-?\d+), y=(-?\d+)$/
sensors = ARGF.map { |line|
  raise "bad #{line}" unless m = sensor.match(line)
  x1, y1, x2, y2 = m[1..4].map(&method(:Integer))
  [y1, x1, (y2 - y1).abs + (x2 - x1).abs].freeze
}.freeze

target = sensors.size == 14 ? 10 : 2_000_000
max_coord = target * 2

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 100.times { results[f] = send(f, sensors, max_coord) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
