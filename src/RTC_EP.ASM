	PAGE	 	59,132
	TITLE		GLaTICK_RTC_EP

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;----------------------------------------------------------------------------;
; RTC Support for MSM/Epson/Seiko RTC-58321 (Boca IO/XT22)
;
; TODO:
; - data validation?
;----------------------------------------------------------------------------;
INCLUDE	RTC.INC

			IFDEF RTC_EP
;----------------------------------------------------------------------------;
; Software compatibility Equates (do not edit here)
;
RTC_DRV_STD		EQU	1			; standard (BCD encoded year)
RTC_DRV_BOCA	EQU	2			; Boca driver (year uses 80-F9)
							; (this has a "Y2060 problem")

;----------------------------------------------------------------------------;
; Config
;----------------------------------------------------------------------------;
MULTI_READ		EQU	1			; use multiple reads instead of BUSY
							; for READ operations

;----------------------------------------------------------------------------;
; I/O Ports
;
ADDR_PORT		EQU	02C0H			; Address/Register port (only 2C0H)

;----------------------------------------------------------------------------;
; Driver Software compatibility: Uncomment to select
;
RTC_DRV_TYPE	EQU	RTC_DRV_STD		; standard
;RTC_DRV_TYPE	EQU	RTC_DRV_BOCA	; Boca driver

;----------------------------------------------------------------------------;
; END Config
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; RTC-58321/58323 Registers Indexes
;
EP_REG STRUC
R_SEC			DB	?			; 00H Seconds units register (0-9)
R_10SEC		DB	?			; 01H Seconds tens register (0-5)
R_MIN			DB	?			; 02H Minutes units register (0-9)
R_10MIN		DB	?			; 03H Minutes tens register (0-5)
R_HOUR		DB	?			; 04H Hours units register (0-9)
R_10HOUR		DB	?			; 05H Hours tens register (0-1 or 0-2), 24/12, AM/PM
R_WEEK		DB	?			; 06H Day-of-week register (0-6)
R_DAY			DB	?			; 07H Day units register
R_10DAY		DB	?			; 08H Day tens register, leap year
R_MON			DB	?			; 09H Month units register
R_10MON		DB	?			; 0AH Month tens register
R_YEAR		DB	?			; 0BH Year units register
R_10YEAR		DB	?			; 0CH Year tens register
R_RESET		DB	?			; 0DH Reset register
;R_REF		DB	2 DUP (?)		; 0EH-0FH Reference signal registers
EP_REG ENDS

;----------------------------------------------------------------------------;
; Register sizes - BCD packed
;----------------------------------------------------------------------------;
EP_SEC		RECORD	SECX:1, SEC10:3, SEC01:4
EP_MIN		RECORD	MINX:1, MIN10:3, MIN01:4
EP_HR			RECORD	HR24:1, HRAP:1, HR10:2, HR01:4; + 24/12/am/pm
EP_DATE		RECORD	DTLY:2, DT10:2, DT01:4		; + leap flag
EP_MON		RECORD	MNX1:3, MON10:1, MON01:4
EP_YR			RECORD	YR10:4, YR01:4
EP_DOW		RECORD	DWX:5, DOW:3			; 0=sun, etc

;----------------------------------------------------------------------------;
; EP_CMD: high 4 bits to READ/WRITE/STOP/BUSY, low 4 bits to address lines
;----------------------------------------------------------------------------;
; 76543210
; x			- EPBZ:	80H R _BUSY?
;  x			- EPREAD:	40H W READ
;   x			- EPWRITE:	20H W WRITE
;    x		- EPSTOP:	10H W STOP
;     xxxx 		- EPREG:	register address
;----------------------------------------------------------------------------;
EP_CMD		RECORD	EPBZ:1,EPREAD:1,EPWRITE:1,EPSTOP:1,EPREG:4

;----------------------------------------------------------------------------;
; EP_05H: 05H - packed 24/12, am/pm / hour tens unit
;----------------------------------------------------------------------------;
; 76543210
; 0000		- EP5X:	unused (always 0)
;     x 		- EP24:	1=24 hour, 0=12 hour (if 0, resets EPAP to 0)
;      x		- EPAP:	1=pm, 0=am
;       xx 		- EPH10:	Hour tens digit (0-2)
;----------------------------------------------------------------------------;
EP_05H		RECORD	EP5X:4, EP24:1, EPAP:1, EPH10:2

