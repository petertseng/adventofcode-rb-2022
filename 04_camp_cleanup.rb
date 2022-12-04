module RangeIntersection
  refine(Range) {
    def intersect?(them)
      self.begin <= them.end && them.begin <= self.end
    end
  }
end

using RangeIntersection

pairs = ARGF.map { |l|
  l.split(?,, 2).map { |elf|
    Range.new(*elf.split(?-, 2).map(&method(:Integer)))
  }.freeze
}.freeze

puts pairs.count { |a, b| a.cover?(b) || b.cover?(a) }
puts pairs.count { |a, b| a.intersect?(b) }
