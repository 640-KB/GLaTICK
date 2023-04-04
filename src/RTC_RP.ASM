	PAGE	 	59,132
	TITLE		GLaTICK_RTC_RP

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for RP = RP5C15 SixPakPlus V2
;----------------------------------------------------------------------------;
; TODO:
; - clear/reset on invalid clock state
; - alarms/interrupts
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_RP
;----------------------------------------------------------------------------;
; Config
;----------------------------------------------------------------------------;
Y2K_OFFSET		=	1			; Store year as YY+20

;----------------------------------------------------------------------------;
; I/O Ports
;
ADDR_PORT		EQU	02C0H			; Address/Register port (only 2C0H)
DATA_PORT		EQU	ADDR_PORT+1		; Data Port

;----------------------------------------------------------------------------;
; RP5C15 Registers Indexes
; Bank 0
;
R0_1SEC		EQU	0			; 1-second counter
R0_10SEC		EQU	1			; 10-second counter
R0_1MIN		EQU	2			; 1-minute counter
R0_10MIN		EQU	3			; 10-minute counter
R0_1HOUR		EQU	4			; 1-hour counter
R0_10HOUR		EQU	5			; 10-hour counter
R0_WEEK		EQU	6			; Day-of-the-week counter
R0_1DAY		EQU	7			; 1-day counter
R0_10DAY		EQU	8			; 10-day counter
R0_1MON		EQU	9			; 1-month counter
R0_10MON		EQU	0AH			; 10-month counter
R0_1YEAR		EQU	0BH			; 1-year counter
R0_10YEAR		EQU	0CH			; 10-year counter
R0_MODE		EQU	0DH			; MODE register
R0_TEST		EQU	0EH			; TEST register
R0_RESET		EQU	0FH			; RESET controller, etc.

;----------------------------------------------------------------------------;
; Bank 1
;
R1_CSEC		EQU	0			; Clock output select
R1_ADJUST		EQU	1			; Adjust
R1_A1MIN		EQU	2			; 1-minute alarm register
R1_A10MIN		EQU	3			; 10-minute alarm register
R1_A1HOUR		EQU	4			; 1-hour alarm register
R1_A10HOUR		EQU	5			; 10-hour alarm register
R1_AWEEK		EQU	6			; Day-of-the-week alarm register
R1_A1DAY		EQU	7			; 1-day alarm register
R1_A10DAY		EQU	8			; 10-day alarm register
R1_12_24H		EQU	0AH			; 12/24 select register
R1_LEAP		EQU	0BH			; Leap year counter

;----------------------------------------------------------------------------;
; Register sizes - BCD packed
;
RP_SEC		RECORD	SECX:1, SEC10:3, SEC01:4
RP_MIN		RECORD	MINX:1, MIN10:3, MIN01:4
RP_HR			RECORD	HRX:1,  HR10:2,  HR01:4
RP_DATE		RECORD	DTX1:2, DT10:2,  DT01:4
RP_MON		RECORD	MNX1:3, MON10:1, MON01:4
RP_DOW		RECORD	DWX:5,  DOW:3

