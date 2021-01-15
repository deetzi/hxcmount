;cfgLoad
cfgCmdline:
				movem.l a0-a2/d0-d1,-(a7)
				move.l	BASEPAGE_ADR(pc),a0
				add.l	#128,a0
				move.b	(a0)+,d0
				tst.b	d0
				beq.s	.end
				
				cmp.b	#12,d0
				ble.b	.lt12
				move.b	#12,d0
.lt12
				andi.w	#$00FF,d0
				
				lea		_fsImgFName(pc),a1

				bra.s	.loopend
.loop
				move.b	(a0)+,(a1)+
.loopend		dbra	d0,.loop
.end
                movem.l (a7)+,a0-a2/d0-d1
				rts