;----------------------------------------------------------------------------;
; EP_08H: 08H - packed leap year select/modulo, day tens unit
;----------------------------------------------------------------------------;
; 76543210
; 0000		- EP8X:	unused (always 0)
;     xx 		- EPLY:	Value module 4 for leap year (always 0)
;       xx 		- EPD10:	day tens digit (0-3)
;----------------------------------------------------------------------------;
EP_08H		RECORD	EP8X:4, EPLY:2, EPD10:2

;----------------------------------------------------------------------------;
; EP_RESET: RESET controller (0Fh)
;----------------------------------------------------------------------------;
; 76543210
; 0000		- RSX:	unused (always 0)
;     x 		- R1K:	1 Hz ON
;      x		- R16K: 	16 Hz ON
;       x 		- TRS:	Timer Reset
;        x		- ARS: 	Alarm Reset
;----------------------------------------------------------------------------;
;EP_RST		RECORD	RSX:4, R1K:1, R16K:1, TRS:1, ARS:1

INCLUDE	GLALIB.INC
INCLUDE 	MACROS.INC

;----------------------------------------------------------------------------;
; Start of segment
;----------------------------------------------------------------------------;
			ASSUME  DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	EP_DETECT
EXTRN		INT_1A_DEFAULT:NEAR, IRET_CF_1:NEAR
EXTRN		PACK_BCD:NEAR, UNPACK_BCD:NEAR

;----------------------------------------------------------------------------;
; RP Display string
;----------------------------------------------------------------------------;
STR_EP	DB	'58321 ', 0		; EP RTC-58321 POST display string

;----------------------------------------------------------------------------;
; INT 1A IVT for 58321 
;----------------------------------------------------------------------------;
INT_1A_EP PROC
	STI
	CMP	AH, 1					; is function 0 or 1?
	JBE	INT_1A_EP_BIOS			; if so, use default call
	CMP	AH, 5 				; is function supported?
	JBE	INT_1A_EP_1				; if not, use default call
INT_1A_EP_BIOS:
	JMP	NEAR PTR INT_1A_DEFAULT		; near jump to BIOS handler
INT_1A_EP_1:
	CLD
	PUSHX	BP, AX, BX
	SUB	SP, SIZE EP_REG			; allocate buffer
	MOV	BP, SP				; SS:BP = read/write buffer
	MOV	BX, AX				; save AX
	XCHG	AH, AL				; AL = function
	SHL	AL, 1					; word align index
	CBW						; AX = jump index
	XCHG	AX, BX				; restore AX, BX = jump offset
	CALL	CS:INT_1A_EP_JMP[BX][-4]	; adjust JMP offset (cannot be 0 or 1)
	LAHF						; preserve return flag
	ADD	SP, SIZE EP_REG			; deallocate buffer
	SAHF
	POPX	BX, AX
	JMP	NEAR PTR IRET_CF_1		; RET with previous flags and current CF

INT_1A_EP_JMP LABEL WORD
	DW	OFFSET EP_INT_1A_2		; AH = 2 - Read RTC
	DW	OFFSET EP_INT_1A_3		; AH = 3 - Set RTC Time
	DW	OFFSET EP_INT_1A_4		; AH = 4 - Read RTC Date
	DW	OFFSET EP_INT_1A_5		; AH = 5 - Set RTC Date

INT_1A_EP ENDP

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
;	DL = 1 if daylight savings time option (always 0)
;----------------------------------------------------------------------------;
EP_INT_1A_2 PROC
	CALL	EP_READ_TIME
	JC	EP_INT_1A_2_RET
	MOV	AX, WORD PTR [BP].R_SEC
	CALL	PACK_BCD
	CWD						; DL = DST (0)
	AND	AL, MASK SEC10 OR MASK SEC01
	MOV	DH, AL				; DH = packed seconds
	MOV	AX, WORD PTR [BP].R_MIN
	CALL	PACK_BCD
	AND	AL, MASK MIN10 OR MASK MIN01
	MOV	CL, AL				; CL = packed minutes
	MOV	AX, WORD PTR [BP].R_HOUR
	CALL	PACK_BCD

