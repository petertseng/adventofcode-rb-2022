require 'benchmark'

bench_candidates = []

Monkey = Struct.new(:starting_items, :op, :divisor, :if_true, :if_false)

bench_candidates << def monkeywise(monkeys, nrounds, &worry)
  items = monkeys.map { |m| m.starting_items.dup }.freeze
  inspects = Array.new(monkeys.size, 0)

  nrounds.times {
    monkeys.zip(items).each_with_index { |(monkey, q), i|
      inspects[i] += q.size
      q.each { |item|
        new_item = worry[monkey.op[item]]
        dest = monkey[new_item % monkey.divisor == 0 ? :if_true : :if_false]
        items[dest] << new_item
      }
      q.clear
    }
  }

  inspects.freeze
end

bench_candidates << def itemwise(monkeys, nrounds, &worry)
  inspects = Array.new(monkeys.size, 0)

  monkeys.each_with_index { |m, i|
    m.starting_items.each { |item|
      rounds_left = nrounds
      item_pos = i
      while rounds_left > 0
        inspects[item_pos] += 1
        monkey = monkeys[item_pos]
        item = worry[monkey.op[item]]
        dest = monkey[item % monkey.divisor == 0 ? :if_true : :if_false]
        rounds_left -= 1 if dest < item_pos
        item_pos = dest
      end
    }
  }

  inspects.freeze
end

bench_candidates << def itemwise_cycle_detection(monkeys, nrounds, &worry)
  inspects = Array.new(monkeys.size, 0)
  monkey_bits = monkeys.size.bit_length

  monkeys.each_with_index { |m, i|
    m.starting_items.each { |item|
      rounds_left = nrounds
      item_pos = i
      history = {}
      inspects_in_cycle = nil
      rounds_left_in_cycle = nil
      cycle_length = nil

      while rounds_left > 0
        inspects[item_pos] += 1
        inspects_in_cycle[item_pos] += 1 if cycle_length
        monkey = monkeys[item_pos]
        item = worry[monkey.op[item]]
        dest = monkey[item % monkey.divisor == 0 ? :if_true : :if_false]
        if dest < item_pos
          rounds_left -= 1

          if cycle_length
            if (rounds_left_in_cycle -= 1) == 0
              complete_cycles = rounds_left / cycle_length
              rounds_left -= complete_cycles * cycle_length
              inspects_in_cycle.each_with_index { |insp, i|
                inspects[i] += insp * complete_cycles
              }
            end
          else
            cache_key = item << monkey_bits | dest
            if prev = history[cache_key]
              inspects_in_cycle = Array.new(monkeys.size, 0)
              cycle_length = prev - rounds_left
              rounds_left_in_cycle = cycle_length
            else
              history[cache_key] = rounds_left
            end
          end
        end
        item_pos = dest
      end
    }
  }

  inspects.freeze
end

monkeys = ARGF.each("\n\n", chomp: true).map.with_index { |monkey, i|
  lines = monkey.lines(chomp: true)
  parse = ->(prefix, &b) {
    l = lines.shift
    raise "#{l} didn't start with #{prefix}" unless l.start_with?(prefix)
    b[l.delete_prefix(prefix)].freeze
  }
  id = parse['Monkey '] { |i| Integer(i.delete_suffix(?:)) }
  raise "monkey #{id} != #{i}" if id != i

  Monkey.new(
    parse['  Starting items: '] { _1.split(', ').map(&method(:Integer)) },
    parse['  Operation: new = old '] {
      case _1.split
      in %w(* old); ->x { x * x }
      in [?*, s]; n = Integer(s); ->x { x * n }
      in [?+, s]; n = Integer(s); ->x { x + n }
      end
    },
    parse['  Test: divisible by ', &method(:Integer)],
    parse['    If true: throw to monkey ', &method(:Integer)],
    parse['    If false: throw to monkey ', &method(:Integer)],
  ).freeze.tap { raise "garbage #{lines}" unless lines.empty? }
}.freeze

prod = monkeys.map(&:divisor).reduce(1, :*)

results = {}

Benchmark.bmbm { |bm|
  bench_candidates.each { |f|
    bm.report(f) { 1.times { results[f] = send(f, monkeys, 10000) { |n| n % prod } } }
  }
}

# Obviously the benchmark would be useless if they got different answers.
if results.values.uniq.size != 1
  results.each { |k, v| puts "#{k} #{v}" }
  raise 'differing answers'
end
