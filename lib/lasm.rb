### LASM: Little Assembler ###
### Morgan Jones, ELEC 220 ###

# LASM works like a normal assembler, except that commas are optional and most stuff
# takes only one argument. It has the .fill virtual opcode, too. That's about it. It works, but isn't fancy.
# Usage: lasm <input.asm> <starting address>
# Output is saved to input.hex as .word commands for IAR.

# &LABEL: Absolute label
# @ADDR:  Absolute address
# %ADDR: Trap label
# !ADDR: Trap address (offset from 0x2800)

verbosity, $VERBOSE = $VERBOSE, nil

module LASMRefinements
  refine Integer do
    def calc
      # Addresses of 0x1000 and above are offset by 0x1400 by the emulator.
      # Subtract the RAM offset and AND it so we can fit it into 13 bits.
      (self >= 0x2400 ? self - 0x1400 : self) & 0x1fff
    end
  end
  refine String do
    # Parses this string with assembly syntax
    def parse
      m = match(/\A(?<virtual>\.)?(?<opcode>[a-z0-9_]+)(?<label>:)?\s*?(?<args>.*)\z/)
      raise "error parsing" if m.nil? || m[:opcode].nil?
      {virtual: !m[:virtual].nil?, label: !m[:label].nil?, opcode: m[:opcode].to_sym, args: m[:args]}
    end

    # Dereferences this reference
    def deref
      if self[0] == ?&
        sym = self[1..-1].to_sym
        raise "unknown symbol #{sym}" unless $symbols.include?(sym)
        ($symbols[sym] + $base).calc
      elsif self[0] == ?@
        Integer(self[1..-1]).calc
      elsif self[0] == ?%
        trap = self[1..-1].to_sym
        raise "unknown trap #{trap}" unless $traps.include?(trap)
        ($traps[trap] & 0xff).calc
      elsif self[0] == ?!
        (Integer(self[1..-1]) + 0x2800).calc
      else
        Integer(self)
      end
    end
  end
end

using LASMRefinements
$VERBOSE = verbosity

puts "Little Assembler (#{File.basename $0}), hacked together by Morgan Jones"
puts "Running on " + RUBY_DESCRIPTION
raise "usage: #{$0} <input> <starting address>" if ARGV.count != 2

$in_file, $base = ARGV.shift, Integer(ARGV.shift)
$obj = File.basename($in_file, File.extname($in_file))
$out_file = File.join(File.dirname($in_file), "#{$obj}.hex")
$i, $o = File.open($in_file, 'r'), File.open($out_file, 'w')

raise 'base address must be even' unless $base % 2 == 0

puts "Assembling #{$obj} at base address #{'%#04x' % $base}"

# A table of LC-1 opcodes
$opcodes = {
  # Native opcodes
  native: {
    call: -> *a {0x0000 | a.first.deref},
    ret:  -> *a {0x2000},
    add:  -> *a {0x4000 | a.first.deref},
    br:   -> *a {0x6000 | a.first.deref},
    ld:   -> *a {0x8000 | a.first.deref},
    st:   -> *a {0xa000 | a.first.deref},
    trap: -> *a {0xc000 | a.first.deref}
  },

  # Virtual opcodes
  virtual: {
    fill: -> *a {a.first.deref}
  }
}

# Start out with no defined symbols
$symbols = {}

# Traps are a bit of a special case
$traps = {
  stop: 0,
  getc: 1,
  outc: 2,
  rr:   3,
  not:  4,
  and:  5,
  ldr:  6,
}

# The last dangling label we've parsed
$dangling = nil

# Current offset
$offset = 0

$o.write ([';;; object: %s, base: %#04x' % [$obj, $base]] +
          $i.readlines.tap{puts "[1] Sanitizing input..."}.
          map{|l| l.gsub(/;.+$/, '').downcase.strip}.tap{puts "[2] Pass 1..."}.each_with_index.map { |l, i|
  ### PASS 1 ###
  next nil if l.empty?

  # Regex match it to extract opcode and label
  m = l.parse
  label = nil

  # Add a symbol table entry if this is a label
  if m[:label]
    $dangling = m[:opcode]

    # Continue processing the remainder of the line
    remaining = m[:args].strip
    unless remaining.empty?
      m = m[:args].strip.parse
    else
      next nil
    end
  end

  # Make an intermediate representation
  ret = {opcode: m[:opcode],
         fn: (m[:virtual] ? $opcodes[:virtual][m[:opcode]] : $opcodes[:native][m[:opcode]]),
         args: m[:args].split,
         line: "#{!$dangling.nil? ? '[%s]' % $dangling : ''} #{m[:opcode]} #{m[:args].strip}".strip,
         offset: $offset,
         addr: $offset + $base}

  # Try to un-dangle labels
  unless $dangling.nil?
    raise "symbol #{$dangling} redefined on line #{i + 1} (previous definition: #{'%#04x' % $symbols[$dangling]})" if $symbols.include? $dangling
    $symbols[$dangling] = $offset
    $dangling = nil
  end

  # 8-bit addressability, but 16 bit words
  $offset += 2
  ret
}.reject(&:nil?).tap{puts "[3] Pass 2..."}.map { |l|
  ### PASS 2 ###

  machine_code = l[:fn].(*l[:args])
  ".word    0x%1$04x      ; 0x%3$04x [%1$016b] %2$s" % [machine_code, l[:line], l[:addr]]
}).tap{|a| puts "Assembled `#{$obj}' (#{a.count} words, #{$symbols.count} symbols)"}.join("\n") + "\n"

puts "Cave Johnson. We're done here."
