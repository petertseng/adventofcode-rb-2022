ROCK = 1
PAPER = 2
SCISSORS = 3

WIN = 6
DRAW = 3
LOSE = 0

abc_to_them = {?A => ROCK, ?B => PAPER, ?C => SCISSORS}.freeze
xyz_to_shape = {?X => ROCK, ?Y => PAPER, ?Z => SCISSORS}.freeze
xyz_to_result = {?X => LOSE, ?Y => DRAW, ?Z => WIN}.freeze

games = ARGF.map { |l|
  them_abc, me_xyz = l.split(' ', 2).map(&:freeze)
  [abc_to_them.fetch(them_abc), me_xyz.chomp].freeze
}.freeze

puts games.sum { |them, me_xyz|
  me_shape = xyz_to_shape.fetch(me_xyz)
  me_shape + [DRAW, WIN, LOSE][me_shape - them]
}

puts games.sum { |them, me_xyz|
  me_result = xyz_to_result.fetch(me_xyz)
  # to achieve a given result:
  # 0 (loss), add -1 to their shape
  # 3 (draw), add  0 to their shape
  # 6 (win),  add  1 to their shape
  # so, add me_result / 3 - 1 to their shape.
  # Don't forget to translate from [1, 2, 3] to [0, 1, 2] and back.
  me_result + ((them - 1 + (me_result / 3 - 1)) % 3) + 1
}
