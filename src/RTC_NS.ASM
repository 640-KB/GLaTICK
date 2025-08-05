	PAGE	 	59,132
	TITLE		GLaTICK_RTC_NS

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for NS MM58167AN: SixPakPlus V1, Clone I/O boards
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_NS
;----------------------------------------------------------------------------;
; MM58167 Equates (do not edit)
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Hardware variants
;
RTC_NS_STD		EQU	1			; standard
RTC_NS_TEC		EQU	2			; Tecmar Captain (data reg is +2)

;----------------------------------------------------------------------------;
; Software compatibility
;
RTC_DRV_STD		EQU	1			; standard (ASTCLOCK, CLOCK.COM)
RTC_DRV_OLD		EQU	2			; previous (<= 0.8.3) behavior
RTC_DRV_86B		EQU	3			; 86Box (AST, 5PAK or EV-170)
RTC_DRV_86B2	EQU	4			; 86Box (PII-147)

;----------------------------------------------------------------------------;
; MM58167 Register Indexes
;
NS_MS			EQU	00H			; milliseconds
NS_TSEC		EQU	01H			; hundredths/tenths of seconds
NS_SEC		EQU	02H			; seconds
NS_MIN		EQU	03H			; minutes
NS_HOUR		EQU	04H			; hour
NS_DOW		EQU	05H			; day of week
NS_DAY		EQU	06H			; day of month
NS_MONTH		EQU	07H			; month
NS_RAM		EQU	08H			; address offset for RAM registers
NS_RAM1		EQU	NS_RAM + NS_MS 	; 08H - RAM1 ms high nibble only, low = 0
NS_RAM2		EQU	NS_RAM + NS_TSEC	; 09H - RAM2 last month (Year DTK Hexa)
NS_RAM3		EQU	NS_RAM + NS_SEC	; 0AH - RAM3 year (AST)
NS_RAM4		EQU	NS_RAM + NS_MIN	; 0BH - RAM4 clock valid
NS_RAM5		EQU	NS_RAM + NS_HOUR	; 0CH - RAM5 not used
NS_RAM6		EQU	NS_RAM + NS_DOW	; 0DH - RAM6 week low nibble only, high = 0
NS_RAM7		EQU	NS_RAM + NS_DAY	; 0EH - RAM7 not used (Year 86Box)
NS_RAM8		EQU	NS_RAM + NS_MONTH	; 0FH - RAM8 not used
NS_TIME_RST		EQU	12H			; counter reset
NS_RAM_RST		EQU	13H			; RAM reset
NS_STATUS		EQU	14H			; rollover status bit

NS_RST		EQU	0FFH			; send all -1 to reset TIME and RAM
NS_STATE_OK		EQU	222			; Clock valid flag for NS_RAM4 (0BH)
NS_TEST		EQU	0AAH			; test value used for detection

;----------------------------------------------------------------------------;
; Standard RAM register addresses
;
NS_MONTH2		=	NS_RAM2		; 09H RAM - last month storage
NS_YEAR		=	NS_RAM3		; 0AH RAM - year storage
NS_STATE		=	NS_RAM4		; 0BH clock valid flag (222 = valid)


;----------------------------------------------------------------------------;
; Config Defaults
;----------------------------------------------------------------------------;
READ_RETRY		=	10		; times to retry for rollover bit on reads
SHOW_CLOCK		=	1		; enable display of clock on boot
RST_STATE		=	1		; reset clock if no valid state flag
Y2K_OFFSET		=	1		; store as year-80 (00=1980, 20=2000, etc)
YEAR_BCD		=	0		; 1=store year as BCD, 0=byte
YEAR_INCR		=	1		; increment year (normal)

;----------------------------------------------------------------------------;
; Hardware type: Uncomment to select
;
RTC_NS_TYPE		=	RTC_NS_STD		; set for standard
;RTC_NS_TYPE	=	RTC_NS_TEC		; set for Tecmar

;----------------------------------------------------------------------------;
; Driver Software compatibility: Uncomment to select
;
RTC_DRV_TYPE	=	RTC_DRV_STD		; set for standard (year as byte)
;RTC_DRV_TYPE	=	RTC_DRV_OLD		; set for <= 0.8.3 behavior
;RTC_DRV_TYPE	=	RTC_DRV_86B		; set for 86Box (AST, 5PAK or EV-170)
;RTC_DRV_TYPE	=	RTC_DRV_86B2	; set for 86Box (PII-147)

