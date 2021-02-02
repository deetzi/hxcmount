ramRstInit:
			lea.l	program_length(pc),a0
			move.l	(a0),d1			;Size required above phystop
			move.l	$42e.w,a1		;phystop 		
			suba.l	d1,a1

			move.l	a1,a2
			move.l	a1,d0
			move.l	d0,a3
			
			lea		___ZEU_STARTUP(pc),a4			
			lea		ramRstVector(pc),a5		;SUPER works...
			sub.l	a4,a5
			add.l	a5,a2
			
			clr.b 	d0

			move.l	d0,$42e.w 			;Set phystop to make space
			movea.w	#$600,a0			;Reset proof area
			movea.l	a0,a1 
			move.l	#$12123456,(a1)+	;Magic number
			move.l	#$00000600,(a1)+	;Pointer to block
			move.w	#$4ef9,(a1)+		;jmp op-code 
			move.l	a2,(a1)+			;Start of reset code

			move.l    #$fe,d0 
			clr.l     d2
			
.sumloop:	add.w     (a0)+,d2
			dbf       d0,.sumloop
			subi.w    #$5678,d2 
			sub.w     d2,(a0)
	
			lea		___ZEU_STARTUP(pc),a0
;			lea		ramRstVector(pc),a0

			sub.l	#1,d1

.copyprg:	;move.b     (a0)+,(a3)+
			move.b	(a0)+,(a3)+
			dbf		d1,.copyprg

			move.w	#2,$446.W 	;Boot C

			movea.l   4.w,a0
			jmp       (a0)

ramRstVector:
			bsr     fontInit
			lea     ramRstLoaded(pc),a0
			tst.b   (a0)
			beq.s   .load

			bsr		mainPrgUnload
.load		bra		SUPER			
			
ramRstLoaded:
			ds.b	1
			even