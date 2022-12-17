WIDTH = 7

ROCKS = [
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
  ].map(&:freeze).freeze,
  [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, 2],
    [2, 1],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
    [2, 2],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
  ].map(&:freeze).freeze,
  [
    [0, 0],
    [0, 1],
    [1, 0],
    [1, 1],
  ].map(&:freeze).freeze,
].map { |rock| [rock, rock.map(&:last).max, rock.map(&:first).max].freeze }.freeze

wind_dir_name = {
  -1 => 'left',
  1 => 'right',
}.freeze

verbose = ARGV.delete('-v')
show_rocks = if arg = ARGV.find { |x| x.start_with?('-r') }
  ARGV.delete(arg)
  Integer(arg[2..])
else
  0
end

dir = {?> => 1, ?< => -1}.freeze
wind = ARGF.read.chomp.each_char.map { |c| dir.fetch(c) }.freeze

wind_i = -1

tallest = 0
tallest_history = []
occupied = []

# rock_lock[rock_i % 5][wind_i] = previous_rock_i
# (the last rock_i where that rock locked at that wind_i)
# detect cycle condition:
# five consecutive rocks locked at the same point in this wind sequence as in a prior sequence
rock_lock = Array.new(5) { {} }
expected_rock_i_diff = nil
correct_rock_i = 0

pattern_length = 2022.times { |rock_i|
  show_rock = rock_i < show_rocks

  rock, rock_width, rock_height = ROCKS[rock_i % 5]
  rock_left = 2
  rock_bottom = 3 + tallest
  translate_rock = ->{ rock.map { |y, x| [y + rock_bottom, y + rock_left] } } if show_rocks

  puts "new rock #{rock_i} #{translate_rock[]}" if show_rock
  loop {
    part_wind_i = (wind_i += 1) % wind.size
    wind_dir = wind[part_wind_i]
    if 0 <= rock_left + wind_dir && rock_left + rock_width + wind_dir < WIDTH && rock.all? { |y, x| !occupied[(y + rock_bottom) * WIDTH + x + wind_dir + rock_left] }
      rock_left += wind_dir
      puts "rock can move #{wind_dir_name.fetch(wind_dir)}: #{translate_rock[]}" if show_rock
    else
      puts "rock can't move #{wind_dir_name.fetch(wind_dir)}" if show_rock
    end

    if rock_bottom == 0 || rock.any? { |y, x| occupied[(y - 1 + rock_bottom) * WIDTH + x + rock_left] }
      rock.each { |y, x| occupied[(y + rock_bottom) * WIDTH + x + rock_left] = true }
      tallest = [tallest, rock_bottom + rock_height + 1].max
      tallest_history << tallest

      if rock_i == 2021
        p tallest_history if verbose
        puts tallest
      end

      if (prev_rock_i = rock_lock[rock_i % 5][part_wind_i])
        if expected_rock_i_diff&.==(rock_i - prev_rock_i)
          correct_rock_i += 1
        else
          expected_rock_i_diff = rock_i - prev_rock_i
          correct_rock_i = 0
        end
      end

      rock_lock[rock_i % 5][part_wind_i] = rock_i

      if show_rock
        puts "rock can't move down and stops at #{translate_rock[]}, tallest now #{tallest}"
        (tallest - 1).downto(0) { |y|
          puts (0...WIDTH).map { |x| occupied[y * WIDTH + x] ? ?# : ' ' }.join
        }
      end
      break
    else
      rock_bottom -= 1
      puts "rock can move down: #{translate_rock[]}" if show_rock
    end
  }
  break expected_rock_i_diff if correct_rock_i == 5
}

patdiff = tallest - tallest_history[-1 - pattern_length]
puts "pattern length #{pattern_length} diff #{patdiff} found after #{tallest_history.size} rocks" if verbose

extrapolate_height_at = ->t {
  full_patterns, part_patterns = (t - tallest_history.size).divmod(pattern_length)
  part = tallest_history[-1 - pattern_length + part_patterns] - tallest_history[-1 - pattern_length]
  tallest + patdiff * full_patterns + part
}

puts extrapolate_height_at[2022] if tallest_history.size < 2022
puts extrapolate_height_at[1000000000000]
