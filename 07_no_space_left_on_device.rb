verbose = ARGV.delete('-v')

cwd = []
lsing = false

# Only calculate each directory's directly-contained size initially.
# This avoids repeatedly doing multi-level updates.
# Indirectly-contained sizes are calculated only after directly-contained sizes are done.
dirsizes_nonrec = ARGF.each_line(chomp: true).each_with_object({}) { |line, dirsizes|
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

p dirsizes_nonrec if verbose

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
