from bitstring import BitArray
import struct
import sys, os

import sys, os
sys.path.append("../../../../specs/telemetry")

import telemetry_define as td
tdef = td.TelemetryDefine()

sys.path.append("../../../../common/python")
import coord_utils

import numpy as np
import re

import yaml

day_offset = 1564153200 # https://tool.konisimple.net/date/unixtime?input=2019%2F07%2F27+00%3A00%3A00

def load_sensor_define_yaml():
    fn = os.path.dirname(os.path.realpath(__file__)) + \
        '/../../../../specs/canbus/canbus_sensor_define.yaml'
    define = yaml.load(open(fn).read())
    types = define['types']
    root = {}
    for t in types:
        key = list(t.keys())[0]
        root[key] = t[key]
    return root

def decode_line(line):
    ba = get_bitarray_from_telemetry_line(line)
    decoded = tdef.decode_telemetry(ba)
    t = line.strip().split(' ')[0][1:-1]
    dbm = re.findall(r'([\-\d]+)dBm', line.strip())
    if len(dbm) == 1:
        return {"t":t, "decoded":decoded, "dBm":int(dbm[0])}
    else:
        return {"t":t, "decoded":decoded}

def get_bitarray_from_telemetry_line(str):
    #print(str)
    n = str.strip().split(' ')
    if len(n) < 17:
        raise AssertionError('Unknown data format: ' + str)
    a = n[1:9] + n[10:18]
    b = struct.pack("B"*16, *[int(x,16) for x in a])
    return BitArray(b)

def to_unixtime(hms_str):
    hmsf = re.findall(r'([\d]+):([\d]+):([\d]+).([\d]+)', hms_str)[0]
    hours = int(hmsf[0])
    minutes = int(hmsf[1])
    seconds = int(hmsf[2])
    seconds_f = float('0.'+hmsf[3])
    return day_offset + hours*3600 + minutes*60 + seconds + seconds_f

def stdout_redirect_to_file(fn):
    current_stdout = sys.stdout
    # below to comment out for test
    sys.stdout = open(fn, 'tw')
    return current_stdout

def stdout_recirect_end(ctx):
    sys.stdout = ctx

def decode_gps_ecef_ecefvel(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],ecef_x[m],ecef_y[m],ecef_z[m],ecef_vx[m/s],ecef_vy[m/s],ecef_vz[m/s]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            nick = d['nick']
            if (nick == 'gps_a2' or nick == 'gps_b2'):
                print("%.2f,%d,%d,%d,%d,%d,%d" % 
                    (t, d['ecef_x'], d['ecef_y'], d['ecef_z'], 
                        d['ecef_vx'], d['ecef_vy'], d['ecef_vz']))
    stdout_recirect_end(ctx)

def decode_gps_ecef_and_info(source_fn, source_t0, nick, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],ecef_x[m],ecef_y[m],ecef_z[m],fix,satellites,hdop,unixtime[s]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == nick):
                unixtime = (d['unixtime_0'] << 16) | \
                           (d['unixtime_1'] << 8) | \
                           (d['unixtime_2'] << 0)
                print("%.2f,%d,%d,%d,%d,%d,%.1f,%d" %
                    (t, d['ecef_x'], d['ecef_y'], d['ecef_z'], 
                        d['fix'], d['sat'], d['hdop'], unixtime))
    stdout_recirect_end(ctx)

def decode_attitude(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],azimuth[deg],elevation[deg],roll[deg]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'ctrl'):
                print("%.2f,%f,%f,%f" %
                    (t, d['azimuth'].value,d['elevation'].value,d['roll'].value))
    stdout_recirect_end(ctx)

def decode_gimbal_control(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],encoder_a[enc],encoder_b[enc],target_a[enc],target_b[enc]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'ctrl'):
                print("%.2f,%d,%d,%d,%d" %
                    (t, d['gimbal_encoder_a'].value, d['gimbal_encoder_b'].value,
                        d['gimbal_target_a'].value, d['gimbal_target_b'].value))
    stdout_recirect_end(ctx)

def decode_GGG_control(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],ggg_target[deg],ggg_az45[deg],ggg_az225[deg]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'ctrl'):
                print("%.2f,%.1f,%.1f,%.1f" %
                    (t, d['ggg_target'].value/10.0, d['ggg_az45']/10.0, d['ggg_az225']/10.0))
    stdout_recirect_end(ctx)

def get_pressure_value(d, name):
    pg = SD['pressure_gauges']
    for e in pg:
        if e['id'] == name:
            coeff_a = e['coeff_a']
            coeff_b = e['coeff_b']
            key = e['can_key']
            return d[key] * coeff_a + coeff_b


