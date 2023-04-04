	PAGE	 	59,132
	TITLE		GLaLIB

;----------------------------------------------------------------------------;
; GLaBIOS (General Libraries and Basic Input Output System)
; Copyright (c) 2022-2023, 640KB and contributors
;----------------------------------------------------------------------------;
; These are the actual General Libraries used for Companion ROMs.
;----------------------------------------------------------------------------;

OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
PUBLIC	WORD_HEX, BYTE_HEX, NIB_HEX, OUT_CHAR
PUBLIC	OUT_SZ_ATTR, OUT_SZ, OUT_SZ_NL
PUBLIC	POST_START_COL_1, POST_START_COL_2, POST_END_COL, POST_END_COL_NL
PUBLIC	IS_GLABIOS, IRET_CF, IRET_CF_1

INCLUDE	GLALIB.INC
INCLUDE 	MACROS.INC
INCLUDE 	SEGS.INC
INCLUDE	RTC.INC

;----------------------------------------------------------------------------;
; Are you still there?
;----------------------------------------------------------------------------;
; Output: ZF if GLaBIOS, otherwise NZ
;----------------------------------------------------------------------------;
IS_GLABIOS	PROC
	PUSH	AX
	PUSH	DS
			ASSUME DS:_BIOS
	MOV	AX, SEG _BIOS
	MOV	DS, AX
	CMP	_BIOS_TOP, DBW < 'G', LF >	; ZF if is GB
			ASSUME DS:OPTROM
	POP	DS
	POP	AX
	RET
IS_GLABIOS	ENDP

;----------------------------------------------------------------------------;
; IRET with all previous flags and current CF
;----------------------------------------------------------------------------;
IRET_CF PROC NEAR
	PUSH	BP
	PUSH	AX

;----------------------------------------------------------------------------;
; Same except BP and AX already on top of stack
;----------------------------------------------------------------------------;
IRET_CF_1 PROC NEAR
	MOV	BP, SP				; get stack frame
	LAHF						; AH = current flags
	AND	AH, 1b				; isolate CF flag bit
	AND	BYTE PTR [BP][8], NOT 1b	; clear CF bit in saved EFLAGS
	OR	[BP][8], AH				; set current CF bit
	POP	AX
	POP	BP
	IRET
IRET_CF_1 ENDP
IRET_CF ENDP

;----------------------------------------------------------------------------;
; Write DWORD BX:AX as HEX to console
;----------------------------------------------------------------------------;
; Input: BX:AX - 32 bit value to write
; WORDS are separated by a colon ex: 1234:ABCD
;
; AX clobbered
; Size: 50 bytes
;----------------------------------------------------------------------------;
;DWORD_HEX PROC
;	PUSH	AX 				; save AX
;	MOV	AX, BX
;	CALL	WORD_HEX 			; write AX to console as HEX
;	MOV	AL, ':'
;	CALL	OUT_CHAR			; Write char in AL to console
;	POP	AX 				; restore AX

;--------------------------------------------------------------------------
; Write WORD AX as HEX to console
;--------------------------------------------------------------------------
WORD_HEX PROC
	PUSH	AX 				; save AX
	MOV	AL, AH 			; move high byte into low byte
	CALL	BYTE_HEX 			; write byte as HEX to console
	POP	AX 				; restore AX

;--------------------------------------------------------------------------
; Write BYTE AL as HEX to console
;--------------------------------------------------------------------------
BYTE_HEX PROC
	PUSH	AX 				; save AL
	SHR	AL, 1				; move high nibble to low nibble
	SHR	AL, 1				; move high nibble to low nibble
	SHR	AL, 1				; move high nibble to low nibble
	SHR	AL, 1				; move high nibble to low nibble
	CALL	NIB_HEX 			; write low nibble of AL as HEX to console
	POP	AX 				; restore AL

