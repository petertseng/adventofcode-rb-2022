verbose = ARGV.delete('-v')

cwd = []
names_this_ls = nil

# Only calculate each directory's directly-contained size initially.
# This avoids repeatedly doing multi-level updates.
# Indirectly-contained sizes are calculated only after directly-contained sizes are done.
dirsizes_nonrec = ARGF.each_with_object({[].freeze => :never_lsed}) { |line, dirsizes|
  case line.split
  in [?$, 'cd', arg]
    names_this_ls = nil
    case arg
    when ?/; cwd = []
    when '..'; raise 'unix allows cd .. from /, but advent of code never does it' unless cwd.pop
    else; cwd << arg.freeze
    end
  in %w($ ls)
    # If the input ever `ls` the same directory twice,
    # then its contents will be double-counted.
    # Ensure that no input does this.
    raise "ls #{cwd} twice" if dirsizes.fetch(cwd) != :never_lsed
    # cwd is fine here instead of cwd.dup.freeze.
    # It was already frozen by creation in dir case
    dirsizes[cwd] = 0
    names_this_ls = {}
  in ['dir', dirname]
    raise "dir #{dirname} outside of ls" unless names_this_ls
    if exist = names_this_ls[dirname]
      raise "in #{cwd}, #{dirname} was a #{exist} and now is a dir"
    end
    names_this_ls[dirname] = :dir
    dirsizes[(cwd + [dirname.freeze]).freeze] = :never_lsed
  in [size, filename]
    raise "file #{line} outside of ls" unless names_this_ls
    if exist = names_this_ls[filename]
      raise "in #{cwd}, #{filename} was a #{exist} and now is a file #{size}"
    end
    # cwd is fine here instead of cwd.dup.freeze.
    # It was already frozen by creation in dir case
    dirsizes[cwd] += (names_this_ls[filename] = Integer(size))
  else
    raise "bad cmd #{line}"
  end
}.freeze

p dirsizes_nonrec if verbose

never_lsed = dirsizes_nonrec.select { |_, v| v == :never_lsed }
raise "never lsed #{never_lsed.keys}" unless never_lsed.empty?

# Now children all add their size to their parents' sizes.
# By going in descending length order,
# we ensure we have all children before adding to parent.
dirsizes_rec = dirsizes_nonrec.dup
dirsizes_nonrec.keys.sort_by(&:size).reverse_each { |k|
  next if k == []
  dirsizes_rec[k[0..-2]] += dirsizes_rec[k]
}
dirsizes_rec.freeze

p dirsizes_rec if verbose

puts dirsizes_rec.values.select { _1 <= 100000 }.sum
need = dirsizes_rec[[]] - 40000000
puts dirsizes_rec.values.select { _1 >= need }.min
