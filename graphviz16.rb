require_relative 'lib/search'

graphviz = ARGV.delete('-g')

valve = /\AValve ([A-Z]{2}) has flow rate=(\d+); tunnels? leads? to valves? ([A-Z]{2}(, [A-Z]{2})*)/
rate, neigh = ARGF.each_line(chomp: true).with_object([{}, {}]) { |line, (rate, neigh)|
  raise "bad #{line}" unless m = valve.match(line)
  rate[m[1]] = Integer(m[2])
  neigh[m[1]] = m[3].split(', ').map(&:freeze).freeze
}.map(&:freeze)

useful = rate.select { |_, v| v > 0 }

# could use Floyd-Warshall here, but I don't feel like it.
dist = (useful.keys + ['AA']).to_h { |k|
  [k, Search.bfs([k], neighbours: neigh, num_goals: useful.size, goal: useful)[:goals]]
}.freeze

puts 'strict graph {'
(useful.keys + ['AA']).each { |name|
  puts "  #{name} [label=\"#{name} #{rate[name] || 0}\"]"
}

(useful.keys + ['AA']).combination(2) { |name1, name2|
  # if its AA, dist graph only has AA to other node,
  # and AA will come second (it's last in the list),
  # so we need to look up by name2 first
  puts "  #{name1} -- #{name2} [len=#{dist[name2][name1]}]"
}
puts ?}