def decode_pressure_gauges_pt1(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],P1[MPa],P2[MPa],P3[MPa],P4[MPa],P5[MPa],P6[MPa],P7[MPa],P8[MPa],P9[MPa],P16[MPa]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'pt1'):
                p1 =  get_pressure_value(d, 'p1')
                p2 =  get_pressure_value(d, 'p2')
                p3 =  get_pressure_value(d, 'p3')
                p4 =  get_pressure_value(d, 'p4')
                p5 =  get_pressure_value(d, 'p5')
                p6 =  get_pressure_value(d, 'p6')
                p7 =  get_pressure_value(d, 'p7')
                p8 =  get_pressure_value(d, 'p8')
                p9 =  get_pressure_value(d, 'p9')
                p16 = get_pressure_value(d, 'p16')
                print('%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' % 
                    (t, p1, p2, p3, p4, p5, p6, p7, p8, p9, p16))
    stdout_recirect_end(ctx)

def decode_pressure_gauges_pt2(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],P10[MPa],P11[MPa],P12[MPa],P13[MPa],P14[MPa],P15[MPa],P17[MPa]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'pt2'):
                p10 =  get_pressure_value(d, 'p10')
                p11 =  get_pressure_value(d, 'p11')
                p12 =  get_pressure_value(d, 'p12')
                p13 =  get_pressure_value(d, 'p13')
                p14 =  get_pressure_value(d, 'p14')
                p15 =  get_pressure_value(d, 'p15')
                p17 =  get_pressure_value(d, 'p17')
                print('%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f' % 
                    (t, p10, p11, p12, p13, p14, p15, p17))
    stdout_recirect_end(ctx)


def decode_temperatures_pt1(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],t_e2[deg_c]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'pt1'):
                print('%.2f,%.1f' % (t, d['t_e2']))
    stdout_recirect_end(ctx)

def decode_temperatures_pt2(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],t4[deg_c],t7[deg_c],t8[deg_c],t_a2[deg_c]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'pt2'):
                print('%.2f,%.1f,%.1f,%.1f,%.1f' % 
                        (t, d['t4'], d['t7'], d['t8'], d['t_a2']))
    stdout_recirect_end(ctx)

def decode_sensors(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],barometer[Pa],wx[dps],wy[dps],wz[dps],ax[g],ay[g],az[g]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'sens'):
                print('%.2f,%d,%f,%f,%f,%f,%f,%f' % (t, d['barometer'].value,
                    d['wx'].value,d['wy'].value,d['wz'].value,
                    d['ax'],d['ay'],d['az'],
                    ))
    stdout_recirect_end(ctx)


def valve_state(vs):
    if vs.open == True and vs.close == False:
        return 'open'
    elif vs.open == False and vs.close == True:
        return 'close'
    elif vs.open == True and vs.close == True:
        return 'invalid'
    else:
        return 'moving'

def decode_control_and_value(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],control,igniter_main,igniter_ggg,v1_state,v2_state,v3_state," +
        "v4_state,v5_state,v6_state,v7_state,mv1_state,mv2_state,mv3_state," +
        "sol1_state,squence_time[s]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            pid = d['page_id']
            if (d['nick'] == 'stat'):
                print('%.2f,%s,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d' % 
                    (t, d['control'].value,
                    d['igniter_main'],
                    d['igniter_ggg'],
                    valve_state(d['v1_state']),
                    valve_state(d['v2_state']),
                    valve_state(d['v3_state']),
                    valve_state(d['v4_state']),
                    valve_state(d['v5_state']),
                    valve_state(d['v6_state']),
                    valve_state(d['v7_state']),
                    valve_state(d['mv1_state']),
                    valve_state(d['mv2_state']),
                    valve_state(d['mv3_state']),
                    valve_state(d['sol1_state']),
                    d['sequence_time'].value
                    ))
    stdout_recirect_end(ctx)

def decode_command_rf_and_voltages(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],control_rtti[dBm],uptime_min[min],batt_v[V],unb_v[V],solenoid_v[V]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'stat'):
                print('%.2f,%d,%d,%.2f,%.2f,%d' % (t, d['control_rtti'].value,
                    d['uptime_min'],
                    d['batt_v'].value,
                    d['unb_v'].value,
                    d['solenoid_v'].value,
                    ))
    stdout_recirect_end(ctx)

