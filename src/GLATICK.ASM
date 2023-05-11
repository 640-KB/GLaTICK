	PAGE	 	59,132
	TITLE		GLaTICK

;----------------------------------------------------------------------------;
; GLaTICK (Generational Logic and Time Interval Cadence Keeper)
;
; A Real Time Clock Companion ROM.
;
; Copyright (c) 2022-2023, 640KB and contributors
;
;----------------------------------------------------------------------------;
;
; This program is free software: you can redistribute it and/or modify it under the terms 
; of the GNU General Public License as published by the Free Software Foundation, either 
; version 3 of the License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
; See the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along with this program. 
; If not, see <https://www.gnu.org/licenses/>.
;
;----------------------------------------------------------------------------;
; Supported Ports:
; - DS1285/MC146818: 	70h, *240h, 2A0h, *2C0h, *340h
; - MSM5832:		310h, 210h
; - MM58167:		*240h, *340h, *2C0h, 250h, *300h, 350h, 377h, 037Dh, 027Dh
; - RP5C15:			*2C0h
; - MSM6242:		2C0h, 240h, 250h, 300h, 340h, 350h
;
; TODO:
; - RTC Detection with overlapping port numbers: 240h, 2C0h, 340h
; - Other Clock Types:
;	- MSM-58321 (is different than 5832?):	2C0, 27E, 37E, 02A2-02A3?
;	- DS1216E/DS1315 "SmartWatch"
; - INT 1Ah services 6h and 7h (where supported)
;
; https://bochs.sourceforge.io/techspec/PORTS.LST
;
;----------------------------------------------------------------------------;
VER_NAME		EQU	'GLaTICK'
VER_NUM		EQU	'0.8.4'		; (max 6 chars)
VER_DATE		EQU	'05/11/23' 		; must be MM/DD/YY format
COPY_YEAR		EQU	'2023'

;----------------------------------------------------------------------------;
; Config
;----------------------------------------------------------------------------;
SHOW_BANNER		=	1			; always show full banner at POST
SHOW_RTC		=	1			; show detected RTC and clock
SHOW_CLOCK		=	1			; if above, show date/time at POST

MAGIC_WORD		EQU	0AA55H		; Magic Word used for option ROM
ROM_SIZE		EQU	800H			; size of ROM (2K)

;----------------------------------------------------------------------------;
; POST clock display format
;----------------------------------------------------------------------------;
DATE_FMT		=	3			; 0 = MM/DD/YY (Ye Olde BIOS style)
							; 1 = MM/DD/YYYY (Y2K Olde BIOS)
							; 2 = YY-MM-DD (ISO short)
							; 3 = YYYY-MM-DD (ISO)
TIME_SEC		=	0			; 1 = HH:MM:SS, 0 = HH:MM only

;----------------------------------------------------------------------------;
; Date/time display formatting based on display config
;
		IF DATE_FMT LT 2
DATE_SEP		=	'/'			; '/' date separator
TIME_FMT		=	1			; 1 = 12 hour
		ELSE
DATE_SEP		= 	'-'			; '-' date separator
TIME_FMT		=	0			; 0 = 24 hour
		ENDIF
TIME_SEP		= 	':'			; ':' time separator

INCLUDE 	RTC.INC
INCLUDE	GLALIB.INC
INCLUDE 	MACROS.INC
INCLUDE 	SEGS.INC

;----------------------------------------------------------------------------;
; Option ROM begins
;----------------------------------------------------------------------------;
			ASSUME DS:OPTROM, SS:OPTROM, CS:OPTROM, ES:OPTROM
OPTROM	SEGMENT BYTE PUBLIC 'CODE'

PUBLIC	INT_1A_DEFAULT, IS_LEAP, LEAP_NEXT, GET_RTC, STR_CRLF
PUBLIC	PACK_BCD, UNPACK_BCD, BCD_TO_WORD, BCD_TO_BYTE, BYTE_TO_BCD

