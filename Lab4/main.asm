;
; Lab4.asm
;
; Created: 04/03/2023 9:49:10 PM
; Author : stlondon, mpass
;

.include "m328Pdef.inc"
.cseg
.org 0


.equ LCD_DATA_PORT = PORTC
.equ LCD_DATA_DDR = DDRC
.equ LCD_DATA_D4 = 0
.equ LCD_DATA_D5 = 1
.equ LCD_DATA_D6 = 2
.equ LCD_DATA_D7 = 3
.equ LCD_RS_PORT = PORTB
.equ LCD_RS_DDR = DDRB
.equ LCD_RS = 5 ; RS is PB5 (Pin 13)
.equ LCD_EN_PORT = PORTB
.equ LCD_EN_DDR = DDRB
.equ LCD_EN = 3 ; Enable is PB3 (Pin 11)
.equ PWM_DDR = DDRD
.equ PWM_pin = 5; PWM is PD5 (Pin 5)


.equ RPG0=2			; RPG0 is PD2 (Pin 2)
.equ RPG1=3			; RPG1 is PD3 (Pin 3)
.equ BUTTON=4		; BUTTON is PD4 (Pin 4)

.def fan = r23

; --- Data-direction register setup ---
; Inputs
cbi DDRD, BUTTON	; Set BUTTON0 (PB3/Pin 11) as input
cbi DDRD, RPG0		; Set RPG0 (PD2/Pin 2) as input
cbi DDRD, RPG1		; Set RPG1 (PD3/Pin 3) as input
; LCD Pins
sbi LCD_DATA_DDR, LCD_DATA_D4 ; Set LCD_DATA_D4 as output
sbi LCD_DATA_DDR, LCD_DATA_D5 ; Set LCD_DATA_D5 as output
sbi LCD_DATA_DDR, LCD_DATA_D6 ; Set LCD_DATA_D6 as output
sbi LCD_DATA_DDR, LCD_DATA_D7 ; Set LCD_DATA_D7 as output
sbi LCD_RS_DDR, LCD_RS ; Set LCD_RS as output
sbi LCD_EN_DDR, LCD_EN ; Set LCD_EN as output 
sbi PWM_DDR, PWM_pin ; Set PWM_pin as output

cbi LCD_EN_PORT, LCD_EN ; Ensure default state of EN is low
ldi fan, 1 ; Fan is on by default
ldi r25, 99; Default backup value of PWM signal 49%

; --- Setup ---
rcall LCD_init
rcall PWM_init

/*
ldi r16, 0xC0 ; Send to 2nd line
rcall send_instruction

ldi r16, 'E'
rcall send_data
*/

rcall display_status

; --- Loop ---
start:

	; 1. Check for button press
    sbis PIND, BUTTON
	rcall wait_for_release_button
	
	; 2. Read RPG
	rcall read_rpg

    rjmp start


wait_for_release_button:
; Note: Button is Active-Low. So I/O bit will be set when released.
	cpi fan, 1
	breq turn_fan_off
	; Fan is Off. Turn on.
turn_fan_on:
	ldi r16, (1<<WGM00)|(1<<WGM01)|(1<<COM0B1) ; Turn to normal output.
	out TCCR0A, r16
	out OCR0B, r25
	ldi fan, 1
	rcall display_status ; Now that Fan has been toggled, update display
	rjmp button_held
turn_fan_off:
	ldi r16, 0xFF
	in r25, OCR0B ; Backup current duty cycle value
	out OCR0B, r16
	ldi r16, (1<<WGM00)|(1<<WGM01)|(1<<COM0B1)|(1<<COM0B0) ; Turn to inverted output. Allows constant low value to be output.
	out TCCR0A, r16
	ldi fan, 0
	rcall display_status ; Now that Fan has been toggled, update display
button_held:
	sbis PIND, BUTTON
	rjmp button_held
	ret

; --- LCD messages ---

	msg1: .db "DC = ", 0x00
	msg2: .db " (%) ", 0x00
	msg3: .db "Fan: ", 0x00
	msg4: .db "ON ", 0x00
	msg5: .db "OFF", 0x00

display_status:
	push r16

	; Send cursor to first line
	ldi r16, 0x80
	rcall send_instruction

	; Display "DC = "
	ldi r30, LOW(2*msg1)
	ldi r31, HIGH(2*msg1)
	rcall displayCString

	; Display Duty Cycle
	rcall update_DC_text
	ldi r30, LOW(dtxt)
	ldi r31, HIGH(dtxt)
	rcall displayDString

	; Display " (%) "
	ldi r30, LOW(2*msg2)
	ldi r31, HIGH(2*msg2)
	rcall displayCString

	; Send cursor to second line
	ldi r16, 0xC0
	rcall send_instruction

	; Display "Fan: "
	ldi r30, LOW(2*msg3)
	ldi r31, HIGH(2*msg3)
	rcall displayCString

	cpi fan, 0 ; See if fan is turned off
	breq display_OFF
	;Fan is ON
	; Display "ON "
	ldi r30, LOW(2*msg4)
	ldi r31, HIGH(2*msg4)
	rcall displayCString
	rjmp end_display_status

