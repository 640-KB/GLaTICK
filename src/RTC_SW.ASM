	PAGE	 	59,132
	TITLE		GLaTICK_RTC_SW

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for DS-1216x/DS1315 "SmartWatch" ROM.
;
; TODO:
;	- RAM
;	- Interleaved ROMs
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_SW
SHOW_CLOCK		=	1			; enable display of clock on boot
SET_DOW		=	1			; calculate and set day of week
Y2K_OFFSET		=	0			; do not offset year

;----------------------------------------------------------------------------;
; Test Mode for debugging without clock present
;
TEST_MODE	EQU	0

			IF TEST_MODE EQ 1
TEST_MMDD	EQU	0814H		; month / day
TEST_YY	EQU	23H		; year
TEST_HHMM	EQU	1009H		; hour / minute
TEST_SS	EQU	33H		; seconds
TEST_READ	EQU	10H		; a valid register byte (2010-10-10 10:10:10)
			ENDIF

;----------------------------------------------------------------------------;
; F600:0000 - SmartWatch ROM access segment and address offsets
;----------------------------------------------------------------------------;
; The SmartWatch uses the ROM's address lines for data transfer in and out.
;
; Scan for clock begins at the below segment, and at every 8K segment 
; boundary until 0000h.
;----------------------------------------------------------------------------;
_SW_ACC	SEGMENT AT 	0F600H	; set the start segment for scan
;_SW_ACC	SEGMENT AT 	0C000H	; set the start segment for scan

;----------------------------------------------------------------------------;
; Non-interleaved ROM access offsets
;
			ORG	0010B
SW_WR0	DB	?		; 010b: A2=write, A0=0
SW_WR1	DB	?		; 011b: A2=write, A0=1
SR_RD		DB	?		; 100b: A2=read,  DQ0=in
_SW_ACC	ENDS

;----------------------------------------------------------------------------;
; SmartWatch Clock Register Buffer
;----------------------------------------------------------------------------;
SW_REG	STRUC
SW_REG_CS	DB	?		; 00h: centi-sec (00-99)
SW_REG_SEC	DB	?		; 01h: seconds (00-59)
SW_REG_MIN	DB	?		; 02h: minutes (00-59)
SW_REG_HOUR	DB	?		; 03h: hours (01-12 / 00-23)
SW_REG_DAY	DB	?		; 04h: OSC/RST/day of week (01-07)
SW_REG_DATE	DB	?		; 05h: day of month (01-31)
SW_REG_MON	DB	?		; 06h: month (01-12)
SW_REG_YEAR	DB	?		; 07h: year (00-99)
SW_REG	ENDS

;----------------------------------------------------------------------------;
; SW 00h: centi-sec (00-99)
;----------------------------------------------------------------------------;
; 76543210
; xxxx 		- CS10:	0.1 sec
;     xxxx		- CS01:	0.01 sec
;----------------------------------------------------------------------------;
SW_CS		RECORD	CS10:4, CS01:4

;----------------------------------------------------------------------------;
; SW 01h: seconds (00-59)
;----------------------------------------------------------------------------;
; 76543210
; x			- SECX:	unused (always 0)
;  xxx 		- SEC10:	10 sec
;     xxxx		- SEC01:	1 sec
;----------------------------------------------------------------------------;
SW_SEC	RECORD	SECX:1, SEC10:3, SEC01:4

;----------------------------------------------------------------------------;
; SW 02h: minutes (00-59)
;----------------------------------------------------------------------------;
; 76543210
; x			- MINX:	unused (always 0)
;  xxx 		- MIN10:	10 minute
;     xxxx		- MIN01:	1 minute
;----------------------------------------------------------------------------;
SW_MIN	RECORD	MINX:1, MIN10:3, MIN01:4

;----------------------------------------------------------------------------;
; SW 03h: hours (01-12 / 00-23)
;----------------------------------------------------------------------------;
; 76543210
; x 			- H1224:	12/24 hour format (0=24, 1=12)
;  0			- HX1:	unused (always 0)
;   x 		- HAP:	AM/PM (0=AM, 1=PM)
;   xxxxxx		- HOUR: 	Hours (1-12/0-23)
;----------------------------------------------------------------------------;
SW_HOUR	RECORD	H1224:1, HX1:1, HAP:1, HOUR:5