EXTRN		OUT_CHAR:NEAR, OUT_SZ_ATTR:NEAR, OUT_SZ:NEAR, OUT_SZ_NL:NEAR
EXTRN		WORD_HEX:NEAR, BYTE_HEX:NEAR
EXTRN		POST_START_COL_1:NEAR, POST_START_COL_2:NEAR
EXTRN		POST_END_COL:NEAR, POST_END_COL_NL:NEAR, IS_GLABIOS:NEAR

;----------------------------------------------------------------------------;
; Option ROM Header
;----------------------------------------------------------------------------;
			ORG	0000H
ROM_HEADER	PROC FAR
	DW	MAGIC_WORD				; ROM magic number
	DB	ROM_SIZE / 512			; ROM size (512 byte blocks)
ROM_HEADER	ENDP

;----------------------------------------------------------------------------;
; INIT procedure called during POST
;----------------------------------------------------------------------------;
			ORG	0003H			; fixed offset for INIT
ROM_INIT	PROC
	PUSHF
	PUSH	AX					; preserve all registers
	PUSH	DS
	MOV	AX, SEG _BDA 			; CX = BDA segment, CH = 0
	MOV	DS, AX 				; DS = BDA
			ASSUME DS:_BDA	
	CMP	RTC_DATA, 0				; already been set up?
	JNZ	DETECT_EXIT				; exit if so
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	ES

			IF SHOW_BANNER EQ 1
;----------------------------------------------------------------------------;
; Optionally display a GLaTICK banner
;
	CALL	IS_GLABIOS				; is GLaBIOS?
	JZ	DETECT_RTCS				; if so, don't display banner
	PRINTLN_SZ VER_BANNER			; otherwise display it
			ENDIF

;----------------------------------------------------------------------------;
; Detect Supported RTCs
;----------------------------------------------------------------------------;
DETECT_RTCS:

			IFDEF RTC_AT
;----------------------------------------------------------------------------;
; Check for AT port 70H, 240H, 2C0H: MC146818, DS12x85
;----------------------------------------------------------------------------;
EXTRN		AT_DETECT:NEAR
DETECT_AT:
	CALL	AT_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_AT		; 'AT' string
	JZ	DETECT_SET
			ENDIF		

			IFDEF RTC_NS
;----------------------------------------------------------------------------;
; Check for NS MM58167AN: SixPakPlus V1, generic I/O boards
; AL = RTC_NS (direct) or RTC_NS2 (latched)
;----------------------------------------------------------------------------;
EXTRN		NS_DETECT:NEAR
DETECT_NS:
	CALL	NS_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_NS		; '58167' string
	JZ	DETECT_SET
			ENDIF

			IFDEF RTC_RP
;----------------------------------------------------------------------------;
; Check for RP5C15: SixPakPlus V2
;----------------------------------------------------------------------------;
EXTRN		RP_DETECT:NEAR
DETECT_RP:
	CALL	RP_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_RP		; 'RP5C15' string
	JZ	DETECT_SET
			ENDIF

			IFDEF RTC_OK2
;----------------------------------------------------------------------------;
; Check for MSM6242: Above Board, others
;----------------------------------------------------------------------------;
EXTRN		OK2_DETECT:NEAR
DETECT_OK2:
	CALL	OK2_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_OK2	; '6242' string
	JNC	DETECT_SET
			ENDIF

			IFDEF RTC_OK
;----------------------------------------------------------------------------;
; Check for MSM5832: Quadram, DTK PII-125
;----------------------------------------------------------------------------;
EXTRN		OK_DETECT:NEAR
DETECT_OK:
	CALL	OK_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_OK		; '5832' string
	JNC	DETECT_SET
			ENDIF

			IFDEF RTC_SW
;----------------------------------------------------------------------------;
; Check for DS-1216x "SmartWatch" (incomplete)
;----------------------------------------------------------------------------;
EXTRN		SW_DETECT:NEAR
DETECT_SW:
	CALL	SW_DETECT			; DI = new IVT, AL = RTC type, DX = port
	MOV	SI, OFFSET STR_SW		; 'DS1216' string
	JNC	DETECT_SET
			ENDIF