;----------------------------------------------------------------------------;
; RP_MODE: MODE register (0Dh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- MOX:	unused (always 0)
;     x 		- TEN:	Timer Enable
;      x		- AEN: 	Alarm Enable
;       x 		- MOZ:	unused (always 0)
;        x		- BNK: 	Bank (1/0)
;----------------------------------------------------------------------------;
RP_MODE		RECORD	MOX:4, TEN:1, AEN:1, MOZ:1, BNK:1

;----------------------------------------------------------------------------;
; RP_RESET: RESET controller (0Fh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- RSX:	unused (always 0)
;     x 		- R1K:	1 Hz ON
;      x		- R16K: 	16 Hz ON
;       x 		- TRS:	Timer Reset
;        x		- ARS: 	Alarm Reset
;----------------------------------------------------------------------------;
RP_RST		RECORD	RSX:4, R1K:1, R16K:1, TRS:1, ARS:1

INCLUDE	GLALIB.INC
INCLUDE 	MACROS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
			ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	RP_DETECT
EXTRN		INT_1A_DEFAULT:NEAR, IS_LEAP:NEAR, PACK_BCD:NEAR
EXTRN		IRET_CF:NEAR, BCD_TO_WORD:NEAR

;----------------------------------------------------------------------------;
; INT 1A IVT for RP RP5C15 
;----------------------------------------------------------------------------;
INT_1A_RP PROC
	STI
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_RP_BIOS			; if so, use default call
	CMP	AH, 5 				; is function supported?
	JBE	INT_1A_RP_1				; if not, use default call
INT_1A_RP_BIOS:
	JMP	NEAR PTR INT_1A_DEFAULT		; near jump to BIOS handler
INT_1A_RP_1:
	PUSH	BX
	XOR	BX, BX				; BL = 0
	CALL	RP_SET_BANK				; set bank to 0
	MOV	BX, AX				; save AX
	XCHG	AH, AL				; AL = function
	SHL	AL, 1					; word align index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	CS:INT_1A_RP_JMP[BX][-4]	; adjust JMP offset (cannot be 0 or 1)
	POP	BX
	JMP	NEAR PTR IRET_CF			; RET with previous flags and current CF

INT_1A_RP_JMP LABEL WORD
	DW	OFFSET RP_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET RP_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET RP_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET RP_INT_1A_5		; AH = 5 - Set RTC Date

INT_1A_RP ENDP

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
RP_INT_1A_2 PROC
	CWD					; DX = 0
	MOV	CX, DX			; CX = 0
	MOV	AL, R0_1SEC			; read 1 and 10-second counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_2_RET
	AND	AL, MASK SEC10 OR MASK SEC01
	MOV	DH, AL			; save to DH
	MOV	AL, R0_1MIN			; read 1 and 10-minute counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_2_RET
	AND	AL, MASK MIN10 OR MASK MIN01
	MOV	CL, AL			; save to CL
	MOV	AL, R0_1HOUR		; read 1 and 10-hour counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_2_RET
	AND	AL, MASK HR10 OR MASK HR01
	MOV	CH, AL			; save to CH
RP_INT_1A_2_RET:
	RET
RP_INT_1A_2 ENDP

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
RP_INT_1A_3 PROC
	PUSHF					; save IF
	CALL	RP_RESET			; prepare for writing, IF=0
	MOV	AL, R0_1HOUR		; 
	MOV	AH, CH			; Hours
	AND	AH, MASK HR10 OR MASK HR01
	CALL	RP_WRITE_BCD
	MOV	AL, R0_1MIN			; 
	MOV	AH, CL			; minutes
	AND	AH, MASK MIN10 OR MASK MIN01
	CALL	RP_WRITE_BCD
	MOV	AL, R0_1SEC			; 
	MOV	AH, DH			; seconds
	AND	AH, MASK SEC10 OR MASK SEC01
	CALL	RP_WRITE_BCD
	POPF					; restore IF
	RET
RP_INT_1A_3 ENDP

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
RP_INT_1A_4 PROC
	CWD					; DX = 0
	MOV	CX, DX			; CX = 0
	MOV	AL, R0_1DAY			; read 1 and 10-day counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_4_RET		; jump if read error
	AND	AL, MASK DT10 OR MASK DT01
	MOV	DL, AL			; save to DL
	MOV	AL, R0_1MON			; read 1 and 10-month counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_4_RET		; jump if read error
	AND	AL, MASK MON10 OR MASK MON01
	MOV	DH, AL			; save to DH
	MOV	AL, R0_1YEAR		; read 1 and 10-year counter
	CALL	RP_READ_BYTE
	JC	RP_INT_1A_4_RET		; jump if read error
			IF Y2K_OFFSET EQ 1
	SUB	AL, 20H			; store year + 20
	DAS					; BCD adjust
			ENDIF
	MOV	CL, AL			; save to CL

;----------------------------------------------------------------------------;
; Get century - the RP does not store century, so if less than 80 assumed Y2K
;
	MOV	AL, 20H			; assume Y2K
	CMP	CL, 80H			; is it above 80?
	JC	RP_GET_CEN_DONE		; jump if not
	DEC	AX				; otherwse it's 19
	DAS					; BCD adjust
RP_GET_CEN_DONE:
	MOV	CH, AL			; century to CH
	CLC					; no error
RP_INT_1A_4_RET:
	RET
RP_INT_1A_4 ENDP

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
RP_INT_1A_5 PROC
	PUSHF					; save IF
	CALL	RP_RESET			; prepare for write operation, IF=0
	PUSH	CX				; save original year
			IF Y2K_OFFSET EQ 1
	XCHG	AX, CX
	ADD	AL, 20H			; store year + 20
	DAA	
	XCHG	AX, CX
			ENDIF
	MOV	AL, R0_1YEAR		; year
	MOV	AH, CL			; AH = year as packed BCD
	CALL	RP_WRITE_BCD
	MOV	AL, R0_1MON			; month
	MOV	AH, DH			; AH = month as packed BCD
	AND	AH, MASK MON10 OR MASK MON01
	CALL	RP_WRITE_BCD
	MOV	AL, R0_1DAY			; day
	MOV	AH, DL			; AH = day as packed BCD
	AND	AH, MASK DT10 OR MASK DT01
	CALL	RP_WRITE_BCD

;----------------------------------------------------------------------------;
; Set leap year counter
;
	POP	AX				; restore AX = BCD year
	CALL	BCD_TO_WORD			; AX = BCD WORD
	CALL	IS_LEAP			; AL = leap counter (0-3)
	XCHG	AL, AH			; AH = leap counter
	MOV	AL, R1_LEAP			; leap counter register
	MOV	BL, 1				; use bank 1
	CALL	RP_WRITE_BANK		; write leap counter
	POPF					; restore IF
	RET
RP_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
; Routines to handle Ricoh RP5C15 realtime clock
;----------------------------------------------------------------------------;
; Tech. Info.
;
; 1) on the face of the card, at the bottom-middle, jumper 6 must be shorted
;  to enable the clock-calendar chip (a Ricoh RP5C15).
; 2) the I/O ports are mapped to addresses 0x2C0-0x2C7.
;  a) 0x2C0/2/4/6 - output only. 4-bit address of Counter/Register
;  b) 0x2C1/3/5/7 - input/output data port. Read/Write Counter/Register
;   addressed by prior output to 0x2C0/2/4/6.
; 3) the lithium Clock-Calendar backup-battery is located on the rear face of
;   the card -
; 4) I/O data programming - low-order 4 bits are significant, set high-order 4
;   bits to 0 prior to output.
; 5) Writing the Clock-Calendar:
;  a) Reset the Test Register.
;  b) Reset the Timer.
;  c) Write data to Counters or Registers.
;
; - Leap Year Counter resets every 4 years. Since it only has two digit year,
;	it cannot handle special non-leap years such as 1900, 2100, etc so 
;	will treat those as leap years. Of course, DOS does not support those
;	years so a moot point in a sense.
; - Weekday counter increments when time wraps around to midnight, and 
;	then wraps from 6 to 0 so weekday is 0-based.
;	However it seems to change sometimes when date or time is updated.
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Detect Ricoh RP5C15 on port 2C0H
;----------------------------------------------------------------------------;
; Output: ZF if RP5C15 is "found" (this is hardly a thorough check though)
;----------------------------------------------------------------------------;
; AST RESEARCH TECHNICAL BULLETIN TB-0143                   1-15-86
;
;                    TWO SIXPAKPLUS CLOCK CHIPS
;
; Recently,  the clock chip on the SixPakPlus has been changed to a 
; different vendor.   The latest version of the SixPakPlus utilizes 
; a  Ricoh  RP5C15,  as  opposed  to the earlier  versions  of  the 
; SixPakPlus  using a National Semiconductor part  number  MM58167.  
; Since  this change has taken place,  the question has been raised 
; as  to  how  the ASTCLOCK.COM program   (included  with  SuperPak 
; Version 4.3) can tell the difference between these two chips.
;
; Internal address "D" is used by ASTCLOCK to determine which  chip 
; is being used.  The address was chosen for the following reasons.  
; For the Ricoh clock chip,  this address is a "read-only" address; 
; it  ALWAYS  returns a "0" when read.   The same address  for  the 
; National Semicoductor chip is RAM  and will read back whatever is 
; written to it.
;
; So ASTCLOCK writes a "1" to address D, bit one.  If the result is 
; a "0",  the program knows a Ricoh chip is present and goes to the 
; appropriate place within the program to read this chip. 
;
; Conversely,  if a "1" is read back by ASTCLOCK,  then the program 
; knows  to use the portion of the clock dedicated to the  National 
; Semiconductor chip.
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	DI = offset of new INT 1A IVT
;	DX = port number
;	AL = RTC type (RTC_RP)
;----------------------------------------------------------------------------;
RP_DETECT PROC

