left_bliz = []
right_bliz = []
up_bliz = []
down_bliz = []
add = ->(a, y, x) {
  a[y] ||= 0
  a[y] |= 1 << x
}

# coordinate convention:
# top-left of the rectangular area is (0, 0)
# bottom-right is (h - 1, w - 1)
# we start at (-1, 0) (one above top-left)
# we want to end at (h, w - 1) (one below bottom-right)
widths = ARGF.map.with_index { |line, y|
  line.chomp.chars.each_with_index { |c, x|
    case c
    when ?<; add[left_bliz, y - 1, x - 1]
    when ?>; add[right_bliz, y - 1, x - 1]
    when ?^; add[up_bliz, y - 1, x - 1]
    when ?v; add[down_bliz, y - 1, x - 1]
    when ?# # OK
    when ?. # OK
    else raise "bad char #{c}"
    end
  }.size
}.freeze

height = widths.size - 2
width = widths[0] - 2
raise "inconsistent width #{widths}" if widths.any? { |w| w - 2 != width }
size = height * width

leftmost = 1 << (width - 1)

[left_bliz, right_bliz, up_bliz, down_bliz].each { |bliz|
  height.times { |y| bliz[y] ||= 0 }
}

# Our strategies rely on there not being up/down blizzards in the leftmost/rightmost columns.
{up: up_bliz, down: down_bliz}.each { |name, bliz|
  height.times { |y|
    raise "forbidden #{name} blizzard in leftmost of #{y}" if bliz[y][0] != 0
    raise "forbidden #{name} blizzard in rightmost of #{y}" if bliz[y][width - 1] != 0
  }
}

# We'll actually just use the corners (0, 0) and (h - 1, w - 1),
# because that way I don't need to add two extra rows of bits.
# The end is handled by checking whether you reached the closest corner and adding 1 to travel time.
# The start is handled by always adding the closest corner to the set of possible positions,
# since you can wait there an arbitrary number of minutes.
# (Both are possible because there are no up/down winds in the leftmost/rightmost columns)
start = 0
goal = size - 1

# Our inputs are wideer than tall, so storing an entire row is better (height < width)
# If our inputs were taller than wide, we would actually want to store an entire column.
# But I'll not complicate things.

fastest = ->(a, b, t0) {
  t = t0
  read_poses = Array.new(height, 0)
  write_poses = Array.new(height, 0)
  ya, xa = a.divmod(width)
  yb, xb = b.divmod(width)

  # A specialised BFS is faster than A* or a generalised BFS here.
  # No visited set necessary, just bitfields for positions at a given time.
  until read_poses[yb][xb] != 0
    # Neighbours of previous positions.
    read_poses.each_with_index { |row, y|
      write_poses[y] = (row & ~leftmost) << 1 | row | row >> 1 | (y == 0 ? 0 : read_poses[y - 1]) | (read_poses[y + 1] || 0)
    }
    # Can always wait at the opening (no wind there), and move to the corner next to it.
    write_poses[ya] |= 1 << xa

    # Remove positions with blizzards.
    write_poses.map!.with_index { |row, y|
      horiz_shift = (t + 1) % width
      # Don't get confused about blizzard movements (they shift in the opposite direction of movement).
      # Left is moving to lower X, which is less-significant bits (right shift).
      orig_left = left_bliz[y]
      new_left = (orig_left | orig_left << width) >> horiz_shift
      # Right is moving to higher X, which is more-significant bits (left shift).
      orig_right = right_bliz[y]
      new_right = orig_right << horiz_shift | orig_right >> (width - horiz_shift)

      row & ~new_left & ~new_right & ~up_bliz[(y + t + 1) % height] & ~down_bliz[(y - t - 1) % height]
    }

    read_poses, write_poses = write_poses, read_poses
    t += 1
  end
  # We moved to the corner next to the goal, so we need to add 1 to actually reach the goal.
  t + 1
}

t1 = fastest[start, goal, 0]
puts t1
t2 = fastest[goal, start, t1]
puts fastest[start, goal, t2]
