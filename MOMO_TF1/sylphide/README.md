File converter of MOMO1 CSV files to Sylphide format log
=============

How to use is just type the following in Ruby available environment

```shell
$ ruby sylphide_conv.rb > log.dat
```

* The default is to use telem1_sensors.csv and telem1_ecef_ecefvel.csv to generate log.dat.
* If you want to change another source except for telem1, please use prefix option as "--prefix=telem2" for telem2 case after "sylphide_conv.rb".
* Other options are
  * "--inertial=sensors.csv" if you want to change inertial CSV file name (default: sensors.csv). 
  * "--posvel=ecef_ecefvel.csv" if you want to change GPS CSV file name (default: ecef_ecefvel.csv).

-------------

MOMO1のCSVデータをSylphide形式に変換する
=============

使い方はRubyが使える環境で以下をタイプするだけ

```shell
$ ruby sylphide_conv.rb > log.dat
```

* 基本動作ではtelem1_sensors.csvとtelem1_ecef_ecefvel.csvからlog.datを生成しています。
* もしtelem1ではなく例えばtelem2を使いたければ"sylphide_conv.rb"のあとに" --prefix=telem2"を指定してください。
* 他のオプションは
  * "--inertial=sensors.csv" 慣性データファイルの名前を変える場合 (default: sensors.csv) 
  * "--posvel=ecef_ecefvel.csv"GPS位置速度データファイルの名前を変える場合 (default: ecef_ecefvel.csv)