;----------------------------------------------------------------------------;
; SW 04h: day of week (01-07)
;----------------------------------------------------------------------------;
; 76543210
; 00 			- DAX1:	unused (always 0)
;   x 		- OSC:	/OSC (0 = running, 1 = stopped)
;    x 		- RST:	/RESET (0 = use reset pin, 1 = ignore reset pin)
;     0 		- DAX2:	unused (always 0)
;      xxx		- DAY: 	Day of week (1-7)
;----------------------------------------------------------------------------;
SW_DOW_ST	RECORD	DAX1:2, OSC:1, RST:1, DAX2:1, DAY:3

;----------------------------------------------------------------------------;
; SW 05h: day of month (01-31)
;----------------------------------------------------------------------------;
; 76543210
; 00 			- DTX1:	unused (always 0)
;   xx 		- DT10:	10 date (1-3)
;     xxxx		- DT01: 	1 date (0-9)
;----------------------------------------------------------------------------;
SW_DATE	RECORD	DTX1:2, DT10:2, DT01:4

;----------------------------------------------------------------------------;
; SW 06h: month (01-12)
;----------------------------------------------------------------------------;
; 76543210
; 000			- MNX1:	unused (always 0)
;    x 		- MON10:	10 month (0-1)
;     xxxx		- MON01: 	1 month (0-9)
;----------------------------------------------------------------------------;
SW_MON	RECORD	MNX1:3, MON10:1, MON01:4

;----------------------------------------------------------------------------;
; SW 07h: year (00-99)
;----------------------------------------------------------------------------;
; 76543210
; xxxx 		- YR10:	10 year (0-9)
;     xxxx		- YR01:	1 year (0-9)
;----------------------------------------------------------------------------;
SW_YEAR	RECORD	YR10:4, YR01:4

SW_DATA_SZ	EQU	SIZE SW_REG				; 8 byte buffer size
SW_DATA_SZB	EQU	SW_DATA_SZ * WIDTH SW_CS 	; 64 bit buffer size

INCLUDE 	GLALIB.INC
INCLUDE 	MACROS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
OPTROM	SEGMENT BYTE PUBLIC 'CODE'
		ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
PUBLIC	SW_DETECT, INT_1A_SW
EXTRN		INT_1A_DEFAULT:NEAR, IRET_CF:NEAR, BYTE_TO_BCD:NEAR
EXTRN		WORD_HEX:NEAR, GET_RTC:NEAR, BCD_TO_BYTE:NEAR

RTC_SW_PROC PROC

;----------------------------------------------------------------------------;
; INT 1A IVT for RTC_SW
;----------------------------------------------------------------------------;
INT_1A_SW PROC
	STI
	CMP	AH, 1				; is function 0 or 1?
	JBE	INT_1A_SW_BIOS		; if so, use default call
	CMP	AH, 5 			; is function > 5?
	JBE	INT_1A_SW_1			; if so, use default call
INT_1A_SW_BIOS:
	JMP	INT_1A_DEFAULT		; near jump to BIOS handler

INT_1A_SW_1:
	PUSHX	AX, BX, DI, ES

;----------------------------------------------------------------------------;
; Check that clock was detected on POST and get address
;
	XCHG	AX, BX			; save AX
	CALL	GET_RTC			; DI = port, AL = type, ZF if no RTC
	STC					; return with CF if not detected
	JZ	INT_1A_SW_EXIT		; exit if port not installed
		REPT	WIDTH RTTYPE	; unpack low three nibbles
	SHL	DI, 1
		ENDM
	MOV	ES, DI			; set ES

	XCHG	AX, BX			; restore AX

	MOV	DI, AX			; save AX
	PUSHX	SI, BP, DS
	XCHG	AH, AL			; AL = function
	SHL	AL, 1				; word align index
	CBW					; AX = jump index
	XCHG	AX, DI			; restore AX, DI = jump offset
	PUSH	CS				; DS = CS (ROM)
	POP	DS
	CLI					; nothing good can come from interrupts
						; from this point on
	SUB	SP, SW_DATA_SZ		; allocate bytes for output data buffer
	MOV	BX, SP			; SS:[BX] = output buffer
	PUSH	CX				; preserve INT 1A input data
	PUSH	DX
	PUSH	AX

