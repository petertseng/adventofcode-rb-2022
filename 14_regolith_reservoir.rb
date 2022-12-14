blocked = Hash.new { |h, k| h[k] = {} }

ARGF.each_line(chomp: true) { |line|
  line.split(' -> ').map { |pt| pt.split(?,).map(&method(:Integer)).freeze }.each_cons(2) { |(x1, y1), (x2, y2)|
    if x1 == x2
      y1, y2 = y2, y1 if y1 > y2
      (y1..y2).each { |y| blocked[y][x1] = true }
    elsif y1 == y2
      x1, x2 = x2, x1 if x1 > x2
      (x1..x2).each { |x| blocked[y1][x] = true }
    else
      raise "bad pair #{x1} #{y1} #{x2} #{y2}"
    end
  }
}

rested = 0
abyss = blocked.keys.max + 1
first_abyss = false

blocked[abyss + 1] = Hash.new(true)

sand = ->(y, x) {
  return if blocked[y][x]

  if y >= abyss && !first_abyss
    puts rested
    first_abyss = true
  end

  sand[y + 1, x]
  sand[y + 1, x - 1]
  sand[y + 1, x + 1]

  rested += 1
  blocked[y][x] = true
}

sand[0, 500]
puts rested
