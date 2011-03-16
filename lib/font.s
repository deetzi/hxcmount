fontInit:       movem.l d0-d7/a0-a6,-(a7)
                bsr.s   fontClearScreen
.return:        movem.l (a7)+,d0-d7/a0-a6
                rts
                

fontClearScreen:
                pea     .dat(pc)
                bsr.s   fontPrintStd
                addq.l  #4,a7
                rts
.dat:           dc.b    27,'E'                      ;MT_CLS
                dc.b    27,'v'                      ;MT_WRAPON
                dc.b    0,0


;4(sp):line to print
fontPrintCust:
fontPrintStd:   movem.l a0-a2/d0-d2,-(a7)
                move.l  4+6*4(a7),-(a7)
                move.w  #9,-(a7)
                trap    #1
                addq.l  #6,a7
                movem.l (a7)+,a0-a2/d0-d2
                rts

;;4(sp): line to print
;;8(sp): font to use
;fontPrintCust:  move.l  4(sp),-(sp)
;                move.l  8+4(sp),-(sp)
;                pea     boxinfo(pc)
;                bsr     draw_line_bitplane_noclip
;                lea     12(a7),a7
;                rts
               