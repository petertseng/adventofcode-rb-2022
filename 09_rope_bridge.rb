# We could actually get an upper bound from the input,
# by summing the L's and the R's, and doing (-l..r).size,
# but I don't care to do it and I'll just use a fixed value.
COORD = 30
Y = 1 << COORD
ORIGIN = (Y / 2) << COORD | (Y / 2)
DIRS = {
  ?L => -1,
  ?R => 1,
  ?U => -Y,
  ?D => Y,
}.freeze

pos = ORIGIN
head_poses = ARGF.flat_map { |line|
  dir, n = line.split
  dpos = DIRS.fetch(dir)
  Integer(n).times.map { pos += dpos }
}.freeze

following = head_poses

9.times { |i|
  my_y, my_x = ORIGIN.divmod(Y)
  following = following.filter_map { |f|
    prevy, prevx = f.divmod(Y)
    dy = prevy - my_y
    dx = prevx - my_x
    next if dy.abs <= 1 && dx.abs <= 1
    my_y += dy.abs == 1 ? dy : dy / 2
    my_x += dx.abs == 1 ? dx : dx / 2
    my_y * Y + my_x
  }.freeze
  puts (following + [ORIGIN]).uniq.size if i == 0 || i == 8
}
