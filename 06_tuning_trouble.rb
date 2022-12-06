def marker(s, n)
  last_seen = Array.new(26, -n)
  first_possible = n
  a = ?a.ord
  s.each_char.with_index { |c, i|
    return i if first_possible == i
    o = c.ord - a
    prev = last_seen[o]
    first_possible = [first_possible, prev + n + 1].max if i - prev < n
    last_seen[o] = i
  }
  raise 'no marker'
end

signal = ARGF.read.freeze

[4, 14].each { |n| puts marker(signal, n) }