;----------------------------------------------------------------------------;
; Read all registers from RTC
;
	MOV	CX, SW_RW_SZ		; code size
	MOV	SI, OFFSET SW_RW		; DS:[SI] = code address

	CLC					; READ function
	CALL	CALL_F_SP			; call DS:[SI] from stack memory

;----------------------------------------------------------------------------;
; Call INT 1A function handler
;
	POP	AX
	POP	DX				; restore INT 1A input data
	POP	CX
	JC	INT_1A_SW_SP		; if read error, exit

	CALL	INT_1A_SW_JMP[DI][-4]	; call INT 1A RTC (02h-05h) function

INT_1A_SW_SP:
	ADD	SP, SW_DATA_SZ		; deallocate output data buffer

INT_1A_SW_DONE:
	POPX	DS, BP, SI

INT_1A_SW_EXIT:
	POPX	ES, DI, BX, AX

INT_1A_SW_RET:
	JMP	NEAR PTR IRET_CF		; IRET with current CF

INT_1A_SW_JMP LABEL WORD
	DW	OFFSET SW_INT_1A_2	; AH = 2 - Read RTC
	DW	OFFSET SW_INT_1A_3	; AH = 3 - Set RTC Time
	DW	OFFSET SW_INT_1A_4	; AH = 4 - Read RTC Date
	DW	OFFSET SW_INT_1A_5	; AH = 5 - Set RTC Date
INT_1A_SW ENDP

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
; INT 1A,2	Read Time From Real Time Clock 
;----------------------------------------------------------------------------;
; Input:
;	SS:[BX] = clock register data buffer
;
; Output:
;	CF = 0 if successful (always 0)
;	CH = hours in BCD
;	CL = minutes in BCD
;	DH = seconds in BCD
;	DL = 1 if daylight savings time option
;
; Clobbers: AX, DS, SI
;----------------------------------------------------------------------------;
SW_INT_1A_2 PROC
	PUSH	SS				; DS = SS
	POP	DS
	MOV	SI, BX			; SI = data pointer

;----------------------------------------------------------------------------;
; Load and clear unused bits
;
	LODSW					; get seconds, DST
	AND	AX, DBW < MASK SEC10 OR MASK SEC01, 0 >
	XCHG	AX, DX			; DH = seconds, DL = DST flag (always 0)

	LODSW					; get hours, minutes
	AND	AX, DBW < MASK HOUR OR MASK HAP, MASK MIN10 OR MASK MIN01 >
	XCHG	AX, CX			; CH = hours, CL = min
			IF TEST_MODE EQ 1
	MOV	CX, TEST_HHMM		; test hour/minute
	MOV	DX, DBW < TEST_SS >	; test seconds
			ENDIF
	CLC					; no error
SW_INT_1A_2_RET:
	RET

SW_INT_1A_2 ENDP

;----------------------------------------------------------------------------;
; INT 1A,3 - Set Time on Real Time Clock 
;----------------------------------------------------------------------------;
; Input:
;	CH = hours in BCD
;	CL = minutes in BCD
;	DH = seconds in BCD
;	DL = 1 if daylight savings time option
;	   = 0 if standard time
;	SS:[BX] = clock register data buffer
;
; Clobbers: SI
;----------------------------------------------------------------------------;
SW_INT_1A_3 PROC

;----------------------------------------------------------------------------;
; Update time in buffer for write
;
	AND	CH, NOT MASK H1224	; set 24 hour mode
	MOV	SS:[BX], DX			; DH = seconds, DL = centiseconds (0 or 1)
	MOV	WORD PTR SS:[BX].SW_REG_MIN, CX	; CL = min, CH = hours

