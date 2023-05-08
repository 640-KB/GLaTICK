	PAGE	 	59,132
	TITLE		GLaTICK_RTC_OK2

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for OK2 = MSM-6242
;----------------------------------------------------------------------------;
; TODO:
; - clear/reset on invalid clock state
; - alarms/interrupts?
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_OK2
;----------------------------------------------------------------------------;
; Config
;----------------------------------------------------------------------------;
Y2K_OFFSET		=	1			; Store year as YY+20

;----------------------------------------------------------------------------;
; MSM6242 Registers Indexes
;
OK_1SEC		EQU	0			; 1-second counter
OK_10SEC		EQU	1			; 10-second counter
OK_1MIN		EQU	2			; 1-minute counter
OK_10MIN		EQU	3			; 10-minute counter
OK_1HOUR		EQU	4			; 1-hour counter
OK_10HOUR		EQU	5			; PM/AM, 10-hour counter

OK_1DAY		EQU	6			; 1-day counter
OK_10DAY		EQU	7			; 10-day counter
OK_1MON		EQU	8			; 1-month counter
OK_10MON		EQU	9			; 10-month counter
OK_1YEAR		EQU	0AH			; 1-year counter
OK_10YEAR		EQU	0BH			; 10-year counter
OK_WEEK		EQU	0CH			; Week counter

CRD			EQU	0DH			; Control register D
CRE			EQU	0EH			; Control register E
CRF			EQU	0FH			; Control register F

;----------------------------------------------------------------------------;
; Register sizes - BCD packed
;
OK2_SEC		RECORD	SECX:1, SEC10:3, SEC01:4
OK2_MIN		RECORD	MINX:1, MIN10:3, MIN01:4
OK2_HR		RECORD	HRX:1,  HRAP:1,  HR10:2, HR01:4
OK2_DATE		RECORD	DTX1:2, DT10:2,  DT01:4
OK2_MON		RECORD	MNX1:3, MON10:1, MON01:4
OK2_DOW		RECORD	DWX:5,  DOW:3

