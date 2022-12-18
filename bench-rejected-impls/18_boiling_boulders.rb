require_relative '../lib/search'

require 'benchmark'

bench_candidates = []

def adj6((x, y, z))
  [
    [x - 1, y, z],
    [x + 1, y, z],
    [x, y - 1, z],
    [x, y + 1, z],
    [x, y, z - 1],
    [x, y, z + 1],
  ].map(&:freeze).freeze
end

def padrange(xs)
  xmin, xmax = xs.minmax
  (xmin - 1)..(xmax + 1)
end

# dedup vs no deup makes no difference at all.
# flat_coord is a 5x speedup.

bench_candidates << def no_dedup(rocks)
  faces = rocks.keys.flat_map(&method(:adj6)).freeze

  xs, ys, zs = rocks.keys.transpose.map(&method(:padrange))
  air = Search.bfs([[0, 0, 0]], neighbours: ->pt {
    adj6(pt).select { |neigh| !rocks[neigh] && xs.cover?(neigh[0]) && ys.cover?(neigh[1]) && zs.cover?(neigh[2]) }
  }, goal: Hash.new(true).freeze, num_goals: [xs, ys, zs].map(&:size).reduce(:*))[:goals]

  [
    faces.count { |face| !rocks[face] },
    faces.count { |face| !rocks[face] && air[face] },
  ]
end

bench_candidates << def dedup(rocks)
  faces = rocks.keys.flat_map(&method(:adj6)).tally.freeze

  xs, ys, zs = rocks.keys.transpose.map(&method(:padrange))
  air = Search.bfs([[0, 0, 0]], neighbours: ->pt {
    adj6(pt).select { |neigh| !rocks[neigh] && xs.cover?(neigh[0]) && ys.cover?(neigh[1]) && zs.cover?(neigh[2]) }
  }, goal: Hash.new(true).freeze, num_goals: [xs, ys, zs].map(&:size).reduce(:*))[:goals]

  [
    faces.sum { |face, count| rocks[face] ? 0 : count },
    faces.sum { |face, count| rocks[face] || !air[face] ? 0 : count },
  ]
end

bench_candidates << def flat_coord(rocks)
  xs, ys, zs = rocks.keys.transpose.map(&method(:padrange))
  width = xs.size
  area = xs.size * ys.size
  adj6_flat = ->pt { [pt - 1, pt + 1, pt - width, pt + width, pt - area, pt + area].freeze }
  flatten = ->((x, y, z)) { x + y * width + z * area }
  rocks = rocks.transform_keys(&flatten).freeze
  faces = rocks.keys.flat_map(&adj6_flat).tally.freeze
  space = flatten[[xs.begin, ys.begin, zs.begin]]..flatten[[xs.end, ys.end, zs.end]]

  air = Search.bfs([0], neighbours: ->pt {
    adj6_flat[pt].select { |neigh| !rocks[neigh] && space.cover?(neigh) }
  }, goal: Hash.new(true).freeze, num_goals: [xs, ys, zs].map(&:size).reduce(:*))[:goals]

  [
    faces.sum { |face, count| rocks[face] ? 0 : count },
    faces.sum { |face, count| rocks[face] || !air[face] ? 0 : count },
  ]
end

rocks = ARGF.to_h { |line|
  [line.split(?,, 3).map(&method(:Integer)).freeze, true]
}.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = send(f, rocks) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
