# 1 -> 1, 2 -> 3, 3 -> 6, etc..
def triangular(n)
  n * (n + 1) / 2
end

# Experiments show that limiting geode robots based on obsidian production is useful here,
# but limiting obsidian robots based on clay production is not useful.
def potential(time, time_limit, obsidian, obsidian_robots, geode_obsidian_cost)
  time_left_geode = time_limit - 2 - time
  time_left_obsidian = time_limit - 4 - time

  obsidian += time_left_geode * obsidian_robots
  obsidian += triangular(time_left_obsidian + 1) if time_left_obsidian >= 0

  new_geode_robots = [obsidian / geode_obsidian_cost, time_left_geode + 1].min
  missing_geode_robots = time_left_geode + 1 - new_geode_robots

  triangular(time_left_geode + 1) - triangular(missing_geode_robots)
end

def most_geodes(blueprint, time_limit)
  seen_state = {}
  most_geodes_so_far = 0

  max_ore_cost = blueprint.values.map { |costs| costs[:ore] }.max

  # Regrettably, accessing two hashes does take a little bit more time than accessing a local.
  # This is a micro-optimisation instead of an algorithmic optimisation,
  # but for the slowest-running day of the year so far I think I have to take it.
  ore_ore_cost = blueprint[:ore][:ore]
  clay_ore_cost = blueprint[:clay][:ore]
  obsidian_ore_cost = blueprint[:obsidian][:ore]
  obsidian_clay_cost = blueprint[:obsidian][:clay]
  geode_ore_cost = blueprint[:geode][:ore]
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  # time conventions:
  # A state with a given time value denotes the resources and robots we have at the *end* of that minute.
  # At the start of a given minute, we can make build decisions.
  # At the end of that minute, we gain robots we built (they did not contribute to income this minute).
  search = ->(ore, clay, obsidian, ore_robots, clay_robots, obsidian_robots, time, do_not_build, geodes) {
    #p [ore, clay, obsidian, ore_robots, clay_robots, obsidian_robots, time, geodes] if geodes > 0 && geodes == most_geodes_so_far
    # As a consequence of the time conventions, the last time a geode robot can be usefully built is when time = 22 or 30.
    # That robot is built at the start of minute 23 or 31, finishes at the end of that minute,
    # and contributes its production in the final minute.
    # A robot built any later than that doesn't get time to contribute.
    # That means our production only needs to sustain us until time = 22 or 30,
    # so all pruning rules involving future production use this limit.
    #
    # We could potentially extend this by resource as well.
    # The last time ore and obsidian robots could usefully be built is 20 or 28,
    # if they contribute to building a new geode robot.
    # And the last time clay robots could usefully be built is 18 or 26.
    time_left_geode = time_limit - 2 - time
    time_left_obsidian = [time_limit - 4 - time, 0].max
    # We do need to allow robots to be built at time = 22 or 30 (time_left_geode = 0),
    # so we only retire branches at time = 23 or 31 (time_left_geode = -1).
    return if time_left_geode < 0
    # This one's not that impactful actually, only about a 1.5x speedup.
    return if geodes + potential(time, time_limit, obsidian, obsidian_robots, geode_obsidian_cost) <= most_geodes_so_far

    # Safe to treat all states with too many of a given resource as all the same,
    # if production is sufficient to cover.
    # Ore is about a 1.5x speedup.
    # Clay is about a 1.2x speedup.
    # No speedup was observed for obsidian (it may even have been a slowdown) so it was left out.
    ore = [ore, max_ore_cost + (max_ore_cost - ore_robots) * time_left_geode].min
    clay = [clay, obsidian_clay_cost + (obsidian_clay_cost - clay_robots) * time_left_obsidian].min
    #obsidian = [obsidian, geode_obsidian_cost + (geode_obsidian_cost - obsidian_robots) * time_left_geode].min

    # given the limits above, we actually shouldn't need so many bits per resource,
    # but we have room to spare so it's fine.
    cache_key = ore << 40 | clay << 30 | obsidian << 20 | ore_robots << 15 | clay_robots << 10 | obsidian_robots << 5 | time
    # Not revisiting is about a 20x speedup.
    # (Though the effect is not as pronounced if the do_not_build prune is also applied;
    # in that case this is only about a 1.5x speedup)
    return if seen_state[cache_key] &.>= geodes
    seen_state[cache_key] = geodes

    if ore >= geode_ore_cost && obsidian >= geode_obsidian_cost
      new_ore = ore + ore_robots - geode_ore_cost
      new_geodes = geodes + time_limit - time - 1
      most_geodes_so_far = [most_geodes_so_far, new_geodes].max
      search[new_ore, clay + clay_robots, obsidian + obsidian_robots - geode_obsidian_cost, ore_robots, clay_robots, obsidian_robots, time + 1, {}.freeze, new_geodes]
      # We would like to always build a geode robot when possible, but this is not always correct.
      # https://www.reddit.com/r/adventofcode/comments/zpy5rm/comment/j0vgtsy/
      # Blueprint 1: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 3 clay. Each geode robot costs 3 ore and 1 obsidian.
      # For this input, building geode robots too eagerly leaves you with no time to improve your ore production to catch up.
      # Therefore, we only unconditionally build a geode robot if remaining ore is sufficient.
      # This is modest, about 1.4x speedup.
      # It's about the same speed as just unconditional `return` and isn't obviously incorrect like `return` is.
      # (I thought we might need to check against ore production, but apparently not?
      # That would only be a 1.1x speedup though)
      return if new_ore >= max_ore_cost
    end

    # If we idle and choose not to build a robot we can afford this turn,
    # we should remember not to build it on future turns until we built some other robot.
    # Presumably we chose not to build because we're saving for some other robot.
    # If we built a robot we could have built on a previous turn, we just wasted time.
    #
    # To do this, keep track of the robots we can afford this turn.
    # If we choose to idle, forbid building those robots.
    #
    # (Observe that new_do_not_build is only propagated on idle;
    # an empty hash is passed instead when building any other robot)
    #
    # This optimisation is surprisingly potent: about a 20x speedup.
    new_do_not_build = do_not_build.dup

    # Do not build {obsidian, clay, ore} robot if we don't need any more of that resource,
    # defined as stock + robots * time left >= (time left + 1) * max_cost
    # Suppose we're at time = 20.
    # We could build on time = 20, 21, and 22.
    # Before the final build at time = 22, we'll have production from time = 20 and 21.
    # So the cost side gets an extra minute compared to the production side.
    #
    # However, I still get correct results even without adding that +1 to the cost side???
    # I don't know if it can be proven correct that it's always safe to omit adding it.
    # My conjecture is:
    # In cases where this +1 makes a difference
    # we can create one fewer instance of the robot that depends on this resource.
    # But if we try to correct this problem by creating one more producer,
    # either we create it too late to make a difference,
    # or we create it too early and it means the dependent resource gets behind.
    # So we might as well not bother, so we don't add the +1 to the cost side.
    # Maybe eventually there will come an input where adding the +1 is necessary,
    # disproving my conjecture, but for now I'll stick with it.
    #
    # Measured as an improvement compared to only comparing production vs maximum cost:
    # For obsidian, this doesn't give much benefit, maybe 1.05x
    # For clay, it's about 1.2x
    # For ore, it's about 1.1x

    if ore >= obsidian_ore_cost && clay >= obsidian_clay_cost && !do_not_build[:obsidian] && obsidian + obsidian_robots * time_left_geode < time_left_geode * geode_obsidian_cost
      new_ore = ore + ore_robots - obsidian_ore_cost
      search[new_ore, clay + clay_robots - obsidian_clay_cost, obsidian + obsidian_robots, ore_robots, clay_robots, obsidian_robots + 1, time + 1, {}.freeze, geodes]
      new_do_not_build[:obsidian] = true
      # We would like to say always build an obsidian robot when possible, but this is not always correct.
      # For blueprint 1 of the example input, building an obsidian robot may stop you from building a geode robot.
      # We have to check that our remaining ore is sufficient, as with the geode bots.
      # In addition, we must allow for the possibility that we should instead build a clay robot,
      # to allow building more obsidian robots down the line.
      # Unfortunately at this point this is barely a speedup at all.
      # So I'd prefer to leave it out, in case there's anything these conditions missed.
      #return if new_ore >= max_ore_cost && clay_robots >= obsidian_clay_cost
    end

    if ore >= clay_ore_cost && !do_not_build[:clay] && clay + clay_robots * time_left_obsidian < time_left_obsidian * obsidian_clay_cost
      new_do_not_build[:clay] = true
      search[ore + ore_robots - clay_ore_cost, clay + clay_robots, obsidian + obsidian_robots, ore_robots, clay_robots + 1, obsidian_robots, time + 1, {}.freeze, geodes]
    end

    if ore >= ore_ore_cost && !do_not_build[:ore] && ore + ore_robots * time_left_geode < time_left_geode * max_ore_cost
      new_do_not_build[:ore] = true
      search[ore + ore_robots - ore_ore_cost, clay + clay_robots, obsidian + obsidian_robots, ore_robots + 1, clay_robots, obsidian_robots, time + 1, {}.freeze, geodes]
    end

    # Only idle if there is some reason to (we're waiting to build a robot).
    # If we can afford every robot right now, we should build one.
    # Unfortunately this seems to make no difference, even though this rule is triggered sometimes.
    if ore < max_ore_cost || clay < obsidian_clay_cost || obsidian < geode_obsidian_cost
      search[ore + ore_robots, clay + clay_robots, obsidian + obsidian_robots, ore_robots, clay_robots, obsidian_robots, time + 1, new_do_not_build.freeze, geodes]
    end
  }

  search[1, 0, 0, 1, 0, 0, 1, {}.freeze, 0]

  most_geodes_so_far
end

verbose = ARGV.delete('-v')

robot = /Each ([a-z]+) robot costs ([^.]+)\./

blueprints = ARGF.map.with_index(1) { |line, id|
  raise "bad line didn't start with Blueprint #{id}: #{line}" unless line.start_with?("Blueprint #{id}:")
  line.scan(robot).to_h { |gathers, costs|
    [gathers.to_sym, costs.split(' and ').to_h { |thing| a, b = thing.split; [b.to_sym, Integer(a)] }.freeze]
  }.freeze
}.freeze

puts blueprints.each.with_index(1).sum { |bp, i|
  i * most_geodes(bp, 24).tap { |g| puts "#{i} * #{g} = #{i * g}" if verbose }
}

puts blueprints.take(3).map { |bp|
  most_geodes(bp, 32).tap { |g| puts g if verbose }
}.reduce(:*)