;----------------------------------------------------------------------------;
; Port 2C0H is used with multiple RTCs:
;
; On Ricoh (RS), port 2C0H is write only, so reading will always return FFH
; On MM58167AN (NS), port 2C0H is ms and low nibble is always 0
; On DS12x85/MC146818 (AT), port 2C0H is ... ?
;
	MOV	DX, ADDR_PORT		; DX = register control port
	ISA_FLUSH				; clear ISA bus
	IN	AL, DX			; read register
	AND	AL, 0FH			; isolate only low nibble
	XOR	AL, 0FH			; ZF = maybe Ricoh (read 0FFH)
	JNZ	RP_DETECT_RET		; if NZ, not detected, exit

;----------------------------------------------------------------------------;
; Write 1 to register D1. Read back and if D1 is 0 Ricoh is present.
;
	MOV	AX, DBW < MASK TEN OR MASK MOZ, R0_MODE >
						; AH = Timer EN + D1, AL = 0DH (MODE register)
	CALL	RP_WRITE			; write AH to register AL
	CALL	RP_READ			; read register AL into AL
	AND	AL, MASK MOZ		; test for bit 1, ZF = detected Ricoh
	JNZ	RP_DETECT_RET		; if NZ, not detected, exit
	MOV	DX, ADDR_PORT		; DX = register control port
	MOV	DI, OFFSET INT_1A_RP	; set DI only if detected (what?)
	MOV	AL, RTC_RP