SW_INT_1A_WR:
	PUSH	CX
	MOV	CX, SW_RW_SZ		; code size
	MOV	SI, OFFSET SW_RW		; DS:[SI] = code address
	STC					; SW_RW WRITE function (CF=1)
	CALL	CALL_F_SP			; clobbers CX, SI
	CLC					; No error
	POP	CX
	RET
SW_INT_1A_3 ENDP

;----------------------------------------------------------------------------;
; INT 1A,4 - Read Real Time Clock Date
;----------------------------------------------------------------------------;
; Input:
;	SS:[BX] = clock register data buffer
; Output:
;	CH = century in BCD (decimal 19 or 20)
;	CL = year in BCD
;	DH = month in BCD
;	DL = day in BCD
;	CF = 0 if successful
;	   = 1 if error or clock not operating
;
; Note: calling this interrupt will update the DOS maintained date and
;	reset the BIOS Data Area date rollover flag at 40:70
;
; Clobbers: AX, DS, SI
;----------------------------------------------------------------------------;
SW_INT_1A_4 PROC
	PUSH	SS					; DS = SS
	POP	DS
	LEA	SI, [BX].SW_REG_DAY		; SI = date buffer, discard time

;----------------------------------------------------------------------------;
; Check clock status bytes
;
	LODSB						; AL = status byte
	TEST	AL, MASK OSC			; ZF if running, NZ if not running
	JNZ	SW_INT_1A_4_ERR			; exit if clock is stopped state
	;TEST	AL, MASK RST			; ZF if in reset, NZ if running
	;JZ	SW_INT_1A_4_ERR			; exit if clock is in reset state

	LODSW						; AH = month, AL = day of month 
			IF TEST_MODE EQ 1
	MOV	AX, TEST_MMDD			; test data
			ENDIF

;----------------------------------------------------------------------------;
; Validate month result
;
	INC	AX					; check if both are FFh
	JZ	SW_INT_1A_4_ERR			; if so, error
	DEC	AX					; restore AX

	AND	AX, DBW < MASK MON10 OR MASK MON01, MASK DT10 OR MASK DT01 >
	JZ	SW_INT_1A_4_ERR			; if both are 0, error

	XCHG	AX, DX				; save to DX for output

;----------------------------------------------------------------------------;
; Read year
;
	LODSB						; AL = year
			IF TEST_MODE EQ 1
	MOV	AL, TEST_YY				; test data
			ENDIF

			IF Y2K_OFFSET EQ 1
	SUB	AL, 20H				; store year + 20
	DAS						; BCD adjust
			ENDIF
	CMP	AL, 80H				; is it above 80?
	MOV	CL, AL				; save to CL

;----------------------------------------------------------------------------;
; Get century - does not store century, so if less than 80 assumed Y2K
;
	MOV	AL, 20H				; assume Y2K
	JC	SW_GET_CEN_DONE			; jump if not
	DEC	AX					; otherwse it's 19
	DAS						; BCD adjust
SW_GET_CEN_DONE:
	MOV	CH, AL				; century to CH
	CLC

SW_INT_1A_4_DONE:
	RET

SW_INT_1A_4_ERR:
	XOR	DX, DX				; clear any incomplete reads
	MOV	CX, DX				; CX = DX = 0000
	STC
	JMP	SHORT SW_INT_1A_4_DONE
SW_INT_1A_4 ENDP

;----------------------------------------------------------------------------;
; INT 1A,5 - Set Real Time Clock Date
;----------------------------------------------------------------------------;
; Input:
;	CH = century in BCD (decimal 19 or 20)
;	CL = year in BCD
;	DH = month in BCD
;	DL = day in BCD
;	SS:[BX] = clock register data buffer
; Output:
;	CF = 0
;
; Clobbers: SI
;----------------------------------------------------------------------------;
SW_INT_1A_5 PROC
			IF SET_DOW EQ 1
	CALL	DOW						; AL = zero-based day of week
	INC	AX						; adjust for one-based day
	OR	AL, MASK RST				; set /RESET bit
	MOV	SS:[BX].SW_REG_DAY, AL
			ELSE
	AND	SS:[BX].SW_REG_DAY, NOT MASK OSC	; enable oscillator
	OR	SS:[BX].SW_REG_DAY, MASK RST		; set /RESET bit (ignore pin)
			ENDIF
	MOV	WORD PTR SS:[BX].SW_REG_DATE, DX	; DH = month, DL = day
	MOV	SS:[BX].SW_REG_YEAR, CL			; CL = year
	JMP	SHORT SW_INT_1A_WR			; write new buffer to clock
