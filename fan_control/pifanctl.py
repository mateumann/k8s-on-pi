#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
from os.path import basename, splitext
# from signal import signal, SIGTERM
from sys import exit
from systemd.journal import JournalHandler
from time import sleep

try:
    import RPi.GPIO as GPIO
except ModuleNotFoundError:
    import fake_rpi.RPi

    GPIO = fake_rpi.RPi.GPIO

PROBE_DELAY = 1.5  # time between each temperature probe (in seconds)
PWM_FREQ = 25  # Change this value if fan behaves strangely (in Hz)
FAN_PIN = 21  # BCM pin used to drive transistor's base
FAN_SPEED_MIN = 30  # minimum fan speed (in percent)
FAN_SPEED_STEPS = [0, 100]
CPU_TEMP_HYSTERESIS = 1.5  # minimum temperature difference to act upon
CPU_TEMP_STEPS = [55, 70]
CPU_THERMAL_ZONE = 0

APP_NAME = splitext(basename(__file__))[0]  # pifanctl
APP_DESCRIPTION = 'Raspberry Pi Fan Control'

log = logging.getLogger(APP_NAME)
log.addHandler(JournalHandler(SYSLOG_IDENTIFIER=APP_NAME))
log.setLevel(logging.INFO)


class PiFanException(Exception):
    pass


def validate(fan_speed_steps: list, cpu_temp_steps: list):
    if len(fan_speed_steps) != len(cpu_temp_steps):
        raise PiFanException('Number of temperature steps and speed steps '
                             'differ.')


def setup(fan_pin: int, pwm_frequency: int) -> GPIO.PWM:
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(fan_pin, GPIO.OUT, initial=GPIO.LOW)
    pwm = GPIO.PWM(fan_pin, pwm_frequency)
    pwm.start(0)
    return pwm


def teardown(_signal_number=None, _stack_frame=None):
    GPIO.cleanup()
    log.info(f'{APP_DESCRIPTION} gracefully stopped ')
    exit(0)


def get_temperature(thermal_zone: int = 0) -> float:
    with open(f'/sys/class/thermal/thermal_zone{thermal_zone}/temp', 'r') as f:
        temperature = float(f.read()) / 1000
    return temperature


def calculate_fan_speed(temperature: float,
                        temperature_steps: list,
                        fan_speed_steps: list,
                        fan_speed_min: float) -> float:
    speed = 0.0
    if temperature < temperature_steps[0]:
        speed = fan_speed_steps[0]
    elif cpu_temperature >= temperature_steps[-1]:
        speed = fan_speed_steps[-1]
    else:
        for i, temp_step in enumerate(temperature_steps[:-1]):
            if temp_step <= temperature <= temperature_steps[i + 1]:
                speed = ((fan_speed_steps[i + 1] - fan_speed_steps[i]) /
                         (temperature_steps[i + 1] - temp_step) *
                         (temperature - temp_step) +
                         fan_speed_steps[i])

    if speed < fan_speed_min:
        return 0.0
    return round(speed, 1)


if __name__ == '__main__':
    try:
        validate(FAN_SPEED_STEPS, CPU_TEMP_STEPS)
    except PiFanException as ex:
        log.fatal(f'Validation error: {ex}.  Terminating.')
        exit(1)
    fan = setup(FAN_PIN, PWM_FREQ)
    # signal(SIGTERM, teardown)

    first_run = True
    cpu_temperature_old = 0.0
    fan_speed_old = 0.0
    try:
        while True:
            if not first_run:
                sleep(PROBE_DELAY)
            cpu_temperature = get_temperature(CPU_THERMAL_ZONE)
            if first_run:
                log.info(f'{APP_DESCRIPTION} started: '
                         f'temperature steps={CPU_TEMP_STEPS}, '
                         f'fan speed steps={FAN_SPEED_STEPS}, '
                         f'minimum fan speed={FAN_SPEED_MIN}.  '
                         f'CPU temperature is {cpu_temperature:.1f}°C, '
                         'fan is not running.')
                first_run = False
            if abs(cpu_temperature -
                   cpu_temperature_old) < CPU_TEMP_HYSTERESIS:
                continue
            log.debug('Temperature changed above hysteresis: '
                      f'{cpu_temperature:.1f}°C')
            cpu_temperature_old = cpu_temperature
            fan_speed = calculate_fan_speed(cpu_temperature,
                                            CPU_TEMP_STEPS,
                                            FAN_SPEED_STEPS,
                                            FAN_SPEED_MIN)
            if fan_speed == fan_speed_old:
                continue
            log.debug(f'New calculated fan speed is {fan_speed:.1f}')
            if fan_speed >= FAN_SPEED_MIN or fan_speed == 0.0:
                fan.ChangeDutyCycle(fan_speed)
                fan_speed_old = fan_speed
                log.info(f'Sensed {cpu_temperature:.1f}°C.  '
                         f'Fan running at {fan_speed:.1f}%')

    finally:
        teardown()
