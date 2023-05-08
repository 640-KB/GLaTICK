	PAGE	 	59,132
	TITLE		GLaTICK_RTC_OK

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for OK MSM5832 including Quadram
;----------------------------------------------------------------------------;
; TODO:
; - handle invalid clock state/reset
;----------------------------------------------------------------------------;
INCLUDE 	RTC.INC

			IFDEF RTC_OK
;----------------------------------------------------------------------------;
; Config
;----------------------------------------------------------------------------;
Y2K_OFFSET		=	0		; Store year as YY+20 (not recommended)
OK_MODE_24		=	1		; 1 = use 24 hour, 0 = 12 hour mode

;----------------------------------------------------------------------------;
; PPI I/O Ports
;
OK_BASE_ADDR_1	EQU	313H		; base address option 1
OK_BASE_ADDR_2	EQU	213H		; base address option 2

;----------------------------------------------------------------------------;
; PPI Ports Addresses
;
PORT_A		EQU	0		; PPI Port A
PORT_B		EQU	1		; PPI Port B
PORT_C		EQU	2		; PPI Port C
PORT_CW		EQU	3		; PPI Control Port

;----------------------------------------------------------------------------;
; 8255 PPI Control Word Modes (set on PORT CW)
;
PPI_CTRL_OUT	EQU	080H		; Clock WRITE: Port A, B, C as OUT
PPI_CTRL_IN		EQU	090H		; Clock READ: Port A as IN; B, C as OUT

;----------------------------------------------------------------------------;
; MS5832 Clock Address Inputs (set on PORT B)
;
OK_REG_S1		EQU	0000B		; 0 : S1 - 1's column of seconds (0-9) 
						;	(reset to 0 during WRITE)
OK_REG_S10		EQU	0001B		; 1 : S10 - 10's column of seconds (0-5)
OK_REG_MI1		EQU	0010B		; 2 : MI1 - 1's minutes (0-9)
OK_REG_MI10		EQU	0011B		; 3 : M10 - 10's minutes (0-5)
OK_REG_H1		EQU	0100B		; 4 : H1 - 1's hours (0-9)
OK_REG_H10		EQU	0101B		; 5 : H10 - 10's hours (0-1/0-2)
OK_REG_AP24		EQU	OK_REG_H10	;	D2 - AM/PM (0/1), 
						;	D3 - 12/24 (0/1) hour format 
OK_REG_W		EQU	0110B		; 6 : W - weekday (0-6)
OK_REG_D1		EQU	0111B		; 7 : D1 - date 1's (0-9)
OK_REG_D10		EQU	1000B		; 8 : D10 - date 10's (0-3)
OK_REG_LEAP		EQU	OK_REG_D10	;	D2 - leap year (0/1)
OK_REG_MO1		EQU	1001B		; 9 : MO1 - month 1's (0-9)
OK_REG_MO10		EQU	1010B		; 10: MO10 - month 10's (0-1)
OK_REG_Y1		EQU	1011B		; 11: Y1 - year 1's (0-9)
						;	2 digit year (19)80-(20)79
OK_REG_Y10		EQU	1100B		; 12: Y10 - year 10's (0-9)

OK_CTRL_CS		EQU	1000B		; Chip Select
OK_CTRL_WR		EQU	0100B		; Write
OK_CTRL_RD		EQU  	0010B		; Read
OK_CTRL_HD		EQU  	0001B		; Hold

OK_FLAG_D10_LEAP	EQU	0100B		; leap year flag on register D10 (D2)
OK_FLAG_H10_AP	EQU	0100B		; AM/PM flag on register H10 (D2)
OK_FLAG_H10_24	EQU	1000B		; 1 = 24 hour flag on reg H10 (D3)
OK_FLAG_H10_AP24	EQU	OK_FLAG_H10_AP + OK_FLAG_H10_24

INCLUDE	GLALIB.INC
INCLUDE	MACROS.INC
INCLUDE	SEGS.INC