SW_INT_1A_5 ENDP

;----------------------------------------------------------------------------;
; Detect SmartWatch RTC
;----------------------------------------------------------------------------;
; Output:
;	ZF if found, NZ if not
;	DI = offset of new INT 1A IVT
;	DX = address for RTC
;	AL = RTC type (RTC_SW)
;
; Clobbers: AH
;----------------------------------------------------------------------------;
SW_DETECT PROC
	PUSHX	DS, BX, CX, SI
	PUSH	CS				; DS = CS (ROM)
	POP	DS
	SUB	SP, SW_DATA_SZ		; allocate bytes for output data buffer
	MOV	BX, SP			; SS:[BX] = output buffer

;----------------------------------------------------------------------------;
; Detect starting with base segment
;
	MOV	SI, SEG _SW_ACC		; must align to 200H boundary
SW_DETECT_STUFF:
	MOV	ES, SI
	MOV	CX, SW_RW_SZ		; code size
	MOV	SI, OFFSET SW_RW		; DS:[SI] = code address
	CLC					; READ function
	CALL	CALL_F_SP			; call DS:[SI] from stack memory
	JC	SW_DETECT_NEXT
SW_DETECT_OK:
	MOV	DI, OFFSET INT_1A_SW	; DI = ISR for RTC SW INT 1A
	MOV	DX, ES
		REPT	WIDTH RTTYPE	; adjust to fit in low three nibbles
	SHR	DX, 1				; CF = 0
		ENDM
	MOV	AL, RTC_SW			; RTC type
	JMP	SHORT SW_DETECT_EXIT	; all good - exit

SW_DETECT_NEXT:
	MOV	SI, ES
	ADD	SI, 2000H SHR 4		; next 8k ROM segment boundary
	JNZ	SW_DETECT_STUFF
	STC					; not detected

SW_DETECT_EXIT:
	LAHF					; don't clobber CF with ADD below
	ADD	SP, SW_DATA_SZ		; deallocate bytes for output data buffer
	SAHF
	POPX	SI, CX, BX, DS
	RET
SW_DETECT ENDP

;----------------------------------------------------------------------------;
; SW_RW: Set up and handle R/W operations for SW RTC
;----------------------------------------------------------------------------;
; Accessing the SmartWatch effectively disables the ROM that sits above it,
; meaning that the ROM becomes inaccesible. In for this to work if the
; GLaTICK ROM is using the SmartWatch socket, the code to access the clock
; must first be copied to memory (stack) and executed from there.
;
; This PROC must be run using CALL_F_SP.
;----------------------------------------------------------------------------;
; Input:
; 	CF = 0 if READ, CF = 1 if WRITE
;	SS:[BX] = output data buffer (preserved)
;	ES = segment of detected RTC
; Output:
;	CF = READ success/failure, CF = 0 always for WRITE
;
; Clobbers: AX, CX, SI, BP
;----------------------------------------------------------------------------;
SW_RW PROC NEAR
			ASSUME ES:_SW_ACC

;----------------------------------------------------------------------------;
; Set up current IP and relative addressing since all OFFSETs have been
; relocated within stack at runtime.
;
	CALL	SW_START			; PUSH IP to stack
SW_START:
	POP	BP				; BP = OFFSET SW_START

;----------------------------------------------------------------------------;
; Use for relative references
;
_RAM_ACC	EQU	[BP][RAM_ACC    -SW_START]
_SW_ACCESS	EQU	[BP][SW_ACCESS  -SW_START]
_SW_RW_DONE	EQU	[BP][SW_RW_DONE -SW_START]