;----------------------------------------------------------------------------;
; Reconfigure for specific hardware/software
;----------------------------------------------------------------------------;

		IF RTC_DRV_TYPE EQ RTC_DRV_OLD
;----------------------------------------------------------------------------;
; GLaTICK <= 0.8.3 behavior
;
YEAR_BCD		=	1			; store year as BCD
		ENDIF

		IF RTC_DRV_TYPE EQ RTC_DRV_86B
;----------------------------------------------------------------------------;
; 86Box (AST, 5PAK or EV-170)
;
NS_YEAR		=	NS_RAM7		; use 0EH for year storage (-80)
YEAR_BCD		=	0			; store year as byte
RST_STATE		=	0			; reset clock if no valid state flag
YEAR_INCR		=	0			; year increment is handled by 86Box
		ENDIF

		IF RTC_DRV_TYPE EQ RTC_DRV_86B2
;----------------------------------------------------------------------------;
; 86Box (PII-147)
;
NS_YEAR		=	NS_RAM2		; use 09H for year storage
NS_MONTH2		=	NS_RAM7		; use 0EH for last month
RST_STATE		=	0			; reset clock if no valid state flag
Y2K_OFFSET		=	0			; store as (80=1980, 00=2000, etc)
YEAR_BCD		=	1			; store year as BCD
YEAR_INCR		=	0			; year increment is handled by 86Box
		ENDIF

INCLUDE	GLALIB.INC
INCLUDE	MACROS.INC
INCLUDE	SEGS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
PUBLIC	NS_DETECT, STR_NS
EXTRN		INT_1A_DEFAULT:NEAR, PACK_BCD:NEAR, IRET_CF:NEAR, IRET_CF_1:NEAR
EXTRN		GET_RTC:NEAR, BCD_TO_BYTE:NEAR, BYTE_TO_BCD:NEAR

RTC_NS_PROC PROC

;----------------------------------------------------------------------------;
; NS Display string
;----------------------------------------------------------------------------;
STR_NS	DB	'58167 ', 0			; NS = MM58167AN

;----------------------------------------------------------------------------;
; Supported I/O ports
;----------------------------------------------------------------------------;
NS_PORTS	DW	2C0H			; common ports
			IF	RTC_NS_TYPE	EQ RTC_NS_TEC
		DW	37DH, 27DH		; Tecmar Captain
			ELSE
		DW	240H, 340H
;		DW	250H, 300H
;		DW	350H, 377H
			ENDIF
NS_PORTS_CT	EQU	($-NS_PORTS)/2	; number of supported ports

;----------------------------------------------------------------------------;
; INT 1A IVT for NS MM58167AN
;----------------------------------------------------------------------------;
INT_1A_NS PROC
	STI						; interrupts okay for now
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_NS_BIOS			; if so, use default call
	CMP	AH, 5 				; is function > 5?
	JBE	INT_1A_NS_1				; if so, use default call
INT_1A_NS_BIOS:
	JMP	INT_1A_DEFAULT			; near jump to BIOS handler
INT_1A_NS_1:
	PUSH	BP					; flag for 2 (1) or 16 (0) port mode
	PUSH	AX
	PUSH	BX					; used as scratch register
	PUSH	DI
	XOR	BP, BP				; flag: 0 = 16, 1 = 2
	XCHG	AX, BX				; save AX
	CALL	GET_RTC				; DI = port, AL = type, ZF if no RTC installed
	STC						; presume failure
	JZ	INT_1A_NS_RET			; exit if port not installed
	CMP	AL, RTC_NS SHL 4			; is NS 2 or 16 port?
	JB	INT_1A_NS_RET			; CF if NS not installed
	JE	INT_1A_NS_2				; jump if 16 port
	INC	BP					; set 2 port flag (BP)
INT_1A_NS_2:
	MOV	AX, BX				; restore AX
	XCHG	AH, AL				; AL = function
	SHL	AL, 1					; word align index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	CS:INT_1A_NS_JMP[BX][-4]	; already checked for 0 or 1, so adjust offset
							; to start at 2
INT_1A_NS_RET:
	POP	DI
	POP	BX
	POP	AX
	JMP	NEAR PTR IRET_CF_1		; IRET with current CF (BP on stack)

