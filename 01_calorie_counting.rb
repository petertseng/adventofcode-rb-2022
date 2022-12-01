verbose = ARGV.delete('-v')
elves = ARGF.each("\n\n", chomp: true).map { |elf| elf.lines.map(&method(:Integer)).sum }.freeze
tops = elves.max(3)

p tops if verbose
puts tops[0]
puts tops.sum
