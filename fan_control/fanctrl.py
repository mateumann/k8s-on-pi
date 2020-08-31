#!/usr/bin/python
# -*- coding: utf-8 -*-

import RPi.GPIO as GPIO
import logging
import time
import sys
from systemd.journal import JournalHandler


log = logging.getLogger('fanctrl')
log.addHandler(JournalHandler(SYSLOG_IDENTIFIER='fanctrl'))
log.setLevel(logging.INFO)

# Configuration
FAN_PIN = 21  # BCM pin used to drive transistor's base
WAIT_TIME = 1  # [s] Time to wait between each refresh
FAN_MIN = 20  # [%] Fan minimum speed.
PWM_FREQ = 25  # [Hz] Change this value if fan has strange behavior

# Configurable temperature and fan speed steps
tempSteps = [50, 70]  # [°C]
speedSteps = [0, 100]  # [%]

# Fan speed will change only of the diff. of temp. is higher than hysteresis
hyst = 1.5

# Setup GPIO pin
GPIO.setmode(GPIO.BCM)
GPIO.setup(FAN_PIN, GPIO.OUT, initial=GPIO.LOW)
fan = GPIO.PWM(FAN_PIN, PWM_FREQ)
fan.start(0)

i = 0
cpuTemp = 0
fanSpeed = 0
cpuTempOld = 0
fanSpeedOld = 0

# We must set a speed value for each temperature step
if len(speedSteps) != len(tempSteps):
    log.error("Numbers of temp steps and speed steps are different")
    exit(0)

first_run = True
try:
    log.info("Fan Control tempSteps={0}; speedSteps={1}; FAN_MIN={2}".format(
        tempSteps, speedSteps, FAN_MIN))
    while 1:
        # Read CPU temperature
        cpuTempFile = open("/sys/class/thermal/thermal_zone0/temp", "r")
        cpuTemp = float(cpuTempFile.read()) / 1000
        cpuTempFile.close()
        if first_run:
            log.info("Current CPU temperature is %.1f °C.", cpuTemp)

        # Calculate desired fan speed
        if abs(cpuTemp - cpuTempOld) > hyst:
            # Below first value, fan will run at min speed.
            log.debug("Temperature changed new one is {0} °C".format(cpuTemp))
            if cpuTemp < tempSteps[0]:
                log.debug("cpuTemp < tempSteps[0]")
                fanSpeed = speedSteps[0]
            # Above last value, fan will run at max speed
            elif cpuTemp >= tempSteps[len(tempSteps) - 1]:
                log.debug("cpuTemp >= tempSteps[MAX]")
                fanSpeed = speedSteps[len(tempSteps) - 1]
            # If temperature is between 2 steps, fan speed is calculated
            # by linear interpolation
            else:
                for i in range(0, len(tempSteps) - 1):
                    if (cpuTemp >= tempSteps[i] and
                            cpuTemp < tempSteps[i + 1]):
                        log.debug("cpuTemp in range %d - %d [°C]",
                                  tempSteps[i], tempSteps[i+1])
                        fanSpeed = round((speedSteps[i + 1] - speedSteps[i])
                                         / (tempSteps[i + 1] - tempSteps[i])
                                         * (cpuTemp - tempSteps[i])
                                         + speedSteps[i], 1)

            if first_run:
                log.info("Current fan speed will be set to %.1f %%.", fanSpeed)
            log.debug("Calculated fan speed is %.1f %%.", fanSpeed)
            if fanSpeed != fanSpeedOld:
                if (fanSpeed != fanSpeedOld
                        and (fanSpeed >= FAN_MIN or fanSpeed == 0)):
                    fan.ChangeDutyCycle(fanSpeed)
                    fanSpeedOld = fanSpeed
                    log.info("Sensed %s °C. Running fan at %.1f %%",
                             cpuTemp, fanSpeed)
            cpuTempOld = cpuTemp

        first_run = False

        # Wait until next refresh
        time.sleep(WAIT_TIME)


# On keyboard intr. (ctrl + c), the GPIO is set to 0 and the program exits.
except KeyboardInterrupt:
    print("Fan ctrl interrupted by keyboard")
    GPIO.cleanup()
    sys.exit()
