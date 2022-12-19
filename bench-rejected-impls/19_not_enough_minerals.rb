require 'benchmark'

bench_candidates = []

# 1 -> 1, 2 -> 3, 3 -> 6, etc..
def triangular(n)
  n * (n + 1) / 2
end

# This is an interesting approach, but it ends up being slower.
# It ends up not being much benefit because it doesn't help if you can build one robot per time step,
# and by the end of the 32 minutes that's mostly true.
bench_candidates << def robotwise(blueprint, time_limit)
  seen_state = {}
  most_geodes_so_far = 0

  max_ore_cost = blueprint.values.map { |costs| costs[:ore] }.max

  ore_ore_cost = blueprint[:ore][:ore]
  clay_ore_cost = blueprint[:clay][:ore]
  obsidian_ore_cost = blueprint[:obsidian][:ore]
  obsidian_clay_cost = blueprint[:obsidian][:clay]
  geode_ore_cost = blueprint[:geode][:ore]
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  ceildiv = ->(a, b) { -(a / -b) }

  search = ->(ore, clay, obsidian, ore_robots, clay_robots, obsidian_robots, time, geodes) {
    time_left_geode = time_limit - 2 - time
    time_left_obsidian = [time_limit - 4 - time, 0].max
    return if time_left_geode < 0
    return if geodes + triangular(time_limit - time - 1) <= most_geodes_so_far

    ore = [ore, max_ore_cost + (max_ore_cost - ore_robots) * time_left_geode].min
    clay = [clay, obsidian_clay_cost + (obsidian_clay_cost - clay_robots) * time_left_obsidian].min
    #obsidian = [obsidian, geode_obsidian_cost + (geode_obsidian_cost - obsidian_robots) * time_left_geode].min

    cache_key = ore << 40 | clay << 30 | obsidian << 20 | ore_robots << 15 | clay_robots << 10 | obsidian_robots << 5 | time
    return if seen_state[cache_key] &.>= geodes
    seen_state[cache_key] = geodes

    if obsidian_robots > 0
      dt = [0, ceildiv[geode_ore_cost - ore, ore_robots], ceildiv[geode_obsidian_cost - obsidian, obsidian_robots]].max + 1
      new_time = time + dt
      if new_time < time_limit
        new_geodes = geodes + time_limit - new_time
        most_geodes_so_far = [most_geodes_so_far, new_geodes].max
        search[ore + ore_robots * dt - geode_ore_cost, clay + clay_robots * dt, obsidian + obsidian_robots * dt - geode_obsidian_cost, ore_robots, clay_robots, obsidian_robots, new_time, new_geodes]
      end
    end

    if clay_robots > 0 && obsidian + obsidian_robots * time_left_geode < time_left_geode * geode_obsidian_cost
      dt = [0, ceildiv[obsidian_ore_cost - ore, ore_robots], ceildiv[obsidian_clay_cost - clay, clay_robots]].max + 1
      new_time = time + dt
      if new_time < time_limit
        search[ore + ore_robots * dt - obsidian_ore_cost, clay + clay_robots * dt - obsidian_clay_cost, obsidian + obsidian_robots * dt, ore_robots, clay_robots, obsidian_robots + 1, new_time, geodes]
      end
    end

    if clay + clay_robots * time_left_obsidian < time_left_obsidian * obsidian_clay_cost
      dt = [0, ceildiv[clay_ore_cost - ore, ore_robots]].max + 1
      new_time = time + dt
      if new_time < time_limit
        search[ore + ore_robots * dt - clay_ore_cost, clay + clay_robots * dt, obsidian + obsidian_robots * dt, ore_robots, clay_robots + 1, obsidian_robots, new_time, geodes]
      end
    end

    if ore + ore_robots * time_left_geode < time_left_geode * max_ore_cost
      dt = [0, ceildiv[ore_ore_cost - ore, ore_robots]].max + 1
      new_time = time + dt
      if new_time < time_limit
        search[ore + ore_robots * dt - ore_ore_cost, clay + clay_robots * dt, obsidian + obsidian_robots * dt, ore_robots + 1, clay_robots, obsidian_robots, new_time, geodes]
      end
    end
  }

  search[1, 0, 0, 1, 0, 0, 1, 0]

  most_geodes_so_far
end

