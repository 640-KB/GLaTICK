
;----------------------------------------------------------------------------;
; GLaBIOS (General Libraries and Basic Input Output System)
; Copyright (c) 2022-2023, 640KB and contributors
;----------------------------------------------------------------------------;
; These are the actual General Libraries used for Companion ROMs.
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; String Defines
;----------------------------------------------------------------------------;
CR 			EQU	0DH 			; Carriage return
LF 			EQU	0AH 			; Line feed
HEART			EQU	03H			; faithful companion
POST_L		EQU	<' [ '>		; left separator string
POST_R		EQU	<' ]'>		; right separator string

;----------------------------------------------------------------------------;
; RTC Data (40:B0H)
;----------------------------------------------------------------------------;
; High nibble = RTC type (0-15) - see RTC.INC
; Low 3 nibbles = I/O port address
;----------------------------------------------------------------------------;
RTC_DAT	RECORD	RTTYPE:4, RTPORT:12

;----------------------------------------------------------------------------;
; GLaBIOS Equipment Flags (40:12H)
;----------------------------------------------------------------------------;
; 76543210
; xxxx    |		- TBD		: Reserved
;     x   |		- TURBO	: Turbo supported
;      x  |		- V20		: 1 if V20, 0 if 8088
;       xx|		- TBD2
; 84218421
;----------------------------------------------------------------------------;
GFLAGS 	RECORD	GTBD1:3, TURBO:1, V20:1, GTBD2:2

;----------------------------------------------------------------------------;
; 0040:0000 - BIOS data area (BDA)
;----------------------------------------------------------------------------;
; https://stanislavs.org/helppc/bios_data_area.html
;----------------------------------------------------------------------------;
_BDA		SEGMENT AT 40H
		ORG 012H
GB_FLAGS		GFLAGS <> 			; 12H  Custom Equipment Flags
		ORG 067H
ROM_INIT_SS		DW	?			; 67H   or Temp location for SS:SP during block move
ROM_INIT_SP 	DW	? 			; 69H	  or Option ROM init
		ORG 06CH
TIMER_CT_L		DW	?			; 6CH  Timer Counter Low Word (ticks)
TIMER_CT_H  	DW	? 			; 6EH  Timer Counter High Word (hours)
TIMER_CT_OF 	DB	? 			; 70H  Timer Overflow flag
		ORG	0EEH
RTC_DATA		RTC_DAT <>			; EEH  GLaTICK address and RTC type
_BDA		ENDS

;----------------------------------------------------------------------------;
; POST colors and visuals
;----------------------------------------------------------------------------;
POST_THEME		=	1		; color theme for POST screen (see below)

;----------------------------------------------------------------------------;
; PC Text Colors
; https://stanislavs.org/helppc/colors.html
;
BLACK			EQU	0
DARKBLUE		EQU	1
DARKGREEN		EQU	2
CYAN			EQU	3
DARKRED		EQU	4
DARKMAGENTA		EQU	5
BROWN			EQU	6
GRAY			EQU	7
DARKGRAY		EQU	8
BLUE			EQU	9
GREEN			EQU	10
LIGHTCYAN		EQU	11
RED			EQU	12
MAGENTA		EQU	13
YELLOW		EQU	14
WHITE			EQU	15

;----------------------------------------------------------------------------;
; Theme My POST Test!
; Pick theme from below or roll your own!
;----------------------------------------------------------------------------;
		IF POST_THEME EQ 3

; Theme #3 - "Boring"
POST_CLR_TXT	EQU	GRAY			; primary color for text
POST_CLR_VAL1	EQU	GRAY			; value text color
POST_CLR_VAL2	EQU	GRAY			; value text alternate color
POST_CLR_COLD	EQU	BLUE			; COLD color
POST_CLR_WARM	EQU	RED			; WARM color
POST_CLR_GB		EQU	GRAY			; BIOS name in bootup screen
		ELSE
		IF POST_THEME EQ 2

; Theme #2 - "Kinda l33t?"
POST_CLR_TXT	EQU	DARKGRAY
POST_CLR_VAL1	EQU	BLUE
POST_CLR_VAL2	EQU	GREEN
POST_CLR_COLD	EQU	BLUE
POST_CLR_WARM	EQU	RED
POST_CLR_GB		EQU	WHITE
		ELSE

