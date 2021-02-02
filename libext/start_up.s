;Megar/ex-Binaris
;Start_up version 1.4c :

;1.1: Clear BSS section
;1.2: Put a text just after the program header.
;     SU_PRG_TEXT may contain (as macro) the text BEFORE include "start_up.s"
;1.3: Now BASEPAGE_ADR contains the address of the basepage
;1.4: If MSG_TEXT not present, assuming MSG_TEXT=0
;     You can now tell to the startup how many memory the stack
;     will take. If SP_LENGHT not present, assuming 256 octets
;     256 bytes are always add to SP_LENGHT
;1.4b:Now standart message contains my email adr.
;1.4c:2011-03-01: corrected typos, new address&email. Removed telephone/minitel.
;1.5: 2011-03-15: removed name&address, added ZEUS_USEBRA

;MSG_TEXT	equ 	0: no message
;MSG_TEXT	equ	1: standard message
;MSG_TEXT	equ	2; SU_PRG_TEXT message
;MSG_TEXT	equ	3; standard message + SU_PRG_TEXT

; JUMP INTO MAIN

 IFD	MSG_TEXT
 IFEQ	MSG_TEXT=0
	bra	___ZEU_STARTUP
 ENDC

 IFNE	(MSG_TEXT=1)+(MSG_TEXT=3)
 	dc.b	"     Megar      "
 	dc.b	" To contact me: "
 	dc.b	"----------------"
	dc.b	"  gb@atomas.com "
 	dc.b	"----------------"
 ENDC
 
 IFNE	(MSG_TEXT=2)+(MSG_TEXT=3)
	SU_PRG_TEXT
 ENDC
 ENDC
 	EVEN

___ZEU_STARTUP:
	movea.l	4(sp),a0	;basepage
	lea.l	BASEPAGE_ADR(pc),a1
	move.l	a0,(a1)
	move.l	$c(a0),d0	;text
	add.l	$14(a0),d0	;+data
	add.l	$1c(a0),d0	;+bss
 IFD SP_LENGHT
	addi.l	#256+SP_LENGHT,d0	;+pile
 ELSE
	addi.l	#512,d0
 ENDC
	bclr	#0,d0		;pair !
	move.l	d0,4(a1)	;save program_length
	lea.l	0(a0,d0.l),sp
	move.l	d0,-(sp)
	pea	(a0)
	clr.w	-(sp)
	
	move.l	$1c(a0),d0	;d0= Bss Lenght
	move.l	$18(a0),a0	;a0= Bss
	lea.l	0(a0,d0.l),a1	;a1= Fin Bss
	lsr.l	#5,d0		;divise par 32
	moveq	#0,d1
	moveq	#0,d2
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d6
	moveq	#0,d7
	move.l	d7,a2
.cl:	movem.l	d1-d7/a2,(a0)
	lea.l	8*4(a0),a0
	dbf	d0,.cl
.cl2:	cmp.l	a1,a0
	bge.s	.ok
	move.b	d1,(a0)+
	bra.s	.cl2
.ok:	
	move.w	#$4a,-(sp)
	trap	#1
	lea.l	12(sp),sp

 IFD ZEUS_BRA
	bra MAIN
 ELSE
	jmp	MAIN
 ENDC

BASEPAGE_ADR:
	ds.l	1
program_length:
	ds.l	1