;----------------------------------------------------------------------------;
; OK2_CRD: Control Register D (0Dh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- CDX:	unused (always 0)
;     x 		- A30:	30 sec. ADJ	1=add 30 seconds
;      x		- IRF: 	IRQ FLAG
;       x 		- BSY:	BUSY
;        x		- HLD: 	HOLD		1=HOLD clock, 0=RUN clock
;----------------------------------------------------------------------------;
OK2_CRD		RECORD	CDX:4, A30:1, IRF:1, BSY:1, HLD:1

;----------------------------------------------------------------------------;
; OK2_CRE: Control Register E (0Eh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- CEX:	unused (always 0)
;     x 		- T1:		T1		Determines the period of the STD.P 
;      x		- T0:		T0		   output in both ITRPT/STND modes
;       x 		- ITR:	ITRPT/STND	INT and STND timing waveforms
;        x		- MSK: 	MASK		1=MASK INTERRUPTS, 0=ENABLE
;----------------------------------------------------------------------------;
OK2_CRE		RECORD	CEX:4, ET1:1, ET0:1, ITR:1, MSK:1

;----------------------------------------------------------------------------;
; OK2_CRF: Control Register F (0Fh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- CFX:	unused (always 0)
;     x 		- TST:	TEST
;      x		- AP: 	24/12		1=24, 0=12
;       x 		- STP:	STOP		1=STOP, 0=RUN
;        x		- RST: 	REST		1=RESET, 0=CLEAR RESET BIT
;----------------------------------------------------------------------------;
OK2_CRF		RECORD	CFX:4, TST:1, AP:1=1, STP:1, RST:1

INCLUDE	GLALIB.INC
INCLUDE 	MACROS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
			ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	OK2_DETECT
EXTRN		INT_1A_DEFAULT:NEAR, IRET_CF:NEAR
EXTRN		BCD_TO_WORD:NEAR, PACK_BCD:NEAR, GET_RTC:NEAR

;----------------------------------------------------------------------------;
; Supported I/O ports 2C0, 240, 250, 300, 340, 350
;----------------------------------------------------------------------------;
OK2_PORTS	DW	2C0H			; common ports
;		DW	240H, 340H		; less common ports
;		DW	250H, 300H
;		DW	340H, 350H
OK2_PORT_CT	EQU	($-OK2_PORTS)/2	; number of supported ports

;----------------------------------------------------------------------------;
; INT 1A IVT for MSM6242
;----------------------------------------------------------------------------;
INT_1A_OK2 PROC
	STI						; interrupts okay for now
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_OK2_BIOS			; if so, use default call
	CMP	AH, 5 				; is function supported?
	JBE	INT_1A_OK2_1			; if not, use default call
INT_1A_OK2_BIOS:
	JMP	NEAR PTR INT_1A_DEFAULT		; near jump to BIOS handler
INT_1A_OK2_1:
	PUSH	BX
	PUSH	DI
	XCHG	AX, BX				; save AX
	CALL	GET_RTC				; DI = port, AL = type, ZF if no RTC installed
	STC						; presume failure
	JZ	INT_1A_OK2_EXIT			; exit if port not installed
	MOV	AX, BX				; restore AX
	XCHG	AH, AL				; AL = function
	SHL	AL, 1					; word align index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	OK2_HOLD				; test and hold clock
	JC	INT_1A_OK2_EXIT			; if error, do not continue
	CALL	CS:INT_1A_OK2_JMP[BX][-4]	; adjust JMP offset (cannot be 0 or 1)
	CALL	OK2_RUN				; clear hold, and CF=0
INT_1A_OK2_EXIT:
	POP	DI
	POP	BX
	JMP	NEAR PTR IRET_CF			; RET with previous flags and current CF

INT_1A_OK2_JMP LABEL WORD
	DW	OFFSET OK2_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET OK2_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET OK2_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET OK2_INT_1A_5		; AH = 5 - Set RTC Date

INT_1A_OK2 ENDP

;----------------------------------------------------------------------------;
; INT 1A - System and "Real Time" Clock BIOS Services
;----------------------------------------------------------------------------;
; INT 1A,0   Read system clock counter
; INT 1A,1   Set system clock counter
; INT 1A,2   Read real time clock time (AT,PS/2)
; INT 1A,3   Set real time clock time (AT,PS/2)
; INT 1A,4   Read real time clock date (AT,PS/2)
; INT 1A,5   Set real time clock date (AT,PS/2)
; INT 1A,6   Set real time clock alarm (AT,PS/2) ** not implemented
; INT 1A,7   Reset real time clock alarm (PS/2)  ** not implemented
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; INT 1A,2	Read Time From RTC
;----------------------------------------------------------------------------;
; Input:
;	AH = 2
; Return:
;	CF = 0 if successful
;	   = 1 if error, RTC not operating
;	CH = hours in BCD
;	CL = minutes in BCD
;	DH = seconds in BCD
;	DL = 1 if daylight savings time option
;----------------------------------------------------------------------------;
OK2_INT_1A_2 PROC
	CWD						; DX = 0
	MOV	CX, DX				; CX = 0
	MOV	AL, OK_1SEC				; read 1 and 10-second counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_2_RET
	AND	AL, MASK SEC10 OR MASK SEC01
	MOV	DH, AL				; save to DH
	MOV	AL, OK_1MIN				; read 1 and 10-minute counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_2_RET
	AND	AL, MASK MIN10 OR MASK MIN01
	MOV	CL, AL				; save to CL
	MOV	AL, OK_1HOUR			; read 1 and 10-hour counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_2_RET
	AND	AL, MASK HR10 OR MASK HR01
	MOV	CH, AL				; save to CH
OK2_INT_1A_2_RET:
	RET
OK2_INT_1A_2 ENDP

;----------------------------------------------------------------------------;
; INT 1A,3 - Set Time on Real Time Clock 
;----------------------------------------------------------------------------;
; Input:
;	AH = 3
;	CH = hours in BCD
;	CL = minutes in BCD
;	DH = seconds in BCD
;	DL = 1 if daylight savings time option
;	   = 0 if standard time
;----------------------------------------------------------------------------;
OK2_INT_1A_3 PROC
	PUSH	AX
	CLI
	CALL	OK2_SET_24				; set 24 hour mode
	MOV	AL, OK_1HOUR
	MOV	AH, CH				; Hours
	AND	AH, MASK HR10 OR MASK HR01
	CALL	OK2_WRITE_BCD
	MOV	AL, OK_1MIN
	MOV	AH, CL				; minutes
	AND	AH, MASK MIN10 OR MASK MIN01
	CALL	OK2_WRITE_BCD
	MOV	AL, OK_1SEC
	MOV	AH, DH				; seconds
	AND	AH, MASK SEC10 OR MASK SEC01
	CALL	OK2_WRITE_BCD
	POP	AX
	RET
OK2_INT_1A_3 ENDP

;----------------------------------------------------------------------------;
; INT 1A,4 - Read Real Time Clock Date
;----------------------------------------------------------------------------;
; Input:
;	AH = 4
; Return:
;	CH = century in BCD (decimal 19 or 20)
;	CL = year in BCD
;	DH = month in BCD
;	DL = day in BCD
;	CF = 0 if successful
;	   = 1 if error or clock not operating
;
; Note: calling this interrupt will update the DOS maintained date and
;	reset the BIOS Data Area date rollover flag at 40:70
;----------------------------------------------------------------------------;
OK2_INT_1A_4 PROC
	CWD						; DX = 0
	MOV	CX, DX				; CX = 0
	MOV	AL, OK_1DAY				; read 1 and 10-day counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_4_RET			; jump if read error
	AND	AL, MASK DT10 OR MASK DT01
	MOV	DL, AL				; save to DL
	MOV	AL, OK_1MON				; read 1 and 10-month counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_4_RET			; jump if read error
	AND	AL, MASK MON10 OR MASK MON01
	MOV	DH, AL				; save to DH
	MOV	AL, OK_1YEAR			; read 1 and 10-year counter
	CALL	OK2_READ_BYTE
	JC	OK2_INT_1A_4_RET			; jump if read error
			IF Y2K_OFFSET EQ 1
	SUB	AL, 20H				; store year + 20
	DAS						; BCD adjust
			ENDIF
	MOV	CL, AL				; save to CL

;----------------------------------------------------------------------------;
; Get century - does not store century, so if less than 80 assumed Y2K
;
	MOV	AL, 20H				; assume Y2K
	CMP	CL, 80H				; is it above 80?
	JC	OK2_GET_CEN_DONE			; jump if not
	DEC	AX					; otherwse it's 19
	DAS						; BCD adjust
OK2_GET_CEN_DONE:
	MOV	CH, AL				; century to CH
	CLC						; no error
OK2_INT_1A_4_RET:
	RET
OK2_INT_1A_4 ENDP

;----------------------------------------------------------------------------;
; INT 1A,5 - Set Real Time Clock Date
;----------------------------------------------------------------------------;
; Input:
;	AH = 5
;	CH = century in BCD (decimal 19 or 20)
;	CL = year in BCD
;	DH = month in BCD
;	DL = day in BCD
; Return:
;	nothing
;----------------------------------------------------------------------------;
OK2_INT_1A_5 PROC
	PUSH	AX
	CLI
			IF Y2K_OFFSET EQ 1
	XCHG	AX, CX
	ADD	AL, 20H				; store year + 20
	DAA
	XCHG	AX, CX
			ENDIF
	MOV	AL, OK_1YEAR			; year
	MOV	AH, CL				; AH = year as packed BCD
	CALL	OK2_WRITE_BCD
	MOV	AL, OK_1MON				; month
	MOV	AH, DH				; AH = month as packed BCD
	AND	AH, MASK MON10 OR MASK MON01
	CALL	OK2_WRITE_BCD
	MOV	AL, OK_1DAY				; day
	MOV	AH, DL				; AH = day as packed BCD
	AND	AH, MASK DT10 OR MASK DT01
	CALL	OK2_WRITE_BCD
	POP	AX
	RET
OK2_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
; Detect MSM6242 on supported ports
;----------------------------------------------------------------------------;
OK2_DETECT PROC
	PUSH	SI
	PUSH	CX
	MOV	SI, OFFSET OK2_PORTS		; port table
	MOV	CX, OK2_PORT_CT			; number of ports
OK2_DETECT_LOOP:
	LODS	WORD PTR CS:[SI]			; AX = next port to try
	XCHG	DI, AX				; DI = port
	CALL	OK2_DETECT_PORT			; NC if found, CF if not
	JNC	OK2_DETECT_OK			; exit if found
	LOOP	OK2_DETECT_LOOP
OK2_DETECT_OK:
	POP	CX
	POP	SI
	RET
OK2_DETECT ENDP

;----------------------------------------------------------------------------;
; Detect MSM6242 on port 2C0H
;----------------------------------------------------------------------------;
; Input:
;	DI = base port to try
; Output:
;	CF if error/not found, NC if okay
;	DI = offset of new INT 1A IVT
;	DX = port number
;	AL = RTC type (RTC_OK2)
; Clobbers: AH
;----------------------------------------------------------------------------;
OK2_DETECT_PORT PROC
	PUSHF						; save IF
	CLI						; disable interrupts
	CALL	OK2_RESET				; reset to defaults
	CALL	OK2_HOLD				; hold clock
	JC	OK2_DETECT_RET			; exit with CF if error
	CALL	OK2_RUN				; clear hold, set CF=0
	MOV	DX, DI				; return detected base port
	MOV	DI, OFFSET INT_1A_OK2		; set DI if detected
	MOV	AL, RTC_OK2				; RTC type is MSM6242
OK2_DETECT_RET:
	LAHF						; save status flags
	POPF						; restore IF
	SAHF						; restore status flags
	RET
OK2_DETECT_PORT ENDP

;----------------------------------------------------------------------------;
; Hold Clock for read/write
;----------------------------------------------------------------------------;
; This can also be used for detection.
; If hold fails, returns error.
;
; Process:
; 1. Clear then Set/Hold Bit = 1
; 2. Read BUSY bit
; 3. BUSY bit = 0?
;	if 1:
;		Clear/Hold Bit = 0
;		idle time
;		goto 1.
; 4. Write/read data registers S1-W
; 5. Hold Bit = 0
;----------------------------------------------------------------------------;
; Output:
;	CF = if failure
;----------------------------------------------------------------------------;
OK2_HOLD PROC
	PUSH	AX
	PUSH	CX
	PUSH	DX
	PUSHF						; save IF
	CLI						; disable interrupts
	MOV	CX, 256 - 1				; retry twice
OK2_HOLD_1:
	CALL	OK2_RUN				; clear HLD bit
	MOV	AL, CRD				; control register D
	CALL	OK2_GET_PORT			; DX = control reg D port
	ISA_CLEAR					; clear ISA buffers
	IN	AL, DX				; read current control reg
	OR	AL, MASK HLD OR MASK BSY	; set HLD and BUSY bit
	OUT	DX, AL				; write back to controller
OK2_HOLD_2:
	ISA_CLEAR
	IN	AL, DX				; read control reg D
	TEST	AL, MASK BSY			; check BUSY bit, CF=0
	JZ	OK2_FOUND_1				; if no busy bit, okay
	TEST	CL, 128 - 1				; retry 128 times
	LOOPNZ OK2_HOLD_2				; keep checking
	INC	CX					; offset LOOP decrement
	LOOP	OK2_HOLD_1				; if CX > 1 retry clear/set HOLD
OK2_NOT_FOUND:
	STC						; not found - set CF=1
OK2_FOUND_1:
	LAHF						; save status flags
	POPF						; restore IF
	SAHF						; restore status flags
	POP	DX
	POP	CX
	POP	AX
	RET
OK2_HOLD ENDP

;----------------------------------------------------------------------------;
; Clear Hold bit and Run Clock
;----------------------------------------------------------------------------;
; Output:
;	CF = 0
;----------------------------------------------------------------------------;
OK2_RUN PROC
	PUSH	AX					; call preserve AX, DX
	PUSH	DX
	MOV	AL, CRD				; control register D
	CALL	OK2_GET_PORT			; DX = control port D
	IN	AL, DX				; read
	AND	AL, OK2_CRD <,1,1,1,0>		; clear HLD bit, CF=0
	OUT	DX, AL				; write back
	POP	DX
	POP	AX
	RET
OK2_RUN ENDP

;----------------------------------------------------------------------------;
; Set all registers to running defaults
;----------------------------------------------------------------------------;
; Input: Interrupts off (IF = 0)
; Clobbers: AX
;----------------------------------------------------------------------------;
OK2_RESET PROC
	CALL	OK2_SET_24					; set 24 hour mode
	MOV	AX, DBW < OK2_CRD <>, CRD >		; clear IRQ, BUSY, HOLD bits
	CALL	OK2_WRITE
	MOV	AX, DBW < OK2_CRE <,,,1,1>, CRE >	; set MASK and ITRPT/STND
	JMP	SHORT OK2_WRITE
OK2_RESET ENDP

;----------------------------------------------------------------------------;
; Set Clock to 24 hour mode
;----------------------------------------------------------------------------;
; Input: Interrupts off (IF = 0)
; Clobbers: AX
;----------------------------------------------------------------------------;
OK2_SET_24 PROC
	MOV	AX, DBW < OK2_CRF <,,0,,1>, CRF >	; set REST = 1
	CALL	OK2_WRITE
	MOV	AX, DBW < OK2_CRF <,,1,,1>, CRF >	; set 24 hour flag, REST = 1
	CALL	OK2_WRITE
	MOV	AX, DBW < OK2_CRF <,,1,,0>, CRF >	; set 24 hour flag, REST = 0
	JMP	SHORT OK2_WRITE
OK2_SET_24 ENDP

;----------------------------------------------------------------------------;
; Get register index port
;----------------------------------------------------------------------------;
; Input: AL = register index, DI = base port
; Output: DX = data port
;----------------------------------------------------------------------------;
OK2_GET_PORT PROC
	PUSH	BX				; save original BX
	MOV	BX, AX			; save original AX
	CBW					; AH = 0
	XCHG	AX, BX			; restore AX, BX = register index
	LEA	DX, [BX][DI]		; DX data port
	POP	BX				; restore BX
	RET
OK2_GET_PORT ENDP

;----------------------------------------------------------------------------;
; Read two digit register from RTC to packed BCD
;----------------------------------------------------------------------------;
; Input: AL = first register index
; Output: AX = byte register value
; 	CF if invalid, NC if valid
;----------------------------------------------------------------------------;
OK2_READ_BYTE PROC
	PUSH	DX				; DX clobbered by OK2_READ
	MOV	AH, AL			; save index
	CALL	OK2_READ
	JC	OK2_READ_BYTE_RET
	XCHG	AH, AL			; AL = first index, AH = first value
	INC	AX				; AL = second index
	CALL	OK2_READ			; AL = second value
	JC	OK2_READ_BYTE_RET
	XCHG	AH, AL			; AH = second value, AL = first value
	CALL	PACK_BCD			; pack BCD digits in AH/AL into AL
	XOR	AH, AH			; zero extend AL, CF = 0
OK2_READ_BYTE_RET:
	POP	DX
	RET
OK2_READ_BYTE ENDP

;----------------------------------------------------------------------------;
; Read single digit register from RTC to AL
;----------------------------------------------------------------------------;
; Input: AL = register index
; Output: AL = register value
; 	CF if invalid, NC if valid
; Clobbers: DX
;----------------------------------------------------------------------------;
OK2_READ PROC
	AND	AL, 0FH			; only low nibble
	CALL	OK2_GET_PORT		; DX = port for index AL
	ISA_CLEAR
	IN	AL, DX			; read register
	AND	AL, 0FH			; only low nibble
	CMP	AL, 10			; is valid (< 10)?
	CMC
	RET
OK2_READ ENDP

;----------------------------------------------------------------------------;
; Write packed BCD in AH to register AL
;----------------------------------------------------------------------------;
; Input: 
;	AL = first register index
;	AH = BCD register value
; Clobbers: BX
;----------------------------------------------------------------------------;
OK2_WRITE_BCD PROC
	MOV	BX, AX			; save starting index
	XCHG	AH, AL			; AL = register value
	UNPACK_BCD				; unpack BCD digits in AL into AH/AL
	MOV	BH, AH			; save high digit
	MOV	AH, AL			; AH = low digit
	MOV	AL, BL			; AL = starting index
	CALL	OK2_WRITE
	MOV	AH, BH			; restore high digit
	INC	AX				; next register
						; fall through for second OK2_WRITE call

;----------------------------------------------------------------------------;
; Write Register to RTC in current bank
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
; Output: None
;----------------------------------------------------------------------------;
OK2_WRITE PROC
	PUSH	DX
	CALL	OK2_GET_PORT		; DX = port for index AL
	XCHG	AL, AH			; AL = new register value
	OUT	DX, AL			; write register
	XCHG	AL, AH			; restore AX
	POP	DX
	RET
OK2_WRITE ENDP
OK2_WRITE_BCD ENDP

OPTROM	ENDS
			ENDIF				; IFDEF RTC_OK2
		END