; Theme #1 - "Old skool BBS" (default)
POST_CLR_TXT	EQU	CYAN
POST_CLR_VAL1	EQU	GREEN
POST_CLR_VAL2	EQU	YELLOW
POST_CLR_COLD	EQU	BLUE
POST_CLR_WARM	EQU	DARKRED
POST_CLR_GB		EQU	GRAY
		ENDIF
		ENDIF

;----------------------------------------------------------------------------;
; POST screen column layout options
;
POST_L		EQU	<' [ '>		; left separator string
POST_R		EQU	<' ]'>		; right separator string
L_POST_L		EQU	2			; length of separator

POST_TAB_COL	EQU	32			; horiz tab width for second column
POST_COL_LBL_W	EQU	7			; column label width
POST_COL_PAD	EQU	3			; padding (non colored) space between cols

POST_COL_W		EQU	POST_COL_LBL_W-1	; zero-based column index

; column label width plus separator
POST_COL_VT		EQU	POST_COL_LBL_W + L_POST_L

; space between next column
POST_TAB_COL_I	EQU	POST_TAB_COL - POST_COL_LBL_W - L_POST_L - POST_COL_PAD

;----------------------------------------------------------------------------;
; POST column UI
;----------------------------------------------------------------------------;
POST_COL_1	MACRO LBL_STR, INNER_ATTR, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
	PUSH	SI
		ENDIF
	MOV	BX, LOW INNER_ATTR
	MOV	SI, OFFSET LBL_STR
	CALL	POST_START_COL_1
		IFNB	<SAVE_REGS>
	POP	SI
	POP	BX
		ENDIF

		ENDM

POST_COL_2	MACRO LBL_STR, INNER_ATTR, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
	MOV	BX, LOW INNER_ATTR
	MOV	SI, OFFSET LBL_STR
	CALL	POST_START_COL_2
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM

POST_COL_END	MACRO	SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
	CALL	POST_END_COL
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM

POST_COL_END_NL	MACRO SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	BX					; save BX
		ENDIF
	CALL	POST_END_COL_NL
		IFNB	<SAVE_REGS>
	POP	BX
		ENDIF
		ENDM


;----------------------------------------------------------------------------;
; Shortcut to write a null-terminated string to console
;----------------------------------------------------------------------------;
; Input:
;	SZ = string to print
;	SAVE_REGS = define (anything) to preserve SI (cost of 2 bytes)
;----------------------------------------------------------------------------;
PRINT_SZ	MACRO	SZ, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	SI					; save SI
		ENDIF
		IFDIFI <SZ>,<SI>			; if SZ is not SI
	MOV	SI, OFFSET SZ
		ENDIF
	CALL	OUT_SZ
		IFNB	<SAVE_REGS>
	POP	SI
		ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Shortcut to write a null-terminated string to console and CRLF
;----------------------------------------------------------------------------;
; Input:
;	SZ = string to print
;	SAVE_REGS = define (anything) to preserve SI (cost of 2 bytes)
;----------------------------------------------------------------------------;
PRINTLN_SZ	MACRO	SZ, SAVE_REGS
		IFNB	<SAVE_REGS>
	PUSH	SI					; save SI
		ENDIF
		IFDIFI <SZ>,<SI>			; if SZ is not SI
	MOV	SI, OFFSET SZ
		ENDIF
	CALL	OUT_SZ_NL
		IFNB	<SAVE_REGS>
	POP	SI
		ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Introduce a short delay of ~15 clock cycles for I/O
;----------------------------------------------------------------------------;
; - Code size: 2 bytes
; - 15 clock cycles
; - Affects no registers or flags
; - CPU Instruction cache is purged
; - No stack required
;----------------------------------------------------------------------------;
IO_DELAY_SHORT	MACRO
		LOCAL _DONE
	JMP	SHORT _DONE
_DONE:
		ENDM

;----------------------------------------------------------------------------;
; Variable delay ~ CX * 15 clock cycles
;----------------------------------------------------------------------------;
; Input: CX delay in 15 clock cycle increments
; Output: CX = 0
;----------------------------------------------------------------------------;
IO_DELAY	MACRO
		LOCAL _DONE
_DONE:
	LOOP	_DONE					; long delay for I/O
		ENDM

;----------------------------------------------------------------------------;
; Long delay ~1.18m clock cycles (roughly 1/4 second on 4.77MHz)
;----------------------------------------------------------------------------;
; Output: CX = 0
;----------------------------------------------------------------------------;
IO_DELAY_LONG	MACRO
	XOR	CX, CX 				; delay 65535 LOOPs
	IO_DELAY
		ENDM
