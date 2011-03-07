
        SECTION TEXT

;in: d0.b: $1f
;out: d1.w: (ascii) "f1"
byteToHex:      movem.l d0/d2/a0,-(sp)
                and.w   #$ff,d0
                move.w  d0,d2
                lsr.b   #4,d0                                       ;d0:MSB
                and.b   #$f,d2                                      ;d2:LSB
                lea     toHexTable(pc),a0
                move.b  0(a0,d2),d1
                lsl.w   #8,d1
                move.b  0(a0,d0),d1
                movem.l (sp)+,d0/d2/a0
                rts
toHexTable:     dc.b "0123456789abcdef"        

;convert D0.l to hex
;results in (a0)+
;registers: none
longD0ToHexA0:  movem.l d1/a1,-(a7)
                lea     toHexTable(pc),a1
                moveq   #0,d1
                rol.l   #8,d0
                move.b  d0,d1
                lsr.b   #4,d1
                move.b  0(a1,d1.w),(a0)+
                move.b  d0,d1
                and.b   #$f,d1
                move.b  0(a1,d1.w),(a0)+
                rol.l   #8,d0
                move.b  d0,d1
                lsr.b   #4,d1
                move.b  0(a1,d1.w),(a0)+
                move.b  d0,d1
                and.b   #$f,d1
                move.b  0(a1,d1.w),(a0)+
                rol.l   #8,d0
                move.b  d0,d1
                lsr.b   #4,d1
                move.b  0(a1,d1.w),(a0)+
                move.b  d0,d1
                and.b   #$f,d1
                move.b  0(a1,d1.w),(a0)+
                rol.l   #8,d0   ;revert d0 to initial state
                move.b  d0,d1
                lsr.b   #4,d1
                move.b  0(a1,d1.w),(a0)+
                move.b  d0,d1
                and.b   #$f,d1
                move.b  0(a1,d1.w),(a0)+
                movem.l (a7)+,d1/a1
                subq.l  #8,a0   ;revert a0 to initial address
                rts
