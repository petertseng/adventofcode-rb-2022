verbose = ARGV.delete('-v')
elves = ARGF.read.split("\n\n").map { |elf| elf.lines.map(&method(:Integer)).sum }.freeze
tops = elves.max(3)

p tops if verbose
puts tops[0]
puts tops.sum
