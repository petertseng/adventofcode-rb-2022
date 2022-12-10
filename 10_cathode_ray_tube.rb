x = 1

sig = ARGF.flat_map { |line|
  case line.split
  in ['noop']; [x]
  in ['addx', n]; [x, x += Integer(n)]
  else raise "bad line #{line}"
  end
  # Time convention: sig[n - 1] is the signal DURING the nth cycle.
  # Since the effect of an addx executed at the first cycle isn't visible until DURING the third,
  # we will need to prepend a 1 to the start.
}.unshift(1).tap(&:pop).freeze

raise "bad size #{sig.size}" if sig.size != 240

puts ((20..220) % 40).sum { |t| t * sig[t - 1] }

sig.each_slice(40) { |row|
  puts row.map.with_index { |c, x|
    (c - x).abs <= 1 ? ?# : ' '
  }.join
}
