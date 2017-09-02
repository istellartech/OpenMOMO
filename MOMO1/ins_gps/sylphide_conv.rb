#!/usr/bin/ruby
# coding: cp932

$stderr.puts "Converter to Sylphide data from multiple files"
$stderr.puts " Usage: #{$0} [--key[=value]]"

[
  File::dirname(__FILE__),
].each{|dir|
  $: << dir unless $:.include?(dir)
}

opt = {
  :prefix => :telem1,
  :inertial => 'sensors.csv',
  :posvel => 'ecef_ecefvel.csv',
}

ARGV.reject!{|arg|
  next false unless arg =~ /--([^=]+)/
  opt[$1.to_sym] = ($'[0] == '=' ? $' : true)
  true
}

opt[:data_dir] ||= File::join(File::dirname(__FILE__), '..', 'csv', opt[:prefix].to_s)
[:inertial, :posvel].each{|k|
  opt[k] = "#{opt[:prefix]}_#{opt[k]}"
} if opt[:prefix] and ('' != opt[:prefix])

$stderr.puts "options: #{opt}"

inertial2imu_csv = proc{|out|
  # read CSV and write [t,accelX,Y,Z,omegaX,Y,Z]
  open(File::join(opt[:data_dir], opt[:inertial])){|io|
    header = io.readline.chomp.split(/, */)
    
    index = ["T[s]",
        "ax[g]", "ay[g]", "az[g]",
        "wx[dps]", "wy[dps]", "wz[dps]"].collect{|k|
      header.index(k)
    }
    io.each{|line|
      values = line.chomp.split(/, */)
      out.puts index.collect{|i|
        values[i].to_f
      }.join(',')
    }
  }
  out
}

inertial2imu_csv.call($stdout)