;----------------------------------------------------------------------------;
; MS5832 Control Inputs (set on PORT C)
;
C_CS			= 	DNB < OK_CTRL_CS >			; CS
C_WRITE		=	DNB < OK_CTRL_WR >			; WRITE
C_READ		=	DNB < OK_CTRL_RD >			; READ
C_HOLD		=	DNB < OK_CTRL_HD >			; HOLD
CS_RESET		=	0						; All signals low
CS_HOLD_LOW		=	C_CS						; Set Hold Low
CS_HOLD_HIGH	=	C_CS + C_HOLD				; Set Hold High
CS_READ_LOW		=	C_CS + C_READ				; Set Read Low
CS_READ_HIGH	=	C_CS + C_READ + C_HOLD			; Set Read High
CS_WRITE_LOW	=	C_CS + C_WRITE				; Set Write Low
CS_WRITE_HIGH	=	C_CS + C_WRITE + C_HOLD			; Set Write High
CS_CS_LOW		=	C_CS + C_READ + C_WRITE			; Set CS Low
CS_CS_HIGH		=	C_CS + C_READ + C_WRITE + C_HOLD	; Set CS High

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
			ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	OK_DETECT, INT_1A_OK
EXTRN		INT_1A_DEFAULT:NEAR, LEAP_NEXT:NEAR, PACK_BCD:NEAR
EXTRN		BCD_TO_WORD:NEAR, BCD_TO_BYTE:NEAR, GET_RTC:NEAR, IRET_CF:NEAR

RTC_OK_PROC PROC

;----------------------------------------------------------------------------;
; INT 1A IVT for OK MS5832 
;----------------------------------------------------------------------------;
INT_1A_OK PROC
	STI
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_OK_BIOS			; if so, use default call
	CMP	AH, 5 				; is function supported?
	JBE	INT_1A_OK_1				; if not, use default call
INT_1A_OK_BIOS:
	JMP	NEAR PTR INT_1A_DEFAULT		; near jump to BIOS handler
INT_1A_OK_1:
	PUSH	AX
	PUSH	BX					; used as scratch register
	PUSH	DI
	XCHG	AX, BX				; save AX
	CALL	GET_RTC				; DI = port, ZF if no RTC installed
	STC						; presume failure
	JZ	INT_1A_OK_RET			; exit if port not installed
	MOV	AX, BX				; restore AX
	XCHG	AH, AL				; AL = function
	SHL	AL, 1					; word align index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	CS:INT_1A_OK_JMP[BX][-4]	; adjust JMP offset (cannot be 0 or 1)
INT_1A_OK_RET:
	POP	DI
	POP	BX
	POP	AX
	JMP	NEAR PTR IRET_CF			; IRET with current CF

INT_1A_OK_JMP LABEL WORD
	DW	OFFSET OK_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET OK_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET OK_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET OK_INT_1A_5		; AH = 5 - Set RTC Date

INT_1A_OK ENDP

;----------------------------------------------------------------------------;
; INT 1A - System and "Real Time" Clock BIOS Services
;----------------------------------------------------------------------------;
; INT 1A,0   Read system clock counter
; INT 1A,1   Set system clock counter
; INT 1A,2   Read real time clock time (AT,PS/2)
; INT 1A,3   Set real time clock time (AT,PS/2)
; INT 1A,4   Read real time clock date (AT,PS/2)
; INT 1A,5   Set real time clock date (AT,PS/2)
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
OK_INT_1A_2 PROC
	CALL	OK_MODE_READ
	CWD					; DX = 0 - clear output
	MOV	CX, DX			; CX = 0
	CLI
	MOV	AL, OK_REG_S1		; read 1 and 10-second counter
	CALL	OK_READ_BYTE
	JC	OK_RESET
	MOV	DH, AL			; save to DH
	MOV	AL, OK_REG_MI1		; read 1 and 10-minute counter
	CALL	OK_READ_BYTE
	JC	OK_RESET
	MOV	CL, AL			; save to CL
	MOV	AL, OK_REG_H1		; read 1 and 10-hour counter
	CALL	OK_READ_BYTE
	JC	OK_RESET
	MOV	CH, AL			; save to CH
	JMP	SHORT OK_RESET
