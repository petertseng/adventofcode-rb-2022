PRIO = [*?a..?z, *?A..?Z].each.with_index(1).to_h.freeze

def common(*sacks)
  commons = sacks.map(&:chars).reduce(:&)
  raise "#{sacks} have nothing in common" if commons.empty?
  raise "#{sacks} have #{commons} in common" if commons.size > 1
  PRIO.fetch(commons[0])
end

sacks = ARGF.map(&:chomp).map(&:freeze).freeze

puts sacks.sum { |sack| common(sack[0, half = sack.size / 2], sack[half, half]) }
puts sacks.each_slice(3).sum { |group| common(*group) }