RP_DETECT_RET:	
	RET
RP_DETECT ENDP

;----------------------------------------------------------------------------;
; Reset and prepare for write
;----------------------------------------------------------------------------;
; Output: IF = 0 (Interrupts Off)
; Clobbers: BX
;----------------------------------------------------------------------------;
RP_RESET PROC
	CLI						; disable interrupts
	PUSH	AX
	MOV	AX, DBW < 0000B, R0_TEST >	; Reset the Test Register
	CALL	RP_WRITE
	MOV	AX, DBW < MASK TRS, R0_RESET >; Reset the Timer
	CALL	RP_WRITE
	MOV	AX, DBW < 0001B, R1_12_24H >	; set to 24-hour time
	MOV	BL, 1					; bank 1
	CALL	RP_WRITE_BANK			; set to 24 hour time
	POP	AX
	RET
RP_RESET ENDP

;----------------------------------------------------------------------------;
; Read two digit register from RTC to packed BCD
;----------------------------------------------------------------------------;
; Input: AL = first register index
; Output: AX = byte register value
; 	CF if invalid, NC if valid
;----------------------------------------------------------------------------;
RP_READ_BYTE PROC
	PUSH	DX				; DX clobbered by RP_READ
	MOV	AH, AL			; save index
	CALL	RP_READ
	JC	RP_READ_BYTE_RET
	XCHG	AH, AL			; AL = first index, AH = first value
	INC	AX				; AL = second index
	CALL	RP_READ			; AL = second value
	JC	RP_READ_BYTE_RET
	XCHG	AH, AL			; AH = second value, AL = first value
	CALL	PACK_BCD			; pack BCD digits in AH/AL into AL
	MOV	AH, 0
RP_READ_BYTE_RET:
	POP	DX
	RET
RP_READ_BYTE ENDP

