require_relative '../lib/priority_queue'
require_relative '../lib/search'

require 'benchmark'

def astar_fixed_cost_queues(starts, neighbours, heuristic, goal)
  g_score = Hash.new(1.0 / 0.0)
  starts.each { |start| g_score[start] = 0 }

  closed = {}

  # The heuristic changes by at most 25 per step, so differences can be 0-26.
  # (though realistically we only queue at +3 at most)
  opens = Array.new(27) { [] }
  opens[0].concat(starts)
  prev = {}

  while (open = opens.shift)
    open.each { |current|
      next if closed[current]
      closed[current] = true
      hcurr = heuristic[current]

      return g_score[current] if goal[current]

      neighbours[current].each { |neighbour|
        cost = 1
        next if closed[neighbour]
        tentative_g_score = g_score[current] + cost
        next if tentative_g_score >= g_score[neighbour]

        g_score[neighbour] = tentative_g_score
        opens[cost - hcurr + heuristic[neighbour]] << neighbour
      }
    }
    opens << []
  end

  nil
end

bench_candidates = []

bench_candidates << def bfs_forward(elev, width, height, starts, goal)
  r = Search.bfs(starts, neighbours: ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] <= current_elev + 1 }
  }, goal: {goal => true}.freeze)
  r[:found] && r[:gen]
end

bench_candidates << def bfs_backward(elev, width, height, starts, goal)
  r = Search.bfs([goal], neighbours: ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] >= current_elev - 1 }
  }, goal: starts.to_h { |s| [s, true] }.freeze)
  r[:found] && r[:gen]
end

bench_candidates << def astar_forward_dist_heur(elev, width, height, starts, goal)
  goal_y, goal_x = goal.divmod(width)
  Search.astar_fixed_cost(starts, ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] <= current_elev + 1 }
  }, ->pos {
    y, x = pos.divmod(width)
    (y - goal_y).abs + (x - goal_x).abs
  }, {goal => true}.freeze)
end

bench_candidates << def astar_forward_elev_heur(elev, width, height, starts, goal)
  goal_y, goal_x = goal.divmod(width)
  Search.astar_fixed_cost(starts, ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] <= current_elev + 1 }
  }, ->pos { 25 - elev[pos] }, {goal => true}.freeze)
end

bench_candidates << def astar_forward_both_heur(elev, width, height, starts, goal)
  goal_y, goal_x = goal.divmod(width)
  Search.astar_fixed_cost(starts, ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] <= current_elev + 1 }
  }, ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [25 - current_elev, (y - goal_y).abs + (x - goal_x).abs].max
  }, {goal => true}.freeze)
end

bench_candidates << def astar_forward_elev_heur_cache_elev(elev, width, height, starts, goal)
  goal_y, goal_x = goal.divmod(width)
  Search.astar_fixed_cost(starts.map { |start| start << 5 }, ->pos_and_elev {
    pos = pos_and_elev >> 5
    y, x = pos.divmod(width)
    current_elev = pos_and_elev & 0x1f
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].filter_map { |npos|
      next unless npos
      new_elev = elev[npos]
      next unless new_elev <= current_elev + 1
      npos << 5 | new_elev
    }
  }, ->pos { 25 - pos & 0x1f }, {goal << 5 | 25 => true}.freeze)
end

bench_candidates << def astar_backward_elev_heur(elev, width, height, starts, goal)
  Search.astar_fixed_cost([goal], ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] >= current_elev - 1 }
  }, ->pos { elev[pos] }, starts.to_h { |s| [s, true] }.freeze)
end

bench_candidates << def astar_backward_elev_heur_queues(elev, width, height, starts, goal)
  astar_fixed_cost_queues([goal], ->pos {
    y, x = pos.divmod(width)
    current_elev = elev[pos]
    [
      (pos - width if y > 0),
      (pos - 1 if x > 0),
      (pos + 1 if x + 1 < width),
      (pos + width if y + 1 < height),
    ].select { |npos| npos && elev[npos] >= current_elev - 1 }
  }, ->pos { elev[pos] }, starts.to_h { |s| [s, true] }.freeze)
end

start = nil
starts = []
goal = nil
elev = ARGF.map.with_index { |line, y|
  line.chomp.chars.map.with_index { |c, x|
    case c
    when ?S
      starts << [y, x].freeze
      raise "already have start #{start} vs #{[y, x]}" if start
      0
    when ?E
      raise "already have goal #{goal} vs #{[y, x]}" if goal
      goal = [y, x].freeze
      25
    when ?a
      starts << [y, x].freeze
      0
    when ?b..?z
      c.ord - ?a.ord
    else
      raise "bad char #{c} at #{y} #{x}"
    end
  }.freeze
}.freeze

height = elev.size
width = elev[0].size
raise "inconsistent width #{elev.map(&:size)}" if elev.any? { |row| row.size != width }
elev = elev.flatten.freeze

goal = goal[0] * width + goal[1]

starts.map! { |y, x| y * width + x }.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 10.times { results[f] = send(f, elev, width, height, starts, goal) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