;----------------------------------------------------------------------------;
; check 24/12 and AM/PM flags and handle if 12 hours AND pm AND < 12H
;
	TEST	AL, MASK HR24			; test 24 hour in high nibble
	JNZ	EP_INT_1A_2_HR			; jump if 24 hour
	TEST	AL, MASK HRAP			; is pm?
	JZ	EP_INT_1A_2_HR			; jump if am

;----------------------------------------------------------------------------;
; handle 12 hour mode in PM
;
	CMP	AL, 12H OR MASK HRAP		; 12H PM = noon
	JAE	EP_INT_1A_2_HR			; jump if >= 12H
	ADD	AL, 12H				; is PM, add 12 hours
	DAA
EP_INT_1A_2_HR:
	AND	AL, MASK HR10 OR MASK HR01	; only important bits, CF=0
	MOV	CH, AL				; CH = packed hours
	;CLC
EP_INT_1A_2_RET:
	RET
EP_INT_1A_2 ENDP

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
EP_INT_1A_3 PROC
	PUSHX	CX, DX

;----------------------------------------------------------------------------;
; Load input into buffer
;
	MOV	AL, DH			; AL = BCD seconds
	CALL	UNPACK_BCD			; AL = packed -> AH/AL = unpacked BCD value
	MOV	WORD PTR [BP].R_SEC, AX

	MOV	AL, CL			; AL = BCD minutes
	CALL	UNPACK_BCD			; AL = packed -> AH/AL = unpacked BCD value
	MOV	WORD PTR [BP].R_MIN, AX

	MOV	AL, CH			; AL = BCD hours
	OR	AL, MASK EP24 SHL 4	; Set 24 hour mode
	CALL	UNPACK_BCD			; AL = packed -> AH/AL = unpacked BCD value
	MOV	WORD PTR [BP].R_HOUR, AX

;----------------------------------------------------------------------------;
; Write buffer to clock
;
	CALL	EP_WRITE_TIME		; write, CF if error
	POPX	DX, CX
	RET
EP_INT_1A_3 ENDP

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
EP_INT_1A_4 PROC
	CALL	EP_READ_DATE
	JC	EP_INT_1A_4_RET
	MOV	AX, WORD PTR [BP].R_SEC		; day
	CALL	PACK_BCD
	AND	AL, MASK DT10 OR MASK DT01	; remove leap year flag
	MOV	DL, AL
	MOV	AX, WORD PTR [BP].R_MIN		; month
	CALL	PACK_BCD
	MOV	DH, AL
	MOV	AX, WORD PTR [BP].R_HOUR	; year
	CALL	PACK_BCD				; AH/AL -> AL

;----------------------------------------------------------------------------;
; Adjust BCD date relative to 00 for century rollover
;
; Boca:
; 80 = 1980, A0 = 2000, F0 = 2050, 19 = 2079, (20-79H invalid)
;
; BCD:
; 00 = 1980, 19 = 1999, 20 = 2000, 70 = 2050, 99 = 2079 (A0-F9H invalid)
;
	XOR	AH, AH				; AH = 0
		IF RTC_DRV_TYPE EQ RTC_DRV_BOCA
	CMP	AL, 80H				; Boca, CF if > 2059
		ELSE
	ADD	AL, 80H				; BCD encoding
		ENDIF
	DAA						; BCD adjust, CF if 2000
	XCHG	AH, AL				; swap bytes
	ADC	AL, 19H				; century 19 or 20
	DAA						; BCD adjust, CF=0
	XCHG	AH, AL				; swap bytes back
	XCHG	AX, CX				; output to CH/CL
	;CLC
EP_INT_1A_4_RET:
	RET
EP_INT_1A_4 ENDP

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
EP_INT_1A_5 PROC
	PUSHX	CX, DX