;----------------------------------------------------------------------------;
; NS MM58167AN Jump Table
;----------------------------------------------------------------------------;
INT_1A_NS_JMP LABEL WORD
	DW	OFFSET NS_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET NS_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET NS_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET NS_INT_1A_5		; AH = 5 - Set RTC Date

INT_1A_NS ENDP

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
NS_INT_1A_2 PROC
	CWD					; DST flag (DL) always 0
	CALL	NS_CHECK_STATE		; check if clock in valid state
	PUSH	SI
	MOV	SI, READ_RETRY		; retry counter
NS_INT_1A_2_LOOP:
	CLI					; disable interrupts while reading
	MOV	AL, NS_SEC			; read 1 and 10-second counter
	CALL	NS_READ
	JC	NS_INT_1A_READ_ERR
	MOV	DH, AL			; save to DH
	MOV	AL, NS_MIN			; read 1 and 10-minute counter
	CALL	NS_READ
	JC	NS_INT_1A_READ_ERR
	MOV	CL, AL			; save to CL
	MOV	AL, NS_HOUR			; read 1 and 10-hour counter
	CALL	NS_READ
	JC	NS_INT_1A_READ_ERR	; exit if read error
	MOV	CH, AL			; save to CH

;----------------------------------------------------------------------------;
; Check for rollover bit meaning a read occurred during a rollover period
; and may not be accurate.  If so, retry up to 10 times.
;
	CALL	NS_CHECK_ROLLOVER		; rollover bit set?
	JZ	NS_INT_1A_2_RET		; jump and return if read okay
NS_INT_1A_2_RETRY:			; read failed, retry
	STI					; allow any pending interrupts
	DEC	SI				; decrement counter
	JNZ	NS_INT_1A_2_LOOP		; retry up to 10 times

;----------------------------------------------------------------------------;
; Rollover bit was not cleared after 10 retries. Return 0000 with CF.
;
NS_INT_1A_READ_ERR:
	XOR	DX, DX			; clear any incomplete reads
	MOV	CX, DX			; CX = DX = 0000
	STC					; CF = read error
NS_INT_1A_2_RET:
	POP	SI
	RET
NS_INT_1A_2 ENDP

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
NS_INT_1A_3 PROC
	CLI					; disable interrupts
	MOV	AL, NS_HOUR
	MOV	AH, CH			; Hours
	CALL	NS_WRITE			; AL = register, AH = value
	MOV	AL, NS_MIN
	MOV	AH, CL			; minutes
	CALL	NS_WRITE
	MOV	AL, NS_SEC
	MOV	AH, DH			; seconds
	CALL	NS_WRITE
	RET
NS_INT_1A_3 ENDP

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
NS_INT_1A_4 PROC
	CALL	NS_CHECK_STATE		; check if clock in valid state
	PUSH	SI
	MOV	SI, READ_RETRY		; retry counter
NS_INT_1A_4_LOOP:
	CLI					; disable interrupts for read
	MOV	AL, NS_DAY			; read 1 and 10-day counter
	CALL	NS_READ
	JC	NS_INT_1A_READ_ERR
	MOV	DL, AL			; save to DL
	MOV	AL, NS_MONTH		; read 1 and 10-month counter
	CALL	NS_READ
	JC	NS_INT_1A_READ_ERR
	MOV	DH, AL			; save to DH
	MOV	AL, NS_YEAR			; read 1 and 10-year counter
	CALL	NS_READ			; AL = year (ignore CF)
			IF YEAR_BCD	EQ 0
	CALL	BYTE_TO_BCD			; AL = BCD year
			ENDIF
	CMP	AL, 99H + 1			; is valid year BCD?
	CMC					; CF if > 99
	JC	NS_INT_1A_READ_ERR
			IF Y2K_OFFSET EQ 1
	SUB	AL, 20H			; year was stored +20, adjust to real year
	DAS					; AL = adjusted BCD year
			ENDIF
	MOV	CL, AL			; save real year to CL
	CALL	NS_CHECK_ROLLOVER		; did a read rollover error occur?
	JNZ	NS_INT_1A_4_RETRY		; if so, restart read