;----------------------------------------------------------------------------;
; No RTC was detected
;
DETECT_NONE:
	MOV	SI, OFFSET STR_NONE	; 'None' string
	XOR	DI, DI			; DI = 0 means not detected
	JMP	SHORT	DETECT_DONE		; done detecting RTCs and none found

;----------------------------------------------------------------------------;
; RTC was detected - set up IVT and BDA
;----------------------------------------------------------------------------;
				ASSUME DS:_BDA
DETECT_SET:
	PUSH	DX				; save DX port
	CALL	SETUP_RTC			; set RTC type and port DX
	POP	DI				; DI = detected port

;----------------------------------------------------------------------------;
; Read and validate date
;
	MOV	AH, 4				; read RTC date, CF if error
	INT	1AH				; CH=century, CL=year, DH=month, DL=day in BCD

			IF RESET_ON_ERROR NE 1
	JC	DETECT_DONE			; do not set BIOS clock if failure
			ELSE
	JC	DETECT_RESET		; if read error, reset date to 1980-01-01
	CALL	VALIDATE_DATE		; validate date
	JC	DETECT_RESET		; if not valid, reset clock
			ENDIF

;----------------------------------------------------------------------------;
; Read and validate time
;
	MOV	AH, 2				; read RTC, CF if error
	INT	1AH				; CH=hours, CL=mins, DH=sec, DL=dst in BCD

			IF RESET_ON_ERROR NE 1
	JC	DETECT_DONE			; do not set BIOS clock if failure
			ELSE
	JC	DETECT_RESET		; if read error, reset time to 00:00:00
	CALL	VALIDATE_TIME		; validate time
	JC	DETECT_RESET		; if not valid, reset clock
			ENDIF

;----------------------------------------------------------------------------;
; Date and time valid - set BIOS ticks
;
	CALL	BCD_TIME_TO_TICKS		; set BIOS time/clock from BCD values
	MOV	AH, 1
	INT	1AH
	MOV	DL, 1				; set "time is valid" flag (DL=1)

DETECT_DONE:
			IF SHOW_RTC EQ 1
	CALL	PRINT_DETECTED		; display on POST screen
			ENDIF
	POP	ES				; restore all regs
	POP	DI
	POP	SI
	POP	DX
DETECT_EXIT:
	POP	DS
	POP	AX
	POPF
	RETF					; return from option ROM init call

			IF RESET_ON_ERROR EQ 1
;----------------------------------------------------------------------------;
; If clock was in error state, reset to 1980-01-01 00:00:00 so clock
; is in running state for DOS to allow initial date/time set.
;
DETECT_RESET:
	MOV	AH, 5					; reset date if error
	MOV	CX, 1980H				; default to beginning of time
	MOV	DX, 0101H				; Jan 01
	INT	1AH

	MOV	AH, 3					; reset time to 00:00:00
	CWD						; DX = 0
	MOV	CX, DX				; CX = 0
	INT	1AH
				IF SHOW_RTC EQ 1
;----------------------------------------------------------------------------;
; Force 'Error' message since clock was reset
;
	CWD						; clear "time is valid" flag (DL=0)
				ENDIF			; END IF SHOW_RTC
	JMP	SHORT DETECT_DONE
			ENDIF				; END IF RESET_ON_ERROR

;----------------------------------------------------------------------------;
; Print detected clock type and I/O port (if enabled)
;----------------------------------------------------------------------------;
; Input:
;	DI = port
;	CS:[SI] = string of RTC type name
;	DL = valid flag: 1 = display time, 0 = print 'Error'
;----------------------------------------------------------------------------;
PRINT_DETECTED PROC
	POST_COL_1	STR_RTC, POST_CLR_VAL2, 1	; display 'RTC' row label
	CALL	OUT_SZ				; display RTC name in SI
	TEST	DI, DI				; port number zero?
	JZ	RTC_DONE				; if zero, do not display
	MOV	AX, DI				; AX = port number to display
	TEST	AH, AH				; if port is < 100H, show only 
	JZ	PORT_BYTE				;  two digits
	CALL	WORD_HEX				; display port as WORD
	JMP	SHORT PORT_DONE
