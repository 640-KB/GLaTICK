
;----------------------------------------------------------------------------;
; GLaTICK Configurable Build Options
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; RTC Support - uncomment each to enable
; (Must be numeric between 0-15)
;
; Note: not all RTCs can be enabled simultaneously due to ROM space
; and potential for misdetections of overlapping ports.
;
; Recommented/Tested groupings:
; - RTC_RP, RTC_NS, RTC_NS2
; - RTC_OK, RTC_OK2, RTC_EP
; - RTC_AT
; - RTC_SW
;----------------------------------------------------------------------------;
RTC_NONE		EQU	0			; No RTC installed

RTC_AT		EQU	1			; 1  AT  - DS12x85/MC146818

;RTC_RP		EQU	2			; 2  RP  - RP5C15
;RTC_NS		EQU	14			; 14 NS  - MM58167AN 16 ports * must be 14
;RTC_NS2		EQU	15			; 15 NS2 - MM58167AN 2 ports * must be 15

;RTC_OK		EQU	3			; 3  OK  - MSM5832
;RTC_OK2		EQU	5			; 5  OK2 - MSM6242
;RTC_EP		EQU	4			; 4  EP  - RTC-58321

;RTC_SW		EQU	8			; 8  SW  - DS1216x/DS1315 SmartWatch

;----------------------------------------------------------------------------;
; Some clock programs store year where 00 = 1980, 20 = 2000, etc
; Enable for compatibility.
; 
Y2K_OFFSET		=	0			; Store year as YY+20
							; default setting - may be overriden
							; for each RTC type

;----------------------------------------------------------------------------;
; RESET_ON_ERROR:
; If enabled, this will validate the date and time read from the clock at POST
;   and if invalid attempt to reset the clock to 1980-01-01 00:00:00. This is
;   to prevent the "chicken and egg" scenario where DOS will not enable the RTC
;   thus preventing the date from being set using DATE/TIME.
; If disabled, non-error/CF results will be displayed as returned by the clock
;   driver. This may be helpful for debugging clock read issues.
;
RESET_ON_ERROR	=	1			; reset date if error on POST

;----------------------------------------------------------------------------;
; Relocate stack during POST to avoid conflict with badly behaving ROMs
;
POST_ALT_STACK	=	0			; use BIOS stack during POST

;----------------------------------------------------------------------------;
; Optional routines (can be removed to save code space)
;
USE_LEAP		=	0			; Do not include LEAP by default
SET_DOW		=	0			; calculate/set day of week if needed

;----------------------------------------------------------------------------;
; Per-clock configuration below
;
			IFDEF RTC_SW
POST_ALT_STACK	=	1			; use alternate stack during POST
							;  due to large amount of stack
							;  space required
RESET_ON_ERROR	=	1			; reset date if error on POST
USE_LEAP		=	1
SET_DOW		=	1			; calculate and set day of week
			ENDIF

			IFDEF RTC_NS
SET_DOW		=	1			; calculate and set day of week
			ENDIF

			IFDEF RTC_AT
SET_DOW		=	1			; calculate and set day of week
			ENDIF

			IFDEF RTC_RP
USE_LEAP		=	1
SET_DOW		=	1			; calculate and set day of week
			ENDIF

			IFDEF RTC_OK
USE_LEAP		=	1
			ENDIF
