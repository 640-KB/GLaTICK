	PAGE	 	59,132
	TITLE		GLaTICK_RTC_AT

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for Standard AT CMOS (port 70H, 240H or 2C0H), MC146818, DS12x85
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_AT
;----------------------------------------------------------------------------;
; CMOS Clock Registers
; https://stanislavs.org/helppc/cmos_ram.html
;
AT_REG_SEC		EQU	00H			; RTC seconds
AT_REG_MIN		EQU	02H			; RTC minutes
AT_REG_HOUR		EQU	04H			; RTC hours
AT_REG_WEEKDAY	EQU	06H			; RTC day of week
AT_REG_DAY		EQU	07H			; RTC day of month
AT_REG_MONTH	EQU	08H			; RTC month
AT_REG_YEAR		EQU	09H			; RTC year
AT_REG_A		EQU	0AH			; RTC Status Register A
AT_REG_B		EQU	0BH			; RTC Status Register B
AT_REG_C		EQU	0CH			; RTC Status register C (read only)
AT_REG_D		EQU	0DH			; RTC Status register D (read only)
AT_REG_DIAG		EQU	0EH			; Diagnostic status byte
AT_REG_CENTURY	EQU	32H

;----------------------------------------------------------------------------;
; RTC Status Register A (0AH)
;----------------------------------------------------------------------------;
; Defaults:
;  0	 		- UIP:   Update in progress
;   010		- ASDIV: stage divider (010 = 32.768kHz)
;      0110		- ARSB:  Rate selection Bits (0110 = 1.024kHz)
;----------------------------------------------------------------------------;
CM_REG_A	RECORD	UIP:1, ASDIV:3=010b, ARSB:4=0110b

;----------------------------------------------------------------------------;
; RTC Status Register B (0BH)
;----------------------------------------------------------------------------;
; Defaults:
;  0	 		- SET:   1=disable clock update, 0=update normally
;   0	 		- PIE:   1=enable periodic interrupt, 0=disable
;    0 		- AIE:   1=enable alarm interrupt, 0=disable
;     0 		- UIE:   1=enable update ended interrupt, 0=disable
;      0 		- SQWE:  1=enable square wave frequency, 0=disable
;       0 		- DM:    1=time/date in binary, 0=BCD (default)
;        1 		- 24/12: 1=24 hour mode, 0=12 hour mode (24 default)
;         0		- DSE:   1=enable daylight savings, 0=disable (default)
;----------------------------------------------------------------------------;
CM_REG_B	RECORD	BSET:1,BPIE:1,BAIE:1,BUIE:1,SQWE:1,BM:1,B24:1=1,DST:1

;----------------------------------------------------------------------------;
; RTC Diagnostic status byte (0EH)
;----------------------------------------------------------------------------;
; Defaults:
;  0	 		- RPER:  1=RTC lost power, 0=power state stable
;   0	 		- CRER:  1=config record checksum is bad, 0=ok
;    0 		- CFER:  1=invalid config info found, 0=ok (see below)
;     0 		- CMER:  1=memory size doesn't match config info, 0=ok
;      0 		- CDER:  1=fixed disk 0 failed initialization, 0=ok
;       0 		- CTER:  1=time is invalid, 0=ok (POST validity check)
;        00		- CREX:  unused
;----------------------------------------------------------------------------;
CM_REG_E	RECORD	RPER:1,CRER:1,CFER:1,CMER:1,CDER:1,CTER:1,CREX:2

INCLUDE 	GLALIB.INC
INCLUDE 	MACROS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
			ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	AT_DETECT, INT_1A_AT
EXTRN		INT_1A_DEFAULT:NEAR, IRET_CF:NEAR, GET_RTC:NEAR

RTC_AT_PROC PROC

;----------------------------------------------------------------------------;
; Supported I/O ports
;----------------------------------------------------------------------------;
AT_PORTS	DW	70H, 240H, 2C0H		; standard ports
;		DW	2A0H, 340H			; less-standard ports
AT_PORTS_CT	EQU	($-AT_PORTS)/2		; number of supported ports

;----------------------------------------------------------------------------;
; INT 1A IVT for RTC_AT
;----------------------------------------------------------------------------;
INT_1A_AT PROC
	STI						; interrupts okay (for now?)
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_AT_BIOS			; if so, use default call
	CMP	AH, 5 				; is function > 5?
	JBE	INT_1A_AT_1				; if so, use default call