;----------------------------------------------------------------------------;
; Read single digit register from RTC to AL
;----------------------------------------------------------------------------;
; Input: AL = register index
; Output: AL = register value
; 	CF if invalid, NC if valid
; Clobbers: DX
;----------------------------------------------------------------------------;
RP_READ PROC
	AND	AL, 0FH			; only low nibble
	MOV	DX, ADDR_PORT		; DX = register control port
	OUT	DX, AL			; select register
	IO_DELAY_SHORT
	INC	DX				; DX = data port
	ISA_FLUSH
	IN	AL, DX			; read register
	AND	AL, 0FH			; only low nibble
	CMP	AL, 10			; is valid (< 10)?
	CMC
	RET
RP_READ ENDP

;----------------------------------------------------------------------------;
; Write packed BCD in AH to register AL
;----------------------------------------------------------------------------;
; Input: 
;	AL = first register index
;	AH = BCD register value
; Clobbers: BX
;----------------------------------------------------------------------------;
RP_WRITE_BCD PROC
	MOV	BX, AX			; save starting index
	XCHG	AH, AL			; AL = register value
	UNPACK_BCD				; unpack BCD digits in AL into AH/AL
	MOV	BH, AH			; save high digit
	MOV	AH, AL			; AH = low digit
	MOV	AL, BL			; AL = starting index
	CALL	RP_WRITE
	MOV	AH, BH			; restore high digit
	INC	AX				; next register
						; fall through for second RP_WRITE call

;----------------------------------------------------------------------------;
; Write Register to RTC in current bank
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
; Output: None
;----------------------------------------------------------------------------;
RP_WRITE PROC
	PUSH	DX
	PUSH	AX
	;AND	AL, 0FH			; only low nibble
	MOV	DX, ADDR_PORT		; DX = register control port
	;OUT	DX, AX			; hacky way!
	OUT	DX, AL			; select register
	INC	DX				; DX = data port
	XCHG	AL, AH			; AL = new register value
	IO_DELAY_SHORT
	OUT	DX, AL			; write register
RP_WRITE_EXIT:
	POP	AX
	POP	DX
	RET
RP_WRITE ENDP
RP_WRITE_BCD ENDP

;----------------------------------------------------------------------------;
; Set Bank
;----------------------------------------------------------------------------;
; Input: BL = bank (0 or 1)
; Output: none
;----------------------------------------------------------------------------;
RP_SET_BANK PROC
	PUSH	DX
	PUSH	AX
	MOV	AL, R0_MODE			; mode register
	MOV	AH, AL			; save to AH
	CALL	RP_READ			; AL = register value in AL
	AND	AL, RP_MODE <,1,1,1,0>	; clear bank bit
	OR	AL, BL			; select bank from BL
	XCHG	AH, AL			; AL = mode register, AH = value
	CALL	RP_WRITE			; write to mode register
	JMP	SHORT RP_WRITE_EXIT
RP_SET_BANK ENDP

;----------------------------------------------------------------------------;
; Write Register to RTC in bank in high nibble of AL
;----------------------------------------------------------------------------;
; Input:
;	AL = register index (low) / register bank (high)
;	AH = register value (byte)
;	BL = bank 0 or 1 (unchanged after)
; Output: None
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
;RP_WRITE_BANK2 PROC
;	PUSH	AX
;	UNPACK_BCD				; AH = bank, AL = register index
;	MOV	BL, AH			; BL = bank
;	POP	AX
;RP_WRITE_BANK2 ENDP

;----------------------------------------------------------------------------;
; Write Register to RTC in bank in BL
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	AH = register value (byte)
;	BL = bank 0 or 1 (unchanged after)
; Output: None
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
RP_WRITE_BANK PROC
	PUSH	DX
	PUSH	AX
	MOV	AL, R0_MODE			; AL = mode register index
	CALL	RP_READ			; AL = current mode register
	MOV	BH, AL			; save to BH
	CALL	RP_SET_BANK			; set desired bank in BL
	POP	AX				; restore original register/value
	CALL	RP_WRITE
	XCHG	AX, BX			; AH = mode register value
	MOV	AL, R0_MODE			; AL = mode register index
	POP	DX
	JMP	SHORT RP_WRITE
RP_WRITE_BANK ENDP

OPTROM	ENDS
			ENDIF				; IFDEF RTC_RP
		END