;--------------------------------------------------------------------------
; Write low nibble of AL as HEX to console
;--------------------------------------------------------------------------
NIB_HEX PROC
	AND	AL, 0FH 			; isolate low nibble
	CMP	AL, 0AH 			; if < 0Ah, CF=1 and setup a -1 for ASCII
						;  adjust since 'A'-'9' is 7 (not 6)
	SBB	AL, -('0'+66H+1) 		; BCD bias for ASCII (30h + 66h + CF)
						;  AF = AL < 0Ah, CF = 1
						;  if > 9, high_nibble = 0Ah
						;  if <=9, high_nibble = 09h
	DAS					; BCD adjust to ASCII
						;  if low_nibble < 0Ah, low_nibble -= 6
						;  high_nibble -= 6

;--------------------------------------------------------------------------
; Write char in AL to console
;--------------------------------------------------------------------------
OUT_CHAR PROC
	PUSH	AX
	PUSH	BX
	XOR	BX, BX			; video page = 0
	MOV	AH, 0EH			; Write AL to screen tty mode
	INT	10H				; send to console
	POP	BX
	POP	AX
	RET

OUT_CHAR ENDP
NIB_HEX ENDP
BYTE_HEX ENDP
WORD_HEX ENDP
;DWORD_HEX ENDP

		;IF SHOW_BANNER EQ 1 OR SHOW_CLOCK EQ 1
;----------------------------------------------------------------------------;
; Write POST column label and start separator 
;----------------------------------------------------------------------------;
; - Start new line
; - display column name in color 1
; - display left separator in color 1
; - set color for inner text to be color 2
;----------------------------------------------------------------------------;
; Input:
; - SI: column name string
; - BL: inner text color/attribute
;
; Output:
; - SI: beginning of next adjacent string
; - CX: inner text color length = POST_TAB_COL_I
;----------------------------------------------------------------------------;
POST_COL PROC

POST_LSEP		DB	POST_L, 0
POST_RSEP		DB	POST_R, 0

;----------------------------------------------------------------------------;
; Handle 40 column mode - move to next line and fall through to col 1
;
POST_START_COL_2_40:
	CALL	CRLF				; move to next line
	POP	AX				; rebalance stack
POST_START_COL_1 PROC
	PUSH	AX
	MOV	AL, POST_COL_W		; column 1 tab width
POST_START_COL_START:
	PUSH	BX				; save inner text color
	MOV	AH, BL			; save text color
	MOV	CX, POST_COL_VT		; set attribute on next CX # of chars
	MOV	BX, LOW POST_CLR_TXT	; set outer text color
	CALL	OUT_SZ_ATTR			; write SI string with attribute
	CALL	MOVE_COL			; move cursor to separator column
	PUSH	SI				; save end of string
	MOV	SI, OFFSET POST_LSEP	; write separator string with
	CALL	OUT_SZ			;  existing attributes
	MOV	BL, AH			; restore text color
	DEC	SI				; [SI] = previous null char
	MOV	CL, POST_TAB_COL_I	; CX = repeat times
	PUSH	CX				; save for return
	CALL	OUT_SZ_ATTR			; set attributes, skip null string
	POP	CX				; CX = inner text color length
	POP	SI				; restore string position
	POP	BX				; BL = attribute for next CX chars
	POP	AX
	RET
POST_START_COL_1 ENDP

;----------------------------------------------------------------------------;
; Same as POST_START_COL_1 except starts at column 2
;----------------------------------------------------------------------------;
POST_START_COL_2 PROC
	PUSH	AX
	MOV	AH, 0FH			; get video mode
	INT	10H				; AL = video mode
	CMP	AL, 1				; is 40 column mode?
	JLE	POST_START_COL_2_40
	MOV	AL, POST_TAB_COL		; move to start of column 2
	CALL	MOVE_COL
	MOV	AL, POST_TAB_COL+POST_COL_W	; set abs. position for column 2 tab
	JMP	POST_START_COL_START
POST_START_COL_2 ENDP