PORT_BYTE:
	CALL	BYTE_HEX				; display port as BYTE
PORT_DONE:

			IF SHOW_CLOCK EQ 1
;----------------------------------------------------------------------------;
; Show the date/time on POST screen (if enabled)
;----------------------------------------------------------------------------;
PRINT_DATETIME PROC
	CALL	POST_END_COL			; end first column
	POST_COL_2	STR_CLK, POST_CLR_VAL2	; start second column

;----------------------------------------------------------------------------;
; Check if clock was previously in error and reset
;
	TEST	DL, DL				; if DL = 0, Error flag
	JZ	RTC_PRINT_ERR			; display 'Error'

;----------------------------------------------------------------------------;
; Re-read time
;
	MOV	AH, 2					; get time from RTC
	INT	1AH
	JC	RTC_PRINT_ERR			; if error, display 'Error'
	PUSH	DX					; save time
	PUSH	CX

;----------------------------------------------------------------------------;
; Re-read date
;
	MOV	AH, 4					; get date from RTC
	INT	1AH
	JNC	RTC_PRINT_DATE			; if no error, print date/time
	POP	CX					; discard date and time values
	POP	DX
RTC_PRINT_ERR:
	MOV	SI, OFFSET STR_ERR		; print 'Error' message
	CALL	OUT_SZ
	JMP	SHORT RTC_DONE			; end column and exit

;----------------------------------------------------------------------------;
; Print Date
;----------------------------------------------------------------------------;
RTC_PRINT_DATE:

;----------------------------------------------------------------------------;
; If big-endian date, display year first
;
		IF DATE_FMT GT 1			; IF big endian date
	XCHG	AX, CX				; year as BCD
			IF DATE_FMT EQ 2		; 2 digit year
	CALL	BYTE_HEX
			ELSE
	CALL	WORD_HEX				; 4 digit year
			ENDIF
	MOV	AL, DATE_SEP
	CALL	OUT_CHAR
		ENDIF					; END big endian date

;----------------------------------------------------------------------------;
; Display month
;
	MOV	AL, DH				; month as BCD
	CALL	BYTE_HEX
	MOV	AL, DATE_SEP
	CALL	OUT_CHAR

;----------------------------------------------------------------------------;
; Display day
;
	MOV	AL, DL				; day as BCD
	CALL	BYTE_HEX

;----------------------------------------------------------------------------;
; If middle-endian date, display year last
;
		IF DATE_FMT LT 2			; IF middle-endian date
	MOV	AL, DATE_SEP
	CALL	OUT_CHAR		
	XCHG	AX, CX				; year as BCD
			IF DATE_FMT EQ 0		; 2 digit year
	CALL	BYTE_HEX
			ELSE
	CALL	WORD_HEX				; 4 digit year
			ENDIF
		ENDIF					; END middle-endian date

;----------------------------------------------------------------------------;
; Display a space to separate date and time
;
	MOV	AL, ' '
	CALL	OUT_CHAR

	POP	CX					; restore time
	POP	DX

;----------------------------------------------------------------------------;
; Print Time
;----------------------------------------------------------------------------;
	MOV	AL, CH				; AL = BCD hours
		IF TIME_FMT EQ 1			; 12 hour time
	CMP	AL, 12H				; is noon or before?
	JLE	TIME_12_DONE			; jump if so
	SUB	AL, 12H				; otherwise subtract 12
	DAS						; BCD adjust subtraction
TIME_12_DONE:
		ENDIF

;----------------------------------------------------------------------------;
; Display hours
;
	CALL	BYTE_HEX				; write BCD digit in AL
	MOV	AL, TIME_SEP			; time separator
	CALL	OUT_CHAR

;----------------------------------------------------------------------------;
; Display minutes
;
	MOV	AL, CL
	CALL	BYTE_HEX

		IF TIME_SEC EQ 1			; END IF seconds shown
;----------------------------------------------------------------------------;
; Display seconds
;
	MOV	AL, TIME_SEP			; time separator
	CALL	OUT_CHAR
	MOV	AL, DH
	CALL	BYTE_HEX
		ENDIF

		IF TIME_FMT EQ 1			; END IF 12 hour time
