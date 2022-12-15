# adventofcode-rb-2022

For the eighth year in a row, it's the time of the year to do [Advent of Code](http://adventofcode.com) again.

The solutions are written with the following goals, with the most important goal first:

1. **Speed**.
   Where possible, use efficient algorithms for the problem.
   Solutions that take more than a second to run are treated with high suspicion.
   This need not be overdone; micro-optimisation is not necessary.
2. **Readability**.
3. **Less is More**.
   Whenever possible, write less code.
   Especially prefer not to duplicate code.
   This helps keeps solutions readable too.

All solutions are written in Ruby.
Features from 3.0.x will be used, with no regard for compatibility with past versions.
`Enumerable#to_h` with block is anticipated to be the most likely reason for incompatibility (will make it incompatible with 2.5).

# Input

In general, all solutions can be invoked in both of the following ways:

* Without command-line arguments, takes input on standard input.
* With command-line arguments, reads input from the named files (- indicates standard input).

Some may additionally support other ways:

* None yet

# Highlights

Favourite problems:

* Day 09 (Rope Bridge): Interesting problem to think about for sure!
* Day 14 (Regolith Reservoir): Good to revisit an old favourite (2018 day 17).
* Day 15 (Beacon Exclusion Zone): Also good to revisit an easier version of a tough problem (2018 day 23) and see that many of the same tricks apply. Good opportunities for optimisation.

Interesting approaches:

* Day 06 (Tuning Trouble): You know, it's too bad. I came up with a nice O(n) algorithm (rather than O(mn)) since this is similar to some commonly-seen questions, but you can barely tell the difference with m = 14.
* Day 08 (Treetop Tree House): You can figure out all viewing distances to the left by scanning left-to-right across the trees.
  You can then repeat this for each of the four directions.
* Day 11 (Monkey in the Middle): All items can be simulated independently of each other.
  You can then find cycles in the item positions and use them to skip most (> 97%) of the iterations.
* Day 13 (Distress Signal): An interesting refresher on how to write a parser (I refuse to use eval on untrusted inputs).
* Day 14 (Regolith Reservoir): Just like in 2018 day 17, there's no need to retrace the sand's path every time.
  This time it's even easier to achieve this:
  Each grain of falling sand spawns three grains at positions beneath itself, then fills itself in.
* Day 15 (Beacon Exclusion Zone): Just like in 2018 day 23, a change of coordinate system allows the sensors' ranges to easily be described with linear equations.
  https://www.reddit.com/r/adventofcode/comments/a9co1u/day_23_part_2_adversarial_input_for_recursive/ecmpxad/
  Since there is only one undetected point, we see that it has to lie just beyond a sensor's range in all four directions, so extend all sensors and look for where a pair of ranges where this is true in both the rising and falling directions.

# Takeaways

* Day 03 (Rucksack Reorganisation): I wasted some time by mapping both uppercase and lowercase letters to 1-26.
  Might want to instead do things like in a way that doesn't leave it open to mistakes, like `with_index(1).to_h` or something.
* Day 05 (Supply Stacks): Parsing was harder than the actual problem.
  Might want to consider transposing for things like this.
  A little time spent thinking about it and deciding to transpose could have overall saved time compared to just trying to impelement parsing left-to-right as fast as possible.
* Day 07 (No Space Left On Device): My initial version actually wasted some time by keeping unnecessary information: The full path and size of each individual file, instead of directories.
  Perhaps the takeaway here is to only keep the information that is necessary to solve the problem and no more.
  The problem was that I did not consider it safe to assume that all the information for one directory would arrive at one chunk.
  Though if you think about it, it has to, because otherwise the results from `ls` would have had to be inconsistent.
  I'm not sure what the takeaway here is, then; it could be about judging which assumptions are safe to make.
* Day 08 (Treetop Tree House): It was frustrating that `take_while` doesn't work.
  You need to conditionally add 1 to its result, or not.
  In my alternative solution, I didn't cleanly split the height comparison into possible cases (less, equal, greater) and thus did the wrong thing by double-counting trees that are equal.
  Worth considering how each of the three cases handles when faced with such a situation.
  A colleague has since suggested unconditionally adding 1, but upper-bounding by how many trees there actually are in that direction, which works well.
* Day 09 (Rope Bridge): Actually part 2 warned us that "more types of motion are possible than before", which is indeed the case, since tails can move diagonally, whereas the head never does.
  I didn't cover this case since I didn't write an `else raise "invalid"` (or similar) in my follow check.
  So if an earlier part's assumption could potetially be violated, there needs to be an assertion on that assumption.

# Posting schedule and policy

Before I post my day N solution, the day N leaderboard **must** be full.
No exceptions.

Waiting any longer than that seems generally not useful since at that time discussion starts on [the subreddit](https://www.reddit.com/r/adventofcode) anyway.

Solutions posted will be **cleaned-up** versions of code I use to get leaderboard times (if I even succeed in getting them), rather than the exact code used.
This is because leaderboard-seeking code is written for programmer speed (whatever I can come up with in the heat of the moment).
This often produces code that does not meet any of the goals of this repository (seen in the introductory paragraph).

# Past solutions

The [index](https://github.com/petertseng/adventofcode-common/blob/master/index.md) lists all years/languages I've ever done (or will ever do).
