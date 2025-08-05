
;----------------------------------------------------------------------------;
; Define Nibbles to Byte
; Convert two nibbles to byte (big endian)
;----------------------------------------------------------------------------;
DNB		RECORD	HBN:4, LBN:4

;----------------------------------------------------------------------------;
; Define Bytes to Word
; Convert two bytes to word (big endian)
;----------------------------------------------------------------------------;
DBW		RECORD	HWB:8, LWB:8

;----------------------------------------------------------------------------;
; Unpack packed BCD nibbles in AL into AH/AL (unpacked BCD)
;----------------------------------------------------------------------------;
SAFE_V20	EQU	1		; don't use AAM/AAD imm instructions to split
					; nibbles in case some CPUs/emulators do not
					; implement this
CPU_V20	EQU	0		; Use V20 nibble instructions instead
					; NOTE: this will NOT work on non-V20/V30 CPUs!
UNPACK_NIB	MACRO
			IF SAFE_V20 EQ 1 AND CPU_V20 NE 1
	MOV	AH, AL		; AH = packed input
		REPT	4
	SHR	AH, 1			; shift high nibble into low nibble
		ENDM
	AND	AL, 0FH		; isolate low nibble
			ELSE
				IF CPU_V20 EQ 1
	MOV	AH, AL		; AH(H) = high digit
	DB	0FH, 2AH, 0C4H	; ROR4 AH: AH(L) = high digit, AL(L) = low digit
	AND	AX, 0F0FH		; clear high nibbles
				ELSE
	DB	0D4H, 10H		; AAM 10H
				ENDIF
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Pack unpacked BCD nibbles in AH/AL into packed BCD in AL
;----------------------------------------------------------------------------;
PACK_NIB	MACRO
			IF SAFE_V20 EQ 1 AND CPU_V20 NE 1
	AND	AL, 0FH		; isolate low nibble
		REPT	4
	SHL	AH, 1			; shift low nibble into high nibble
		ENDM
	OR	AL, AH		; combine nibbles
			ELSE
				IF CPU_V20 EQ 1
	DB	0FH, 28H, 0C4H	; ROL4 AH
	XCHG	AL, AH
				ELSE
	DB	0D5H, 10H		; AAD 10H
				ENDIF
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; Clear ISA bus before I/O port read
;----------------------------------------------------------------------------;
ISA_CLEAR	MACRO
	MOV	AL, 0FFH		; write all 1s to bus to clear buffer ICs
	OUT	0BFH, AL		; write to any unused port
		ENDM

;----------------------------------------------------------------------------;
; PUSH multiple registers (up to 8)
;----------------------------------------------------------------------------;
PUSHX	MACRO r1, r2, r3, r4, r5, r6, r7, r8
			IFNB <r1>			; exit if last reg
	PUSH	r1 					; push register and repeat
	PUSHX	r2, r3, r4, r5, r6, r7, r8
			ENDIF
		ENDM

;----------------------------------------------------------------------------;
; POP multiple registers (up to 8)
;----------------------------------------------------------------------------;
POPX	MACRO r1, r2, r3, r4, r5, r6, r7, r8
			IFNB <r1>			; exit if last reg
	POP	r1 					; pop register and repeat
	POPX	r2, r3, r4, r5, r6, r7, r8
			ENDIF
		ENDM