;----------------------------------------------------------------------------;
; If 12 hour time, display a/p
;
	MOV	AL, 'a'
	CMP	CH, 12H				; hours > 12?
	JL	TIME_12_DONE_1			; if not, leave 'a'
	MOV	AL, 'p'				; otherwise, change to 'p'
TIME_12_DONE_1:
	CALL	OUT_CHAR
		ENDIF					; END IF 12 hour time

PRINT_DATETIME ENDP
			ENDIF				; END IF SHOW_CLOCK EQ 1

RTC_DONE:
	JMP	POST_END_COL_NL			; end column and RET

PRINT_DETECTED ENDP

ROM_INIT	ENDP					; end of option ROM init

;----------------------------------------------------------------------------;
; Set up IVT, Port and RTC type
;----------------------------------------------------------------------------;
; Input:
;	AL = RTC type
;	DX = port
;	DI = new INT 1Ah
;
; Clobbers: AX, DX
;----------------------------------------------------------------------------;
				ASSUME DS:_BDA
SETUP_RTC PROC
	PUSH	DS
	PUSH	CX
	PUSHF						; save IF
	CLI						; no interrupts while writing IVT

;----------------------------------------------------------------------------;
; Set in BDA
;
	MOV	CL, RTTYPE-8			; nibble size shift
	SHL	AL, CL				; shift type to high nibble
	XCHG	AX, DX				; AX = port
	AND	AX, MASK RTPORT			; clear any old RTC type
	OR	AH, DL				; set new RTC type
	MOV	RTC_DATA, AX			; save to BDA

;----------------------------------------------------------------------------;
; Set in IVT - important that this is run only once!
;----------------------------------------------------------------------------;
; Re-vector the existing INT 1Ah.  Each RTC's ISR will handle
; AH function 2-5 (or 7), otherwise it will call the previous 1Ah.
;
; Alternative:
; http://www.ctyme.com/intr/int-4c.htm
;
; The relocated INT can be changed in SEGS.INC
; http://ctyme.com/intr/int.htm
;----------------------------------------------------------------------------;
				ASSUME DS:_IVT
	XOR	AX, AX
	MOV	DS, AX				; DS = IVT
	LES	AX, _INT_1AH			; ES:AX = current INT 1Ah
	MOV	_INT_1AH_BIOS_OFF, AX		; Save previous BIOS INT 1A
	MOV	_INT_1AH_BIOS_SEG, ES
	MOV	_INT_1AH_OFF, DI			; Set up new INT 1Ah
	MOV	_INT_1AH_SEG, CS

SETUP_RTC_EXIT:
				ASSUME DS:_BDA
	POPF						; restore IF
	POP	CX
	POP	DS
	RET
SETUP_RTC ENDP

;----------------------------------------------------------------------------;
; Get Detected Port and RTC type from BDA
;----------------------------------------------------------------------------;
; Output:
;	DI = port
;	AL = RTC type (high nibble)
;	ZF if no RTC, NZ if port was not detected during POST
;----------------------------------------------------------------------------;
GET_RTC PROC NEAR
	PUSH	DS
	MOV	AX, SEG _BDA 			; get BDA segment
	MOV	DS, AX 				; DS = BDA
	MOV	AX, RTC_DATA
	MOV	DI, AX
	AND	DI, MASK RTPORT			; DI = RTC port
	MOV	AL, AH
	AND	AL, MASK RTTYPE SHR 8		; AL (high nibble) = RTC type
	POP	DS
	RET
GET_RTC ENDP

;----------------------------------------------------------------------------;
; INT 1A - Use existing BIOS function
;----------------------------------------------------------------------------;
INT_1A_DEFAULT PROC NEAR
	INT	INT_1A_BIOS				; use BIOS function instead
	IRET						; clobber BIOS INT 1Ah flags and IRET
INT_1A_DEFAULT ENDP