OK_INT_1A_2 ENDP

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
OK_INT_1A_3 PROC
	CLI					; disable interrupts
	CALL	OK_MODE_WRITE
	MOV	AL, OK_REG_H1		; 
	MOV	AH, CH			; Hours
	CALL	OK_WRITE_BCD		; AL = first register, AH = BCD value
	MOV	AL, OK_REG_MI1
	MOV	AH, CL			; minutes
	CALL	OK_WRITE_BCD
	MOV	AL, OK_REG_S1
	MOV	AH, DH			; seconds
	CALL	OK_WRITE_BCD

OK_RESET:
;----------------------------------------------------------------------------;
; Reset MS5832 RTC and PPI
;----------------------------------------------------------------------------;
; Take all RTC control signals low to resume clock and set PPI to READ mode
; Input: DI = base port
; Clobbers: AL
;----------------------------------------------------------------------------;
OK_MODE_RUN PROC
	PUSHF
	PUSH	DX
	LEA	DX, PORT_CW[DI]		; DX = Port Control Word
	MOV	AL, PPI_CTRL_IN		; PPI READ mode
	OUT	DX, AL			; set Port CW to READ (Control Word #8)
	DEC	DX				; DX = Port C (RTC control)
	MOV	AL, CS_RESET		; Disable all RTC control lines
	OUT	DX, AL
	POP	DX
	POPF
	CLC
	RET
OK_MODE_RUN ENDP

OK_INT_1A_3 ENDP

;----------------------------------------------------------------------------;
; INT 1A,4 - Read Real Time Clock Date
;----------------------------------------------------------------------------;
; Check and set leap year flag if needed
;
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
OK_INT_1A_4 PROC
	CALL	OK_MODE_READ
	CWD					; DX = 0
	MOV	CX, DX			; CX = 0
	CLI
	MOV	AL, OK_REG_D1		; read 1 and 10-day counter
	CALL	OK_READ_BYTE
	JC	OK_RESET
	MOV	DL, AL			; save to DL
	MOV	AL, OK_REG_MO1		; read 1 and 10-month counter
	CALL	OK_READ_BYTE
	JC	OK_RESET
	MOV	DH, AL			; save to DH
	MOV	AL, OK_REG_Y1		; read 1 and 10-year counter
	CALL	OK_READ_BYTE		; AL = year
	JC	OK_RESET

;----------------------------------------------------------------------------;
; Optionally adjust Y2K_OFFSET here so LEAP year always get actual year
;
			IF Y2K_OFFSET EQ 1
	SUB	AL, 20H			; some clock progs stores year + 20
	DAS					; AL = adjusted BCD year
			ENDIF

;----------------------------------------------------------------------------;
; Get century: if less than 80 assumed Y2K
;
	MOV	CL, AL			; save year to CL
	CMP	AL, 80H			; is it above 80?
	MOV	AL, 20H			; assume Y2K
	JB	OK_GET_CEN_DONE		; jump if not
	DEC	AX				; otherwse it's 19
	DAS					; ...use this just because
OK_GET_CEN_DONE:
	MOV	CH, AL			; century to CH
	CALL	CHECK_RTC_LEAP_BCD	; check and reset leap year flag
	CLC
	JMP	SHORT OK_RESET
OK_INT_1A_4 ENDP

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
OK_INT_1A_5 PROC
	CLI					; disable interrupts
	CALL	OK_MODE_WRITE
			IF Y2K_OFFSET EQ 1
	XCHG	AX, CX
	ADD	AL, 20H			; store years + 20
	DAA	
	XCHG	AX, CX
			ENDIF
	MOV	AL, OK_REG_Y1		; year
	MOV	AH, CL
	CALL	OK_WRITE_BCD		; AL = first register, AH = BCD value
	MOV	AL, OK_REG_MO1		; month
	MOV	AH, DH
	CALL	OK_WRITE_BCD
	MOV	AL, OK_REG_D1		; day
	MOV	AH, DL
	CALL	OK_WRITE_BCD		; write day
	CALL	CHECK_RTC_LEAP_BCD	; check and reset leap year flag
	JMP	SHORT OK_RESET
OK_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
;
; MS5832 RTC I/O routines
;
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Detect MS5832 RTC
;----------------------------------------------------------------------------;
; Output:
;	AL = RTC type and CF = 0 on success
;	DX = base address (313H or 213H)
;	DI = ISR for INT 1A
;----------------------------------------------------------------------------;
OK_DETECT PROC
	MOV	DX, OK_BASE_ADDR_1	; try 31xH first
OK_TRY_ADDR:
	MOV	AL, PPI_CTRL_IN		; Clock READ mode
	OUT	DX, AL			; set Port CW to READ (Control Word #8)
	DEC	DX
	DEC	DX				; DX = Port B
	MOV	AL, 0A5H			; test with an "arbitrary" value
	OUT	DX, AL			; write to Port B (RTC address)
	IO_DELAY_SHORT
	ISA_CLEAR				; flush ISA bus will all 1s
	IN	AL, DX			; read back to AL
	SUB	AL, 0A5H			; still the same?
	JE	CARD_FOUND			; if so, is
	CMP	DX, OK_BASE_ADDR_2-2	; already tried 21xH?
	STC
	JZ	OK_DETECT_RET		; exit, if so
	MOV	DX, OK_BASE_ADDR_2	; otherwise try 21xH
	JMP	OK_TRY_ADDR
CARD_FOUND:
	DEC	DX				; DX = Port A (base port)

;----------------------------------------------------------------------------;
; Set default modes and reset
;
	MOV	DI, DX			; save base port
	MOV	AL, OK_REG_AP24
	CALL	OK_MODE_READ
	CALL	OK_READ

;----------------------------------------------------------------------------;
; Set 12/24 hour mode
;
			IF OK_MODE_24 EQ 1
	AND	AL, NOT OK_FLAG_H10_AP24; clear AM/PM/12/24 flags
	OR	AL, OK_FLAG_H10_24	; set 24 hour flag
			ELSE
	AND	AL, OK_FLAG_H10_24	; set 12 hour flag
			ENDIF
	MOV	AH, AL			; AH = register value
	MOV	AL, OK_REG_AP24		; AL = register index
	CALL	OK_MODE_WRITE		; set to write mode
	CALL	OK_WRITE			; write AH to AL
	CALL	OK_MODE_RUN			; reset and run, set CF=0
	MOV	DX, DI			; restore base port
	MOV	AL, RTC_OK			; RTC type
OK_DETECT_RET:
	MOV	DI, OFFSET INT_1A_OK	; return INT 1Ah IVT
	RET
OK_DETECT ENDP

;----------------------------------------------------------------------------;
; Hold clock and set for read
;----------------------------------------------------------------------------;
; Output: None
; Clobbers: BL
;----------------------------------------------------------------------------;
OK_MODE_READ PROC
	PUSH	DX
	XCHG	AX, BX			; save AX
	LEA	DX, PORT_CW[DI]		; DX = Port Control Word
	MOV	AL, PPI_CTRL_IN		; PPI READ mode
	OUT	DX, AL			; set Port CW to READ (Control Word #8)
	DEC	DX				; DX = Port C (RTC control)
	MOV	AL, CS_READ_HIGH		; RTC READ mode (CS+READ+HOLD)
	OUT	DX, AL			; send to PPI
	XCHG	AX, BX			; restore AX
	POP	DX
	RET
OK_MODE_READ ENDP

;----------------------------------------------------------------------------;
; Hold clock and set for write
;----------------------------------------------------------------------------;
OK_MODE_WRITE PROC
	PUSH	AX
	PUSH	DX
	LEA	DX, PORT_CW[DI]		; DX = Port Control Word
	MOV	AL, PPI_CTRL_OUT		; PPI direction WRITE mode
	OUT	DX, AL			; set Port CW to WRITE (Control Word #8)
	DEC	DX				; DX = Port C (RTC control)
	MOV	AL, CS_HOLD_HIGH		; hold RTC clock high for access
	OUT	DX, AL			; send to PPI
	POP	DX
	POP	AX
	RET
OK_MODE_WRITE ENDP

;----------------------------------------------------------------------------;
; Read two digit register from RTC to packed BCD
;----------------------------------------------------------------------------;
; Input: AL = first register index
; Output: AX = byte register value
; 	CF if invalid, NC if valid
; Clobbers: BL
;----------------------------------------------------------------------------;
OK_READ_BYTE PROC
	PUSH	DX				; DX clobbered by OK_READ
	MOV	AH, AL			; save index
	CALL	OK_READ
	JC	OK_READ_BYTE_RET
	XCHG	AH, AL			; AL = first index, AH = first value
	INC	AX				; AL = second index
	CALL	OK_READ			; AL = second value
	JC	OK_READ_BYTE_RET
	XCHG	AH, AL			; AH = second value, AL = first value
	CALL	PACK_BCD			; pack BCD digits in AH/AL into AL
	MOV	AH, 0				; clear AH
OK_READ_BYTE_RET:
	POP	DX
	RET
OK_READ_BYTE ENDP

;----------------------------------------------------------------------------;
; Read MS5832 RTC
;----------------------------------------------------------------------------;
; Input: AL = first register index
; Output: AL = byte register value
; 	CF if invalid, NC if valid
;
; Clock: must be in READ+HOLD and PPI direction IN
; Clobbers: BL, DX
;----------------------------------------------------------------------------;
OK_READ PROC
	LEA	DX, PORT_B[DI]		; DX = Port B (RTC address)
	OUT	DX, AL			; AL = register index
	CALL	READ_DELAY			; access time delay
	MOV	BL, AL			; BL = register index
	DEC	DX				; DX = Port A (RTC data)
	IN	AL, DX			; AL = counter byte
	CMP	BL, OK_REG_H10		; is 10-digit hour of day?
	JE	OK_READ_REG_H10		; jump to handle 12/24 hour mode
	CMP	BL, OK_REG_D10		; is 10-digit day of month?
	JE	OK_READ_TWO_BIT		; remove leap year flag
OK_READ_1:
	AND	AL, 0FH			; only low nibble
	CMP	AL, 10			; is valid (0-9)?
	CMC					; CF if >= 10
	RET

OK_READ_REG_H10:
			IF OK_MODE_24 EQ 0
;----------------------------------------------------------------------------;
; Handle 12/24 hour mode
;
	TEST	AL, OK_FLAG_H10_24	; is 12 (0) or 24 (1) hour mode?
	JNZ	OK_READ_TWO_BIT		; jump if 24 hour
	TEST	AL, OK_FLAG_H10_AP	; is AM (0) or PM (1)?
	JZ	OK_READ_TWO_BIT		; jump if AM
	ADD	AL, 12			; convert to 24 hour time
			ENDIF
OK_READ_TWO_BIT:
	AND	AL, 0011B			; only low two bits of hour or month
	JMP	SHORT OK_READ_1

OK_READ ENDP

;----------------------------------------------------------------------------;
; Write packed BCD in AH to register AL
;----------------------------------------------------------------------------;
; Input: 
;	AL = first register index
;	AH = BCD register value
; Clock: must be in WRITE+HOLD and PPI direction OUT
; Clobbers: BX
;----------------------------------------------------------------------------;
OK_WRITE_BCD PROC
	MOV	BX, AX			; save starting index to BL
	MOV	AL, AH			; AL = register value
	UNPACK_BCD				; unpack BCD digits into AH/AL
	MOV	BH, AH			; save high digit to BH
	MOV	AH, AL			; AH = low digit
	MOV	AL, BL			; AL = starting index
	PUSH	BX
	CALL	OK_WRITE			; write AH to register AL
	POP	AX				; AH = high digit value, AL = low index
	INC	AX				; next register/index
						; fall through for second OK_WRITE call

;----------------------------------------------------------------------------;
; Write Register to RTC in current bank
;----------------------------------------------------------------------------;
; Input: AL = register index, AH = register value
; Clock: must be in WRITE+HOLD and PPI direction OUT
; Output: BX = 0
; Clobbers: BX
;----------------------------------------------------------------------------;
OK_WRITE PROC
	PUSH	AX
	PUSH	DX

;----------------------------------------------------------------------------;
; Handle 12/24 hour register
;
	MOV	BX, AX			; save AX
	CMP	AL, OK_REG_AP24		; is hour/12/24 register?
	JNE	OK_WRITE_1			; continue if not
	AND	AH, 0FH AND NOT OK_FLAG_H10_AP24	; clear AM/PM/12/24 flags
			IF OK_MODE_24 EQ 1
	OR	AH, OK_FLAG_H10_24	; set 24 hour flag
			ELSE
	CMP	AH, 12			; is AM?
	JB	OK_WRITE_1			; jump if so
	SUB	AH, 12			; convert to 12 hour time
	OR	AH, OK_FLAG_H10_24	; set PM flag
			ENDIF
OK_WRITE_1:
	LEA	DX, PORT_B[DI]		; DX = Port B (RTC address)
	OUT	DX, AL			; write to address register
	CALL	WRITE_DELAY			; write access time delay
	MOV	AL, AH			; AL = register value
	DEC	DX				; DX = Port A (RTC data)
	OUT	DX, AL			; write value to PPI
	INC	DX
	INC	DX				; DX = Port C (RTC control)
	MOV	AL, CS_WRITE_HIGH		; RTC WRITE mode (CS+WRITE+HOLD)
	OUT	DX, AL			; send to PPI
	CALL	WRITE_DELAY			; write access time delay
	MOV	AL, CS_HOLD_HIGH		; RTC WRITE off (CS+HOLD)
	OUT	DX, AL			; send to PPI
	POP	DX
	POP	AX
						; fall through for WRITE_DELAY
OK_WRITE ENDP
OK_WRITE_BCD ENDP

;----------------------------------------------------------------------------;
; Write Delay 40 read delay clock address access time
; Clobbers: BX
;----------------------------------------------------------------------------;
WRITE_DELAY PROC
	MOV	BL, 40
WRITE_DELAY_LOOP:
	CALL	READ_DELAY
	DEC	BL
	JNZ	WRITE_DELAY_LOOP		; loop 44x
						; fall through for last loop
WRITE_DELAY ENDP

;----------------------------------------------------------------------------;
; Delay at least 6ns for clock address access time
; Clobbers: BH
;----------------------------------------------------------------------------;
READ_DELAY PROC
	MOV	BH, 25			; 25 NOPs, plus LOOP
DELAY_LOOP:
	NOP
	DEC	BH
	JNZ	DELAY_LOOP
SET_RTC_LEAP_DONE:
	RET
READ_DELAY ENDP

;----------------------------------------------------------------------------;
; Update leap flag if needed input in BCD
;----------------------------------------------------------------------------;
; Input:
;	CX = year in BCD
;	DH = month
; Clobbers: AX, BX
;
; TODO: unnecessary to convert to WORD then back to BCD
;----------------------------------------------------------------------------;
CHECK_RTC_LEAP_BCD PROC
	MOV	AL, DH			; AL = month as BCD
	CALL	BCD_TO_BYTE			; AL = month as BYTE
	MOV	BL, AL			; BL = month as BYTE
	MOV	AX, CX			; AX = year as BCD
	CALL	BCD_TO_WORD			; AX = year as WORD

;----------------------------------------------------------------------------;
; Update leap flag if needed
;----------------------------------------------------------------------------;
; Input:
;	AX = year
;	BL = month
; Output:
;	Clock: HOLD+WRITE
; Clobbers: AX, BX
;----------------------------------------------------------------------------;
CHECK_RTC_LEAP_YEAR PROC
	PUSH	CX				; don't clobber me bro
	MOV	CH, BL			; CH = month
	CALL	LEAP_NEXT 			; ZF if leap, NZ if not leap
	POP	CX
	JNZ	SET_RTC_LEAP_DONE 	; if not a leap, do nothing
	MOV	AL, OK_REG_D10		; AL = leap flag register
	CALL	OK_MODE_READ		; set RTC to WRITE+HOLD
	CALL	OK_READ_BYTE		; AL = leap flag value
	JC	SET_RTC_LEAP_DONE		; exit if error
	TEST	AL, OK_FLAG_D10_LEAP	; is leap flag set?
	JNZ	SET_RTC_LEAP_DONE 	; if so, do nothing
	OR	AL, OK_FLAG_D10_LEAP	; set leap flag
	MOV	AH, AL			; AH = register value
	MOV	AL, OK_REG_D10		; AL = leap flag register index
	CALL	OK_MODE_WRITE		; set RTC to WRITE+HOLD
	JMP	SHORT OK_WRITE		; write AH to register AL
CHECK_RTC_LEAP_YEAR ENDP
CHECK_RTC_LEAP_BCD ENDP

RTC_OK_PROC ENDP

OPTROM	ENDS
			ENDIF			; IFDEF RTC_OK
		END
