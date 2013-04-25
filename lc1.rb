$f, $base = File.open(ARGV.shift, 'r'), ARGV.shift.to_i(16)

# A table of LC-1 opcodes
$opcodes = {
  # Native opcodes
  native: {
    call: -> *a {0x0000 | (dereference(a.first) & 0x1fff)},
    ret:  -> *a {0x2000},
    add:  -> *a {0x4000 | (dereference(a.first) & 0x1fff)},
    br:   -> *a {0x6000 | (dereference(a.first) & 0x1fff)},
    ld:   -> *a {0x6000 | (dereference(a.first) & 0x1fff)},
    st:   -> *a {0xa000 | (dereference(a.first) & 0x1fff)},
    trap: -> *a {0xe000 | (dereference(a.first) & 0x1fff)}
  },

  # Virtual opcodes
  virtual: {
    fill: -> *a {dereference a.first}
  }
}

# Start out with no defined symbols
$symbols = {}

# Traps are just external vectors
$extern = {
  stop: 0,
  getc: 1,
  outc: 2
  rr: 3,
  not: 4,
  and: 5,
  ldr: 6
}

def p f, *a
  puts '>> ' + f.send(:%, *a)
end

def extract l
  l.downcase.match(/^(?<virtual>\.)?(?<opcode>[a-z0-9]+)(?<label>:)?\s*?(?<args>.+)$/)
  raise 'line malformed' if m.nil? || m[:opcode].nil?
  {virtual: !m[:virtual].nil?, label: !m[:label].nil?, opcode: m[:opcode].downcase.to_sym, args: m[:args]}
end

def dereference val
  if val[0] == ?&
    $symbols[val[1..-1].to_sym]
  else
    val.to_i
  end
end

# Register external symbols
$symbols.merge! $extern

$o.write $f.readlines.map{|l| l.gsub(/;.+$/, '').strip}.reject(&:empty?).each_with_index.map { |i, l|
  ### PASS 1 ###

  # Regex match it to extract opcode and label
  m = extract l

  # Add a symbol table entry if this is a label
  unless m[:label].nil?
    unless $symbols.include?(m[:opcode])
      $symbols[m[:opcode]] = i + $base
    else
      raise "symbol #{m[:opcode]} redefined (previous definition: #{'%#04x' % $symbols[m[:opcode]]})"
    end

    # Continue processing the remainder of the line
    m = extract m[:args]
  end

  # Make an intermediate representation
  {opcode: m[:opcode], fn: (m[:virtual] ? $opcodes[:virtual][m[:opcode]] : $opcodes[:native][m[:opcode]]), args: m[:args].split}
}.map { |l|
  ### PASS 2 ###

  # Convert to machine code
  '.word %04xh' % l[:fn].(*l[:args])
}.join("\n")
