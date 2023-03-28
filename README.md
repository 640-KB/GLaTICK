# GLaTICK
## (Generational Logic and Time Interval Cadence Knower)
A real-time clock PC BIOS [Companion ROM](https://github.com/640-KB/GLaBIOS) supporting many popular RTC ICs

Copyright &copy; 2023, [640KB](mailto:640kb@glabios.org) and contributors.

### Pre-release ROMs available for testing

[GLaTICK pre-releases](https://github.com/640-KB/GLaTICK/releases)

## Features

- Implements `INT 1Ah` RTC functionality for seamless clock support (no software needed!)
- Support for many popular ICs including:
  - DS1285/MC146818 - [RTC ISA 8 bits](https://hackaday.io/project/168972-rtc-isa-8-bits-pcxt), [NuXT](https://monotech.fwscart.com/NuXT_v20_-_MicroATX_Turbo_XT_-_10MHz_832K_XT-IDE_Multi-IO_SVGA/p6083514_19777986.aspx), AT/CMOS (Ports `70h`, `240h`, `2C0h`)
  - MM58167/UM82C8167 - SixPakPlus V1, Turbo 33-XT, Many clone I/O boards (Ports `2C0h`, `240h`, `340h`)
  - RP5C15 - SixPakPlus V2
  - MSM5832x - Quadram, DTK PII-125
  - and more to come!
- Works with any PC BIOS that supports option ROMs (almost all)

### Credits:

- @PickledDog, for the name
