require 'benchmark'

# An approach that seems possible but not very good:
#
# You can decide the next state of a cell by looking at 21 cells:
#
#  xxx
# xxexx
# xe!ex
# xxexx
#  xxx
#
# You would probably need four lookup tables for this,
# but 1 << 23 is 8388608 so this is not out of the question.
# Bigger problem is you're potentially doing five reads just to decide one cell.
#
# In my input, there around 3000 elves in around a 140x140 (19600) area,
# so it seems it will be far faster to only act on elves rather than all possible spaces.

COORD = 30
Y = 1 << COORD
ORIGIN = (Y / 2) << COORD | (Y / 2)

ADJ8 = [
  -Y - 1,
  -Y,
  -Y + 1,
  -1,
  1,
  Y - 1,
  Y,
  Y + 1,
].freeze

def raw_neighs
  # north 0, 3, 6
  # south 2, 5, 8
  # west 0, 1, 2
  # east 6, 7, 8
  #
  # 036
  # 147
  # 258
  (1 << 9).times.map { |n|
    {
      exist:  n[4] != 0,
      lonely: n & 0b111101111 == 0,
      north:  n & 0b1001001 == 0,
      south:  n & 0b100100100 == 0,
      west:   n & 0b111 == 0,
      east:   n & 0b111000000 == 0,
    }.freeze
  }.freeze
end

def neigh9x9
  neighs = raw_neighs
  # We start on round 1, so move it so that 1 cooresponds to north.
  considers = %i(east north south west)
  4.times.map {
    neighs.map { |neigh|
      next if neigh[:lonely]
      case considers.find(&neigh)
      when :north; -Y
      when :south; Y
      when :west; -1
      when :east; 1
      when nil; nil
      else raise 'impossible'
      end
    }.freeze.tap { considers.rotate!(1) }
  }.freeze
end

def neigh16x16
  # We start on round 1, so move it so that 1 corresponds to north.
  considers = %i(east north south west)

  4.times.map {
    neighs = raw_neighs

    # 0 if not moving
    # 1, 3, 5, 7 if moving north, south, west, east
    # 3 bits per output
    neigh3x3 = neighs.map { |neigh|
      next 0 if !neigh[:exist] || neigh[:lonely]
      case considers.find(&neigh)
      when :north; 1
      when :south; 3
      when :west; 5
      when :east; 7
      when nil; 0
      else raise 'impossible'
      end
    }.freeze

    considers.rotate!(1)

    # 0 4 8 c
    # 1 5 9 d
    # 2 6 a e
    # 3 7 b f
    #
    # with 3 bits per output we'll just pack them next to each other into a 12-bit output.
    (1 << 16).times.map { |i|
      ul = neigh3x3[(i & 0x700)  >> 2 | (i & 0x70)  >> 1 |  i & 0x7]
      ll = neigh3x3[(i & 0xe00)  >> 3 | (i & 0xe0)  >> 2 | (i & 0xe)  >> 1]
      ur = neigh3x3[(i & 0x7000) >> 6 | (i & 0x700) >> 5 | (i & 0x70) >> 4]
      lr = neigh3x3[(i & 0xe000) >> 7 | (i & 0xe00) >> 6 | (i & 0xe0) >> 5]
      lr << 9 | ur << 6 | ll << 3 | ul
    }.freeze
  }.freeze
end

bench_candidates = []

# these three (all, actives, actives_sleeping_near) aren't using the "only two elves can propose" optimisation,
# but it barely makes a difference anyway.
bench_candidates << def all(elves)
  considers = %i(north south west east)

  1.step { |time|
    propose = Hash.new { |h, k| h[k] = [] }

    elves.each_key { |pos|
      next if ADJ8.none? { |dpos| elves[pos + dpos] }

      considers.each { |cons|
        case cons
        when :north
          if !elves[pos - Y - 1] && !elves[pos - Y] && !elves[pos - Y + 1]
            propose[pos - Y] << pos
            break
          end
        when :south
          if !elves[pos + Y - 1] && !elves[pos + Y] && !elves[pos + Y + 1]
            propose[pos + Y] << pos
            break
          end
        when :west
          if !elves[pos - 1 - Y] && !elves[pos - 1] && !elves[pos - 1 + Y]
            propose[pos - 1] << pos
            break
          end
        when :east
          if !elves[pos + 1 - Y] && !elves[pos + 1] && !elves[pos + 1 + Y]
            propose[pos + 1] << pos
            break
          end
        end
      }
    }

    any_moved = false
    propose.each { |dest, proposers|
      next if proposers.size != 1
      elves.delete(proposers[0])
      elves[dest] = true
      any_moved = true
    }
    break time unless any_moved
    considers.rotate!(1)
  }
