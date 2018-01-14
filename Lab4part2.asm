$MODDE0CV
org 0000H
   ljmp mycode

dseg at 30h

x:		ds	4
y:		ds	4
bcd:	ds	5
operation: ds 1
bseg

mf:		dbit 1

$include(math32.asm)

CSEG

; Look-up table for 7-seg displays
T_7seg:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H
    DB 092H, 082H, 0F8H, 080H, 090H    

showBCD MAC
	; Display LSD
    mov A, %0
    anl a, #0fh
    movc A, @A+dptr
    mov %1, A
	; Display MSD
    mov A, %0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    mov %2, A
ENDMAC

Display:
	mov dptr, #T_7seg
	showBCD(bcd+0, HEX0, HEX1)
	showBCD(bcd+1, HEX2, HEX3)
	showBCD(bcd+2, HEX4, HEX5)
    ret

MYRLC MAC
	mov a, %0
	rlc a
	mov %0, a
ENDMAC

Shift_Digits:
	mov R0, #4 ; shift left four bits
Shift_Digits_L0:
	clr c
	MYRLC(bcd+0)
	MYRLC(bcd+1)
	MYRLC(bcd+2)
	MYRLC(bcd+3)
	MYRLC(bcd+4)
	djnz R0, Shift_Digits_L0
	; R7 has the new bcd digit	
	mov a, R7
	orl a, bcd+0
	mov bcd+0, a
	; bcd+3 and bcd+4 don't fit in the 7-segment displays so make them zero
	clr a
	mov bcd+4, a
	ret

Wait50ms:
;33.33MHz, 1 clk per cycle: 0.03us
	mov R0, #30
L3: mov R1, #74
L2: mov R2, #250
L1: djnz R2, L1 ;3*250*0.03us=22.5us
    djnz R1, L2 ;74*22.5us=1.665ms
    djnz R0, L3 ;1.665ms*30=50ms
    ret

; Check if SW0 to SW9 are toggled up.  Returns the toggled switch in
; R7.  If the carry is not set, no toggling switches were detected.
ReadNumber:
	mov r4, SWA ; Read switches 0 to 7
	mov a, SWB ; Read switches 8 to 9
	anl a, #00000011B ; Only two bits of SWB available
	mov r5, a
	mov a, r4
	orl a, r5
	jz ReadNumber_no_number
	lcall Wait50ms ; debounce
	mov a, SWA
	clr c
	subb a, r4
	jnz ReadNumber_no_number ; it was a bounce
	mov a, SWB
	anl a, #00000011B
	clr c
	subb a, r5
	jnz ReadNumber_no_number ; it was a bounce
	mov r7, #16 ; Loop counter
ReadNumber_L0:
	clr c
	mov a, r4
	rlc a
	mov r4, a
	mov a, r5
	rlc a
	mov r5, a
	jc ReadNumber_decode
	djnz r7, ReadNumber_L0
	sjmp ReadNumber_no_number	
ReadNumber_decode:
	dec r7
	setb c
ReadNumber_L1:
	mov a, SWA
	jnz ReadNumber_L1
ReadNumber_L2:
	mov a, SWB
	jnz ReadNumber_L2
	ret
ReadNumber_no_number:
	clr c
	ret
	
mycode:
	mov SP, #7FH
	clr a
	mov LEDRA, a
	mov LEDRB, a
	mov bcd+0, a
	mov bcd+1, a
	mov bcd+2, a
	mov bcd+3, a
	mov bcd+4, a
	lcall Display

forever:
	jnb KEY.3, forever_a
	jnb	KEY.2, forever_b
ljmp forever 

	forever_a:
		forever_add:
		jb KEY.3, add_mult ; If '+' key not pressed, skip
		jnb KEY.3, $ ; Wait for user to release '+' key	
		lcall bcd2hex ; Convert the BCD number to hex in x
		lcall copy_xy ; move x to y (this is a function)
		Load_X(0) ; clear x (this is a macro)
		lcall hex2bcd ; Convert binary x to BCD
		lcall Display ; Display the new BCD number
		mov operation, #0000_0000B
		ljmp forever_add ; Go check for more input	
				
		add_mult:	
		jnb KEY.0, is_mult
		jnb KEY.3, is_add
		ljmp do_equala	
		is_mult:
		mov operation, #0000_0100B
		ljmp do_equala
		is_add: 
		mov operation, #0000_0001B
		ljmp do_equala
				
		do_equala:
		jb KEY.1, no_equala ; If the ’=’ key not pressed, skip
		jnb KEY.1, $ ; Wait for user to release the ’=’ key 
		lcall bcd2hex ; Convert the BCD number to hex in x
		 ; Select the function the user wants to perform:
		mov a, operation ; The accumulator is bit addressable!
		jb acc.0, do_addition 
		jb acc.2, do_multiplication
		
		do_addition:
		lcall add32 ; Add the numbers stored in x and y
		lcall hex2bcd ; Convert result in x to BCD
		lcall Display ; Display BCD using 7-segment displays
		ljmp forever ; go check for more input
		
		do_multiplication:
		lcall mul32 ; Add the numbers stored in x and y
		lcall hex2bcd ; Convert result in x to BCD
		lcall Display ; Display BCD using 7-segment displays
		ljmp forever ; go check for more input
		
		no_equala:
		; get more numbers
		lcall ReadNumber
		jnc no_new_digita ; Indirect jump to 'forever'
		lcall Shift_Digits
		lcall Display
		
		no_new_digita:
		ljmp forever_add ; 'forever' is to far away, need to use ljmp
	ljmp forever_a
		
	forever_b:
		forever_sub:
			jb KEY.2, sub_div ; If '+' key not pressed, skip
			jnb KEY.2, $ ; Wait for user to release '+' key	
			lcall bcd2hex ; Convert the BCD number to hex in x
			lcall copy_xy ; move x to y (this is a function)
			Load_X(0) ; clear x (this is a macro)
			lcall hex2bcd ; Convert binary x to BCD
			lcall Display ; Display the new BCD number
			mov operation, #0000_0000B
			ljmp forever_sub ; Go check for more input
			
		sub_div:	
			jnb KEY.0, is_div
			jnb KEY.2, is_sub
			ljmp do_equalb	
		is_sub:
			mov operation, #0000_0010B
			ljmp do_equalb
		is_div: 
			mov operation, #0000_1000B
			ljmp do_equalb	
			
		do_equalb:
		jb KEY.1, no_equalb ; If the ’=’ key not pressed, skip
		jnb KEY.1, $ ; Wait for user to release the ’=’ key 
		lcall bcd2hex ; Convert the BCD number to hex in x
		 ; Select the function the user wants to perform:
		lcall xchg_xy 
		mov a, operation ; The accumulator is bit addressable!
		jb acc.1, do_subtraction
		jb acc.3, do_division
		
		do_subtraction:
		lcall sub32 ; Add the numbers stored in x and y
		lcall hex2bcd ; Convert result in x to BCD
		lcall Display ; Display BCD using 7-segment displays
		ljmp forever ; go check for more input	
		
		do_division: 
		lcall div32 ; Add the numbers stored in x and y
		lcall hex2bcd ; Convert result in x to BCD
		lcall Display ; Display BCD using 7-segment displays
		ljmp forever ; go check for more input
		
		no_equalb:
		; get more numbers
		lcall ReadNumber
		jnc no_new_digitb ; Indirect jump to 'forever'
		lcall Shift_Digits
		lcall Display
		
		no_new_digitb:
		ljmp forever_sub ; 'forever' is to far away, need to use ljmp
	ljmp forever_b

END