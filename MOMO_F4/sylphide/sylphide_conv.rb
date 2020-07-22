#!/usr/bin/ruby
# coding: cp932

opt = {
  :data_dir => File::join(File::dirname(__FILE__), '..', 'telemetry_csv', 'C_band', 'PC1'),
  :basetime => "2019-07-17 16:20:00 +0900", # according to http://www.istellartech.com/7hbym/wp-content/uploads/2019/07/IST-PressRelease_2019072901.pdf
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

cmd = (['ruby', File::join(File::dirname($0), '..', '..', 'MOMO_F3', 'sylphide', 'sylphide_conv.rb')] \
    + opt.collect{|k, v|
      "--#{k}='#{v}'"
    } + ARGV).join(' ')
raise("Runtime error! #{cmd}") unless system(cmd)