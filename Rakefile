require 'shellwords'

def lasm *args
  system "./lasm #{args.shelljoin}"
end

task :clean do |t|
  FileList['**/*.hex'].each(&method(:rm))
end

task :traps do |t|
  [[:getc, 0x2700], [:outc, 0x2770], [:and, 0x254e], [:ldr, 0x2600]].each do |(obj, addr)|
    lasm "./traps/#{obj}.asm", "#{'%#04x' % addr}"
    puts
  end
end

task :native do |t|
  [:echo].each do |obj|
    lasm "./native/#{obj}.asm", "0x2400"
    puts
  end
end

task :test do |t|
  [:and, :getc, :outc, :ldr, :stop].each do |obj|
    lasm "./test/test_#{obj}.asm", "0x2400"
    puts
  end
end

task :all => [:traps, :native, :test]
task :default => :all
