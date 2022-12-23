# bitwise, first seen in https://github.com/SLiV9/AdventOfCode2022/blob/main/src/bin/day23/main.rs
# https://www.reddit.com/r/adventofcode/comments/zt6xz5/comment/j1faxrh/

num_elves = 0
# we place smallest X coordinates in most-significant bits.
# thus, looking eastward is looking toward less-significant bits,
# and looking westward is looking toward more-significant bits.
read_grid = ARGF.map { |line|
  num_elves += line.count(?#)
  line.chomp.chars.reduce(0) { |acc, c| acc << 1 | {?# => 1, ?. => 0}.fetch(c) }
}
write_grid = []

considers = %i(north south west east)

puts 1.step { |time|
  # Proposal conflicts are only possible by two elves in opposite directions.
  # Two elves at right angles to each other simply cannot propose the same destination.
  # We can resolve any east/west conflicts immediately in the same row.
  # We'll have to delay north/south by storing the last two rows of south proposals.
  prev_prev_south = 0
  prev_south = 0
  # the row loop is assuming that read_grid[i] writes to write_grid[i];
  # if we need to prepend a row (from 0 moving north), delay it to not violate that assumption.
  # we could just prepend it immediately and just offset all write indices by +1,
  # but I didn't feel like writing the code this way.
  row_to_prepend = 0
  # Ordinarily, a 1 bit in the LSB moving east (right shift) would just disappear.
  # We'll need to track such disappearancs and correct them all (by shifting all rows left).
  rows_extending_east = []

  any_moved = false

  read_grid.each_with_index { |row, i|
    north = i == 0 ? 0 : read_grid[i - 1]
    northwest = north >> 1
    northeast = north << 1
    norths = north | northwest | northeast

    south = read_grid[i + 1] || 0
    southwest = south >> 1
    southeast = south << 1
    souths = south | southwest | southeast

    west = row >> 1
    east = row << 1

    lonely = row & ~west & ~east & ~norths & ~souths
    can_move = row & ~lonely

    propose_north = 0
    propose_south = 0
    propose_east = 0
    propose_west = 0

    considers.each { |cons|
      case cons
      when :north
        propose_north = can_move & ~norths
        can_move &= ~propose_north
      when :south
        propose_south = can_move & ~souths
        can_move &= ~propose_south
      when :west
        propose_west = can_move & ~northwest & ~southwest & ~west
        can_move &= ~propose_west
      when :east
        propose_east = can_move & ~northeast & ~southeast & ~east
        can_move &= ~propose_east
      else raise "bad #{cons}"
      end
    }

    no_move = lonely | can_move

    east_ok = propose_east & ~(propose_west << 2)
    east_conflict = propose_east & propose_west << 2
    west_ok = propose_west & ~(propose_east >> 2)
    west_conflict = east_conflict >> 2

    north_ok = propose_north & ~prev_prev_south
    if i == 0
      row_to_prepend = north_ok
    else
      write_grid[i - 1] |= north_ok
    end

    prev_prev_south_ok = prev_prev_south & ~propose_north
    if prev_prev_south_ok != 0
      raise "impossible to have S moving from two above at row #{i}" if i < 2
      any_moved = true
      write_grid[i - 1] |= prev_prev_south_ok
    end

    north_south_conflict = propose_north & prev_prev_south
    if north_south_conflict != 0
      raise "impossible to have NS conflict at row #{i}" if i < 2
      write_grid[i - 2] |= north_south_conflict
    end

    write_grid[i] = no_move | east_conflict | west_conflict | east_ok >> 1 | west_ok << 1 | north_south_conflict
    rows_extending_east << i if east_ok & 1 != 0
    prev_prev_south = prev_south
    prev_south = propose_south
    any_moved ||= east_ok != 0 || west_ok != 0 || north_ok != 0
  }
  # prev_prev_south: grid[-2] wants to move into grid[-1].
  if prev_prev_south != 0
    write_grid[-1] |= prev_prev_south
    any_moved = true
  end
  # prev_south: grid[-1] wants to move into a new row off the grid.
  if prev_south != 0
    write_grid << prev_south
    any_moved = true
  end
  write_grid.unshift(row_to_prepend) if row_to_prepend != 0
  unless rows_extending_east.empty?
    write_grid.map! { |row| row << 1 }
    rows_extending_east.each { |i| write_grid[i + (row_to_prepend != 0 ? 1 : 0)] |= 1 }
  end

  break time unless any_moved

  considers.rotate!(1)
  read_grid, write_grid = write_grid, read_grid

  if time == 10
    # need to check for any rows that were once populated, but now no longer are.
    height = read_grid.rindex { |r| r != 0 } - read_grid.index { |r| r != 0 } + 1
    width = read_grid.map(&:bit_length).max
    puts height * width - num_elves
  end
}
