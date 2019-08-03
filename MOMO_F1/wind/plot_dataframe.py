# -*- coding: utf-8 -*-
import sys
import platform

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.font_manager
from matplotlib.font_manager import FontProperties
from matplotlib.backends.backend_pdf import PdfPages
import subprocess
import pandas as pd
import os
from datetime import datetime

plt.ion()

df = pd.read_csv("GPVdate_Taiki_Hokkaido_Japan_2017073018.csv")

year_list = [2017]
month_list = [7]
# day_list = [x for x in range(1,32)]
day_list = [30]
time_list = [18]
daytime_list = ["{0:04d}{1:02d}{2:02d}{3:02d}".format(y,m,d,t) for y in year_list for m in month_list for d in day_list for t in time_list]
PRESS_array = [1000, 975, 950, 925, 900, 850, 800, 700, 600, 500, 400,
			   300, 250, 200, 150, 100]


daytime = "2017073018"
df0 = df.ix[df["daytime"] == int(daytime)]

alt = []
mean = []
std = []
var = []
max_df = []
min_df = []

df0 = df[df["hour"] == 18]

plt.figure()
plt.plot(df0["wind_speed(m/s)"], [x/1000 for x in df0["altitude(m)"]],".-")
plt.grid()
# plt.xlabel("風速 m/s")
# plt.ylabel("高度 km")
plt.xlabel("wind speed m/s")
plt.ylabel("altitude km")
# plt.title("2017年7月30日18時の上空風 北海道大樹町（気象庁GPVより）")
plt.title("2017/07/30 6pm high altitude wind speed Hokkaido Taiki-cho Japan")
plt.ylim([0,17])
plt.yticks(range(0,17,1))
plt.savefig("2017-07-30_6pm high altitude wind speed Hokkaido Taiki-cho Japan"+ ".png")

plt.figure()
plt.plot(df0["wind_direction(deg)"], [x/1000 for x in df0["altitude(m)"]],".-")
plt.grid()
# plt.xlabel("風向 deg")
# plt.ylabel("高度 km")
plt.xlabel("wind direction deg")
plt.ylabel("altitude km")
# plt.title("2017年7月30日18時の上空風 北海道大樹町（気象庁GPVより）")
plt.title("2017/07/30 6pm high altitude wind direction Hokkaido Taiki-cho Japan")
plt.xlim([0,360])
plt.xticks(range(0,360,45))
plt.ylim([0,17])
plt.yticks(range(0,17,1))
# plt.savefig("2017年7月30日18時の上空風向 北海道大樹町（気象庁GPVより）"+ ".png")
plt.savefig("2017-07-30_6pm high altitude wind direction Hokkaido Taiki-cho Japan"+ ".png")