INT_1A_AT_BIOS:
	JMP	INT_1A_DEFAULT			; near jump to BIOS handler

;----------------------------------------------------------------------------;
; Get base port from BDA - DI for all calls
;
INT_1A_AT_1:
	PUSH	DI
	PUSH	BX					; BX = offset and scratch register
	XCHG	AX, BX				; save AX
	CALL	GET_RTC				; DI = port, ZF if no RTC installed
	STC						; presume failure
	JZ	INT_1A_AT_RET			; exit if port not installed
	;CMP	AL, RTC_AT SHL 4			; is AT type? (necessary?)
	;JNE	INT_1A_AT_RET			; exit if not (wrong ZF value)
	MOV	AX, BX				; restore AX
	XCHG	AH, AL				; AL = INT 1Ah function
	SHL	AL, 1					; word align function index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	CS:INT_1A_AT_JMP[BX][-4]	; adjust JMP offset (cannot be 0 or 1)
INT_1A_AT_RET:
	POP	BX
	POP	DI
	JMP	NEAR PTR IRET_CF			; IRET with current CF

;----------------------------------------------------------------------------;
; INT 1A RTC function jump table
;
INT_1A_AT_JMP LABEL WORD
	DW	OFFSET AT_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET AT_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET AT_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET AT_INT_1A_5		; AH = 5 - Set RTC Date
INT_1A_AT ENDP

;----------------------------------------------------------------------------;
; INT 1A - System and "Real Time" Clock BIOS Services
;----------------------------------------------------------------------------;
; INT 1A,0   Read system clock counter
; INT 1A,1   Set system clock counter
; INT 1A,2   Read real time clock time (AT,PS/2)
; INT 1A,3   Set real time clock time (AT,PS/2)
; INT 1A,4   Read real time clock date (AT,PS/2)
; INT 1A,5   Set real time clock date (AT,PS/2)
; INT 1A,6   Set real time clock alarm (AT,PS/2) ** not yet implemented
; INT 1A,7   Reset real time clock alarm (PS/2) ** not yet implemented
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; INT 1A,2	Read Time From Real Time Clock 
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
AT_INT_1A_2 PROC
	XCHG	AX, BX				; preserve AX
	CALL	AT_WAIT_FOR_UIP			; wait for no update
	STC						; presume failure
	JNZ	AT_INT_1A_2_RET			; exit if timeout
	CLI
	MOV	AL, AT_REG_SEC			; RTC seconds
	CALL	AT_READ
	JC	AT_INT_1A_READ_ERR
	MOV	AH, AL				; save to AH
	MOV	AL, AT_REG_MIN			; RTC minutes
	CALL	AT_READ
	JC	AT_INT_1A_READ_ERR
	MOV	CL, AL				; CL = minutes
	MOV	AL, AT_REG_HOUR			; RTC hours
	CALL	AT_READ
	JC	AT_INT_1A_READ_ERR
	MOV	CH, AL				; CH = hours
	MOV	AL, AT_REG_B			; Status Reg B
	CALL	AT_READ
	JC	AT_INT_1A_READ_ERR
	AND	AL, MASK DST			; isolate DST bit and CLC
	XCHG	AX, DX				; DH = seconds, DL = DST
AT_INT_1A_2_RET:
	XCHG	AX, BX				; restore AX
	RET

AT_INT_1A_READ_ERR:
	XOR	DX, DX				; clear any incomplete reads
	MOV	CX, DX				; CX = DX = 0000
	STC						; CF = read error
	JMP	SHORT AT_INT_1A_2_RET