end

bench_candidates << def actives(elves)
  considers = %i(north south west east)

  actives = elves.dup
  idles = {}

  1.step { |time|
    propose = Hash.new { |h, k| h[k] = [] }

    becoming_active = {}
    becoming_idle = {}

    actives.each_key { |pos|
      if ADJ8.none? { |dpos| elves[pos + dpos] }
        becoming_idle[pos] = true
        next
      end

      considers.each { |cons|
        case cons
        when :north
          if !elves[pos - Y - 1] && !elves[pos - Y] && !elves[pos - Y + 1]
            propose[pos - Y] << pos
            break
          end
        when :south
          if !elves[pos + Y - 1] && !elves[pos + Y] && !elves[pos + Y + 1]
            propose[pos + Y] << pos
            break
          end
        when :west
          if !elves[pos - 1 - Y] && !elves[pos - 1] && !elves[pos - 1 + Y]
            propose[pos - 1] << pos
            break
          end
        when :east
          if !elves[pos + 1 - Y] && !elves[pos + 1] && !elves[pos + 1 + Y]
            propose[pos + 1] << pos
            break
          end
        end
      }
    }

    any_moved = false
    propose.each { |dest, proposers|
      next if proposers.size != 1
      elves.delete(proposers[0])
      actives.delete(proposers[0])
      elves[dest] = true
      actives[dest] = true
      ADJ8.each { |dpos|
        becoming_idle.delete(dest + dpos) if becoming_idle.has_key?(dest + dpos)
        becoming_active[dest + dpos] = true if idles.has_key?(dest + dpos)
      }
      any_moved = true
    }
    break time unless any_moved
    considers.rotate!(1)

    becoming_idle.each_key { |pos| actives.delete(pos); idles[pos] = true }
    becoming_active.each_key { |pos| idles.delete(pos); actives[pos] = true }
  }
end

bench_candidates << def actives_sleeping_near(elves)
  considers = %i(north south west east)

  actives = elves.dup
  idles = {}
  idle_near = Hash.new { |h, k| h[k] = {} }
  becoming_idle_near = Hash.new { |h, k| h[k] = {} }

  1.step { |time|
    propose = Hash.new { |h, k| h[k] = [] }

    becoming_active = {}
    becoming_idle = {}

    actives.each_key { |pos|
      if ADJ8.none? { |dpos| elves[pos + dpos] }
        becoming_idle[pos] = true
        ADJ8.each { |dpos| becoming_idle_near[pos + dpos][pos] = true }
        next
      end

      considers.each { |cons|
        case cons
        when :north
          if !elves[pos - Y - 1] && !elves[pos - Y] && !elves[pos - Y + 1]
            propose[pos - Y] << pos
            break
          end
        when :south
          if !elves[pos + Y - 1] && !elves[pos + Y] && !elves[pos + Y + 1]
            propose[pos + Y] << pos
            break
          end
        when :west
          if !elves[pos - 1 - Y] && !elves[pos - 1] && !elves[pos - 1 + Y]
            propose[pos - 1] << pos
            break
          end
        when :east
          if !elves[pos + 1 - Y] && !elves[pos + 1] && !elves[pos + 1 + Y]
            propose[pos + 1] << pos
            break
          end
        end
      }
    }

    any_moved = false
    propose.each { |dest, proposers|
      next if proposers.size != 1
      elves.delete(proposers[0])
      actives.delete(proposers[0])
      elves[dest] = true
      actives[dest] = true

      becoming_idle_near.delete(dest).each_key { |woken|
        becoming_idle.delete(woken)
        ADJ8.each { |dpos|
          becoming_idle_near[woken + dpos].delete(woken)
        }
      } if becoming_idle_near.has_key?(dest)
      idle_near.delete(dest).each_key { |woken|
        becoming_active[woken] = true
      } if idle_near.has_key?(dest)

      any_moved = true
    }
    break time unless any_moved
    considers.rotate!(1)

    becoming_idle.each_key { |pos|
      actives.delete(pos)
      ADJ8.each { |dpos|
        becoming_idle_near[pos + dpos].delete(pos)
        idle_near[pos + dpos][pos] = true
      }
      idles[pos] = true
    }
    becoming_active.each_key { |pos|
      idles.delete(pos)
      ADJ8.each { |dpos| idle_near[pos + dpos].delete(pos) }
      actives[pos] = true
    }
  }
