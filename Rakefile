task :clean do |t|
  FileList['**/*.hex'].each(&method(:rm))
end

task :traps do |t|
  [[:getc, 0x2700], [:outc, 0x2750], [:and, 0x254e], [:ldr, 0x2600]].each do |(obj, addr)|
    system "./lasm ./traps/#{obj}.asm #{'%#04x' % addr}"
    puts
  end
end

task :default => :traps