AT_INT_1A_2 ENDP

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
AT_INT_1A_3 PROC
	XCHG	AX, BX				; preserve AX
	CALL	AT_WAIT_FOR_UIP			; wait for no update
	STC						; presume failure
	JNZ	AT_INT_1A_2_RET			; exit if timeout
	CLI
	CALL	AT_HOLD				; clear all flags
	MOV	AL, AT_REG_SEC			; RTC seconds
	MOV	AH, DH				; AH = new seconds
	CALL	AT_WRITE
	MOV	AL, AT_REG_MIN			; RTC minutes
	MOV	AH, CL				; AH = new minutes
	CALL	AT_WRITE
	MOV	AL, AT_REG_HOUR			; RTC hours
	MOV	AH, CH				; AH = new hours
	CALL	AT_WRITE
	MOV	AL, AT_REG_B			; Register B
	CALL	AT_READ
	AND	AX, MASK BPIE OR MASK BAIE OR MASK B24
	OR	AL, MASK B24			; set 24 hour mode
	SHR	DL, 1					; CF = DST
	ADC	AH, AL
	MOV	AL, AT_REG_B			; Register B
	CALL	AT_WRITE
	XCHG	AX, BX				; restore AX
	RET
AT_INT_1A_3 ENDP

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
AT_INT_1A_4 PROC
	XCHG	AX, BX				; preserve AX
	CALL	AT_WAIT_FOR_UIP			; wait for no update
	STC						; presume failure
	JNZ	AT_INT_1A_4_RET			; exit if timeout
	CLI
	MOV	AL, AT_REG_MONTH			; RTC month
	CALL	AT_READ
	JC	AT_INT_1A_4_READ_ERR
	MOV	AH, AL				; save to DH
	MOV	AL, AT_REG_DAY			; RTC day
	CALL	AT_READ
	JC	AT_INT_1A_4_READ_ERR
	XCHG	AX, DX				; save to DL
	MOV	AL, AT_REG_CENTURY		; RTC century
	CALL	AT_READ				; AL = century
	JC	AT_INT_1A_4_READ_ERR
	MOV	AH, AL				; save to AH
	MOV	AL, AT_REG_YEAR			; RTC year
	CALL	AT_READ				; AL = year
	CMP	AL, 99H + 1				; is valid BCD year?
	CMC						; CF if > 99H
	JC	AT_INT_1A_4_READ_ERR
	XCHG	AX, CX				; save to CH/CL
AT_INT_1A_4_RET:
	XCHG	AX, BX				; restore AX
	RET

AT_INT_1A_4_READ_ERR:
	MOV	CX, 1980H				; clear any incomplete reads
	MOV	DX, 0101H				; default to beginning of time
	JMP	SHORT AT_INT_1A_4_RET

AT_INT_1A_4 ENDP

;----------------------------------------------------------------------------;
; INT 1A,5 - Set Real Time Clock Date
;----------------------------------------------------------------------------;
; Input:
;	AH = 5
;	CH = century in BCD (decimal 19 or 20)
;	CL = year in BCD
;	DH = month in BCD
;	DL = day in BCD
;----------------------------------------------------------------------------;
AT_INT_1A_5 PROC
	XCHG	AX, BX				; preserve AX
	CALL	AT_WAIT_FOR_UIP			; wait for no update
	STC						; presume failure
	JNZ	AT_INT_1A_4_RET			; exit if timeout
	CLI
	CALL	AT_HOLD				; hold clock and clear flags
	MOV	AL, AT_REG_DAY			; RTC day (7)
	MOV	AH, DL				; AH = new day
	CALL	AT_WRITE
	INC	AX					; RTC month (8)
	MOV	AH, DH				; AH = new month
	CALL	AT_WRITE
	INC	AX					; RTC year (9)
	MOV	AH, CL				; AH = new year
	CALL	AT_WRITE
	MOV	AL, AT_REG_CENTURY		; RTC century
	MOV	AH, CH				; AH = new century
	CALL	AT_WRITE
	MOV	AL, AT_REG_B			; Get Register B
	CALL	AT_READ
	AND	AL, NOT MASK BSET			; clear SET bit
	MOV	AH, AL
	MOV	AL, AT_REG_B			; Register B
	CALL	AT_WRITE
	XCHG	AX, BX				; restore AX
	RET
AT_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
; Hold clock and clear flags
;----------------------------------------------------------------------------;
AT_HOLD PROC
	MOV	AX, DBW < CM_REG_A <>,  AT_REG_A >	; AH = defaults, AL = Reg A
	CALL	AT_WRITE				; write AH to register AL
	MOV	AX, DBW < CM_REG_B <1>, AT_REG_B >	; AH = disable clock, AL = Reg B
	CALL	AT_WRITE				; write AH to register AL
	INC	AX					; Register C
	CALL	AT_READ				; read to clear flags
	MOV	AL, AT_REG_D			; Register D
	CALL	AT_READ				; read to clear flags
	RET
