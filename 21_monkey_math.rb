module RationalDivision
  refine(Integer) {
    def /(v)
      Rational(self, v)
    end
  }
end
using RationalDivision

def monkey_math(monkeys)
  Hash.new { |h, k|
    v = monkeys.fetch(k)
    h[k] = v.is_a?(Integer) ? v : h[v[0]].send(v[1], h[v[2]])
  }
end

verbose = ARGV.delete('-v')

monkeys = ARGF.to_h { |line| line.split(': ', 2) }.transform_values { |v|
  if v.match?(/\A\d+$/)
    Integer(v)
  elsif v.match?(/\A\w+ [-+*\/] \w+$/)
    v.split.map(&:freeze).freeze
  else
    raise "bad monkey #{v}"
  end
}.freeze

must_be_int = ->rat {
  raise "#{rat} isn't int" if rat.denominator != 1
  rat.to_i
}

orig = monkey_math(monkeys)
puts must_be_int[orig['root']]

rootl, _, rootr = monkeys.fetch('root')
human0 = monkey_math(monkeys.merge('humn' => 0))
leq = human0[rootl] == orig[rootl]
req = human0[rootr] == orig[rootr]

change_monkey, change_val, check_val = case [leq, req]
when [true, false]; [rootr, human0[rootr], orig[rootl]]
when [false, true]; [rootl, human0[rootl], orig[rootr]]
when [false, false]; raise 'both changed'
when [true, true]; raise 'neither changed'
else raise 'impossible'
end

guess = ->g { monkey_math(monkeys.merge('humn' => g))[change_monkey] }

next_guess = ->(prev_guess, prev_result, current_guess) {
  new_result = guess[current_guess]
  delta_result = new_result - prev_result
  remaining_diff = check_val - new_result
  [new_result, (current_guess + (current_guess - prev_guess) * remaining_diff.fdiv(delta_result)).round]
}

prev_guess = 0
prev_result = change_val
current_guess = 100
1.step { |t|
  new_result, new_guess = next_guess[prev_guess, prev_result, current_guess]
  puts "#{t}: #{prev_guess} -> #{prev_result} and #{current_guess} -> #{new_result}. next guess #{new_guess}" if verbose
  break if new_guess == current_guess
  prev_guess = current_guess
  prev_result = new_result
  current_guess = new_guess
}

puts current_guess