display_OFF:
	; Display "OFF"
	ldi r30, LOW(2*msg5)
	ldi r31, HIGH(2*msg5)
	rcall displayCString
end_display_status:
	pop r16
	ret



displayCString:
	push r16
loop_displayCString:
	lpm r16, Z+ ; Load contents of Z-pointer into r16, post-increment after
	tst r16
	breq end_displayCString
	rcall send_data
	rjmp loop_displayCString
end_displayCString:
	pop r16
	ret

displayDString:
	push r16
loop_displayDString:
	ld r16, Z+
	tst r16
	breq end_displayDString
	rcall send_data
	rjmp loop_displayDString
end_displayDString:
	pop r16
	ret

read_rpg:
	in R21, PIND	; Read all pins on Port D simultaneously
	lsr R21			; Shift contents to the right
	lsr R21	
	andi R21, 0x03	; Ignore all but two least-significant bits
	mov R22, R21
	lsl R22			; Make room for previous reading into R22
	lsl R22
	or R22, R20		; Load previous reading (R20) into current comparison (R22)
	cpi R22, 0x0D	;  (Reading now in detent after clockwise rotation)
	breq do_clockwise
	cpi R22, 0x0E	; (Reading now in detent after counter-clockwise rotation)
	breq do_counterclockwise
	rjmp end_read_rpg

do_clockwise:
	cpi fan, 0			; Don't increment if fan is off
	breq end_do_clockwise
	rcall increment_PWM
	rcall display_status
end_do_clockwise: 
	rjmp end_read_rpg

do_counterclockwise:
	cpi fan, 0			; Don't decrement if fan is off
	breq end_do_counterclockwise
	rcall decrement_PWM
	rcall display_status
end_do_counterclockwise:
	rjmp end_read_rpg

end_read_rpg:
	mov R20, R21	; Save current reading as previous reading
	ret


increment_PWM:
	push r16
	in r16, OCR0B
	cpi r16, 199
	breq end_increment_PWM ; Don't increment past 199 = 100% (Will display as 99%)
	inc r16
	inc r16
	out OCR0B, r16 ; Store value back in OCR0B
end_increment_PWM:
	pop r16
	ret

decrement_PWM:
	push r16
	in r16, OCR0B
	cpi r16, 1
	breq end_decrement_PWM
	dec r16
	dec r16
	out OCR0B, r16
end_decrement_PWM:
	pop r16
	ret


update_DC_text:
.dseg 
	dtxt: .BYTE 5 ; Allocation

.cseg
	in r24, OCR0B	; Get OCR0B value. This corresponds with the current duty cycle.
	cpi r24, 0xFF
	brne use_regular
	mov r24, r25
use_regular:
	lsr r24	; Divide by 2. OCR0B values range from 1 to 199. This now means they range from 0 to 99. PWM percentage can be directly taken from this number.
	mov dd8u, r24
	ldi dv8u, 10 ; Divide by 10 to get digits
; Store null-terminated string
	ldi r24, 0x00
	sts dtxt+4, r24
; Store 0
	ldi r24, 0x30 ; 0 in ASCII
	sts dtxt+3, r24
; Store decimal point
	ldi r24, 0x2E
	sts dtxt+2, r24
; Divide percentage by 10 and format remainder
	rcall div8u ; Remainder is stored in drem8u (r15), Result is stored in dres8u (r16)
	ldi r24, 0x30 ; ASCII offset
	add drem8u, r24 ; Covert to ASCII
	sts dtxt+1, drem8u
; Store remaining digit.
	add dres8u, r24 ; Covert to ASCII
	sts dtxt, dres8u
	ret

send_instruction:
	push r16
	cbi LCD_RS_PORT, LCD_RS ; Set RS low for an instruction
	swap r16
	out LCD_DATA_PORT, r16 ; Output high-nibble
	rcall LCD_strobe

	rcall delay_200us

	swap r16; Move low-nibble to end
	out LCD_DATA_PORT, r16
	rcall LCD_strobe

	rcall delay_40us

	pop r16
	ret

send_data:
	push r16
	sbi LCD_RS_PORT, LCD_RS ; Set RS high for data
	swap r16
	out LCD_DATA_PORT, r16 ; Output high-nibble
	rcall LCD_strobe

	rcall delay_200us

	swap r16; Move low-nibble to end
	out LCD_DATA_PORT, r16
	rcall LCD_strobe

	rcall delay_40us

	pop r16
	ret


LCD_strobe:
	cbi LCD_EN_PORT, LCD_EN
	sbi LCD_EN_PORT, LCD_EN
	rcall delay_200us
	cbi LCD_EN_PORT, LCD_EN
	ret

