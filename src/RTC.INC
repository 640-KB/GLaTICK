
;----------------------------------------------------------------------------;
; GLaTICK Configurable Build Options
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; RTC Support - uncomment to enable
; (Must be numeric between 0-7)
;
RTC_NONE		EQU	0			; No RTC installed
;RTC_AT		EQU	1			; 1 AT - DS12x85/MC146818
RTC_OK		EQU	2			; 2 OK - MSM5832
RTC_RP		EQU	3			; 3 RP - Ricoh RP5C15
;RTC_SW		EQU	4			; 4 SW - DS1216x SmartWatch (incomplete)
							; 5 TBD
RTC_NS		EQU	6			; 6 NS - MM58167AN 16 ports * must be 6
RTC_NS2		EQU	7			; 7 NS - MM58167AN 2 ports  * must be 7

;----------------------------------------------------------------------------;
; Some clock programs store year where 00 = 1980, 20 = 2000, etc
; Enable for compatibility.
; 
Y2K_OFFSET		=	0			; Store year as YY+20
							; default setting - may be overriden
							; for each RTC type