def minutewise_with_potential(blueprint, time_limit)
  seen_state = {}
  most_geodes_so_far = 0

  max_ore_cost = blueprint.values.map { |costs| costs[:ore] }.max

  ore_ore_cost = blueprint[:ore][:ore]
  clay_ore_cost = blueprint[:clay][:ore]
  obsidian_ore_cost = blueprint[:obsidian][:ore]
  obsidian_clay_cost = blueprint[:obsidian][:clay]
  geode_ore_cost = blueprint[:geode][:ore]
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  search = ->(ore, clay, obsidian, ore_robots, clay_robots, obsidian_robots, time, do_not_build, geodes) {
    time_left_geode = time_limit - 2 - time
    time_left_obsidian = [time_limit - 4 - time, 0].max
    return if time_left_geode < 0
    return if geodes + yield(time, clay, obsidian, clay_robots, obsidian_robots) <= most_geodes_so_far

    ore = [ore, max_ore_cost + (max_ore_cost - ore_robots) * time_left_geode].min
    clay = [clay, obsidian_clay_cost + (obsidian_clay_cost - clay_robots) * time_left_obsidian].min
    #obsidian = [obsidian, geode_obsidian_cost + (geode_obsidian_cost - obsidian_robots) * time_left_geode].min

    cache_key = ore << 40 | clay << 30 | obsidian << 20 | ore_robots << 15 | clay_robots << 10 | obsidian_robots << 5 | time
    return if seen_state[cache_key] &.>= geodes
    seen_state[cache_key] = geodes

    if ore >= geode_ore_cost && obsidian >= geode_obsidian_cost
      new_ore = ore + ore_robots - geode_ore_cost
      new_geodes = geodes + time_limit - time - 1
      most_geodes_so_far = [most_geodes_so_far, new_geodes].max
      search[new_ore, clay + clay_robots, obsidian + obsidian_robots - geode_obsidian_cost, ore_robots, clay_robots, obsidian_robots, time + 1, {}.freeze, new_geodes]
      return if new_ore >= max_ore_cost
    end

    new_do_not_build = do_not_build.dup

    if ore >= obsidian_ore_cost && clay >= obsidian_clay_cost && !do_not_build[:obsidian] && obsidian + obsidian_robots * time_left_geode < time_left_geode * geode_obsidian_cost
      new_ore = ore + ore_robots - obsidian_ore_cost
      search[new_ore, clay + clay_robots - obsidian_clay_cost, obsidian + obsidian_robots, ore_robots, clay_robots, obsidian_robots + 1, time + 1, {}.freeze, geodes]
      new_do_not_build[:obsidian] = true
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

    if ore < max_ore_cost || clay < obsidian_clay_cost || obsidian < geode_obsidian_cost
      search[ore + ore_robots, clay + clay_robots, obsidian + obsidian_robots, ore_robots, clay_robots, obsidian_robots, time + 1, new_do_not_build.freeze, geodes]
    end
  }

  search[1, 0, 0, 1, 0, 0, 1, {}.freeze, 0]

  most_geodes_so_far
end

# Only need this to test that potentials aren't getting wrong answers.
bench_candidates << def minutewise_without_potential(blueprint, time_limit)
  minutewise_with_potential(blueprint, time_limit) { time_limit * time_limit }
end if false

bench_candidates << def minutewise_triangular_geode(blueprint, time_limit)
  minutewise_with_potential(blueprint, time_limit) { |time| triangular(time_limit - time - 1) }
end

bench_candidates << def minutewise_triangular_obsidian(blueprint, time_limit)
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  minutewise_with_potential(blueprint, time_limit) { |start_time, _, obsidian, _, obsidian_robots|
    time_left_geode = time_limit - 2 - start_time
    time_left_obsidian = time_limit - 4 - start_time

    obsidian += time_left_geode * obsidian_robots
    obsidian += triangular(time_left_obsidian + 1) if time_left_obsidian >= 0

    new_geode_robots = [obsidian / geode_obsidian_cost, time_left_geode + 1].min
    missing_geode_robots = time_left_geode + 1 - new_geode_robots

    triangular(time_left_geode + 1) - triangular(missing_geode_robots)
  }
end

bench_candidates << def minutewise_triangular_clay(blueprint, time_limit)
  geode_obsidian_cost = blueprint[:geode][:obsidian]
  obsidian_clay_cost = blueprint[:obsidian][:clay]

  minutewise_with_potential(blueprint, time_limit) { |start_time, clay, obsidian, clay_robots, obsidian_robots|
    time_left_geode = time_limit - 2 - start_time
    time_left_obsidian = time_limit - 4 - start_time
    time_left_clay = time_limit - 6 - start_time

    clay += time_left_obsidian * clay_robots
    clay += triangular(time_left_clay + 1) if time_left_clay >= 0

    new_obsidian_robots = [clay / obsidian_clay_cost, time_left_obsidian + 1].min
    missing_obsidian_robots = time_left_obsidian + 1 - new_obsidian_robots

    obsidian += time_left_geode * obsidian_robots
    obsidian += triangular(time_left_obsidian + 1) - triangular(missing_obsidian_robots)

    new_geode_robots = [obsidian / geode_obsidian_cost, time_left_geode + 1].min
    missing_geode_robots = time_left_geode + 1 - new_geode_robots

    triangular(time_left_geode + 1) - triangular(missing_geode_robots)
  }
end

bench_candidates << def minutewise_sim_obsidian(blueprint, time_limit)
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  minutewise_with_potential(blueprint, time_limit) { |start_time, _, obsidian, _, obsidian_robots|
    (start_time..(time_limit - 2)).sum { |time|
      can_build_geode = obsidian >= geode_obsidian_cost

      obsidian += obsidian_robots

      obsidian_robots += 1
      can_build_geode ? time_limit - time - 1 : 0
    }
  }
end

bench_candidates << def minutewise_sim_clay(blueprint, time_limit)
  obsidian_clay_cost = blueprint[:obsidian][:clay]
  geode_obsidian_cost = blueprint[:geode][:obsidian]

  minutewise_with_potential(blueprint, time_limit) { |start_time, clay, obsidian, clay_robots, obsidian_robots|
    (start_time..(time_limit - 2)).sum { |time|
      can_build_obsidian = clay >= obsidian_clay_cost
      can_build_geode = obsidian >= geode_obsidian_cost

      clay += clay_robots
      obsidian += obsidian_robots

      clay_robots += 1
      obsidian_robots += 1 if can_build_obsidian
      can_build_geode ? time_limit - time - 1 : 0
    }
  }
end

robot = /Each ([a-z]+) robot costs ([^.]+)\./

blueprints = ARGF.map.with_index(1) { |line, id|
  raise "bad line didn't start with Blueprint #{id}: #{line}" unless line.start_with?("Blueprint #{id}:")
  line.scan(robot).to_h { |gathers, costs|
    [gathers.to_sym, costs.split(' and ').to_h { |thing| a, b = thing.split; [b.to_sym, Integer(a)] }.freeze]
  }.freeze
}.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = blueprints.map { |bp| [send(f, bp, 24), send(f, bp, 32)] }.transpose } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end

p results.values.uniq[0]