LCD_init:
	push r16

	rcall delay_100ms ; Wait for LCD to power up.
	rcall delay_100ms
	rcall delay_100ms
	rcall delay_100ms
	rcall delay_100ms

	; 8-bit mode. Write only upper-nibble. First write.
	ldi r16, 0x03
	;rcall send_instruction
	out LCD_DATA_PORT, r16
	cbi LCD_RS_PORT, LCD_RS ; RS=0 (Command)
	rcall LCD_strobe
	rcall delay_5ms

	; 8-bit mode. Write only upper-nibble. Second write.
	ldi r16, 0x03
	;rcall send_instruction
	out LCD_DATA_PORT, r16
	cbi LCD_RS_PORT, LCD_RS
	rcall LCD_strobe
	rcall delay_200us

	; 8-bit mode. Write only upper-nibble. Third write.
	ldi r16, 0x03
	;rcall send_instruction
	out LCD_DATA_PORT, r16
	cbi LCD_RS_PORT, LCD_RS
	rcall LCD_strobe
	rcall delay_200us

	; Enter 4-bit mode. Write only upper-nibble.
	ldi r16, 0x02
	;rcall send_instruction
	out LCD_DATA_PORT, r16
	cbi LCD_RS_PORT, LCD_RS
	rcall LCD_strobe
	rcall delay_5ms

	; Write Command "Set Interface"
	ldi r16, 0x28
	rcall send_instruction
	rcall delay_200us

	; Write Command "Enable Display/Cursor"
	ldi r16, 0x09
	rcall send_instruction
	rcall delay_200us


	; Write Command "Clear and Home"
	ldi r16, 0x01
	rcall send_instruction
	rcall delay_200us


	; Write Command "Set Cursor Move Direction"
	ldi r16, 0x06
	rcall send_instruction
	rcall delay_200us


	; Turn on display
	ldi r16, 0x0C
	rcall send_instruction
	rcall delay_200us


	ldi r16, 0x02
	rcall send_instruction
	rcall delay_200us

	pop r16
	ret


PWM_init:
	push r16

	ldi r16, 0b00001001 ; Set prescaler to 1
	out TCCR0B, r16

	ldi r16, 199 ; Set top value for PWM. This gives a frequency of 80kHz.
	out OCR0A, r16

	ldi r16, 99 ; Set duty cycle to 50%
	out OCR0B, r16

	ldi r16, (1<<WGM00)|(1<<WGM01)|(1<<COM0B1) ; set the waveform generation mode to Fast PWM, 8-bit, with OC0B set on compare match
	out TCCR0A, r16

	pop r16
	ret



delay_5s:
	push r16
	ldi r16, 50
loop_5s:
	rcall delay_100ms
	dec r16
	brne loop_5s
	pop r16
	ret

delay_100ms:
	push r16
	ldi r16, 50
loop_100ms:
	rcall delay_2ms
	dec r16
	brne loop_100ms
	pop r16
	ret

delay_5ms:
	push r16
	ldi r16, 25
loop_5ms:
	rcall delay_200us
	dec r16
	brne loop_5ms
	pop r16
	ret

delay_2ms: ; 2.250 ms
	push r16
	ldi r16, 10 ; Run loop 10 times to get to 2000us = 2ms
loop_2ms:
	rcall delay_200us
	dec r16
	brne loop_2ms
	pop r16
	ret

delay_200us: ; 200.625 us
	push r16
	ldi r16, 5
loop_200us:
	rcall delay_40us
	dec r16
	brne loop_200us
	pop r16
	ret

delay_40us: ; 40.125 us
	push r16
	ldi r16, 107
loop_40us:
	rcall delay_375ns
	dec r16
	brne loop_40us
	pop r16
	ret
	

delay_375ns:
	ret ; rcall - 2 cycles, ret - 4 cycles = 375ns @ 16MHz



;***************************************************************************
;*
;* "div8u" - 8/8 Bit Unsigned Division
;*
;* This subroutine divides the two register variables "dd8u" (dividend) and 
;* "dv8u" (divisor). The result is placed in "dres8u" and the remainder in
;* "drem8u".
;*  
;* Number of words	:14
;* Number of cycles	:97
;* Low registers used	:1 (drem8u)
;* High registers used  :3 (dres8u/dd8u,dv8u,dcnt8u)
;*
;***************************************************************************

;***** Subroutine Register Variables

.def	drem8u	=r15		;remainder
.def	dres8u	=r16		;result
.def	dd8u	=r16		;dividend
.def	dv8u	=r17		;divisor
.def	dcnt8u	=r18		;loop counter

;***** Code

div8u:	sub	drem8u,drem8u	;clear remainder and carry
	ldi	dcnt8u,9	;init loop counter
d8u_1:	rol	dd8u		;shift left dividend
	dec	dcnt8u		;decrement counter
	brne	d8u_2		;if done
	ret			;    return
d8u_2:	rol	drem8u		;shift dividend into remainder
	sub	drem8u,dv8u	;remainder = remainder - divisor
	brcc	d8u_3		;if result negative
	add	drem8u,dv8u	;    restore remainder
	clc			;    clear carry to be shifted into result
	rjmp	d8u_1		;else
d8u_3:	sec			;    set carry to be shifted into result
	rjmp	d8u_1

.exit