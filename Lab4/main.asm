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

.equ RPG0=2			; RPG0 is PD2 (Pin 2)
.equ RPG1=3			; RPG1 is PD3 (Pin 3)
.equ BUTTON=4		; BUTTON is PD4 (Pin 4)

; --- Data-direction register setup ---
; Inputs
cbi DDRB, BUTTON	; Set BUTTON0 (PB3/Pin 11) as input
cbi DDRD, RPG0		; Set RPG0 (PD2/Pin 2) as input
cbi DDRD, RPG1		; Set RPG1 (PD3/Pin 3) as input
; LCD Pins
sbi LCD_DATA_DDR, LCD_DATA_D4 ; Set LCD_DATA_D4 as output
sbi LCD_DATA_DDR, LCD_DATA_D5 ; Set LCD_DATA_D5 as output
sbi LCD_DATA_DDR, LCD_DATA_D6 ; Set LCD_DATA_D6 as output
sbi LCD_DATA_DDR, LCD_DATA_D7 ; Set LCD_DATA_D7 as output
sbi LCD_RS_DDR, LCD_RS ; Set LCD_RS as output
sbi LCD_EN_DDR, LCD_EN ; Set LCD_EN as output 

cbi LCD_EN_PORT, LCD_EN ; Ensure default state of EN is low

rcall LCD_init

/*
ldi r16, 0x02
rcall send_instruction
*/

/*
ldi r16, 'E'
rcall send_data
*/

	rcall delay_5s

	ldi r16, 'F'
	rcall send_data

start:



	rcall delay_5s

	ldi r16, 'E'
	rcall send_data

    rjmp start




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
	rcall increment_counter
	cpi R23, 0			; Motion from RPG should change the dash display to a digit. If R23 is 0, the dash is being displayed. Motion should cancel this.
	brne end_do_clockwise
	inc R23				; Turn R23 to 1 so as to begin displaying and accepting first digit
	clr R16				; Because increment_counter is called above, R16 must be cleared to begin display on 0.
end_do_clockwise: 
	rjmp end_read_rpg

do_counterclockwise:
	rcall decrement_counter
	cpi R23, 0			; Motion from RPG should get rid of displaying dash and begin displaying numbers.
	brne end_do_counterclockwise
	inc R23				; Incrementing R23 moves display from a dash to actual numbers
	clr R16				; Although decrement won't decrement to zero, because display is beginning to display numbers, best to ensure that it starts out on zero.
end_do_counterclockwise:
	rjmp end_read_rpg

end_read_rpg:
	mov R20, R21	; Save current reading as previous reading
	ret


increment_counter:
	ret

decrement_counter:
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


.exit