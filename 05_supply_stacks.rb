crates, moves = ARGF.read.split("\n\n", 2).map(&:lines)

moves.map! { |move|
  case move.split
  in ['move', n, 'from', from, 'to', to]; [n, from, to].map(&method(:Integer)).freeze
  else raise "bad move #{move}"
  end
}.freeze

labels = crates.pop.split.map(&method(:Integer))
raise "bad labels #{labels}" if labels != (1..labels.size).to_a

orig_crates = crates.map { |line|
  line.chars.each_slice(4).map { |crate|
    space = crate.pop
    raise "non-space #{space} between crates" if space != ' ' && space != "\n"

    case crate
    in [?[, letter, ?]]
      raise "bad crate content #{letter}" unless (?A..?Z).cover?(letter)
      letter.freeze
    in [' ', ' ', ' ']; nil
    else raise "bad crate format #{crate}"
    end
  }
}.transpose.map! { |stack|
  stack.drop_while(&:nil?).freeze.tap { raise "stack #{_1} has gap" if _1.include?(nil) }
}.freeze

%i(reverse itself).each { |transform|
  crates = orig_crates.map(&:dup).freeze
  moves.each { |n, from, to|
    crates[to - 1].unshift(*crates[from - 1].shift(n).send(transform))
  }
  puts crates.map(&:first).join
}