;----------------------------------------------------------------------------;
; Handle registers
;
	PUSH	DS
	CLI					; ensure interrupts are disabled
	CLD					; string direction forward
	PUSHF					; save CF
	PUSH	CS				; DS = CS (stack)
	POP	DS
	LEA	AX, _SW_ACCESS		; magic incantation to access clock data
	CALL	AX
	MOV	SI, BX			; SI = data buffer

;----------------------------------------------------------------------------;
; Is read (CF=0) or write (CF=1) operation?
;
	POPF					; restore CF
	JC	SW_WRITE_ALL		; jump to WRITE

;----------------------------------------------------------------------------;
; SW_READ_ALL: Read all 64 data bits of the clock
;----------------------------------------------------------------------------;
; Data contained in the SmartWatch registers is in binary-coded decimal 
; format (BCD). Reading and writing the registers is always accomplished by 
; stepping through all eight registers, starting with bit 0 of register 0
; and ending with bit 7 of register 7.
;----------------------------------------------------------------------------;
; Input:
;	DS:SI = Pointer to 8-byte buffer to contain chip data
;	ES = segment of detected RTC
;	AL = 0
; Output:
;	CF if invalid read (all 00s or FFs)
;	CX = 0
;
; Clobbers: AX, CX, DX, SI
;----------------------------------------------------------------------------;
SW_READ_ALL PROC
	PUSH	SI					; save start of buffer
	MOV	CL, 8					; read 8 bytes (64 bits)
SW_READ_BYTE:
	MOV	CH, 8					; read 8 bits (1 byte)
	CBW						; AH = working data byte
SW_READ_BIT:
	MOV	AL, ES:SR_RD			; read next bit from RTC
	SHR	AL, 1					; CF = bit read
	RCR	AH, 1					; shift and add bit to working byte
	DEC	CH					; decrement bit counter
	JNZ	SW_READ_BIT				; loop until end of byte
			IF TEST_MODE EQ 1
	MOV	AH, TEST_READ			; test data byte read
			ENDIF
	MOV	[SI], AH				; save byte to data buffer
	INC	SI					; next output byte in buffer
	LOOP	SW_READ_BYTE			; loop 8 bytes
	POP	SI					; restore start of buffer for test

;----------------------------------------------------------------------------;
; Verify result is not all 00 or FF: CF=1 if error
;
	MOV	CL, 4
	XOR	DX, DX				; clear DX for zero-test
TEST_LOOP:
	LODSW						; AX = next two bytes
	INC	AX					; check if all FFs
	JZ	SW_READ_ERR				; if so, exit with error
	DEC	AX					; restore AX
	OR	DX, AX				; OR all 8 bytes, set CF=0
	LOOP	TEST_LOOP
	JNZ	SW_READ_DONE			; result was not all 00s
SW_READ_ERR:
	STC						; set CF for error
SW_READ_DONE:					; fall through to exit

SW_READ_ALL ENDP

;----------------------------------------------------------------------------;
; End of SW_RW - clean up and exit
;
SW_RW_DONE:
	POP	DS
	RETF

;----------------------------------------------------------------------------;
; SW_WRITE_ALL: Write all 64 data bits to the clock
;----------------------------------------------------------------------------;
; Data contained in the SmartWatch registers is in binary-coded decimal 
; format (BCD). Reading and writing the registers is always accomplished by 
; stepping through all eight registers, starting with bit 0 of register 0
; and ending with bit 7 of register 7.
;----------------------------------------------------------------------------;
; Input:
;	DS:[SI] = Pointer to 8-byte buffer to be written to chip
; Output:
;	CF = 0
;
; Clobbers: AX, CX, SI
;----------------------------------------------------------------------------;
SW_WRITE_ALL PROC
	LEA	AX, _SW_RW_DONE			; set return offset for SW_WRITE
	PUSH	AX
	JMP	SHORT SW_WRITE