;----------------------------------------------------------------------------;
; Check for Year rollover and update RTC as necessary:
; - If current month != NS_MONTH2:
;	if current month < NS_MONTH2 and NS_MONTH2 <= 12 (over 12 is invalid):
;		increment year, save to NS_YEAR
;	NS_MONTH2 = current month
;----------------------------------------------------------------------------;
	MOV	AL, NS_MONTH2		; AL = saved month register
	CALL	NS_READ			; get last/saved month
	CMP	AL, 12H			; saved month = 12?
	JA	NS_UPD_MONTH		; if saved month > 12, is invalid
	CMP	AL, DH			; saved month same as current month?
	JE	NS_NO_YEAR_ROLLOVER	; if so, do nothing
	JB	NS_UPD_MONTH		; jump if only month has changed

		IF YEAR_INCR EQ 1
;----------------------------------------------------------------------------;
; Year has rolled into next: current month < NS_MONTH2
;
	XCHG	AX, CX			; move year to AL for DAA
	INC	AX				; increment year
	DAA					; fix BCD
	XCHG	AX, CX			; CL = incremented BCD year
	CALL	NS_INT_1A_5			; update date on RTC
		ENDIF

;----------------------------------------------------------------------------;
; Month has changed: update saved month NS_MONTH2
;
NS_UPD_MONTH:
	MOV	AH, DH			; AH = current month
	MOV	AL, NS_MONTH2		; AL = saved month register
	CALL	NS_WRITE			; update the RTC's saved month

NS_NO_YEAR_ROLLOVER:

;----------------------------------------------------------------------------;
; Get century: if less than 80 assumed Y2K
;
	CMP	CL, 80H			; is year above 80?
	MOV	AL, 20H			; assume Y2K
	JB	NS_GET_CEN_DONE		; jump if not
	DEC	AX				; otherwse it's 19
	DAS					; AL = adjusted BCD century
NS_GET_CEN_DONE:
	MOV	CH, AL			; century to CH
	CLC
NS_INT_1A_4_RET:
	POP	SI
	RET

;----------------------------------------------------------------------------;
; Rollover bit was set, retry operation 10 times
;
NS_INT_1A_4_RETRY:			; read failed, retry
	STI					; allow any pending interrupts
	DEC	SI				; decrement retry counter
	JNZ	NS_INT_1A_4_LOOP		; loop up to READ_RETRY times
	JMP	SHORT NS_INT_1A_READ_ERR	; rollover bit not cleared
NS_INT_1A_4 ENDP

;----------------------------------------------------------------------------;
; Check if rollover status bit was set
;----------------------------------------------------------------------------;
; Output:  ZF if not set (read okay), NZ if set (error in a previous read)
; Clobbers: AX
;----------------------------------------------------------------------------;
NS_CHECK_ROLLOVER PROC
	PUSH	DX				; save DX
	MOV	AL, NS_STATUS		; status bit index
	CALL	NS_GET_PORT			; DX = data port
	IN	AL, DX
	TEST	AL, AL			; rollover bit set?
	POP	DX				; restore DX
	RET
NS_CHECK_ROLLOVER ENDP

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
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
NS_INT_1A_5 PROC
			IF SET_DOW EQ 1
			EXTRN	DOW:NEAR
	CALL	DOW				; AL = zero-based day of week
	INC	AX				; adjust for one-based day
	MOV	AH, AL
	MOV	AL, NS_DOW			; day of week
	CALL	NS_WRITE			; write dow: AL = register, AH = value
			ENDIF
	MOV	AX, CX			; AL = year in BCD
			IF Y2K_OFFSET EQ 1
	ADD	AL, 20H			; store years + 20
	DAA					; BCD adjust
			ENDIF
			IF YEAR_BCD	EQ 0
	CALL	BCD_TO_BYTE			; AL = byte year
			ENDIF
	MOV	AH, AL			; AH = year
	MOV	AL, NS_YEAR			; year
	CLI
	CALL	NS_WRITE			; write year: AL = register, AH = value
	MOV	AL, NS_MONTH		; month
	MOV	AH, DH
	CALL	NS_WRITE			; write month: AL = register, AH = value
	MOV	AL, NS_MONTH2		; previous month
	MOV	AH, DH
	CALL	NS_WRITE			; write month: AL = register, AH = value
	MOV	AL, NS_DAY			; day
	MOV	AH, DL
	CALL	NS_WRITE			; AL = register, AH = value
	RET