;----------------------------------------------------------------------------;
; Load input into buffer
;
	MOV	AL, DH				; AL = BCD month
	CALL	UNPACK_BCD				; AL -> AH/AL
	MOV	WORD PTR [BP].R_MIN, AX		; (actually month)

	XCHG	AX, DX				; AL = BCD day
	AND	AL, MASK DT10 OR MASK DT01	; Leap year always 0 (Gregorian calendar)
	CALL	UNPACK_BCD				; AL -> AH/AL
	MOV	WORD PTR [BP].R_SEC, AX		; (actually day)

	XCHG	AX, CX				; AX = year
	ADD	AH, -20H				; CF if century 20H
	DAS						; convert century/year to tens-based century
							;  1985=85, 2025=C5
							; Note: this has a year 2060 problem!

		IF RTC_DRV_TYPE EQ RTC_DRV_STD
;----------------------------------------------------------------------------;
; Adjust Boca to BCD encoding
; 80 -> 00, 99 -> 19, A0 -> 20, F0 -> 70, 19 -> 99
;
	SUB	AL, 80H				; offset year relative to 1980
		ENDIF

	CALL	UNPACK_BCD				; AL -> AH/AL
	MOV	WORD PTR [BP].R_HOUR, AX	; (actually year)

;----------------------------------------------------------------------------;
; Write buffer to clock and exit
;
	CALL	EP_WRITE_DATE			; write date from buffer to RTC
	POPX	DX, CX
	RET
EP_INT_1A_5 ENDP


;----------------------------------------------------------------------------;
; MSM58321/RTC-58321/58323 Routines and notes
;----------------------------------------------------------------------------;
; The STOP pin is used to input on/off control for a 1 Hz signal.  When this pin
; goes to the H level, 1 Hz signals are inhibited and counting for all digits
; succeeding the S1 digit is stopped.  When this pin goes to the L level, normal
; operations are performed; the digits are counted up.  This STOP input controls
; stopping digit counting.  Writing of external data in digits can be assured by
; setting the STOP input to the H level to stop counting, then writing sequentially
; from the low-order digits.
;
; READ pin is used to read data; it is activated when it is at the H level.
; Address contents are latched with ADDRESS LATCH inside the IC at the D0~D3 and
; ADDRESS WRITE pins to select the object digit, then an H-level signal is input
; to the READ pin to read data.
; If a count operation is continued by setting the STOP input to the L level, read
; operation must be performed, in principle, while the BUSY output is at the H
; level.  While the BUSY output is at the L level, count operations are performed
; by digit counters and read data is not guaranteed, therefore, read operations are
; inhibited in this period.  Figure 2 shows a time chart of the BUSY output, 1 Hz
; signal inside the IC, and READ input.
; A read operation is stopped temporarily within a period of 244 µs from the BUSY
; output trailing edge and it is restarted when the BUSY output goes to the H level
; again.
;
; A read operation is enabled by microcomputer software regardless of the BUSY
; output during the counter operation by setting the STOP input to the L level.
; In this method, read operations are performed two or more times continuously
; and data that matches twice is used as guaranteed data.
;
; WRITE pin is used to write data; it is activated when it is at the H level.
; Data bus  data inside the IC is loaded to the object digit while this WRITE
; pin is at the H level, not at the WRITE input edge.
;----------------------------------------------------------------------------;
; Implementation note:
;
; Due to the relatively slow process of syncronizing to BUSY periods and
; timing requirements, data is read/written to/from a buffer from the RTC all
; at once per call.
;----------------------------------------------------------------------------;

;----------------------------------------------------------------------------;
; Detect 58321 on port 2C0H
;----------------------------------------------------------------------------;
; Test for 58321 by waiting for BUSY to go high then low within expected time.
;
; Note: Port 2C0H is used with multiple RTCs:
; - On Ricoh (RS), port 2C0H is write only, so reading will always return FFH
; - On MM58167AN (NS), port 2C0H is ms and low nibble is always 0
; - On DS12x85/MC146818 (AT), port 2C0H is ... ?
;----------------------------------------------------------------------------;
; Output:
;	NC if found, CF if not found
;	DI = offset of new INT 1A IVT
;	DX = port number
;	AL = RTC type (RTC_EP)
;----------------------------------------------------------------------------;
EP_DETECT PROC
	MOV	DX, ADDR_PORT
	CALL	EP_BUSY			; wait for a BUSY cycle
	JC	EP_DETECT_RET		; exit if not
	MOV	DI, OFFSET INT_1A_EP	; set DI only if detected
	MOV	SI, OFFSET STR_EP		; '58321' string
	MOV	AL, RTC_EP			; set RTC type
