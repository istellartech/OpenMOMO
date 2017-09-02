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

posvel2ubx = proc{|out|
  # read CSV and write ubx format binary
  
  require 'coordinate'
  require 'ubx'
  
  open(File::join(opt[:data_dir], opt[:posvel])){|io|
    header = io.readline.chomp.split(/, */)
    index_t = header.index("T[s]")
    index_pos, index_vel = [
      ["ecef_x[m]","ecef_y[m]","ecef_z[m]"],
      ["ecef_vx[m/s]","ecef_vy[m/s]","ecef_vz[m/s]"],
    ].collect{|k_s| 
      k_s.collect{|k| header.index(k)}
    }
    
    io.each{|line|
      values = line.chomp.split(/, */)
      t = values[index_t].to_f
      pos_ecef, vel_ecef = [index_pos, index_vel].collect{|index|
        System_XYZ::new(*(values.values_at(*index).collect{|str| str.to_f}))
      }
      pos_llh = pos_ecef.llh
      vel_enu = System_ENU.relative_rel(vel_ecef, pos_ecef)
    
      # 0x01 0x06/0x02/0x12 が必要
      itow = [(1E3 * t).to_i].pack('V')
      
      # NAV-SOL (0x01-0x06)
      ubx_sol = [0xB5, 0x62, 0x01, 0x06, 52].pack('c4v') + itow
      ubx_sol << [ \
          0, # frac
          0, #base_gpstime[0], # week
          0x03, # 3D-Fix
          0x0D, # GPSfixOK, WKNSET, TOWSET
          pos_ecef.to_a.collect{|v| (v * 1E2).to_i}, # ECEF_XYZ [cm]
          0, # 3D pos accuracy [cm]
          vel_ecef.to_a.collect{|v| (v * 1E2).to_i}, # ECEF_VXYZ [cm/s]
          0, # Speed accuracy [cm/s]
          [0] * 8].flatten.pack('Vvc2l<3Vl<3Vc8')
      ubx_sol << UBX::checksum(ubx_sol.unpack('c*'), 2..-1).pack('c2')
      out.print ubx_sol
      
      # NAV-POSLLH (0x01-0x02)
      ubx_posllh = [0xB5, 0x62, 0x01, 0x02, 28].pack('c4v') + itow
      ubx_posllh << [ \
          (pos_llh.lng / Math::PI * 180 * 1E7).to_i, # 経度 [1E-7 deg]
          (pos_llh.lat / Math::PI * 180 * 1E7).to_i, # 緯度 [1E-7 deg]
          (pos_llh.h * 1E3).to_i, # 楕円高度 [mm]
          0, # 平均海面高度
          3000, # HAcc [mm]
          10000, # VAcc [mm]
          ].pack('V*')
      ubx_posllh << UBX::checksum(ubx_posllh.unpack('c*'), 2..-1).pack('c2')
      out.print ubx_posllh
      
      # NAV-VELNED (0x01-0x12)
      speed_pow2 = vel_enu.abs2
      speed_2D = Math::sqrt(speed_pow2 - (vel_enu.u ** 2))
      speed_dir = Math::atan2(vel_enu.e, vel_enu.n)
      ubx_velned = [0xB5, 0x62, 0x01, 0x12, 36].pack('c4v') + itow
      ubx_velned << [
          (vel_enu.n * 1E2).to_i, # N方向速度 [cm/s]
          (vel_enu.e * 1E2).to_i, # E方向速度 [cm/s]
          (-vel_enu.u * 1E2).to_i, # D方向速度 [cm/s]
          (Math::sqrt(speed_pow2) * 1E2).to_i, # 3D速度 [cm/s]
          (speed_2D * 1E2).to_i, # 2D速度 [cm/s]
          (speed_dir / Math::PI * 180 * 1E5).to_i, # ヘディング [1E-5 deg]
          50, # 速度精度 [cm/s]
          (0.5 * 1E5).to_i, # ヘディング精度 [1E-5 deg]
          ].pack('V*')
      ubx_velned << UBX::checksum(ubx_velned.unpack('c*'), 2..-1).pack('c2')
      out.print ubx_velned
    }
  }
  
  out
}

#inertial2imu_csv.call($stdout)
posvel2ubx.call($stdout)