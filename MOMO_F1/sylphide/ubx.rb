#!/usr/bin/ruby

# U-blox file utilities

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

class UBX
  def initialize(io)
    @io = io
    @buf = []
  end
  def UBX.checksum(packet, range = 2..-3)
    ck_a, ck_b = [0, 0]
    packet[range].each{|b|
      ck_a += b
      ck_b += ck_a
    }
    ck_a &= 0xFF
    ck_b &= 0xFF
    [ck_a, ck_b]
  end
  def read_packet
    while !@io.eof?
      if @buf.size < 8 then
        @buf += @io.read(8 - @buf.size).unpack('C*')
        return nil if @buf.size < 8
      end
      
      if @buf[0] != 0xB5 then
        @buf.shift
        next
      elsif @buf[1] != 0x62 then
        @buf = @buf[2..-1]
        next
      end
      
      len = (@buf[5] << 8) + @buf[4]
      if @buf.size < len + 8 then
        @buf += @io.read(len + 8 - @buf.size).unpack('C*')
        return nil if @buf.size < len + 8
      end
      
      ck_a, ck_b = UBX::checksum(@buf, 2..(len + 5))
      if (@buf[len + 6] != ck_a) || (@buf[len + 7] != ck_b) then
        @buf = @buf[2..-1]
        next
      end
      
      packet = @buf[0..(len + 7)]
      @buf = @buf[(len + 8)..-1]
      
      return packet
    end
    return nil
  end
end
