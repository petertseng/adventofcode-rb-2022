require 'benchmark'

bench_candidates = []

bench_candidates << def iter(s, n)
  s.size.times.find { |i| s[i, n].chars.uniq.size == n } &.+ n
end

bench_candidates << def count_hash_no_delete(s, n)
  count = Hash.new(0)
  s[0, n].each_char { |c| count[c] += 1 }
  (n...s.size).each { |i|
    return i if count.values.all? { |n| n <= 1 }
    count[s[i]] += 1
    count[s[i - n]] -= 1
  }
end

bench_candidates << def count_hash_delete(s, n)
  count = Hash.new(0)
  s[0, n].each_char { |c| count[c] += 1 }
  (n...s.size).each { |i|
    return i if count.values.all? { |n| n <= 1 }
    count[s[i]] += 1
    prevc = s[i - n]
    prev_count = count[prevc]
    if prev_count == 1
      count.delete(prevc)
    else
      count[prevc] = prev_count - 1
    end
  }
end

bench_candidates << def count_hash_counter(s, n)
  count = Hash.new(0)
  repeats = 0
  s[0, n].each_char { |c| repeats += 1 if (count[c] += 1) == 2 }
  (n...s.size).each { |i|
    return i if repeats == 0
    c = s[i]
    repeats += 1 if (count[c] += 1) == 2
    prevc = s[i - n]
    repeats -= 1 if (count[prevc] -= 1) == 1
  }
end

bench_candidates << def count_array(s, n)
  count = Array.new(26, 0)
  a = ?a.ord
  s[0, n].each_char { |c| count[c.ord - a] += 1 }
  (n...s.size).each { |i|
    return i if count.all? { |n| n <= 1 }
    count[s[i].ord - a] += 1
    count[s[i - n].ord - a] -= 1
  }
end

bench_candidates << def count_array_counter(s, n)
  count = Array.new(26, 0)
  repeats = 0
  a = ?a.ord
  s[0, n].each_char { |c| repeats += 1 if (count[c.ord - a] += 1) == 2 }
  (n...s.size).each { |i|
    return i if repeats == 0
    repeats += 1 if (count[s[i].ord - a] += 1) == 2
    repeats -= 1 if (count[s[i - n].ord - a] -= 1) == 1
  }
end

bench_candidates << def index(s, n)
  last_seen = Array.new(26, -n)
  first_possible = n
  a = ?a.ord
  s.each_char.with_index { |c, i|
    return i if first_possible == i
    o = c.ord - a
    prev = last_seen[o]
    first_possible = [first_possible, prev + n + 1].max if i - prev < n
    last_seen[o] = i
  }
end

signal = ARGF.read.freeze

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 50.times { results[f] = send(f, signal, 14) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