EP_DETECT_RET:
	RET
EP_DETECT ENDP

;----------------------------------------------------------------------------;
; Clear read/write/latch lines and wait for not busy
;----------------------------------------------------------------------------;
; Input:
;	DX = port address
; Output:
;	NC if success, CF if fail (busy never went from low to high)
;
; Clobbers: AL, BX
;----------------------------------------------------------------------------;
EP_BUSY PROC
	PUSH	CX
	XOR	AL, AL				; AL = 0, CF = 0
	OUT	DX, AL				; clear all latched signals
	XOR	CX, CX				; timeout for LOW wait
	MOV	BX, 10				; timeout for HI wait

;----------------------------------------------------------------------------;
; Wait for _BUSY to go low
;
EP_BUSY_WAIT:
	IN	AL, DX
	TEST	AL, MASK EPBZ
	LOOPNZ EP_BUSY_WAIT			; wait until timeout
	JZ	EP_BUSY_WAIT_DONE
	DEC	BX
	JNZ	EP_BUSY_WAIT
EP_BUSY_ERR:
	STC
	POP	CX
	RET

EP_BUSY_WAIT_DONE:
;----------------------------------------------------------------------------;
; Wait for _BUSY to go high again
;
	MOV	CH, 1					; should take no more than 100H
EP_BUSY_HIGH:
	IN	AL, DX
	TEST	AL, MASK EPBZ			; CF = 0
	LOOPZ EP_BUSY_HIGH			; wait until timeout
	JZ	EP_BUSY_ERR
	POP	CX
	RET

EP_BUSY ENDP

;----------------------------------------------------------------------------;
; Read all time bytes into buffer
;----------------------------------------------------------------------------;
; Input: SS:BP = start of buffer
; Output: 
; 	CF if invalid, NC if valid
;----------------------------------------------------------------------------;
EP_READ_TIME PROC
	MOV	AH, R_SEC
	MOV	CX, R_10HOUR - R_SEC + 1
	JMP	SHORT EP_READ

;----------------------------------------------------------------------------;
; Read all date bytes into buffer
;----------------------------------------------------------------------------;
EP_READ_DATE PROC
	MOV	AH, R_DAY
	MOV	CX, R_10YEAR - R_DAY + 1

;----------------------------------------------------------------------------;
; Read all bytes into buffer
;----------------------------------------------------------------------------;
; Input:
;	CX = number of bytes to read (1-13)
;	AH = starting register index
;	SS:BP = start of buffer
; Output:
;	NC if success, CF if error
;
; Clobbers: AX, CX, DX
;----------------------------------------------------------------------------;
EP_READ PROC
	MOV	DX, ADDR_PORT

			IF MULTI_READ EQ 1
	XOR	AL, AL				; AL = 0, CF = 0
	OUT	DX, AL				; clear all latched signals
			ELSE
	CALL	EP_BUSY				; wait for BUSY to go low then high
	JC	EP_RW_EXIT				; timeout waiting for BUSY change
			ENDIF

	PUSH	ES					; set up ES:DI for buffer in stack
	PUSH	DI
	MOV	DI, SS
	MOV	ES, DI
	MOV	DI, BP				; ES:DI = buffer start

;----------------------------------------------------------------------------;
; Set up RTC for read mode and select register
;
EP_READ_BYTES:
	MOV	AL, AH				; AL = next register index
	OR	AL, MASK EPSTOP			; set STOP
	OUT	DX, AL
	MOV	AL, AH
	OUT	DX, AL				; set register address
	MOV	AL, MASK EPREAD
	OUT	DX, AL				; set read register

