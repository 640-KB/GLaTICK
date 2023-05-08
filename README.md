# GLaTICK
## (Generational Logic and Time Interval Cadence Knower) <sup>[**](#credits)</sup> 
A real time clock PC BIOS [Companion ROM](https://github.com/640-KB/GLaBIOS/wiki/Companion-ROMs) for XT machines supporting many popular RTCs and ISA I/O adapters.

GLaTICK eliminates the need for DOS-based RTC clock drivers/programs letting your supported RTC "just work" like later PCs.

## Pre-release Version 0.8:

[Download ROMs](https://github.com/640-KB/GLaTICK/releases)

[Source Code](https://github.com/640-KB/GLaTICK/tree/main/src)

## Features

- Implements `INT 1Ah` RTC functionality for seamless clock support. Real time clock is set and read by DOS - no software needed!
- Support for many popular ICs including:
  - **DS12x85/MC146818** used by [RTC ISA 8 bits](https://www.tindie.com/products/spark2k06/rtc-isa-8-bits-very-low-profile-2/?utm_source=glabios&utm_medium=link&utm_campaign=project_buynow), [NuXT](https://monotech.fwscart.com/NuXT_v20_-_MicroATX_Turbo_XT_-_10MHz_832K_XT-IDE_Multi-IO_SVGA/p6083514_19777986.aspx), [AT/CMOS](https://hackaday.io/project/168972-rtc-isa-8-bits-pcxt) (Ports `70h`, `240h`, `2C0h`)
  - **MM58167/UM82C8167** used by SixPakPlus V1, Turbo 33-XT, Many clone I/O boards (Ports `2C0h`, `240h`, `340h`)
  - **RP5C15** used by SixPakPlus V2
  - **MSM5832** used by Quadram, DTK PII-125
  - **MSM6242**	used by Intel Above Board and other MSM-6242 boards

## Requirements

- Any BIOS that supports [Option ROMs](https://en.wikipedia.org/wiki/Option_ROM)
- A [supported](#features) RTC card (of course)
- DOS 3.3 or later <super>[**](https://github.com/640-KB/GLaTICK/wiki/IBM-DOS-7-and-PC-DOS-2000)</super>
- GLaTICK ROM image within the valid Option ROM address space.  [More info here](https://github.com/640-KB/GLaTICK/wiki/Option-ROM-How-to).

## Screenshots

SixPakPlus at `2C0h` on [GLaBIOS](https://github.com/640-KB/GLaBIOS):

![SixPakPlus GLaBIOS](https://github.com/640-KB/GLaTICK/blob/main/images/glatick_nc_gb_cga_2.png)

RTC_8088 on PC/XT:

![RTC_8088 XT](https://raw.githubusercontent.com/640-KB/GLaTICK/main/images/glatick_at_pc_mda_1.png)

### Build:

Using MASM 5: `MAKE GLATICK.MAK`.  

Using MASM 6: `NMAKE GLATICK.NMK`.

The included `OPT2ROM.COM` will convert the produced EXE file to a 2 KiB ROM file.

### Roadmap:

- Support for additional RTCs including:
  - MSM-58321
  - DS1216 / DS1315 "Smart Watch"
- `INT 1Ah` ALARM (`6h` and `7h`) (where supported)

### Credits:

- @PickledDog, for the name

Copyright &copy; 2023, [640KB](mailto:640kb@glabios.org) and contributors.
