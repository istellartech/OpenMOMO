概要
	T+66秒でUHFテレメトリの通信途絶
	打上げ時刻　2017年07月30日 日曜日 16時30分44秒

telem1/telem1_*.csv
	・UHFテレメトリ ハードウエア受信機で受信したもの
telem2/telem2_*.csv
	・UHFテレメトリ SDR受信機で受信したもの(telem1と同じ物を受信している)
telem3/telem3_*.csv
	・Cバンドテレメトリを受信したもの(CANバスに流れていたもの)

telem1_*.csvとtelem2_*.csvについて
	・_attitude.csv クォータニオン
	・_command_rf_votage.csv コマンド無線のゲイン、バッテリー電圧
	・_ecef_ecefvel.csv ECEFとECEF速度のペア(GPS受信機AとBのマージ)
	・_ecef_gpsinfo_firefly_a.csv GPS受信機Aでの位置時間衛星数Hdop
	・_ecef_gpsinfo_firefly_b.csv GPS受信機Bでの位置時間衛星数Hdop
	・_gimbal.csv ジンバル関連
	・_module_health.csv モジュールの健康状態
	・_pressure_gauges.csv 圧力計データ
	・_sensors.csv 気圧計、角速度、加速度
	・_sequence_and_valve.csv バルブ制御とバルブ状況
	・_temperatures.csv 温度計
	・_receiver_rssi.csv UHFハードウエア受信機での受信感度(telem1のみ)


telem3_*.csvについて
	・telem3_000.csv: コントロール(10進)、シーケンス時間
	・telem3_001.csv: コマンド無線コントロール(10進)
	・telem3_004.csv: Quaternion Q0
	・telem3_005.csv: Quaternion Q1
	・telem3_006.csv: Quaternion Q2
	・telem3_007.csv: Quaternion Q3
	・telem3_008.csv: ジンバルA/Bのターゲット、ガスジェット制御
	・telem3_01a.csv: ジンバルAモータのエンコーダ
	・telem3_01b.csv: ジンバルBモータのエンコーダ
	・telem3_020.csv: 点火器動作と点火器バッテリー電圧
	・telem3_021.csv: LOXメインバルブの状態、電流電圧
	・telem3_022.csv: LOX充填・ドレインバルブの状態、電流電圧
	・telem3_023.csv: LOX大気開放バルブの状態、電流電圧
	・telem3_024.csv: V-25の状態
	・telem3_025.csv: V-18の状態
	・telem3_026.csv: V-6,7,10,16,35の状態
	・telem3_030.csv: P-4圧力
	・telem3_031.csv: P-3圧力
	・telem3_032.csv: P-0,1,2圧力
	・telem3_033.csv: P-5圧力
	・telem3_040.csv: T-3温度
	・telem3_041.csv: T-4,5温度
	・telem3_042.csv: T-2温度
	・telem3_043.csv: T-1温度
	・telem3_045.csv: ジャイロ温度
	・telem3_080.csv: OBC Uptime, CAN REC/TEC
	・telem3_082.csv: ADIS(Gyro) Uptime, CAN REC/TEC
	・telem3_100.csv: メインバッテリー、アンビリカル、メイン電圧電流
	・telem3_10a.csv: ジンバルA 電圧電流 CAN REC/TEC
	・telem3_10b.csv: ジンバルB 電圧電流 CAN REC/TEC
	・telem3_111.csv: コマンド無線受信感度
	・telem3_121.csv: GPS_A基板搭載の気圧計、温度
	・telem3_122.csv: GPS_B基板搭載の気圧計、温度
	・telem3_123.csv: ADIS(Gyro)搭載の気圧計
	・telem3_130.csv: ADIS(Gyro) 角速度
	・telem3_131.csv: ADIS(Gyro) 加速度
	・telem3_132.csv: 微小重力観測用加速度計
	・telem3_240.csv: GPSの情報からOBCが射点からの機体位置（ENU座標）を計算したもの
	・telem3_241.csv: GPSの情報からOBCがIIP位置を計算したもの
	・telem3_firefly_a.csv: GPS_AのGPS情報
	・telem3_firefly_b.csv: GPS_BのGPS情報

etc
	・attitude_plan_nominal.csv: 姿勢制御入力値
	・enc2deg.csv: ジンバルのエンコーダ値からジンバル角度への変換テーブル

機体姿勢については座標系は右手系。
リフトオフ前のEast/North/Upに対して機体座標系（加速度・ジャイロセンサの軸方向：センサ座標系と一致させています）を合わせています。
/notebook の中の coordinate_before_launch.png を参照。
