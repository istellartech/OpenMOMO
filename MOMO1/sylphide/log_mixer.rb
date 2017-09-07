#!/usr/bin/ruby
# coding: cp932

# concatenating date and generating log.dat

# Copyright (c) 2016, M.Naruoka (fenrir)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# - Neither the name of the naruoka.org nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

UTIL_DIR = File::join(File::dirname(__FILE__), 'misc')
$: << UTIL_DIR unless $:.include?(UTIL_DIR)
require 'ubx'

class G_Packet_Converter
  DATA_PER_PACKET = 31
  def G_Packet_Converter.g_packet(binary)
    packets, last_size = binary.size.divmod(DATA_PER_PACKET)
    if last_size > 0
      packets += 1
      binary += ([0] * (DATA_PER_PACKET - last_size)).pack('C*')
    end
    res = []
    packets.times{|i|
      head = DATA_PER_PACKET * i
      res << "G#{binary[head..(head + DATA_PER_PACKET - 1)]}"
    }
    res.join
  end
end

class GPS_UBX < G_Packet_Converter
  def initialize(io, opt = {})
    @ubx = UBX::new(io)
    @cache = {:itow => nil, :data => ""}
    @filter = opt[:filter] || proc{|packet| packet}
    @delay = opt[:delay] || 0
  end
  def read_chunk
    res = @cache.clone
    while true
      unless (packet = @ubx.read_packet)
        @cache = {:itow => nil, :data => ""}
        break
      end
      next unless (packet = @filter.call(packet))
      
      data_new = packet.pack('C*')
      itow_new = ((1E-3 * data_new[6..9].unpack('V')[0] + @delay) if {
        0x01 => [0x01, 0x02, 0x03, 0x04, 0x06, 0x08, 0x11, 0x12, 0x20, 0x21, 0x22, 0x30, 0x31, 0x32], 
        0x02 => [0x10, 0x20]
      }[packet[2]].include?(packet[3])) rescue nil
      
      # when same time stamp data or data without time stamp, append it to current chuck
      if res[:itow] then
        if itow_new and (res[:itow] != itow_new) then
          @cache = {:itow => itow_new, :data => data_new}
          break
        end
      else
        res[:itow] = itow_new  
      end
      res[:data] += data_new
    end
    
    unless res[:data].empty?
      res[:data] = G_Packet_Converter::g_packet(res[:data])
      return res
    else
      return nil
    end
  end
end

class A_Packet_Converter
  DEFAULT_CONV_PARAMS = { # based on MPU-6000/9250
    :index_base => 0,
    :index_temp_ch => 8,
    :acc_bias => [1 << 15] * 3,
    :acc_bias_tc => 0,
    :acc_sf => [(1<<15).to_f / (9.80665 * 8)] * 3, # 8[G] full scale; [1/(m/s^2)]
    :acc_mis => [1, 0, 0, 0, 1, 0, 0, 0, 1],
    :gyro_bias => [1 << 15] * 3,
    :gyro_bias_tc => [0, 0, 0],
    :gyro_sf => [(1<<15).to_f / (Math::PI / 180 * 2000)] * 3, # 2000[dps] full scale; [1/(rad/s)]
    :gyro_mis => [1, 0, 0, 0, 1, 0, 0, 0, 1],
    :sigma_accel => [0.05] * 3, # approx. 150[mG] ? standard deviation
    :sigma_gyro => [5e-3] * 3, # approx. 0.3[dps] standard deviation
  }
  def initialize(opt = {})
    DEFAULT_CONV_PARAMS.each{|k, v|
      eval("@#{k} = opt[k] || v")
    }
  end
  def A_Packet_Converter.packN24(v)
    (v.kind_of?(Array) ? v : [v]).collect{|num|
      [[[num.to_i, 0].max, ((1 << 24) - 1)].min].pack('N')[1..3]
    }.join
  end
  def a_packet(info = {})
    "A#{
      [0, ((info[:t_s] || 0) * 1E3).to_i].pack('CV')
    }#{
      A_Packet_Converter::packN24([
        (info[:accel_ms2] || [0, 0, 0]).zip(@acc_sf, @acc_bias).collect{|v, sf, bias|
          (v * sf) + bias
        },
        (info[:omega_rads] || [0, 0, 0]).zip(@gyro_sf, @gyro_bias).collect{|v, sf, bias|
          (v * sf) + bias
        }
      ].flatten)
    }#{([0] * 8).pack('C*')}"
  end
  def dump_conf
    DEFAULT_CONV_PARAMS.keys.collect{|k|
      "#{k} #{[eval("@#{k}")].flatten.join(' ')}"
    }.join("\n")
  end
end

class IMU_CSV < A_Packet_Converter
  DEFAULT_PARAMS = {
    :t_index => 0,
    :t_scale => 1.0, # s
    :t_offset => 0,
    :filter => proc{|t, accel, omega| [t, accel, omega]},
    :acc_index => [1, 2, 3],
    :acc_units => [1.0] * 3, # m/s^2
    :gyro_index => [4, 5, 6],
    :gyro_units => [Math::PI / 180] * 3, # rad/s
  }
  def initialize(io, opt = {})
    super(opt)
    @io = io
    DEFAULT_PARAMS.each{|k, v|
      eval("@#{k} = opt[k] || v")
    }
  end
  def read_chunk
    while !@io.eof?
      items = @io.readline.split(/[,\s]+/) # space, tab or comma
      items.collect!{|v| Float(v)} rescue next
      t = (items[@t_index] * @t_scale) + @t_offset
      accel = items.values_at(*@acc_index).zip(@acc_units).collect{|v, sf| v * sf}
      omega = items.values_at(*@gyro_index).zip(@gyro_units).collect{|v, sf| v * sf}
      t, accel, omega = @filter.call(t, accel, omega)
      next unless t
      return {
        :itow => t,
        :data => a_packet({:t_s => t, :accel_ms2 => accel, :omega_rads => omega}),
      }
    end
    return nil
  end
end

$log_mix = proc{|prop|
  readers = prop[:readers]
  
  out = prop[:out] || $stdout
  out.binmode # for Windows
  
  chunks = []
  readers.each_with_index{|reader, i|
    chunk = reader.read_chunk
    chunks << [chunk, i] if chunk
  }
  
  $stderr.print "Processing "
  loop = 0
  while !chunks.empty?
    chunks.sort!{|a, b| [a[0][:itow], a[1]] <=> [b[0][:itow], b[1]]}
    out.print(chunks[0][0][:data])
    $stderr.print '.' if ((loop += 1) % 10000 == 0)
    chunks.shift unless (chunks[0][0] = readers[chunks[0][1]].read_chunk)
  end
  $stderr.puts " Done." 
}

if $0 == __FILE__ then

$stderr.puts "Log mixer"
$stderr.puts "Usage: #{__FILE__} [options] gps_data imu_data > log.dat"

options = {}
ARGV.reject{|arg|
  if arg =~ /--([^=]+)=?/ then
    k, v = [$1.to_sym, $']
    options[k] = v
    true
  else
    false
  end
}

if ARGV.size < 2
  $stderr.puts "Minimum arguments error!"
  exit(-1)
end

src = {
  :gps => ARGV.shift,
  :imu => ARGV.shift,
}
$log_mix.call({:readers => [
  IMU_CSV::new(open(src[:imu])),
  GPS_UBX::new(open(src[:gps])), 
]})

end