;----------------------------------------------------------------------------;
; Convert packed four digit BCD to WORD
;----------------------------------------------------------------------------;
; Input:
;	AX = BCD value
; Output:
;	AX = WORD value
;----------------------------------------------------------------------------;
BCD_TO_WORD PROC
	PUSH	BX
	MOV	BX, AX		; save input
	CALL	BCD_TO_BYTE		; convert low byte
	XCHG	AX, BX		; BL = low byte
	MOV	AL, AH		; AL = high byte
	CALL	BCD_TO_BYTE		; AL = convert high byte
	MOV	BH, 100		; multiply by 100
	MUL	BH			; AX = high BCD * 100
	XOR	BH, BH		; zero extend BL
	ADD	AX, BX		; add high BCD byte to sum
	POP	BX
	RET
BCD_TO_WORD ENDP

;----------------------------------------------------------------------------;
; Convert packed two digit BCD to BYTE
;----------------------------------------------------------------------------;
; Input:
;	AL = BCD value
; Output:
;	AL = BYTE value
; Clobbers: AH
;----------------------------------------------------------------------------;
BCD_TO_BYTE PROC
	CALL	UNPACK_BCD		; split nibbles in AL into BCD in AH/AL
	AAD				; AL = unpacked BCD nibbles into decimal
	RET
BCD_TO_BYTE ENDP

;----------------------------------------------------------------------------;
; Convert packed BCD to unpacked BCD
;----------------------------------------------------------------------------;
; Input:
;	AL = packed BCD value
; Output:
;	AH/AL = unpacked BCD value
;----------------------------------------------------------------------------;
UNPACK_BCD PROC
	UNPACK_NIB			; unpack nibbles
	RET
UNPACK_BCD ENDP

;----------------------------------------------------------------------------;
; Convert BYTE to packed BCD
;----------------------------------------------------------------------------;
; Input:
;	AL = BYTE value
; Output:
;	AL = BCD value
; Clobbers: AH
;----------------------------------------------------------------------------;
BYTE_TO_BCD PROC
	AAM				; split nibbles to AH / AL

;----------------------------------------------------------------------------;
; Convert unpacked BCD to packed BCD
;----------------------------------------------------------------------------;
; Input:
;	AH/AL = Unpacked BCD value
; Output:
;	AL = Packed BCD value, CF = 0
; Clobbers: AH
;----------------------------------------------------------------------------;
PACK_BCD PROC
	PACK_NIB			; pack nibbles
	RET
PACK_BCD ENDP
BYTE_TO_BCD ENDP

;----------------------------------------------------------------------------;
; Convert BCD to byte values
;----------------------------------------------------------------------------;
; Input:
;	CH = hour (byte NOT BCD)
;	CL = minute
;	DH = second
; Output:
;	CX:DX = ticks
;
; Clobbers: AX, DI
;----------------------------------------------------------------------------;
BCD_TIME_TO_TICKS PROC
	XCHG	AL, CH			; convert BCD hours to BYTE
	CALL	BCD_TO_BYTE
	XCHG	AL, CH

	XCHG	AL, CL			; convert BCD minutes to BYTE
	CALL	BCD_TO_BYTE
	XCHG	AL, CL

	XCHG	AL, DH			; convert BCD seconds to BYTE
	CALL	BCD_TO_BYTE
	XCHG	AL, DH	

;----------------------------------------------------------------------------;
; Convert time to ticks
;----------------------------------------------------------------------------;
; Input: (bytes NOT BCD)
;	CH = hour
;	CL = minute
;	DH = second
; Output:
;	CX:DX = ticks
; Clobbers: AX
;----------------------------------------------------------------------------;
TIME_TO_TICKS PROC
	PUSH	DI
	MOV	DL, DH			; DL = second
	XOR	DH, DH			; DX = second (zero extend DL)
	MOV	DI, DX			; DI = second

;----------------------------------------------------------------------------;
; Convert time components to seconds
;
	MOV	AL, 60			; convert hours to minutes
	MUL	CH				; AX = hour in minutes
	MOV	CH, DH			; CX = minute (zero extend CL)
	ADD	AX, CX			; AX = total minutes (hour + min)
	MOV	CL, 60			; convert minutes to seconds
	MUL	CX				; DX:AX = total seconds (hour + min)
	ADD	AX, DI			; add second to sum
	ADC	DX, 0				; carry to high word