end

bench_candidates << def inactives_row_col_multi_write_single_read(elves)
  neighs = neigh9x9

  idles = {}
  reactivate_y = {}
  reactivate_x = {}

  1.step { |time|
    propose = {}

    prev_y = nil
    prev_x = nil
    neigh = 0

    elves.keys.sort.each { |pos|
      y, x = pos.divmod(Y)

      if idles[pos]
        # do not reactivate if nobody moved into the x or y vicinity
        if reactivate_y[y] && reactivate_x[x]
          idles.delete(pos)
        else
          next
        end
      end

      if y != prev_y
        neigh = 0
        prev_x = x - 3
      end

      xdiff = x - prev_x
      neigh >>= xdiff * 3
      # west (column at X - 1) in bits 0, 1, 2
      if xdiff > 2
        neigh |= 1 if elves[pos - Y - 1]
        neigh |= 2 if elves[pos - 1]
        neigh |= 4 if elves[pos + Y - 1]
      end
      # column at X in bits 3, 4, 5
      if xdiff > 1
        neigh |= 010 if elves[pos - Y]
        neigh |= 020 # if elves[pos] (this is always true)
        neigh |= 040 if elves[pos + Y]
      end
      # east (column at X + 1) in bits 6, 7, 8
      neigh |= 0100 if elves[pos - Y + 1]
      neigh |= 0200 if elves[pos + 1]
      neigh |= 0400 if elves[pos + Y + 1]

      if dpos = neighs[time % 4][neigh]
        if propose.has_key?(pos + dpos)
          propose.delete(pos + dpos)
        else
          propose[pos + dpos] = pos
        end
      else
        idles[pos] = true
      end

      prev_y = y
      prev_x = x
    }

    reactivate_y.clear
    reactivate_x.clear

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
      y, x = dest.divmod(Y)
      reactivate_y[y - 1] = true
      reactivate_y[y] = true
      reactivate_y[y + 1] = true
      reactivate_x[x - 1] = true
      reactivate_x[x] = true
      reactivate_x[x + 1] = true
    }
  }
end

bench_candidates << def inactives_row_col_single_write_multi_read(elves)
  neighs = neigh9x9

  idles = {}
  reactivate_y = {}
  reactivate_x = {}

  1.step { |time|
    propose = {}

    prev_y = nil
    prev_x = nil
    neigh = 0

    elves.keys.sort.each { |pos|
      y, x = pos.divmod(Y)

      if idles[pos]
        # do not reactivate if nobody moved into the x or y vicinity
        if (reactivate_y[y - 1] || reactivate_y[y] || reactivate_y[y + 1]) && (reactivate_x[x - 1] || reactivate_x[x] || reactivate_x[x + 1])
          idles.delete(pos)
        else
          next
        end
      end

      if y != prev_y
        neigh = 0
        prev_x = x - 3
      end

      xdiff = x - prev_x
      neigh >>= xdiff * 3
      # west (column at X - 1) in bits 0, 1, 2
      if xdiff > 2
        neigh |= 1 if elves[pos - Y - 1]
        neigh |= 2 if elves[pos - 1]
        neigh |= 4 if elves[pos + Y - 1]
      end
      # column at X in bits 3, 4, 5
      if xdiff > 1
        neigh |= 010 if elves[pos - Y]
        neigh |= 020 # if elves[pos] (this is always true)
        neigh |= 040 if elves[pos + Y]
      end
      # east (column at X + 1) in bits 6, 7, 8
      neigh |= 0100 if elves[pos - Y + 1]
      neigh |= 0200 if elves[pos + 1]
      neigh |= 0400 if elves[pos + Y + 1]

      if dpos = neighs[time % 4][neigh]
        if propose.has_key?(pos + dpos)
          propose.delete(pos + dpos)
        else
          propose[pos + dpos] = pos
        end
      else
        idles[pos] = true
      end

      prev_y = y
      prev_x = x
    }

    reactivate_y.clear
    reactivate_x.clear

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
      reactivate_y[dest >> COORD] = true
      reactivate_x[dest & (Y - 1)] = true
    }
  }
