
;----------------------------------------------------------------------------;
; 0000:0000 - 8086 INT vector table
;----------------------------------------------------------------------------;
_IVT		SEGMENT AT 0H
		ORG 15H*4
_INT_15H		LABEL DWORD			; INT 15H - System Services
_INT_15H_OFF	DW	?
_INT_15H_SEG	DW	?
		ORG 1AH*4
_INT_1AH		LABEL DWORD			; INT 1AH - Time/RTC
_INT_1AH_OFF	DW	?
_INT_1AH_SEG	DW	?
		ORG 50H*4
_INT_50H		LABEL DWORD			; INT 15H - Relocated
_INT_50H_OFF	DW	?
_INT_50H_SEG	DW	?
		ORG 55H*4
_INT_55H		LABEL DWORD			; INT 1AH - Relocated
_INT_55H_OFF	DW	?
_INT_55H_SEG	DW	?
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
