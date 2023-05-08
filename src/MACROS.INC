
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
; Unpack BCD - Split nibbles (packed BCD) in AL into AH/AL (unpacked BCD)
;----------------------------------------------------------------------------;
UNPACK_BCD	MACRO
	DB	0D4H, 10H		; AAM 10H
		ENDM

;----------------------------------------------------------------------------;
; Clear ISA bus before I/O port read
;----------------------------------------------------------------------------;
ISA_CLEAR	MACRO
	MOV	AL, 0FFH			; write all 1s to bus to clear buffer ICs
	OUT	0C0H, AL			; write to any unused port
		ENDM