end

bench_candidates << def neigh_sort_all_each_iter(elves)
  neighs = neigh9x9

  1.step { |time|
    propose = {}

    prev_y = nil
    prev_x = nil
    neigh = 0

    elves.keys.sort.each { |pos|
      y, x = pos.divmod(Y)

      if y != prev_y
        neigh = 0
        prev_x = x - 3
      end

      xdiff = x - prev_x
      neigh >>= xdiff * 3
      # west (column at X - 1) in bits 0, 1, 2
      if xdiff > 2
        neigh |= 1 if elves[pos - Y - 1]
        neigh |= 2 if elves[pos - 1]
        neigh |= 4 if elves[pos + Y - 1]
      end
      # column at X in bits 3, 4, 5
      if xdiff > 1
        neigh |= 010 if elves[pos - Y]
        neigh |= 020 # if elves[pos] (this is always true)
        neigh |= 040 if elves[pos + Y]
      end
      # east (column at X + 1) in bits 6, 7, 8
      neigh |= 0100 if elves[pos - Y + 1]
      neigh |= 0200 if elves[pos + 1]
      neigh |= 0400 if elves[pos + Y + 1]

      if dpos = neighs[time % 4][neigh]
        if propose.has_key?(pos + dpos)
          propose.delete(pos + dpos)
        else
          propose[pos + dpos] = pos
        end
      end

      prev_y = y
      prev_x = x
    }

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
    }
  }
end

bench_candidates << def neigh_bucket_sort_all_each_iter(elves)
  neighs = neigh9x9

  # they're sorted the first time
  sorted_elves = elves.keys

  1.step { |time|
    propose = {}

    prev_y = nil
    prev_x = nil
    neigh = 0

    new_elves = Hash.new { |h, k| h[k] = [] }

    sorted_elves.each { |pos|
      y, x = pos.divmod(Y)

      if y != prev_y
        neigh = 0
        prev_x = x - 3
      end

      xdiff = x - prev_x
      neigh >>= xdiff * 3
      # west (column at X - 1) in bits 0, 1, 2
      if xdiff > 2
        neigh |= 1 if elves[pos - Y - 1]
        neigh |= 2 if elves[pos - 1]
        neigh |= 4 if elves[pos + Y - 1]
      end
      # column at X in bits 3, 4, 5
      if xdiff > 1
        neigh |= 010 if elves[pos - Y]
        neigh |= 020 # if elves[pos] (this is always true)
        neigh |= 040 if elves[pos + Y]
      end
      # east (column at X + 1) in bits 6, 7, 8
      neigh |= 0100 if elves[pos - Y + 1]
      neigh |= 0200 if elves[pos + 1]
      neigh |= 0400 if elves[pos + Y + 1]

      if dpos = neighs[time % 4][neigh]
        if propose.has_key?(pos + dpos)
          del = propose.delete(pos + dpos)
          new_elves[del >> COORD] << del
          new_elves[y] << pos
        else
          propose[pos + dpos] = pos
        end
      else
        new_elves[y] << pos
      end

      prev_y = y
      prev_x = x
    }

    break time if propose.empty?
    propose.each { |dest, src|
      new_elves[dest >> COORD] << dest
      elves.delete(src)
      elves[dest] = true
    }
    sorted_elves = new_elves.sort_by(&:first).flat_map { |_, v| v.sort }
  }
end

bench_candidates << def neigh_group_by_and_sort_row(elves)
  neighs = neigh9x9

  1.step { |time|
    propose = {}

    elves.keys.group_by { |pos| pos >> COORD }.each { |y, elves_at_y|
      neigh = 0
      prev_pos = nil

      elves_at_y.sort.each { |pos|
        next unless elves[pos]
        xdiff = prev_pos ? pos - prev_pos : 3
        neigh >>= xdiff * 3

        # west (column at X - 1) in bits 0, 1, 2
        if xdiff > 2
          neigh |= 1 if elves[pos - Y - 1]
          neigh |= 2 if elves[pos - 1]
          neigh |= 4 if elves[pos + Y - 1]
        end
        # column at X in bits 3, 4, 5
        if xdiff > 1
          neigh |= 010 if elves[pos - Y]
          neigh |= 020 # if elves[pos] (this is always true)
          neigh |= 040 if elves[pos + Y]
        end
        # east (column at X + 1) in bits 6, 7, 8
        neigh |= 0100 if elves[pos - Y + 1]
        neigh |= 0200 if elves[pos + 1]
        neigh |= 0400 if elves[pos + Y + 1]

        if dpos = neighs[time % 4][neigh]
          if propose.has_key?(pos + dpos)
            propose.delete(pos + dpos)
          else
            propose[pos + dpos] = pos
          end
        end

        prev_pos = pos
      }
    }

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
    }
  }