;----------------------------------------------------------------------------;
; SW_ACCESS: Send data pattern to socket to activate RTC
;----------------------------------------------------------------------------;
; Communication with the SmartWatch RAM is established by pattern recognition
; on a serial bit stream of 64 bits that must be matched by executing 64
; consecutive write cycles containing the proper data on DQ0.
;----------------------------------------------------------------------------;
; Input:
;	ES = SEG _SW_ACC
; Output:
;	IF = 0, DF = 0
;
; Clobbers: AX, CX, SI
;----------------------------------------------------------------------------;
SW_ACCESS	PROC

;----------------------------------------------------------------------------;
; When power is cycled, 64 reads should be executed prior to any writes to 
; ensure that the RTC registers are not written.
;
	MOV	CX, SW_DATA_SZB + 1
SW_ACCESS_CLEAR:
	MOV	AL, ES:SR_RD			; read next bit from RTC
	LOOP	SW_ACCESS_CLEAR
	IO_DELAY_SHORT				; short delay before continuing

	LEA	SI, _RAM_ACC			; RAM access data pattern
							; fall through to write

;----------------------------------------------------------------------------;
; SW_WRITE: Write all 64 data bits to the clock
;----------------------------------------------------------------------------;
; Input:
;	DS:[SI] = output data buffer to write
; Output:
;	CF = 0, CX = 0, AL = 0
;
; Clobbers: AX, CX, SI
;----------------------------------------------------------------------------;
SW_WRITE PROC
	PUSH	DI
	MOV	CL, 8					; loop 8 bytes
SW_WRITE_BYTE:
	MOV	CH, 8					; loop 8 bits
	LODSB						; AL = next byte to write to clock
SW_WRITE_BIT:
	MOV	DI, OFFSET ES:SW_WR0		; default to write 0
	SHR	AL, 1					; CF = next data bit to write
	ADC	DI, 0					; if CF, write 1
	MOV	AH, BYTE PTR ES:[DI]		; write to clock
	DEC	CH
	JNZ	SW_WRITE_BIT
	LOOP	SW_WRITE_BYTE			; loop all 64 bits
	POP	DI
	RET

SW_WRITE ENDP
SW_ACCESS ENDP
SW_WRITE_ALL ENDP

;----------------------------------------------------------------------------;
; Communication with the SmartWatch RAM is established by pattern recognition
; on a serial bit stream of 64 bits that must be matched by executing 64
; consecutive write cycles containing the proper data on DQ0.
;
; Note: this pattern is NOT / ROL4 repeated 4 times
;
RAM_ACC	DB	0C5H, 03AH, 0A3H, 05CH 		; RAM access pattern
		DB	0C5H, 03AH, 0A3H, 05CH

SW_RW_END:
SW_RW_SZ	EQU	SW_RW_END-SW_RW

			ASSUME ES:NOTHING
SW_RW ENDP

;----------------------------------------------------------------------------;
; Make FAR CALL to a PROC in stack memory
;----------------------------------------------------------------------------;
; Copies FAR CALL code from ROM into stack memory end executes.
; Must return with RETF.
;
; Input:
;	DS:[SI] = offset of FAR PROC code
;	CX = size of PROC code
;
; Clobbers: SI, CX
;----------------------------------------------------------------------------;
CALL_F_SP PROC
	PUSHX	AX, ES, DS, BP, DI	; preserve working registers
	MOV	BP, SP			; save stack pointer
	LAHF					; save flags
	SUB	SP, CX			; reserve stack space, SP = start of code
	SAHF
	MOV	DI, SP			; start of temp space
	PUSH	ES				; save ES
	PUSH	SS
	POP	ES				; ES = SS (MEM code destination)
			ASSUME DS:_BDA
	REP	MOVSB				; copy code
	POP	ES				; restore ES
	MOV	DI, SEG _BDA		; use BDA for temp call location
	MOV	DS, DI			; ES = BDA
	MOV	DI, OFFSET ROM_INIT_SS	; DI = BDA temp location for FAR CALL
	MOV	[DI], SP			; offset
	MOV	[DI][2], SS			; segment
	PUSH	BP				; call-preserve stack pointer
	CALL	DWORD PTR [DI]		; call function in memory
	POP	BP				; restore stack pointer
	MOV	SP, BP			; restore stack
	POPX	DI, BP, DS, ES, AX	; restore registers
			ASSUME DS:NOTHING
	RET