;----------------------------------------------------------------------------;
; Convert Ticks = seconds * 1193180 / 65536
;
; This is a 21 bit x 17 bit multiply, which can be simplified for 16 bit
; operations by adjusting to a 22 x 16 bit multiply using the following: 
;	A*B == A/2 * B*2 + B[A is odd]
;
	SHR	DX, 1				; divide seconds by 2 to fit in word
	RCR	AX, 1				; shift into high bit of low word
	PUSHF					; save CF if odd
	XCHG	AX, DI			; DI = low total seconds (hour + min)
	MOV	AX, 34DCH * 2		; low ( 1193180 * 2 )
	MUL	DI				; DX:AX = low ( ticks * 2 ) * sec / 2
	POPF					; restore CF
	JNC	TTT_EVEN_SEC		; skip if even
	ADD	AX, 34DCH			; add 1 second of ticks if an odd second
	ADC	DX, 12H			;  was shifted off
TTT_EVEN_SEC:
	MOV	CX, DX			; CX:AX = working product
	MOV	AX, 12H * 2			; high ( 1193180 * 2 )
	MUL	DI				; DX:AX = high ( ticks * 2 ) * sec / 2
	ADD	CX, AX			; add working products
	ADC	DX, 0				; carry to high word
	XCHG	DX, CX			; move to CX:DX
	POP	DI
	RET
TIME_TO_TICKS ENDP
BCD_TIME_TO_TICKS ENDP

;----------------------------------------------------------------------------;
; Is leap year in next 12 months?
;----------------------------------------------------------------------------;
; Input: AX = year, CH = month
; Output: ZF if leap, NZ if not leap
; Clobbers AX, BX
;----------------------------------------------------------------------------;
LEAP_NEXT PROC
	CMP	CH, 3 			; is Mar - Dec?
	JL	IS_LEAP 			; if so, check if NEXT year is a leap
	INC	AX

;----------------------------------------------------------------------------;
; Is a leap year?
;----------------------------------------------------------------------------;
; Input: AX = year
; Output: 
;	ZF if leap, NZ if not leap
;	AL = leap counter (0 = leap year, 1-3 = non-leap year)
;----------------------------------------------------------------------------;
IS_LEAP PROC
	MOV	BL, 100			; divide by 100 to split year
	DIV	BL				; AL = first two digits, AH = last two
	XCHG	AL, AH			; look at last two digits
	TEST	AL, AL			; year ends in 00?
	JNZ	LEAP_MOD4			; if so, use mod of first two
	XCHG	AL, AH			; look at first two digits
LEAP_MOD4:
	AND	AL, 3     			; mod 4 = 0?
	RET

IS_LEAP ENDP
LEAP_NEXT ENDP

;----------------------------------------------------------------------------;
; Validate BCD time: 00:00:00-23:59:59
;----------------------------------------------------------------------------;
; Input:
;	CH = Hours (BCD)
;	CL = Minutes (BCD)
;	DH = Seconds (BCD)
; Output:
;	CF = 1 if error
; Clobbers: AX
;----------------------------------------------------------------------------;
VALIDATE_TIME PROC
	MOV	AL, CH
	CALL	BCD_TO_BYTE				; AL = BYTE hours
	CMP	AL, 24 + 1				; hours > 24?
	JAE	VAL_TIME_RET			; if so, invalid
	MOV	AL, CL
	CALL	BCD_TO_BYTE				; AL = BYTE minutes
	CMP	AL, 59 + 1				; minutes > 59?
	JAE	VAL_TIME_RET			; if so, invalid
	MOV	AL, DH
	CALL	BCD_TO_BYTE				; AL = BYTE seconds
	CMP	AL, 59 + 1				; seconds > 59?
VAL_TIME_RET:
	CMC
	RET
VALIDATE_TIME ENDP

