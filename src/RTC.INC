
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
; - RTC_RP, RTC_OK, RTC_NS, RTC_NS2
; - RTC_OK, RTC_OK2
; - RTC_AT
;----------------------------------------------------------------------------;
RTC_NONE		EQU	0			; No RTC installed
;RTC_AT		EQU	1			; 1  AT  - DS12x85/MC146818
RTC_RP		EQU	2			; 2  RP  - RP5C15
RTC_OK		EQU	3			; 3  OK  - MSM5832

;RTC_OK1		EQU	4			; 4  OK1 - MSM58321 (in progress)
;RTC_OK2		EQU	5			; 5  OK2 - MSM6242
;RTC_SW		EQU	8			; 8  SW  - DS1216x/DS1315 SmartWatch (in progress)

RTC_NS		EQU	14			; 14 NS  - MM58167AN 16 ports * must be 14
RTC_NS2		EQU	15			; 15 NS2 - MM58167AN 2 ports * must be 15

;----------------------------------------------------------------------------;
; Some clock programs store year where 00 = 1980, 20 = 2000, etc
; Enable for compatibility.
; 
Y2K_OFFSET		=	0			; Store year as YY+20
							; default setting - may be overriden
							; for each RTC type