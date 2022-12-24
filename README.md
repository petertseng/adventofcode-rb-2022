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
* Day 17 (Pyroclastic Flow): Part 1 is a classic, in the cultural sense, and implementing it was inteesting. Part 2 is a classic in the Advent of Code sense and is an interesting application of it.

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
* Day 16 (Proboscidea Volcanium): I had hit upon many of the good ideas early (ignore valves with 0 flow rate, use ints everywhere, cache results).
  However, the single most important optimisation had eluded me:
  To quickly find two disjoint sets of valves without checking all pairs, first sort them by flow descending so you know the maximum possible value achievable by any yet-unexamined route.
  Then you know when to (and should) break out of the inner or outer loop once it's no longer possible to beat the current best.
* Day 17 (Pyroclastic Flow): A lot of solutions differ on how they choose to detect cycles!
  You can detect it just by looking at the height differences.
  But I chose to call it a cycle when five consecutive rocks fall in the same x position and wind index as they did in a previous wind cycle.
* Day 19 (Not Enough Minerals): Many interesting optimisations for this one.
  The code comments give an idea of how much time each optimisation saved.
  There are two main classes of approach:
  Step forward one minute at a time, or step forward one robot at a time.
  I found the per-minute approach to be more performant so I stuck with it.
  A surprisingly good optimisation was to not build a robot you could afford but chose not to build in a previous minute.
* Day 20 (Grove Positioning System): Looking for data structures with fast insert and fast search (possibly by allowing references to elements).
  I stuck with an O(√N) one, but the door is open for exploring whether a O(log N) one would be an improvement.
* Day 21 (Monkey Math): It's interesting that you can define a map (Hash in Ruby) in terms of itself.
  I've actually never done that before in Ruby, though my Haskell solutions do so from time to time.
  To make the two sides equal I originally used binary search but the secant method does turn out to be faster.
  Some others have suggested symbolically inverting the operations, but I haven't tried that approach yet.
* Day 22 (Monkey Map): My solution can't handle arbitrary cube nets, only the specific ones in the example and personal inputs.
  It's all hard-coded, with only a small convenience function that ensures that all connections are symmetric/two-way.
* Day 23 (Unstable Diffusion): Store each row of elves as a bit field.
* Day 24 (Blizzard Basin): Breadth-first search is faster than A\*.
  Store blizzard positions and the set of possible positions of the expedition party as bit fields.
  No visited set is needed because the entire frontier is at the same time step.

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
* Day 16 (Proboscidea Volcanium): The example actively sabotaged me.
  An early strategy I considered was to have the protagonist do as much work as possible, then start the elephant from that point.
  This strategy works for our personal inputs, but gets the wrong answer for the example input because the protagonist does too much work and doesn't leave enough for the elephant to do.
  Allowing the protagonist to stop working at any point (`allow_idle` in the code) allows this approacch to work for the example but be too slow for our personal inputs.
  So, there is no one configuration that works for both the example and our personal inputs.
  I initially did not allow the protagonist to stop at any point, since I did not know this matters, and therefore I would always get an answer that was too low on the example.
  Since it was too low, I didn't bother trying it on my personal input, when in reality it would have worked.
* Day 18 (Boiling Boulders): For inexplicable reasons, I hadn't converted my set of boulders from a list to a set, which slowed down the existence checks.
  Not sure why I didn't do that, really.
* Day 22 (Monkey Map): Ah, unfortunate: I updated my facing to be the facing I would be on the new cube face even if my way was blocked by a wall on the new cube face. You are not supposed to do that. Don't partially update state if the state might get rolled back due to a check. I wasted two hours on this and it was an unpleasant experience. This day is impossible to debug because how are you supposed to pick out the move you got wrong out of 2000?
* Day 24 (Blizzard Basin): I tested against the wrong example so I didn't bother submitting my answer. I should have submitted.

# Posting schedule and policy

Before I post my day N solution, the day N leaderboard **must** be full.
No exceptions.

Waiting any longer than that seems generally not useful since at that time discussion starts on [the subreddit](https://www.reddit.com/r/adventofcode) anyway.

Solutions posted will be **cleaned-up** versions of code I use to get leaderboard times (if I even succeed in getting them), rather than the exact code used.
This is because leaderboard-seeking code is written for programmer speed (whatever I can come up with in the heat of the moment).
This often produces code that does not meet any of the goals of this repository (seen in the introductory paragraph).

# Past solutions

The [index](https://github.com/petertseng/adventofcode-common/blob/master/index.md) lists all years/languages I've ever done (or will ever do).
