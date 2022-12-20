# https://github.com/p88h/aoc2022/blob/main/lib/day20.cs
# https://www.reddit.com/r/adventofcode/comments/zqezkn/2022_day_20_solutions/j0yaksg/
class BucketList
  # 96 * 96 = 9216,
  # this seems to work slightly better than 71 or 72 (sqrt 5000)
  SIZE = 96

  def initialize(size)
    @buckets = (0...size).each_slice(SIZE).to_a.freeze
    @bucket_idx = @buckets.each_with_index.flat_map { |bucket, i| bucket.map { |x| [x, i] } }.to_h
  end

  def move(x, offset)
    b = @bucket_idx[x]
    offset += @buckets[b].index(x)
    @buckets[b].delete(x)
    while offset > @buckets[b].size
      offset -= @buckets[b].size
      b = (b + 1) % @buckets.size
    end
    @buckets[b].insert(offset, x)
    @bucket_idx[x] = b
  end

  def index(x)
    b = @bucket_idx[x]
    @buckets[0...b].sum(&:size) + @buckets[b].index(x)
  end

  def [](i)
    b = 0
    until i < @buckets[b].size
      i -= @buckets[b].size
      b += 1
    end
    @buckets[b][i]
  end

  def to_a
    @buckets.flatten(1)
  end
end

cont = BucketList

def mix(nums, cont)
  nums.each_with_index { |num, i| cont.move(i, num % (nums.size - 1)) }
  cont
end

def grove(cont, zero, nums)
  zi = cont.index(zero)
  [1000, 2000, 3000].sum { |i| nums[cont[(zi + i) % nums.size]] }
end

orig_nums = ARGF.map(&method(:Integer)).freeze
zero = orig_nums.index(0)

puts grove(mix(orig_nums, cont.new(orig_nums.size)), zero, orig_nums)

bignums = orig_nums.map { |v| v * 811589153 }.freeze
bkt = cont.new(bignums.size)
10.times { mix(bignums, bkt) }
puts grove(bkt, zero, bignums)
