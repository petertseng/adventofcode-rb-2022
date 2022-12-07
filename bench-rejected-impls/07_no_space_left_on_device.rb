require 'benchmark'

bench_candidates = []

cmds = ARGF.map(&:chomp).map(&:freeze).freeze

results = {}

# Immediately add size to all ancestors.
bench_candidates << def immediate(cmds)
  cwd = []
  lsing = false

  cmds.each_with_object({}) { |line, dirsizes|
    case line.split
    in [?$, 'cd', arg]
      lsing = false
      case arg
      when ?/; cwd = []
      when '..'; cwd.pop
      else cwd << arg.freeze
      end
    in %w($ ls)
      # If the input ever `ls` the same directory twice,
      # then its contents will be double-counted.
      # Ensure that no input does this.
      raise "ls #{cwd} twice" if dirsizes.has_key?(cwd)
      dirsizes[cwd.dup.freeze] = 0
      lsing = true
    in ['dir', dirname]
      raise "dir #{dirname} outside of ls" unless lsing
    in [size, _]
      raise "file #{line} outside of ls" unless lsing
      size = Integer(size)
      (0..cwd.size).each { |n|
        dirsizes[cwd[0, n].freeze] += size
      }
    else
      raise "bad cmd #{line}"
    end
  }.freeze
end

# Only calculate each directory's directly-contained size initially.
# This avoids repeatedly doing multi-level updates.
# Indirectly-contained sizes are calculated only after directly-contained sizes are done.
bench_candidates << def delayed(cmds)
  cwd = []
  lsing = false

  dirsizes_nonrec = cmds.each_with_object({}) { |line, dirsizes|
    case line.split
    in [?$, 'cd', arg]
      lsing = false
      case arg
      when ?/; cwd = []
      when '..'; cwd.pop
      else; cwd << arg.freeze
      end
    in %w($ ls)
      # If the input ever `ls` the same directory twice,
      # then its contents will be double-counted.
      # Ensure that no input does this.
      raise "ls #{cwd} twice" if dirsizes.has_key?(cwd)
      dirsizes[cwd.dup.freeze] = 0
      lsing = true
    in ['dir', dirname]
      raise "dir #{dirname} outside of ls" unless lsing
    in [size, _]
      raise "file #{line} outside of ls" unless lsing
      # cwd is fine here instead of cwd.dup.freeze.
      # It was already frozen by creation in ls case
      dirsizes[cwd] += Integer(size)
    else
      raise "bad cmd #{line}"
    end
  }.freeze

  dirsizes_rec = dirsizes_nonrec.dup
  dirsizes_nonrec.keys.sort_by(&:size).reverse_each { |k|
    next if k == []
    dirsizes_rec[k[0..-2]] += dirsizes_rec[k]
  }
  dirsizes_rec.freeze
end

# if we assume the input always comes in a DFS,
# we know we can propagate on a cd ..
bench_candidates << def assume_dfs(cmds)
  cwd = []
  lsing = false
  current_dir_size = 0
  saved_sizes = []

  dirsizes = {}

  popdir = -> {
    # cwd is fine here instead of cwd.dup.freeze.
    # It was already frozen by creation in ls case
    dirsizes[cwd] = current_dir_size
    cwd.pop
    current_dir_size += saved_sizes.pop
  }
  popall = -> {
    popdir[] until cwd.empty?
    raise 'mismatch in saved sizes' unless saved_sizes.empty?
  }

  cmds.each { |line|
    case line.split
    in [?$, 'cd', arg]
      lsing = false
      case arg
      when ?/; popall[]
      when '..'; popdir[]
      else
        cwd << arg.freeze
        saved_sizes << current_dir_size
        current_dir_size = 0
      end
    in %w($ ls)
      # If the input ever `ls` the same directory twice,
      # then its contents will be double-counted.
      # Ensure that no input does this.
      raise "ls #{cwd} twice" if dirsizes.has_key?(cwd)
      dirsizes[cwd.dup.freeze] = 0
      lsing = true
    in ['dir', dirname]
      raise "dir #{dirname} outside of ls" unless lsing
    in [size, _]
      raise "file #{line} outside of ls" unless lsing
      current_dir_size += Integer(size)
    else
      raise "bad cmd #{line}"
    end
  }

  popall[]
  dirsizes[[].freeze] = current_dir_size

  dirsizes
end

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 50.times { results[f] = send(f, cmds) } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
