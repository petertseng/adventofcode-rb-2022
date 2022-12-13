verbose = ARGV.delete('-v')

using(Module.new {
  refine(Integer) {
    def <=>(that)
      that.is_a?(Array) ? [self] <=> that : self - that
    end
  }
  refine(Array) {
    # we can't include Comparable since it won't use the refined <=>
    def <(that)
      (self <=> that) < 0
    end

    def <=>(that)
      that = [that] if that.is_a?(Integer)
      zip(that) { |l, r|
        break unless r
        v = l <=> r
        return v if v != 0
      }
      size - that.size
    end
  }
})

# I refuse to use eval or JSON.parse, so I'm writing my own parser.
def packet(s, pos)
  case c = s[pos]
  when ?[
    list, new_pos = list_elements(s, pos + 1)
    raise "unclosed list at #{new_pos} (opened at #{pos})" if s[new_pos] != ?]
    [list.freeze, new_pos + 1]
  when ?0..?9
    v = Integer(c)
    while (?0..?9).cover?(c = s[pos += 1])
      v *= 10
      v += Integer(c)
    end
    [v, pos]
  else raise "expected list or number at #{pos}, not #{c}"
  end
end

def list_elements(s, pos)
  vs = []
  last_seen = nil

  while pos < s.size
    case s[pos]
    when ?[, ?0..?9
      v, pos = packet(s, pos)
      last_seen = :elt
      vs << v
    when ?,
      raise "can only have a comma after a list element at #{pos}, not #{last_seen}" if last_seen != :elt
      last_seen = :comma
      pos += 1
    when ?], nil
      raise "need a list element after a comma at #{pos}" if last_seen == :comma
      break
    else raise "expected list or number at #{pos}, not #{s[pos]}"
    end
  end

  [vs.freeze, pos]
end

pairs = ARGF.each("\n\n", chomp: true).map { |pair|
  lines = pair.lines(chomp: true)
  raise "#{lines.size} is not a pair" if lines.size != 2
  lines.map { |l| packet(l, 0).tap { |_, s| raise "unparsed #{l[s..]} (#{s} vs #{l.size})" if s != l.size }.first }.freeze
}.freeze

puts pairs.each_with_index.map { |(a, b), i| a < b ? i + 1 : 0 }.tap { p _1 if verbose }.sum

packets = pairs.flatten(1).freeze
marks = [[[2].freeze].freeze, [[6].freeze].freeze].freeze
mark_poses = marks.map.with_index(1) { |mark, i| packets.count { |pack| pack < mark } + i }
p mark_poses if verbose
puts mark_poses.reduce(:*)