;----------------------------------------------------------------------------;
; Validate BCD date: year (1980-2079), month (1-12) and day (1-31)
;----------------------------------------------------------------------------;
; Check that clock is in valid state and returing sane values.
; Does not check days in month or leap year.
;
; Input:
;	CX = Year (BCD)
;	DH = Month (BCD)
;	DL = Day (BCD)
; Output:
;	CF = 1 if error
; Clobbers: AX
;----------------------------------------------------------------------------;
VALIDATE_DATE PROC

;----------------------------------------------------------------------------;
; Validate year is 1980-2079
;
CHECK_YYYY:
	MOV	AX, CX				; AX = year as BCD
	CALL	BCD_TO_WORD				; AX = year as WORD
	CMP	AX, 1980				; is < 1980?
	JB	VAL_DATE_RET			; if so, invalid (CF)
	CMP	AX, 2079				; is > 2079?
	JA	VAL_DATE_ERR			; if so, invalid (NC)

;----------------------------------------------------------------------------;
; Validate month is 01-12
;
CHECK_MONTH:
	MOV	AL, DH				; AL = BCD month
	CALL	BCD_TO_BYTE				; AL = BYTE month
	TEST	AL, AL				; is 0?
	JZ	VAL_DATE_ERR			; if so, not valid (ZF)
	CMP	AL, 12				; is > 12?
	JA	VAL_DATE_ERR			; if so, not valid (NC)

;----------------------------------------------------------------------------;
; Validate day is 01-31
;
CHECK_DAY:
	MOV	AL, DL				; AL = BCD day
	CALL	BCD_TO_BYTE				; AL = BYTE day
	TEST	AL, AL				; is 0?
	JZ	VAL_DATE_ERR			; if so, not valid
	CMP	AL, 31				; is <= 31?
	CMC						; if not, not valid (CF)
VAL_DATE_RET:
	RET						; return with current CF
VAL_DATE_ERR:
	STC						; return with CF = 1
	RET

VALIDATE_DATE ENDP

;----------------------------------------------------------------------------;
; Strings
;----------------------------------------------------------------------------;
				IF SHOW_BANNER EQ 1
VER_BANNER	DB	CR, LF
		DB	VER_NAME, ' [', HEART, '] '
		DB	"It's About Time"
		DB	CR, LF
		DB	'Ver: '
				ELSE
		DB	VER_NAME, ' '		; embed name and version
				ENDIF
		DB	VER_NUM, ' '
		DB	'(C) '
		DB	COPY_YEAR
		DB	' 640KB Released under GPLv3'
STR_CRLF	DB	CR, LF, 0
STR_RTC	DB	'RTC', 0
STR_CLK	DB	'Clock', 0
STR_ERR	DB	'Error', 0

;----------------------------------------------------------------------------;
; RTC type display
;
STR_NONE	DB	'None', 0
			IFDEF RTC_AT
STR_AT	DB	'AT ', 0			; AT = DS1285/MC146818
			ENDIF
			IFDEF RTC_OK
STR_OK	DB	'5832 ', 0			; OK = MSM5832/1
			ENDIF
			IFDEF RTC_OK2
STR_OK2	DB	'6242 ', 0			; OK2 = MSM6242
			ENDIF
			IFDEF RTC_RP			
STR_RP	DB	'RP5C15 ', 0		; RP = RP5C15
			ENDIF
			IFDEF RTC_SW
STR_SW	DB	'DS1216 ', 0		; SW = DS1216x
			ENDIF
			IFDEF RTC_NS
STR_NS	DB	'58167 ', 0			; NS = MM58167AN
			ENDIF

;----------------------------------------------------------------------------;
; END of ROM
;----------------------------------------------------------------------------;
OPTROM	ENDS
		END

----------------------------------------------------------------------------
Text Auto-Formatting:

----------------------------------------------------------------------------
Sublime Text syntax:
{
 	"tab_completion": false,
	"auto_complete": false,
	"tab_size": 6,
}

----------------------------------------------------------------------------
Modeline magic for various editors

/* vim: set tabstop=6:softtabstop=6:shiftwidth=6:noexpandtab */
# sublime: tab_completion false; auto_complete false; tab_size 6
