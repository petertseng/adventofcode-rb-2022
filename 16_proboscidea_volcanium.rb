require_relative 'lib/search'

verbose = ARGV.delete('-v')

valve = /\AValve ([A-Z]{2}) has flow rate=(\d+); tunnels? leads? to valves? ([A-Z]{2}(, [A-Z]{2})*)$/
rate, neigh = ARGF.each_with_object([{}, {}]) { |line, (rate, neigh)|
  raise "bad #{line}" unless m = valve.match(line)
  rate[m[1]] = Integer(m[2])
  neigh[m[1]] = m[3].split(', ').map(&:freeze).freeze
}.map(&:freeze)

useful = rate.select { |_, v| v > 0 }
raise "AA can't be useful" if useful['AA']
ids = (useful.keys + ['AA']).each_with_index.to_h.freeze
names = ->bits { ids.select { |name, i| bits[i] != 0 }.keys }

# convert a hash whose keys are 0, 1, 2... N to an array.
# hash[k] == array[k]
htoa = ->h {
  raise "bad #{h.keys.sort}" if h.keys.sort != (0...h.size).to_a
  h.sort_by(&:first).map(&:last).freeze
}

rate = htoa[useful.transform_keys(&ids)]

# could use Floyd-Warshall here, but I don't feel like it.
dist = htoa[(useful.keys + ['AA']).to_h { |k|
  [ids[k], htoa[Search.bfs([k], neighbours: neigh, num_goals: useful.size, goal: useful)[:goals].transform_keys(&ids)]]
}.freeze]

USEFUL_ROOM_BITS = (1 << useful.size) - 1

def best_by_opened(rate, dist, time)
  time_bits = 30.bit_length
  time_offset = rate.size
  loc_offset = time_offset + time_bits

  seen_state = {}
  best_by_opened = Hash.new(0)

  search = ->(loc, time_left, opened, flow) {
    best_by_opened[opened] = [best_by_opened[opened], flow].max
    return if time_left <= 2

    cache_key = loc << loc_offset | time_left << time_offset | opened
    return if seen_state[cache_key] &.> flow
    seen_state[cache_key] = flow

    remain_rooms = USEFUL_ROOM_BITS & ~opened

    dest = 0
    until remain_rooms == 0
      if remain_rooms & 1 != 0
        my_time_left = time_left - dist[loc][dest] - 1
        search[dest, my_time_left, opened | 1 << dest, flow + rate[dest] * my_time_left] if my_time_left > 0
      end
      remain_rooms >>= 1
      dest += 1
    end
  }

  aa = rate.size
  search[aa, time, 0, 0]

  best_by_opened.freeze
end

opened, best_flow = best_by_opened(rate, dist, 30).max_by(&:last)
puts best_flow
p names[opened] if verbose

# Generate all routes for one person,
# then find the best pair of disjoint routes.
#
# Instead of combination(2), we actually want to sort and manually check pairs,
# so that we can exit early if a pair can't beat the best so far.
#puts best_by_opened(rate, dist, 26).to_a.combination(2).select { |(b1, _), (b2, _)| b1 & b2 == 0 }.map { |(_, f1), (_, f2)| f1 + f2 }.max
routes = best_by_opened(rate, dist, 26).sort_by { |_, flow| -flow }

best_flow = 0
best_pair = nil

routes.each_with_index { |(bits1, flow1), i|
  break if flow1 * 2 < best_flow

  ((i + 1)...routes.size).each { |j|
    bits2, flow2 = routes[j]
    break if flow1 + flow2 < best_flow

    if bits1 & bits2 == 0 && flow1 + flow2 > best_flow
      best_flow = flow1 + flow2
      best_pair = routes.values_at(i, j).freeze
    end
  }
}

puts best_pair.sum(&:last)
p best_pair.map { |bits, flow| [names[bits], flow] } if verbose