NS_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
;
; MM58167 I/O Routines
;
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Get register port for either 2 or 16 port mode
;----------------------------------------------------------------------------;
; Input: AL = register index, BP = 2/16 flag, DI = base port
; Output: DX = data port
; Clobbers: BX (on 16 port mode)
;----------------------------------------------------------------------------;
NS_GET_PORT PROC
	TEST	BP, BP			; is 2 or 16 port mode?
	JNZ	NS_SET_2			; if 1, is 2 port mode

;----------------------------------------------------------------------------;
; Set address port in DX for 16 port direct mode
;
	MOV	BX, AX			; BL = register index
	AND	BX, 1FH			; only valid ports, clear high word
	LEA	DX, [BX][DI]		; DX data port
	RET

;----------------------------------------------------------------------------;
; Set address port for 2 port mode
;
NS_SET_2:
	MOV	DX, DI			; DX = base port
	OUT	DX, AL			; set register index
			IF RTC_NS_TYPE EQ RTC_NS_TEC
	CMP	DX, 02C0H			; if port 2C0, data port is 2C1
	JE	NS_TEC_DONE
	INC	DX				; DX = data port = index port + 2
NS_TEC_DONE:
			ENDIF
	INC	DX				; DX = data port
	RET
NS_GET_PORT ENDP

;----------------------------------------------------------------------------;
; Read register from MM58167AN RTC
;----------------------------------------------------------------------------;
; Input: AL = register index, BP = 2/16 flag, DI = base port
; Output: AL = byte register value
; 	CF if invalid (value > 59H), NC if valid
; Clobbers: BX
;----------------------------------------------------------------------------;
NS_READ PROC
	PUSH	DX
	CALL	NS_GET_PORT			; DX = data port for register AL
	IN	AL, DX			; AL = register value
	CMP	AL, 59H + 1			; is valid BCD?
	CMC					; CF if > 59
	POP	DX
NS_READ_RET:
	RET
NS_READ ENDP

;----------------------------------------------------------------------------;
; Check that clock is in valid state and reset clock if not
;----------------------------------------------------------------------------;
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
NS_CHECK_STATE PROC
	MOV	AL, NS_STATE		; state register
	CALL	NS_READ			; AL = state register value
	CMP	AL, NS_STATE_OK		; is OK?
	JE	NS_RET			; exit if so
						; otherwise fall through to reset
NS_CHECK_STATE ENDP

;----------------------------------------------------------------------------;
; Reset all counters (time) and alarms
;----------------------------------------------------------------------------;
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
NS_RESET PROC
			IF RST_STATE EQ 1
	MOV	AX, DBW <NS_RST, NS_TIME_RST>	; counter reset register
	CALL	NS_WRITE				; write all 1's to reset
	MOV	AL, NS_RAM_RST			; RAM reset register
	CALL	NS_WRITE
			ENDIF
	MOV	AX, DBW <NS_STATE_OK, NS_STATE>	; set state register to OK
							; fall through to write
NS_RESET ENDP

;----------------------------------------------------------------------------;
; Write to Register
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
; Clobbers: AL, BX
;----------------------------------------------------------------------------;
NS_WRITE PROC
	PUSH	DX
	CALL	NS_GET_PORT			; DX = data port in AL
	MOV	AL, AH			; AL = register value
	OUT	DX, AL
	POP	DX
NS_RET:
	RET
NS_WRITE ENDP

;----------------------------------------------------------------------------;
; Detect MM58167 RTC
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	AL = card type and CF = 0 on success
;	AH = 0
;	DX = base address (2C0, 240, 340, etc), 0 if not detected
;	DI = IVT offset, 0 if not detected
;
; Clobbers: AX, SI
;----------------------------------------------------------------------------;
; Port 2C0H is used with multiple RTCs:
;
; On MM58167AN (NS), port 2C0H is ms and low nibble is always 0
; On Ricoh (RS), port 2C0H is write only, so reading will always return FFH
; On DS12x85/MC146818 (AT), port 2C0H is ... ?
;----------------------------------------------------------------------------;
NS_DETECT PROC
	PUSH	BP
	PUSH	CX
	MOV	SI, OFFSET NS_PORTS	; supported ports
	MOV	CX, NS_PORTS_CT		; number of supported ports

NS_DETECT_LOOP:
	MOV	DI, WORD PTR CS:[SI]	; DI = next port to try

