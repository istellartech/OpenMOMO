#!/usr/bin/ruby
# coding: cp932

opt = {
  :data_dir => File::join(File::dirname(__FILE__), '..', 'telemetry_csv', 'C_band'),
  :basetime => "2019-05-04 05:45:00 +0900", # according to http://www.istellartech.com/7hbym/wp-content/uploads/2019/05/IST-PressRelease_2019050501.pdf
  :inertial_prefix => 'gyro_5f',
  :posvel => 'gps_a.csv',
  :prefix => '',
}

ARGV.reject!{|arg|
  next false if arg !~ /--([^=]+)=?/
  k, v = [$1.to_sym, $']
  next false unless opt.include?(k)
  opt[k] = v
  true
}

require 'tempfile'
require 'pathname'

inertial_csv = proc{
  # merge CSV files related to inertial data
  fprefix = opt.delete(:inertial_prefix)
  data = [:ax, :ay, :az, :wx, :wy, :wz].collect{|k|
    f = File::join(opt[:data_dir], "#{fprefix}_#{k}.csv")
    open(f){|io|
      io.readline # 1st line is header
      io.collect{|line|
        line.chomp.split(',').collect{|v| v.to_f}
      }.transpose
    }
  }
  # special assumption; time stamp is always synchronized
  t = data[0][0]
  xddot = data[0..2].collect{|t_v| t_v[1]}.transpose
  omega = data[3..5].collect{|t_v| t_v[1]}.transpose
  
  Tempfile::open(fprefix, opt[:data_dir]){|io|
    io.puts(([[:T, :s]] \
        + [:x, :y, :z].collect{|axis| ["w#{axis}".to_sym, :dps]} \
        + [:x, :y, :z].collect{|axis| ["a#{axis}".to_sym, :g]}).collect{|k, unit|
      "#{k}[#{unit}]"
    }.join(','))
    t.zip(omega, xddot).each{|t, vo, va|
      io.puts [t, vo, va.collect{|v| v / 1250}].flatten.join(',')
      # LSB = 1/1250 G
    }
    io
  }
}.call

opt[:inertial] = Pathname::new(inertial_csv.path).relative_path_from(Pathname::new(opt[:data_dir])).to_s

pos_vel_csv = proc{|dst|
  Tempfile::open(File::basename(opt[:posvel], '.*'), opt[:data_dir]){|dst|
    dst.puts "T[s],unixtime[s],fix,ecef_x[m],ecef_y[m],ecef_z[m],ecef_vx[m/s],ecef_vy[m/s],ecef_vz[m/s],sat hdop"
    open(File::join(opt[:data_dir], opt[:posvel])){|src|
      src.readline
      dst.print src.read
    }
    dst
  }
}.call

opt[:posvel] = Pathname::new(pos_vel_csv.path).relative_path_from(Pathname::new(opt[:data_dir])).to_s

cmd = (
    (['ruby', File::join(File::dirname($0), '..', '..', 'MOMO_F1', 'sylphide', 'sylphide_conv.rb')] \
    + opt.collect{|k, v|
      "--#{k}='#{v}'"
    } + ARGV).join(' '))
raise("Runtime error! #{cmd}") unless system(cmd)