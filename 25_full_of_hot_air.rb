verbose = ARGV.delete('-v')

snafu = {
  ?= => -2,
  ?- => -1,
  ?0 => 0,
  ?1 => 1,
  ?2 => 2,
}.freeze

carry = 0
puts ARGF.sum { |line|
  line.chomp.chars.reduce(0) { |acc, c| acc * 5 + snafu.fetch(c) }
}.tap { puts _1 if verbose }.digits(5).map { |d|
  %w(0 1 2 = - 0).fetch((d + carry).tap { |d2| carry = d2 >= 3 ? 1 : 0 })
}.reverse.join