;----------------------------------------------------------------------------;
; Same as POST_END_COL and displays a CRLF
;----------------------------------------------------------------------------;
POST_END_COL_NL PROC
	CALL	POST_END_COL

;----------------------------------------------------------------------------;
; Write a CRLF string to console
;----------------------------------------------------------------------------;
CRLF PROC
	PUSH	SI
	CALL	OUT_NL
	POP	SI
	RET
CRLF ENDP

POST_END_COL_NL ENDP

;----------------------------------------------------------------------------;
; Write POST column end separator 
;----------------------------------------------------------------------------;
; Display right separator in color POST_CLR_TXT
;----------------------------------------------------------------------------;
POST_END_COL PROC NEAR
	MOV	SI, OFFSET POST_RSEP
POST_END_COL_STR PROC NEAR
	MOV	CX, 2
	MOV	BX, LOW POST_CLR_TXT	; Fall through to OUT_SZ_ATTR and RET
POST_END_COL_STR ENDP
POST_END_COL ENDP

;----------------------------------------------------------------------------;
; Write a zero-terminated string to console with attributes, no cursor move
;----------------------------------------------------------------------------;
; Sets attribute in BL for the next CX number of characters, past end of string.
;
; Input: CS:SI = String, CX = length, BL = attribute, BH = video page
; Output: SI = end of string
;----------------------------------------------------------------------------;
OUT_SZ_ATTR PROC
	PUSH	AX
	MOV	AX, DBW < 9, ' ' >	; AH = function 9, AL = space char
	INT	10H				; write CX number of chars with attribute
	POP	AX				; Fall through to OUT_SZ and RET

;----------------------------------------------------------------------------;
; Display a zero-terminated string in BIOS at CS:[SI]
;----------------------------------------------------------------------------;
; Input: CS:SI = String
; Size: 24 bytes
;----------------------------------------------------------------------------;
OUT_SZ PROC
	PUSH	AX
	PUSH	BX
	XOR	BX, BX			; video page 0
OUT_SZ_LOOP:
	MOV	AH, 0EH			; TTY output
	LODS	BYTE PTR CS:[SI]		; AL = CS:[SI++]
	TEST	AL, AL			; is zero terminator?
	JZ	OUT_SZ_DONE			; if so, exit
	INT	10H
	JMP	SHORT OUT_SZ_LOOP
OUT_SZ_DONE:
	POP	BX
	POP	AX
	RET
OUT_SZ ENDP

;----------------------------------------------------------------------------;
; Display a zero-terminated string in BIOS at CS:[SI], followed by CRLF
;----------------------------------------------------------------------------;
OUT_SZ_NL PROC
	CALL	OUT_SZ

;----------------------------------------------------------------------------;
; Write a CRLF string to console
;----------------------------------------------------------------------------;
; Clobbers SI
;----------------------------------------------------------------------------;
OUT_NL PROC
	EXTRN	STR_CRLF:NEAR		; use CRLF from GLATICK.ASM
	MOV	SI, OFFSET STR_CRLF
	JMP	SHORT OUT_SZ
OUT_NL ENDP

OUT_SZ_NL ENDP

OUT_SZ_ATTR ENDP

;----------------------------------------------------------------------------;
; Locate cursor to column on current line
;----------------------------------------------------------------------------;
; Input:
; - AL = new col
;
; Size: 23 bytes
;----------------------------------------------------------------------------;
MOVE_COL PROC
	PUSH	AX				; must preserve all of these
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	AX				; preserve AL on INT 10H call
	XOR	BH, BH 			; video page 0
	MOV	AH, 3 			; get cursor position
	INT	10H 				; DH = row, DL = column
	POP	AX
MOVE_COL_SET:
	MOV	DL, AL			; set new column
	MOV	AH, 2 			; set cursor position
	INT	10H 				; row = DH, column = DL
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
MOVE_COL ENDP
POST_COL ENDP
		;ENDIF

OPTROM	ENDS
		END