AT_HOLD ENDP

;----------------------------------------------------------------------------;
; DS RTC Read Register
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	DI = base I/O port
; Output:
;	AL = register value
;	CF if data read is not valid BCD
;----------------------------------------------------------------------------;
AT_READ PROC
	PUSH	DX
	MOV	DX, DI				; DX = address reg
	OUT	DX, AL
	IO_DELAY_SHORT				; I/O settling delay
	IO_DELAY_SHORT
	INC	DX					; data reg
	IN	AL, DX
	CMP	AL, 59H + 1				; is valid BCD?
	CMC						; CF if > 59
	POP	DX
	RET
AT_READ ENDP
  
;----------------------------------------------------------------------------;
; DS RTC Write Register
;----------------------------------------------------------------------------;
; Input:
;	AL = register index
;	AH = register value
;	DI = base I/O port
;----------------------------------------------------------------------------;  
AT_WRITE PROC
	PUSH	DX
	MOV	DX, DI				; DX = address reg
	OUT	DX, AL
	XCHG	AL, AH				; AL = new value
	IO_DELAY_SHORT				; I/O settling delay
	IO_DELAY_SHORT
	INC	DX					; data reg
	OUT	DX, AL
	XCHG	AL, AH				; restore AX
	POP	DX
	RET
AT_WRITE ENDP

;----------------------------------------------------------------------------;
; DS Wait for Update In Progress (UIP)
;----------------------------------------------------------------------------;
; Return:
;	ZF = 1 if success, NZ if timeout/error
;
; Clobbers: AX
;----------------------------------------------------------------------------;
AT_WAIT_FOR_UIP PROC
	PUSHF						; save IF
	PUSH	CX
	MOV	CX, 1000				; timeout ~ 250us ?
AT_UIP_LOOP:
	STI
	MOV	AL, AT_REG_A			; RTC Status Register A
	CLI
	CALL	AT_READ
	TEST	AL, MASK UIP			; check UIP bit
	LOOPNZ AT_UIP_LOOP			; loop until no UIP or timeout
	JMP	SHORT AT_DETECT_EXIT		; restore CX, IF and RET
AT_WAIT_FOR_UIP ENDP

;----------------------------------------------------------------------------;
; Detect AT RTC
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	DI = offset of new INT 1A IVT
;	DX = port for RTC
;	AL = RTC type (RTC_AT)
;
; Clobbers: AH, SI
;
; TODO: an additional detection check
;----------------------------------------------------------------------------;
AT_DETECT PROC
	PUSHF						; save IF, DF
	PUSH	CX
	MOV	CX, AT_PORTS_CT			; number of ports to check
	MOV	SI, OFFSET AT_PORTS		; I/O ports to check
	CLD						; string direction forward
	CLI						; interrupts off
AT_DETECT_LOOP:
	LODS	WORD PTR CS:[SI]			; AX = next port to check
	CWD						; DX = 0
	XCHG	AX, DI				; DI = next port
	CALL	AT_WAIT_FOR_UIP			; wait for no update
	JNZ	AT_DETECT_NEXT			; exit if UIP flag never clear
	MOV	AX, DBW < CM_REG_A <>, AT_REG_A > ; AH = defaults, AL = Register A
	CALL	AT_WRITE				; write AH to register AL
	CALL	AT_READ				; AL = read back value
	CMP	AL, CM_REG_A <>			; ZF if same (success), NZ if not
	MOV	AX, DX				; AX = 0
AT_DETECT_NEXT:
	LOOPNZ AT_DETECT_LOOP
	JNZ	AT_DETECT_EXIT			; do not set if no result
	MOV	AL, RTC_AT				; RTC type
	MOV	DX, DI				; DX = detected port
	MOV	DI, OFFSET INT_1A_AT		; DI = ISR for RTC AT INT 1A
AT_DETECT_EXIT:
	POP	CX
	LAHF						; save status flags
	POPF						; restore IF
	SAHF						; restore status flags
	RET
AT_DETECT ENDP

RTC_AT_PROC ENDP

OPTROM	ENDS
			ENDIF			; IFDEF RTC_AT
		END