;----------------------------------------------------------------------------;
; Short I/O delay (necessary if _BUSY?)
;
	PUSH	CX
	MOV	CL, 3
	IO_DELAY
	POP	CX

			IF MULTI_READ EQ 1
;----------------------------------------------------------------------------;
; Instead of waiting for BUSY, read byte multiple times and if data matches
; twice, it is "guaranteed data" (per datasheet).
;
	MOV	BX, DBW < 0AAH, 50 >		; BL = number of retries
							; BH = last read = AAH (unlikely)
READ_RETRY:
	IN	AL, DX
	CMP	AL, BH				; same as last?
	JE	READ_OK				; if indentical, data is good
	MOV	BH, AL				; otherwise, save last
	DEC	BL					; dec retry counter
	JNZ	READ_RETRY				; if counter > 0, continue
EP_RW_ERR:
	STC						; error, too many tries
	JMP	SHORT EP_RW_DONE

READ_OK:
			ELSE
;----------------------------------------------------------------------------;
; Read data once - already waited for BUSY
;
	IN	AL, DX
			ENDIF

	AND	AL, MASK EPREG			; only data nibble
	STOSB						; write to buffer
	INC	AH					; next register
	LOOP	EP_READ_BYTES

;----------------------------------------------------------------------------;
; Read loop complete, rebalance stack
;
EP_RW_DONE:
	POP	DI
	POP	ES

;----------------------------------------------------------------------------;
; Clear STOP and resume clock after operation complete
;
EP_RESUME PROC
	MOV	AL, R_WEEK OR MASK EPSTOP	; write to reg 6 with STOP
	OUT	DX, AL
	MOV	AL, R_WEEK				; clear latch
	OUT	DX, AL

EP_RW_EXIT:
	RET

EP_RESUME ENDP

EP_READ ENDP
EP_READ_DATE ENDP
EP_READ_TIME ENDP

;----------------------------------------------------------------------------;
; Write all time bytes from buffer
;----------------------------------------------------------------------------;
; Input: SS:BP = start of buffer
; Output: 
; 	CF if invalid, NC if valid ?
;
; Clobbers: AX, CX, DX
;----------------------------------------------------------------------------;
EP_WRITE_TIME PROC
	MOV	AH, R_SEC
	MOV	CX, R_10HOUR - R_SEC + 1
	JMP	SHORT EP_WRITE

;----------------------------------------------------------------------------;
; Write all date bytes from buffer
;----------------------------------------------------------------------------;
EP_WRITE_DATE PROC
	MOV	AH, R_DAY
	MOV	CX, R_10YEAR - R_DAY + 1

;----------------------------------------------------------------------------;
; Write all bytes from buffer
;----------------------------------------------------------------------------;
; Input:
;	CX = number of bytes to write (1-13)
;	AH = starting register index
;	SS:BP = start of buffer
; Output: ZF if success, NZ if error
; Clobbers: AX, CX, DX
;----------------------------------------------------------------------------;
EP_WRITE PROC
	MOV	DX, ADDR_PORT
	CALL	EP_BUSY				; wait for BUSY then ready
	JC	EP_RW_EXIT				; exit if error
	PUSH	SI
	MOV	SI, BP				; SS:SI = buffer start

;----------------------------------------------------------------------------;
; Set up write mode, load from buffer, write to RTC
;
EP_WRITE_BYTES:
	MOV	AL, AH
	OR	AL, MASK EPSTOP			; set STOP
	OUT	DX, AL
	MOV	AL, AH
	OUT	DX, AL				; set register index
	LODS	BYTE PTR SS:[SI]
	OR	AL, MASK EPWRITE			; set WRITE bit
	OUT	DX, AL
	AND	AL, NOT MASK EPWRITE		; remove WRITE bit
	OUT	DX, AL				; write register value
	INC	AH
	LOOP	EP_WRITE_BYTES			; next byte
	POP	SI
	JMP	SHORT EP_RESUME
EP_WRITE ENDP
EP_WRITE_DATE ENDP
EP_WRITE_TIME ENDP

OPTROM	ENDS
			ENDIF				; IFDEF RTC_EP
		END
