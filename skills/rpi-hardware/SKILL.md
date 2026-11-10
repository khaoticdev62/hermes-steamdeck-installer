---
name: rpi-hardware
description: Autonomous hardware, GPIO, I2C, SPI, and thermal management skill for Raspberry Pi 5.
---

# Raspberry Pi 5 Hardware & Physical Computing Skill

This skill empowers Hermes Agent to interact directly with the Raspberry Pi 5 (Broadcom BCM2712 quad-core Arm Cortex-A76 @ 2.4GHz) physical computing capabilities, GPIO pins, sensors, and hardware telemetry.

---

## 1. GPIO Control & Pin Mapping (RP1 I/O Controller)

On Raspberry Pi 5, GPIO is routed through the dedicated **RP1 southbridge I/O controller**.

### Using `gpiod` / `pinctrl` (Recommended for Pi 5 / Bookworm)
```bash
# Query state of all 40 GPIO pins
pinctrl

# Read specific GPIO pin (e.g., GPIO 17)
pinctrl get 17

# Set GPIO pin as output high / low (e.g., toggle an LED on GPIO 17)
pinctrl set 17 op dh    # Output drive high (3.3V)
pinctrl set 17 op dl    # Output drive low (GND)

# Configure internal pull-up / pull-down resistor
pinctrl set 17 pu       # Pull-up
pinctrl set 17 pd       # Pull-down
```

### Using Python `gpiozero`
```python
from gpiozero import LED, Button
from time import sleep

led = LED(17)
btn = Button(2)

def on_press():
    print("Button on GPIO 2 pressed!")
    led.toggle()

btn.when_pressed = on_press
```

---

## 2. I2C & SPI Sensor Diagnostics

### I2C Bus Diagnostics
```bash
# Detect devices on default I2C bus 1
i2cdetect -y 1
```
*Common I2C addresses:*
- `0x3c` / `0x3d`: SSD1306 OLED Display (128x64)
- `0x76` / `0x77`: BME280 / BMP280 Temperature, Humidity, Pressure Sensor
- `0x48`: ADS1115 16-Bit ADC
- `0x68`: MPU-6050 6-Axis Accelerometer / Gyroscope

---

## 3. Pi 5 Hardware Telemetry & Active Cooler Fan Control

### CPU Temperature & Frequency
```bash
# Real-time SoC thermal reading in °C
vcgencmd measure_temp
# Or via sysfs:
awk '{printf "CPU Temp: %.1f°C\n", $1/1000}' /sys/class/thermal/thermal_zone0/temp

# Arm Cortex-A76 clock frequencies
vcgencmd measure_clock arm
```

### Active Cooler Fan Speed
The official Raspberry Pi 5 Active Cooler is managed via the kernel fan driver:
```bash
# Read current fan RPM
cat /sys/devices/platform/cooling_fan/hwmon/hwmon*/fan1_input

# Read active thermal trip state (0=off, 1=low, 2=med, 3=high, 4=max)
cat /sys/class/thermal/thermal_zone0/trip_point_*_temp
```

### Power & PMIC Telemetry
```bash
# Check for low voltage throttling events
vcgencmd get_throttled
# 0x0 = OK, non-zero indicates under-voltage, throttling, or temperature cap
```

---

## 4. Raspberry Pi 5 40-Pin Header Reference

```
 3V3 Power (1)   (2)   5V Power
 GPIO 2 (SDA)    (3)   (4)   5V Power
 GPIO 3 (SCL)    (5)   (6)   Ground
 GPIO 4 (GPCLK0) (7)   (8)   GPIO 14 (TXD)
 Ground          (9)   (10)  GPIO 15 (RXD)
 GPIO 17         (11)  (12)  GPIO 18 (PWM0)
 GPIO 27         (13)  (14)  Ground
 GPIO 22         (15)  (16)  GPIO 23
 3V3 Power       (17)  (18)  GPIO 24
 GPIO 10 (MOSI)  (19)  (20)  Ground
 GPIO 9 (MISO)   (21)  (22)  GPIO 25
 GPIO 11 (SCLK)  (23)  (24)  GPIO 8 (CE0)
 Ground          (25)  (26)  GPIO 7 (CE1)
 GPIO 0 (ID_SD)  (27)  (28)  GPIO 1 (ID_SC)
 GPIO 5          (29)  (30)  Ground
 GPIO 6          (31)  (32)  GPIO 12 (PWM0)
 GPIO 13 (PWM1)  (33)  (34)  Ground
 GPIO 19 (MISO)  (35)  (36)  GPIO 16
 GPIO 26         (37)  (38)  GPIO 20
 Ground          (39)  (40)  GPIO 21
```
