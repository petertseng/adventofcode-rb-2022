require_relative 'lib/search'

verbose = ARGV.delete('-v')
map = ARGV.delete('-m')

start = nil
starts = []
goal = nil
elev = ARGF.map.with_index { |line, y|
  line.chomp.chars.map.with_index { |c, x|
    case c
    when ?S
      starts << [y, x].freeze
      raise "already have start #{start} vs #{[y, x]}" if start
      start = [y, x].freeze
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

start = start[0] * width + start[1]
goal = goal[0] * width + goal[1]

starts.map! { |y, x| y * width + x }.freeze

neigh = ->pos {
  y, x = pos.divmod(width)
  current_elev = elev[pos]
  [
    (pos - width if y > 0),
    (pos - 1 if x > 0),
    (pos + 1 if x + 1 < width),
    (pos + width if y + 1 < height),
  ].select { |npos| npos && elev[npos] >= current_elev - 1 }
}

show = ->search {
  raise 'not found' unless search[:found]
  search[:paths].each { |_goal, path|
    puts path.each_cons(2).map { |p1, p2| elev[p1] - elev[p2] }.sort.tally
  } if verbose
  if map
    colour = search[:paths].flat_map { |_, path| path.each_cons(2).map { |p1, p2|
      [p1, elev[p1] - elev[p2] < 0 ? 31 : 32]
    }.concat([[path[0], 34], [path[-1], 34]])}.to_h
    elev.each_slice(width).with_index { |row, y|
      puts row.map.with_index { |e, x|
        pos = y * width + x
        "#{"\e[#{colour[pos] || 0}m"}#{(?a.ord + e).chr}\e[0m"
      }.join
    }
  end
  puts search[:gen]
}

show[Search.bfs([goal], neighbours: neigh, goal: {start => true}.freeze, verbose: verbose || map)]
show[Search.bfs([goal], neighbours: neigh, goal: starts.to_h { |s| [s, true] }.freeze, verbose: verbose || map)]
