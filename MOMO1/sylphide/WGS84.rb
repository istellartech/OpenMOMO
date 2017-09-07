=begin
世界測地系WGS84の定数等をまとめたファイル(一部refined)
@see NIMA TR 8350.2 Third Edition
Department of Defense World Geodetic System 1984
Its Definition and Relationships with Local Geodetic Systems
=end

class WGS84

    R_E               = 6378137.0             # 3.2.1 (a) 赤道半径[m]
    F_E               = (1.0 / 298.257223563) # 3.2.2 (f) flattening
    OMEGA_EARTH       = 7292115.0E-11         # 3.2.4 (omega) 地球自転速度 [rad/s]
    OMEGA_EARTH_IAU   = 7292115.1467E-11      # 3.2.4 (omega') International Astronomical Union (IAU), or the GRS 67, version
    MU_EARTH_DERIVED  = 3986004.418E8         # 3.2.3 (GM) 地球重力定数[m^3/s^2] (refined)
    MU_EARTH          = 3986005.0E8           # 3.2.3.2 (GM_orig) for GPS receiver
    
    EPSILON_EARTH     = 8.1819190842622E-2    # Table 3.3 (e) 第一偏心性
    G_WGS0            = 9.7803253359          # Table 3.4 (gamma_e) 赤道上重力
    G_WGS1            = 0.00193185265241      # Table 3.4 (k) 重力公式定数
    M_DERIVED         = 0.00344978650684      # Table 3.4 (m) omega^2 * a^2 * b / GM

    def WGS84.r_meridian(latitude) # 子午線(南北)方向の曲率半径
      return R_E * (1.0 - (EPSILON_EARTH ** 2)) \
                  / ((1.0 - (EPSILON_EARTH ** 2) * (Math.sin(latitude)) ** 2) ** 1.5);
    end
    
    def WGS84.r_normal(latitude) # 卯酉線(東西)方向の曲率半径
      return R_E / Math.sqrt(1.0 - (EPSILON_EARTH ** 2) * (Math.sin(latitude) ** 2));  
    end
    
    def WGS84.gravity(latitude, altitude = 0)
      slat2 = Math.sin(latitude) ** 2
      g0 = G_WGS0 * (1.0 + G_WGS1 * slat2) \
                          / Math.sqrt(1.0 - (EPSILON_EARTH ** 2) * slat2);
      return g0 if altitude == 0
      # @see DEPARTMENT OF DEFENSE WORLD GEODETIC SYSTEM 1984
      # Eq. (4-3)
      return g0 * (1.0 \
          - (2.0 / R_E * (1.0 + F_E + M_DERIVED - 2.0 * F_E * slat2) * altitude) \
          + (3.0 / (R_E ** 2) * (altitude ** 2)))
    end
    
    # 2点間の距離を求める、緯度経度はラジアンで指定のこと
    # 計算にはヒュベニ公式を使う
    # http://yamadarake.web.fc2.com/trdi/2009/report000001.html
    def WGS84.distance(lat1, lng1, lat2, lng2)
      
      # 平均緯度
      lat_avg = (lat1 + lat2) / 2

      # 緯度差
      lat_delta = lat1 - lat2
      
      # 経度差
      lng_delta = lng1 - lng2
      
      lat_s = Math::sin(lat_avg)
      lat_c = Math::cos(lat_avg)
      
      w = Math::sqrt(1.0 - (EPSILON_EARTH * EPSILON_EARTH) * (lat_s * lat_s))
      
      # 子午線曲率半径
      r_M = 6335439.0 / (w ** 3)
      
      # 卯酉線曲率半径
      r_N = R_E / w
      
      t1 = r_M * lat_delta
      t2 = r_N * lat_c * lng_delta
      
      return Math::sqrt((t1 * t1) + (t2 * t2))
    end
    
    def WGS84.xz(geographic_lat, height = 0)
      cphi, cphi2, sphi, sphi2 = [:cos, :sin].collect{|f|
        v = Math.send(f, geographic_lat)
        [v, v ** 2]
      }.flatten
      ba2 = 1.0 - (EPSILON_EARTH ** 2)
      denom = cphi2 + (ba2 * sphi2);
      x2 = (R_E ** 2) * cphi2 / denom
      z2 = (R_E ** 2) * (ba2 ** 2) * sphi2 / denom
      x = Math::sqrt(x2)
      z = Math::sqrt(z2) * (geographic_lat >= 0 ? 1 : -1)
      return [x + cphi * height, z + sphi * height]
    end
    
    # 地球中心緯度への変換
    def WGS84.geocentric_lat(geographic_lat, height = 0)
      x, z = xz(geographic_lat, height)
      return Math::atan2(z, x)
    end
end
