verbose = ARGV.delete('-v')

beacons_at = {
  10 => {},
  2_000_000 => {},
}.freeze

sensor = /\ASensor at x=(-?\d+), y=(-?\d+): closest beacon is at x=(-?\d+), y=(-?\d+)$/
sensors = ARGF.map { |line|
  raise "bad #{line}" unless m = sensor.match(line)
  x1, y1, x2, y2 = m[1..4].map(&method(:Integer))
  beacons_at[y2]&.[]=(x2, true)
  [y1, x1, (y2 - y1).abs + (x2 - x1).abs].freeze
}.freeze

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

target = sensors.size == 14 ? 10 : 2_000_000

ranges = merge(sensors.filter_map { |y, x, r|
  remain_dist = r - (y - target).abs
  if remain_dist < 0
    puts "#{[y, x, r]} too far" if verbose
  else
    [x - remain_dist, x + remain_dist].freeze.tap { |xl, xr| puts "#{[y, x, r]} #{xl..xr}" if verbose }
  end
}.sort).freeze

p ranges if verbose

puts ranges.sum { |l, r| (l..r).size } - beacons_at[target].size

max_coord = target * 2

plus, minus = [+1, -1].map { |ymult|
  minus_r = sensors.map { |y, x, r| x + y * ymult - r - 1 }.freeze
  plus_r = sensors.map { |y, x, r| x + y * ymult + r + 1 }.freeze
  (minus_r & plus_r).freeze
}

candidates = plus.product(minus).filter_map { |xplusy, xminusy|
  twice_x = xplusy + xminusy
  next unless twice_x.even?
  x = twice_x / 2
  next unless (0..max_coord).cover?(x)
  y = xplusy - x
  next unless (0..max_coord).cover?(y)
  [y, x].freeze
}.uniq.freeze

if verbose
  puts "x + y: #{plus}"
  puts "x - y: #{minus}"
  puts "candidates: #{candidates}"
end

winner = candidates.select { |y1, x1|
  sensors.none? { |y2, x2, r| (y2 - y1).abs + (x2 - x1).abs <= r }
}.freeze
raise "expected one winner: #{winner}" if winner.size != 1

y, x = winner[0]
puts x * 4_000_000 + y