end

bench_candidates << def neigh_minmax_no_sort(elves)
  neighs = neigh9x9

  1.step { |time|
    propose = {}

    elves.keys.group_by { |pos| pos >> COORD }.each { |y, elves_at_y|
      posmin, posmax = elves_at_y.minmax
      neigh = 0
      prev_pos = posmin - 3

      (posmin..posmax).each { |pos|
        next unless elves[pos]
        xdiff = pos - prev_pos
        neigh >>= xdiff * 3

        # west (column at X - 1) in bits 0, 1, 2
        if xdiff > 2
          neigh |= 1 if elves[pos - Y - 1]
          neigh |= 2 if elves[pos - 1]
          neigh |= 4 if elves[pos + Y - 1]
        end
        # column at X in bits 3, 4, 5
        if xdiff > 1
          neigh |= 010 if elves[pos - Y]
          neigh |= 020 # if elves[pos] (this is always true)
          neigh |= 040 if elves[pos + Y]
        end
        # east (column at X + 1) in bits 6, 7, 8
        neigh |= 0100 if elves[pos - Y + 1]
        neigh |= 0200 if elves[pos + 1]
        neigh |= 0400 if elves[pos + Y + 1]

        if dpos = neighs[time % 4][neigh]
          if propose.has_key?(pos + dpos)
            propose.delete(pos + dpos)
          else
            propose[pos + dpos] = pos
          end
        end

        prev_pos = pos
      }
    }

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
    }
  }
end

# askalski's 2021 day 20 solution.
# Because of proposal/conflict resolution, the 16-bit lookup table cannot directly decide a cell's next state;
# it can only decide the proposals of the four elves.
# Because of this, I chose to store the elves separately in a set,
# but now you need to do 8 or 16 set membership checks for every four elves, and it ends up not being better.
bench_candidates << def neigh4x4_group_by(elves)
  neighs = neigh16x16
  proposes_dpos = [-Y, Y, -1, 1].freeze

  1.step { |time|
    propose = {}

    # >> COORD + 1 instead of just >> COORD: group into 2-row groups
    elves.keys.group_by { |pos| pos >> (COORD + 1) }.sort_by(&:first).each { |ygroup, poses|
      neigh = 0
      ypos = ygroup << (COORD + 1)

      prev_x_group = nil
      # any 2-column group that's occupied:
      poses.map { |pos| (pos & (Y - 1)) >> 1 }.uniq.sort.each { |xgroup|
        xpos = xgroup << 1
        pos = ypos + xpos

        if prev_x_group && xgroup == prev_x_group + 1
          # previous's right half is our left half
          neigh >>= 8
        else
          # must populate left half
          neigh = (elves[pos - Y - 1] ? 0x1 : 0) | (elves[pos - 1] ? 0x2 : 0) | (elves[pos + Y - 1] ? 0x4 : 0) | (elves[pos + 2 * Y - 1] ? 0x8 : 0) |
            (elves[pos - Y] ? 0x10 : 0) | (elves[pos] ? 0x20 : 0) | (elves[pos + Y] ? 0x40 : 0) | (elves[pos + 2 * Y] ? 0x80 : 0)
        end
        # populate right half
        neigh |= (elves[pos - Y + 1] ? 0x100 : 0) | (elves[pos + 1] ? 0x200 : 0) | (elves[pos + Y + 1] ? 0x400 : 0) | (elves[pos + 2 * Y + 1] ? 0x800 : 0) |
          (elves[pos - Y + 2] ? 0x1000 : 0) | (elves[pos + 2] ? 0x2000 : 0) | (elves[pos + Y + 2] ? 0x4000 : 0) | (elves[pos + 2 * Y + 2] ? 0x8000 : 0)

        proposes = neighs[time % 4][neigh]
        [0, Y, 1, 1 + Y].each { |proposer_dpos|
          break if proposes == 0
          if proposes & 1 != 0
            proposer_pos = pos + proposer_dpos
            proposed_pos = proposer_pos + proposes_dpos[(proposes & 0b110) >> 1]
            if propose.has_key?(proposed_pos)
              propose.delete(proposed_pos)
            else
              propose[proposed_pos] = proposer_pos
            end
          end
          proposes >>= 3
        }
        prev_x_group = xgroup
      }
    }

    break time if propose.empty?
    propose.each { |dest, src|
      elves.delete(src)
      elves[dest] = true
    }
  }
