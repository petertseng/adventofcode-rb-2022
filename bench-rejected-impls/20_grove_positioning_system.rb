require 'benchmark'

bench_candidates = []

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

  def self.mix(nums, rounds)
    bkt = BucketList.new(nums.size)
    rounds.times {
      nums.each_with_index { |num, i| bkt.move(i, num % (nums.size - 1)) }
    }
    bkt
  end

  def self.to_a(bkt, orig_nums)
    is = bkt.to_a
    nums = is.map { |i| orig_nums[i] }
    nums.rotate(is.index(orig_nums.index(0)))
  end
end

bench_candidates << BucketList

# https://cs.brown.edu/cgc/jdsl/papers/tiered-vector.pdf
# Except we don't need insert/delete, only moving an element,
# and we need a map tracking every element's queue index.
#
# https://arxiv.org/pdf/1711.00275.pdf ("Fast Dynamic Arrays")
# adds additional tiers, but I think I do not want to go to the effort,
# so just the basic two-tiered one for now.
class TieredVector
  # Needs to be a power of 2 such that SIZE**2 > N
  # since is 5000, 64 is too small (64*64=4096) so we use 128.
  SIZE = 128
  MASK = SIZE - 1
  SHIFT = SIZE.to_s(2).count(?0)

  def initialize(size)
    # Being low-effort and using the native Array
    # (which has O(1) insert/delete on both ends,
    # so is a double-ended queue)
    # instead of circular arrays
    @qs = (0...size).each_slice(SIZE).to_a.freeze
    @qidx = @qs.each_with_index.flat_map { |q, i| q.map { |x| [x, i] } }.to_h
    @size = size
  end

  def [](i)
    @qs[i >> SHIFT][i & MASK]
  end

  def index(x)
    return nil unless qi = @qidx[x]
    return nil unless i_in_q = @qs[qi].index(x)
    qi << SHIFT | i_in_q
  end

  def to_a
    @qs.flatten(1)
  end

  def move(x, di)
    return nil unless qi = @qidx[x]
    return nil unless i_in_q = @qs[qi].index(x)
    @qs[qi].delete_at(i_in_q)
    i = qi << SHIFT | i_in_q

    new_i = (i + di) % (@size - 1)
    new_qi = new_i >> SHIFT
    new_i_in_q = new_i & MASK

    if new_qi > qi
      @qs[qi..new_qi].each_cons(2).with_index(qi) { |(q1, q2), j|
        q1 << (moved = q2.shift)
        @qidx[moved] = j
      }
    elsif new_qi < qi
      @qs[new_qi..qi].each_cons(2).with_index(new_qi) { |(q1, q2), j|
        q2.unshift(moved = q1.pop)
        @qidx[moved] = j + 1
      }
    end

    @qs[new_qi].insert(new_i_in_q, x)
    @qidx[x] = new_qi
    self
  end

  def self.mix(nums, rounds)
    vec = TieredVector.new(nums.size)
    rounds.times {
      nums.each_with_index { |num, i| vec.move(i, num % (nums.size - 1)) }
    }
    vec
  end

  def self.to_a(vec, orig_nums)
    is = vec.to_a
    nums = is.map { |i| orig_nums[i] }
    nums.rotate(is.index(orig_nums.index(0)))
  end
end

bench_candidates << TieredVector

module LinkedList
  Thing = Struct.new(:v, :l, :r)

  module_function

  def mix(nums, rounds)
    order_to_move = nums.map { |v| Thing.new(v, nil, nil) }.freeze
    zero = order_to_move[nums.index(0)]
    order_to_move.each_cons(2) { |l, r|
      l.r = r
      r.l = l
    }
    order_to_move[0].l = order_to_move[-1]
    order_to_move[-1].r = order_to_move[-1]
    list_size = nums.size

    rounds.times {
      order_to_move.each { |thing|
        next if thing.v == 0
        thing.l.r = thing.r
        thing.r.l = thing.l

        right_steps = thing.v % (list_size - 1)
        left_steps = list_size - 1 - right_steps

        if right_steps <= left_steps
          new_r = thing.r
          right_steps.times { new_r = new_r.r }
          thing.r = new_r
          thing.l = new_r.l
        else
          new_l = thing.l
          left_steps.times { new_l = new_l.l }
          thing.l = new_l
          thing.r = new_l.r
        end
        thing.r.l = thing
        thing.l.r = thing
      }
    }

    zero
  end

  def to_a(zero, _)
    a = [0]
    pt = zero.r
    until pt == zero
      a << pt.v
      pt = pt.r
    end
    a
  end
end

bench_candidates << LinkedList

module ArrayOfPointer
  module_function

  def mix(nums, rounds)
    left = Array.new(nums.size) { |i| i - 1 }
    right = Array.new(nums.size) { |i| i + 1 }
    right[-1] = 0
    list_size = nums.size

    rounds.times {
      nums.each_with_index { |v, i|
        next if v == 0
        right[left[i]] = right[i]
        left[right[i]] = left[i]

        right_steps = v % (list_size - 1)
        left_steps = list_size - 1 - right_steps

        if right_steps <= left_steps
          new_r = right[i]
          right_steps.times { new_r = right[new_r] }
          right[i] = new_r
          left[i] = left[new_r]
        else
          new_l = left[i]
          left_steps.times { new_l = left[new_l] }
          left[i] = new_l
          right[i] = right[new_l]
        end
        left[right[i]] = i
        right[left[i]] = i
      }
    }

    right
  end

  def to_a(right, nums)
    a = [0]
    zero = nums.index(0)
    pt = right[zero]
    until pt == zero
      a << nums[pt]
      pt = right[pt]
    end
    a
  end
end

bench_candidates << ArrayOfPointer

# Surprisingly competitive?
module ArrayInsertDelete
  module_function

  def mix(nums, rounds)
    mixed = (0...nums.size).to_a

    rounds.times {
      mixed.each_index { |orig_v|
        next if (v = nums[orig_v]) == 0
        orig_i = mixed.index(orig_v)
        new_i = (orig_i + v) % (nums.size - 1)
        mixed.delete_at(orig_i)
        mixed.insert(new_i, orig_v)
      }
    }

    mixed.freeze
  end

  def to_a(is, orig_nums)
    nums = is.map { |i| orig_nums[i] }
    nums.rotate(is.index(orig_nums.index(0)))
  end
end

bench_candidates << ArrayInsertDelete

# Surprisingly competitive?
module ArrayRotate
  module_function

  def mix(nums, rounds)
    mixed = (0...nums.size).to_a

    rounds.times {
      mixed.each_index { |orig_v|
        next if (v = nums[orig_v]) == 0
        mixed.rotate!(mixed.index(orig_v))
        mixed.shift
        mixed.rotate!(v)
        mixed.unshift(orig_v)
      }
    }

    mixed.freeze
  end

  def to_a(is, orig_nums)
    nums = is.map { |i| orig_nums[i] }
    nums.rotate(is.index(orig_nums.index(0)))
  end
end

bench_candidates << ArrayRotate

nums = ARGF.map { |n| Integer(n) * 811589153 }.freeze

results2 = {}

puts 'mix'

Benchmark.bmbm { |bm|
  bench_candidates.each { |mod|
    bm.report(mod) { 1.times { results2[mod] = mod.mix(nums, 10) } }
  }
}

results = {}

puts 'to_a'

Benchmark.bmbm { |bm|
  bench_candidates.each { |mod|
    bm.report(mod) { 1.times { results[mod] = mod.to_a(results2[mod], nums) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
