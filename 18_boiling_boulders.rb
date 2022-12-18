require_relative 'lib/search'

rocks = ARGF.to_h { |line|
  [line.split(?,, 3).map(&method(:Integer)).freeze, true]
}.freeze

# flatten the 3d coordinates into a single integer
# (Ruby too slow at creating many arrays)
xs, ys, _ = rocks.keys.transpose.map { |coords|
  cmin, cmax = coords.minmax
  (cmin - 1)..(cmax + 1)
}
width = xs.size
area = xs.size * ys.size
adj6_flat = ->pt { [pt - 1, pt + 1, pt - width, pt + width, pt - area, pt + area].freeze }
flatten = ->((x, y, z)) { x + y * width + z * area }

rocks = rocks.transform_keys(&flatten).freeze
# A face here is actually just stored as the point that the face touches.
# Since multiple faces can border the same point, we keep the tally.
faces = rocks.keys.flat_map(&adj6_flat).tally.reject { |pos, _| rocks[pos] }.freeze

puts faces.values.sum

# If the rock's external outline is completely connected,
# (TODO: Perhaps raise error if this is not the case?)
# then we only need to trace along the outline of the rock.
# So we only need to stay within manhattan distance 2 of any point of the rock,
# Since with a distance of 2 you can travel from one face to another.
next_to_face = faces.keys.flat_map(&adj6_flat).to_h { |pos| [pos, true] }.reject { |pos, _| rocks[pos] }.freeze

# The face with minimum value (which here means minimum z) must be air,
# because there can be no rock with a lower z to block it.
air = Search.bfs([faces.keys.min], neighbours: ->pt {
  adj6_flat[pt].select { |neigh| next_to_face[neigh] || faces[neigh] }
}, goal: faces, num_goals: faces.size)[:goals]

puts faces.sum { |face, count| air[face] ? count : 0 }
