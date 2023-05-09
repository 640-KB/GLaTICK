
;----------------------------------------------------------------------------;
; Re-vectored INTs for original BIOS ISRs
;----------------------------------------------------------------------------;
; AH function 2-5 (or 7), otherwise it will call the previous 1Ah.
; These may be changed below in the (unlikely) event of a conflict.
;
; http://ctyme.com/intr/int.htm
;----------------------------------------------------------------------------;
INT_15_BIOS		EQU	50H			; location for old BIOS 15H ISR
INT_1A_BIOS		EQU	55H			; location for old BIOS RTC ISR

;----------------------------------------------------------------------------;
; 0000:0000 - 8086 INT vector table
;----------------------------------------------------------------------------;
_IVT		SEGMENT AT 0H
		ORG	15H * 4
_INT_15H		LABEL DWORD			; INT 15H - System Services
_INT_15H_OFF	DW	?
_INT_15H_SEG	DW	?
		ORG	1AH * 4
_INT_1AH		LABEL DWORD			; INT 1AH - Time/RTC
_INT_1AH_OFF	DW	?
_INT_1AH_SEG	DW	?
		ORG	INT_15_BIOS * 4
_INT_15H_BIOS	LABEL DWORD			; INT 15H - Relocated
_INT_15H_BIOS_OFF	DW	?
_INT_15H_BIOS_SEG	DW	?
		ORG	INT_1A_BIOS * 4
_INT_1AH_BIOS	LABEL DWORD			; INT 1AH - Relocated
_INT_1AH_BIOS_OFF	DW	?
_INT_1AH_BIOS_SEG	DW	?
_IVT 		ENDS

;----------------------------------------------------------------------------;
; F000:E000 - System BIOS ROM segment map
;----------------------------------------------------------------------------;
_BIOS		SEGMENT AT 0F000H
		ORG	0E000H
_BIOS_TOP	LABEL WORD
		ORG	0E05BH
_BOOT		LABEL WORD				; BIOS boot offset
		ORG	0FFF0H
_POWER_ON	LABEL WORD				; CPU power-on jump address
_BIOS		ENDS
