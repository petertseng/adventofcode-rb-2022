verbose = ARGV.delete('-v')
trees = ARGF.map { |line|
  line.chomp.chars.map(&method(:Integer)).freeze
}.freeze
height = trees.size
width = trees[0].size
size = height * width
raise "inconsistent width #{trees.map(&:size)}" if trees.any? { |row| row.size != width }
trees = trees.flatten.freeze

visible_from_outside = Array.new(trees.size, false)
score = Array.new(trees.size, 1)

# Count trees visible in a given direction for all trees.
#
# Approach:
# Travel in a given direction and calculate number of trees visible in the backward direction,
# by tracking previous heights.
count_trees = ->(majors, minors) {
  majors.each { |major|
    # index: height
    # value: position of previous tree that blocks a tree of that height
    prev_blocker = Array.new(10)

    minors.each_with_index { |minor, seq_i|
      tree_i = major + minor
      tree_height = trees[tree_i]

      visible_trees = seq_i - (prev_blocker[tree_height] || (visible_from_outside[tree_i] = true; 0))
      # a tree of height N will block trees of height 0, 1, ... N
      prev_blocker.fill(seq_i, 0, tree_height + 1)
      score[tree_i] *= visible_trees
    }
  }
}

# left to right
count_trees[(0...size) % width, 0...width]
# right to left
count_trees[(0...size) % width, (width - 1).downto(0)]
# top to bottom
count_trees[0...width, (0...size) % width]
# bottom to top
count_trees[0...width, (size - width).step(0, -width)]

if verbose
  visible_from_outside.each_slice(width) { p _1 }
  score.each_slice(width) { p _1 }
end

puts visible_from_outside.count(true)
puts score.max