CALL_F_SP ENDP

			IF SET_DOW EQ 1
;----------------------------------------------------------------------------;
; Get Day of week
;----------------------------------------------------------------------------;
; Input:
;	CH = century in BCD	(J)
;	CL = year in BCD		(K)
;	DH = month in BCD		(m)
;	DL = day in BCD		(q)
; Output:
;	AX = day of week (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat)
;
; Source: https://en.wikipedia.org/wiki/Zeller%27s_congruence
;----------------------------------------------------------------------------;
DOW PROC
	PUSH	BX
	PUSH	CX
	PUSH	DX

;----------------------------------------------------------------------------;
; h = q
;
	MOV	AL, DL		; q day
	CALL	BCD_TO_BYTE		; AX = q (byte)
	XCHG	AX, BX		; save to running sum in BX

	MOV	AL, DH		; m month
	CALL	BCD_TO_BYTE		; AX = m (byte)

;----------------------------------------------------------------------------;
; if Jan/Feb, adjust backwards to previous year
; (3 = March, 4 = April, 5 = May, ..., 14 = February)
;
	SUB	AL, 2			; compare and perform (m-2) operation below
					;  (1 = Mar, ..., 10 = Dec)
	JA	DOW_1			; jump if Mar-Dec
	ADD	AL, 12		; 11 = Jan, 12 = Feb

;----------------------------------------------------------------------------;
; if Jan or Feb, decrement year (in BCD)
;
	XCHG	AX, CX		; AX = year (BCD)
	SUB	AL, 1			; decrement low digits
	DAS				; adjust for BCD
	XCHG	AH, AL		; swap high byte for DAS
	SBB	AL, 0			; if borrow, decrement high digits
	DAS				; adjust for BCD
	XCHG	AH, AL		; swap back
	XCHG	AX, CX		; CX = decremented year (BCD)

;----------------------------------------------------------------------------;
; + 13(m-2)/5
;
DOW_1:
	MOV	AH, 13
	MUL	AH			; AX = AL * 13
	DB	0D4H, 5		; AAM 10H ; AH = quotient
	XCHG	AH, AL		; AL = quotient
	;MOV	DL, 5			; alt use DIV instead of AAM imm
	;DIV	DL
	XOR	AH, AH		; zero extend AL
	ADD	BX, AX		; add to running sum	

;----------------------------------------------------------------------------;
; + K
;
	MOV	AL, CL		; K year
	CALL	BCD_TO_BYTE
	ADD	BX, AX		; add to running sum

;----------------------------------------------------------------------------;
; + K/4
;
	SHR	AX, 1			; K / 4
	SHR	AX, 1
	ADD	BX, AX		; add to running sum

;----------------------------------------------------------------------------;
; + J/4
;
	MOV	AL, CH		; J century
	CALL	BCD_TO_BYTE
	MOV	CX, AX		; save byte century
	SHR	AX, 1			; J / 4
	SHR	AX, 1
	ADD	BX, AX		; add to running sum
	XCHG	AX, CX		; restore byte century

;----------------------------------------------------------------------------;
; + 5*J
;
	ADD	BX, AX		; 1 * J
	SHL	AX, 1			; 2 * J
	SHL	AX, 1			; 2 * J
	ADD	AX, BX		; AX = final sum

;----------------------------------------------------------------------------;
; % 7
;
	CWD				; zero extend to DX
	MOV	BX, 7
	DIV	BX			; DX = DX:AX % 7
	XCHG	AX, DX		; AX = modulo

	POP	DX
	POP	CX
	POP	BX
	RET
DOW ENDP
			ENDIF

RTC_SW_PROC ENDP

OPTROM	ENDS
			ENDIF			; IFDEF RTC_SW
		END