end

# What if we just stored the elves in a grid, and used bitwise operations to move them after every conflict resolution?
# It turns out this is even worse, perhaps because of iterating over blocks you don't even need to iterate over.
# Recall I mentioned having around 3000 elves in a 140x140 (19600) area.
# By the way the prepending isn't the reason for the slowness.
# The prepending takes total < 1 millisecond.
bench_candidates << def neigh4x4_mutate_grid(elves)
  neighs = neigh16x16
  proposes_dpos = [-Y, Y, -1, 1].freeze

  (yblockmin, yblockmax), (xblockmin, xblockmax) = elves.keys.map { |pos| pos.divmod(Y).map { _1 >> 1 } }.transpose.map(&:minmax)
  rows_needed = (yblockmin..yblockmax).size
  cols_needed = (xblockmin..xblockmax).size

  grid = Array.new(rows_needed) { |yblock|
    ypos = (yblockmin + yblock) << (COORD + 1)
    Array.new(cols_needed) { |xblock|
      xpos = (xblockmin + xblock) << 1
      pos = ypos + xpos
      (elves[pos] ? 0x1 : 0) | (elves[pos + 1] ? 0x10 : 0) | (elves[pos + Y] ? 0x2 : 0) | (elves[pos + Y + 1] ? 0x20 : 0)
    }
  }

  1.step { |time|
    propose = {}

    (0..grid.size).each { |yblock|
      ypos = (((yblockmin + yblock) << 1) - 1) << COORD

      prev_row = grid[yblock - 1]
      this_row = grid[yblock]
      above_active = yblock != 0
      below_active = yblock < grid.size
      above = 0
      below = 0

      (0..[prev_row&.size || 0, this_row&.size || 0].max).each { |xblock|
        xpos = + ((xblockmin + xblock) << 1) - 1
        pos = ypos + xpos

        above = (above >> 8) | ((prev_row[xblock] || 0) << 8) if above_active
        below = (below >> 8) | ((this_row[xblock] || 0) << 8) if below_active

        proposes = neighs[time % 4][above | below << 2]
        [0, Y, 1, 1 + Y].each { |proposer_dpos|
          break if proposes == 0
          if proposes & 1 != 0
            proposer_pos = pos + proposer_dpos
            proposed_pos = proposer_pos + proposes_dpos[(proposes & 0b110) >> 1]
            if propose.has_key?(proposed_pos)
              propose.delete(proposed_pos)
            else
              propose[proposed_pos] = proposer_pos
            end
          end
          proposes >>= 3
        }
      }
    }

    break time if propose.empty?
    propose.each { |dest, src|
      # unset src bit
      srcy, srcx = src.divmod(Y)
      srcyblock = (srcy >> 1) - yblockmin
      srcxblock = (srcx >> 1) - xblockmin
      srcbit = (srcy & 1) + 4 * (srcx & 1)
      grid[srcyblock][srcxblock] &= ~(1 << srcbit)

      # set dest bit. may need to prepend elements.
      desty, destx = dest.divmod(Y)
      destyblock = (desty >> 1) - yblockmin
      destxblock = (destx >> 1) - xblockmin
      if destyblock < 0
        yblockmin -= 1
        destyblock = 0
        grid.unshift([])
      elsif destyblock >= grid.size
        grid << []
      end
      if destxblock < 0
        xblockmin -= 1
        destxblock = 0
        grid.each { |row| row.unshift(0) }
      end
      destbit = (desty & 1) + 4 * (destx & 1)
      grid[destyblock][destxblock] = (grid[destyblock][destxblock] || 0) | 1 << destbit
    }
  }
end

elves = ARGF.flat_map.with_index { |line, y|
  line.chars.filter_map.with_index { |c, x| [ORIGIN + y * Y + x, true] if c == ?# }
}.to_h.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = send(f, elves.dup) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