;----------------------------------------------------------------------------;
; Check 16 port mode - ZF if found
;
	XOR	BP, BP			; BP = 0 (16 port mode)
	CALL	NS_DETECT_PORT		; check for NS at DI and BP (16 mode)
	MOV	AL, RTC_NS			; default to 16 port direct
	JNC	NS_DETECT_FOUND		; NS found

;----------------------------------------------------------------------------;
; Check 2 port mode - ZF if found
;
	INC	BP				; BP = 1 (2 port mode)
	CALL	NS_DETECT_PORT		; check for NS at DI and BP (2 mode)
	LODSW					; next port (clobbers AX)
	MOV	AL, RTC_NS2			; 2 port latched
	JNC	NS_DETECT_FOUND		; NS found

	LOOP	NS_DETECT_LOOP		; try next port

;----------------------------------------------------------------------------;
; NS NOT detected
;
	CBW					; AH = 0
	CWD					; DX = 0
	MOV	DI, DX			; DI = 0
	CMP	AL, 0				; ZF = 0 (not found), CF = 0

NS_DETECT_EXIT:
	POP	CX
	POP	BP
	RET

;----------------------------------------------------------------------------;
; NS detected
;
NS_DETECT_FOUND:
	MOV	DX, DI			; DX = detected port
	MOV	DI, OFFSET INT_1A_NS	; return INT 1Ah IVT
	XOR	AH, AH			; ZF = 1 (found), CF = 0
	JMP	SHORT NS_DETECT_EXIT

NS_DETECT ENDP

;----------------------------------------------------------------------------;
; Detect if NS is present
;----------------------------------------------------------------------------;
; Input: BP = 2/16 flag, DI = base port
;
; Output: CF if not found
;
; Clobbers: AX, DX
;----------------------------------------------------------------------------;
; Detection:
;
; 1. Read register 0 - if 0, maybe NS or AT (not RP)
; 2. Read register 0Dh and save, write AAh, read back, finally restore
;	- if 80h or 0 then is an AT or Ricoh
;	- if 0FAh or 0AHh, then likely NS
;	- if 0AAh, then unknown card
;----------------------------------------------------------------------------;
NS_DETECT_PORT PROC
	PUSHF					; save IF (TODO: necessary?)
	CLI					; disable interrupts

;----------------------------------------------------------------------------;
; Test register 00h
;
	MOV	AL, NS_MS			; NS register 0 low nibble is always 0
	CALL	NS_READ
	AND	AL, 0FH			; ZF if 0, maybe NS
	JNZ	NS_DETECT_PORT_ND		; not 0, so isn't NS

;----------------------------------------------------------------------------;
; Test register 0Dh
;
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_READ			; read original value
	XCHG	AX, DX			; save to DL
	MOV	AX, DBW < NS_TEST, NS_RAM6 > ; AH = test value, AL = register 0DH
	CALL	NS_WRITE			; write test value 
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_READ			; AL = re-read value
	XCHG	AX, DX			; AL = original value, DL = test read	

;----------------------------------------------------------------------------;
; Restore previous value
;
	MOV	AH, AL			; AH = original value
	MOV	AL, NS_RAM6			; register 0DH
	CALL	NS_WRITE			; write back
	XCHG	AX, DX			; AL = test read
	TEST	AL, 0FH			; is low nibble 0?
	JZ	NS_DETECT_PORT_ND		; if so, not detected
			IF RTC_DRV_TYPE EQ RTC_DRV_86B OR RTC_DRV_TYPE EQ RTC_DRV_86B2
	CMP	AL, NS_TEST			; if 0AAh, then likely NS (workaround 86Box bug)
			ELSE
	CMP	AL, NS_TEST AND 0FH	; if 0Ah, then likely NS
			ENDIF
	JNZ	NS_DETECT_PORT_ND		; jump if not

;----------------------------------------------------------------------------;
; NS detected
;
	POPF					; restore IF
	CLC					; CF = 0 (found)
	RET

;----------------------------------------------------------------------------;
; NS NOT detected
;
NS_DETECT_PORT_ND:
	POPF					; restore IF
	STC					; CF = 1 (not found)
	RET

NS_DETECT_PORT ENDP

RTC_NS_PROC ENDP

OPTROM	ENDS
			ENDIF			; IFDEF RTC_NS
		END
