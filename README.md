# GLaTICK
## (Generational Logic and Time Interval Cadence Knower)
A real-time clock PC BIOS [Companion ROM](https://github.com/640-KB/GLaBIOS/wiki/Companion-ROMs) supporting many popular RTC ICs.

GLaTICK eliminates the need for DOS-based RTC clock drivers/programs and lets your supported RTC "just work" like later PCs.

### Pre-release ROMs available for testing

[Download ROMs](https://github.com/640-KB/GLaTICK/releases)

## Features

- Implements `INT 1Ah` RTC functionality for seamless clock support (no software needed!)
- Support for many popular ICs including:
  - DS12x85/MC146818 - [RTC ISA 8 bits](https://www.tindie.com/products/spark2k06/rtc-isa-8-bits-very-low-profile-2/?utm_source=glabios&utm_medium=link&utm_campaign=project_buynow), [NuXT](https://monotech.fwscart.com/NuXT_v20_-_MicroATX_Turbo_XT_-_10MHz_832K_XT-IDE_Multi-IO_SVGA/p6083514_19777986.aspx), [AT/CMOS](https://hackaday.io/project/168972-rtc-isa-8-bits-pcxt) (Ports `70h`, `240h`, `2C0h`)
  - MM58167/UM82C8167 - SixPakPlus V1, Turbo 33-XT, Many clone I/O boards (Ports `2C0h`, `240h`, `340h`)
  - RP5C15 - SixPakPlus V2
  - MSM5832x - Quadram, DTK PII-125
  - and more to come!

## Requirements

- Any BIOS that supports Option ROMs
- DOS 3.3 or later
- a ROM within the valid Option ROM address space typically `D000h`-`EF80h`, however [GLaBIOS](https://github.com/640-KB/GLaTICK/releases) and [Super PC/Turbo XT BIOS](https://www.phatcode.net/downloads.php?id=101) support option ROMs up to `FD80h` enabling the use of motherboard ROM sockets.
- A [supported](#features) RTC card

## Screenshots

SixPakPlus at `2C0h` on [GLaBIOS](https://github.com/640-KB/GLaBIOS):

![SixPakPlus GLaBIOS](https://github.com/640-KB/GLaTICK/blob/main/images/glatick_nc_gb_cga_2.png)

RTC_8088 on PC/XT:

![SixPakPlus GLaBIOS](https://raw.githubusercontent.com/640-KB/GLaTICK/main/images/glatick_at_pc_mda_1.png)

### Credits:

- @PickledDog, for the name

Copyright &copy; 2023, [640KB](mailto:640kb@glabios.org) and contributors.
