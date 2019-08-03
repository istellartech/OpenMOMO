#!/usr/bin/env ruby

class GPSTime
  WEEK_SEC = 7 * 24 * 60 * 60
  CYCLE_SEC = 1024 * WEEK_SEC
  ZERO = Time::gm(1980, 1, 6, 0, 0, 0)
  
  LEAP_SEC_LIST = [
    [Time::gm(1981, 7, 1, 0, 0, 0), 1],
    [Time::gm(1982, 7, 1, 0, 0, 0), 1],
    [Time::gm(1983, 7, 1, 0, 0, 0), 1],
    [Time::gm(1985, 7, 1, 0, 0, 0), 1],
    [Time::gm(1988, 1, 1, 0, 0, 0), 1],
    [Time::gm(1990, 1, 1, 0, 0, 0), 1],
    [Time::gm(1991, 1, 1, 0, 0, 0), 1],
    [Time::gm(1992, 7, 1, 0, 0, 0), 1],
    [Time::gm(1993, 7, 1, 0, 0, 0), 1],
    [Time::gm(1994, 7, 1, 0, 0, 0), 1],
    [Time::gm(1996, 1, 1, 0, 0, 0), 1],
    [Time::gm(1997, 7, 1, 0, 0, 0), 1],
    [Time::gm(1999, 1, 1, 0, 0, 0), 1],
    [Time::gm(2006, 1, 1, 0, 0, 0), 1],
    [Time::gm(2009, 1, 1, 0, 0, 0), 1],
    [Time::gm(2012, 7, 1, 0, 0, 0), 1],
    [Time::gm(2015, 7, 1, 0, 0, 0), 1],
    [Time::gm(2017, 1, 1, 0, 0, 0), 1],
  ]
  
  UTC2GPST_DELTA = proc{|list|
    delta_sum = 0
    list.collect{|utc, delta|
      [utc, delta_sum += delta]
      }.sort{|a, b| b[0] <=> a[0]} # Latest first
  }.call(LEAP_SEC_LIST)
  
  def GPSTime::itow(utc = Time::now)
    sec = utc - ZERO
    return nil if sec < 0
    UTC2GPST_DELTA.each{|check_t, delta| 
      if utc > check_t then
        sec += delta
        break
      end
    }
    cycle, sec = sec.divmod(CYCLE_SEC)
    week, sec = sec.divmod(WEEK_SEC)
    [cycle, week, sec]
  end
  
  GPST2UTC_DELTA = UTC2GPST_DELTA.collect{|utc, delta|
    [utc - ZERO + delta, delta]
  }
  
  def GPSTime::utc(gpstime)
    sec = gpstime[0] * CYCLE_SEC + gpstime[1] * WEEK_SEC + gpstime[2]
    GPST2UTC_DELTA.each{|check_t, delta| 
      if sec > check_t then
        sec -= delta
        break
      end
    }
    ZERO + sec
  end
end

if $0 == __FILE__ then
  options = {}
  ARGV.reject!{|arg|
    if arg =~ /--([^=]+)=?/ then
      options[$1.to_sym] = $' || true
      true
    else
      false
    end
  }
  require 'time'
  target = ARGV.empty? ?  Time::now : Time::parse(ARGV.join(' '))
  gpstime = GPSTime::itow(target)
  
  downloader = { # @see http://mgex.igs.org/IGS_MGEX_Products.html
    :igs => proc{
      week = gpstime[0] * 1024 + gpstime[1]
      day = (gpstime[2] / (24 * 60 * 60)).to_i
      {"ftp://igscb.jpl.nasa.gov/pub/product/#{sprintf('%04d', week)}/" =>
        {
          'u' => ["igu#{sprintf('%04d', week)}#{day}_00.sp3", "igu#{sprintf('%04d', week)}#{day}_00.erp", "igu#{sprintf('%04d', week)}#{day}_00.sum", "igu#{sprintf('%04d', week)}#{day}_00_cmp.sum"],
          'r'=> ["igr#{sprintf('%04d', week)}#{day}.sp3", "igr#{sprintf('%04d', week)}#{day}.clk", "igr#{sprintf('%04d', week)}#{day}.cls", "igr#{sprintf('%04d', week)}#{day}.erp", "igr#{sprintf('%04d', week)}#{day}.sum"],
          'f' => ["igs#{sprintf('%04d', week)}#{day}.sp3", "igr#{sprintf('%04d', week)}#{day}.clk", "igr#{sprintf('%04d', week)}#{day}.cls", "igs#{sprintf('%04d', week)}7.erp", "igs#{sprintf('%04d', week)}7.sum"],
        }[options[:igsmode] || 'f'].collect{|f| "#{f}.Z"} # f:final, r:rapid, u:ultrarapid
      }
    },
    :bkg => proc{ # RINEX 2, GPS/GLONASS
      {"https://igs.bkg.bund.de/root_ftp/IGS/BRDC/%d/%03d/"%[target.year, target.yday] =>
        [:n, :g].collect{|suffix| 
          "brdc%03d0.%2d%s.Z"%[target.yday, target.year % 100, suffix]
        }
      }
    },
    :brdm => proc{ # RINEX 3, GNSS
      {"ftp://ftp.cddis.eosdis.nasa.gov/gnss/data/campaign/mgex/daily/rinex3/%d/brdm/"%[target.year] =>
        ["brdm%03d0.%2dp.Z"%[target.yday, target.year % 100]]
      }
    }
  }.select{|k, job| options[k]}.values
  unless downloader.empty? 
    require 'open-uri'
    downloader.each{|job| 
      job.call.each{|base_uri, files|
        files.each{|fname|
          path = base_uri + fname
          $stderr.puts "Downloading #{path} ..."
          open(fname, 'w'){|dst|
            open(path){|src| dst.write src.read}
          }
        }
      }
    }
    exit(0)
  end
  
  p target
  p gpstime
  p GPSTime::utc(gpstime)
end