def decode_receiver_rssi(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print('T[s],receiver_rssi[dBm]')
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            if ('dBm' in d):
                print("%.2f,%d" % (t, d['dBm']))
    stdout_recirect_end(ctx)

def decode_modules_health(source_fn, source_t0, write_to_fn):
    modules = """alive_1f_adis
alive_1f_umb_mgr
alive_1f_motor_a
alive_1f_motor_b
alive_1f_igniter_main
alive_1f_igniter_ggg
alive_1f_loxdrain
alive_1f_loxmain
alive_1f_rs485
alive_1f_solenoid
alive_1f_pressure_gauge_hub
alive_1f_sensor_hub
alive_2f_loxvent
alive_2f_rs485
alive_2f_thermo
alive_2f_solenoid
alive_3f_rs485_a
alive_3f_rs485_b
alive_3f_solenoid
alive_5f_umb_mgr
alive_5f_rf_150
alive_5f_obc
alive_6f_firefly_a
alive_6f_firefly_b
adis_error_flag""".split('\n')
    ctx = stdout_redirect_to_file(write_to_fn)
    header = ','.join(modules)
    #header += 'adis_error_flags'
    print("T[s],%s" % header)
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'stat'):
                output = '%.2f,' % t
                for m in modules:
                    output += '%s,' % d[m]
                #output += '%d' % d['adis_error_flags']
                print(output)
    stdout_recirect_end(ctx)

def decode_strain_gauges(source_fn, source_t0, write_to_fn):
    ctx = stdout_redirect_to_file(write_to_fn)
    print("T[s],qs_d_ref[-],qs_d1[-],qs_d2[-],qs_d3[-],qs_d4[-]")
    with open(source_fn, 'r') as f:
        for line in f:
            d = decode_line(line)
            t = to_unixtime(d['t']) - source_t0
            d = d['decoded']
            if (d['nick'] == 'strain'):
                print('%.2f,%d,%d,%d,%d,%d' % (t, d['qs_d_ref'],
                    d['qs_d1'],
                    d['qs_d2'],
                    d['qs_d3'],
                    d['qs_d4'],
                    ))
    stdout_recirect_end(ctx)

def render_csv(prefix, t0):
    decode_gps_ecef_ecefvel(prefix+'_seq.log', t0, prefix+'_ecef_ecefvel.csv')
    decode_gps_ecef_and_info(prefix+'_seq.log', t0, 'gps_a1', prefix+'_ecef_gpsinfo_firefly_a.csv')
    decode_gps_ecef_and_info(prefix+'_seq.log', t0, 'gps_b1', prefix+'_ecef_gpsinfo_firefly_b.csv')
    decode_gimbal_control(prefix+'_seq.log', t0, prefix+'_gimbal.csv')
    decode_GGG_control(prefix+'_seq.log', t0, prefix+'_ggg.csv')
    decode_pressure_gauges_pt1(prefix+'_seq.log', t0, prefix+'_pressure_gauges1.csv')
    decode_pressure_gauges_pt2(prefix+'_seq.log', t0, prefix+'_pressure_gauges2.csv')
    decode_temperatures_pt1(prefix+'_seq.log', t0, prefix+'_temperatures1.csv')
    decode_temperatures_pt2(prefix+'_seq.log', t0, prefix+'_temperatures2.csv')
    decode_sensors(prefix+'_seq.log', t0, prefix+'_sensors.csv')
    decode_control_and_value(prefix+'_seq.log', t0, prefix+'_sequence_and_valve.csv')
    decode_command_rf_and_voltages(prefix+'_seq.log', t0, prefix+'_command_rf_and_voltages.csv')
    decode_attitude(prefix+'_seq.log', t0, prefix+'_attitude.csv')
    decode_modules_health(prefix+'_seq.log', t0, prefix+'_modules_health.csv')
    decode_strain_gauges(prefix+'_seq.log', t0, prefix+'_strain_gauges.csv')

if __name__ == '__main__':
    SD = load_sensor_define_yaml()

    t0_for_telem1 = 1564211980.473506 + 20.0
    render_csv('telem1', t0_for_telem1)
    decode_receiver_rssi('telem1_seq.log', t0_for_telem1, 'telem1_receiver_rssi.csv')

    t0_for_telem2 = 1564211980.480544 + 20.0
    render_csv('telem2', t0_for_telem2)
    decode_receiver_rssi('telem2_seq.log', t0_for_telem2, 'telem2_receiver_rssi.csv')

    t0_for_telem3 = 1564211980.435192 + 20.0
    render_csv('telem3', t0_for_telem3)
    decode_receiver_rssi('telem3_seq.log', t0_for_telem3, 'telem3_receiver_rssi.csv')

