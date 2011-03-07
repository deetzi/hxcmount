scrollTarget:
                ;a0:targetinfo
                ;d2:number of pixel lines to scroll up

                movem.l d0-d7/a0-a6,-(a7)
                ;compute numbers
                    move.w  d2,d3                                               ;d3:nb vertical pixels to scroll
                    sub.w   d2,_tar_y(a0)                                       ;decrease _tar_y
                    move.l  _tar_addr(a0),a1                                    ;a1:screen top address
                    move.w  _tar_lineLen(a0),d0                                 ;d0:linelength
                    move.w  _tar_boxY(a0),d1                                    ;d1:yOffset
                    mulu    d0,d1
                    lea     0(a1,d1.l),a1                                       ;a1:screen box top address
                    mulu    d0,d2                                               ;d2:nb lines*linelen
                    lea     0(a1,d2.l),a2                                       ;a2:screen top+nb lines*linelen
                    move.w  _tar_boxH(a0),d1                                    ;d1:height of box
                    sub.w   d3,d1                                               ;d1:number of box lines to scroll
                    mulu    d0,d1                                               ;d1:length to scroll
                
                ;bmove a2->a1, d1.L bytes
.movem384:          sub.l   #384,d1
                    blt.s   .endmovem384
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,48(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,96(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,144(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,192(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,240(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,288(a1)
                    movem.l (a2)+,d0/d2-d7/a0/a3-a6
                    movem.l d0/d2-d7/a0/a3-a6,336(a1)
                    lea     384(a1),a1
                    bra.s   .movem384
.endmovem384:       add.w   #384,d1
.movem40            sub.w   #40,d1
                    blt.s   .endmovem40
                    movem.l (a2)+,d2-d7/a3-a6
                    movem.l d2-d7/a3-a6,(a1)
                    lea     40(a1),a1
                    bra.s   .movem40
.endmovem40:        add.w   #40,d1
                    lsr.w   #2,d1
                    bra.s   .entermove4
.move4:             move.l  (a2)+,(a1)+
.entermove4         dbra    d1,.move4

                ;fill a1->a2 with 0
                    move.l  a2,d1
                    sub.l   a1,d1                                               ;d1:bytes to clear
                    moveq   #0,d0
                    moveq   #0,d2
                    moveq   #0,d3
                    moveq   #0,d4
                    moveq   #0,d5
                    moveq   #0,d6
                    moveq   #0,d7
                    move.l  d7,a0
                    move.l  d7,a3
                    move.l  d7,a4
                    move.l  d7,a5
                    move.l  d7,a6
                    
.fill192:           sub.l   #192,d1
                    blt.s   .endfill192
                    movem.l d0/d2-d7/a0/a3-a6,-(a2)
                    movem.l d0/d2-d7/a0/a3-a6,-(a2)
                    movem.l d0/d2-d7/a0/a3-a6,-(a2)
                    movem.l d0/d2-d7/a0/a3-a6,-(a2)
                    bra.s   .fill192
.endfill192:        add.w   #192,d1
.fill40             sub.w   #40,d1
                    blt.s   .endfill40
                    movem.l d2-d7/a3-a6,-(a2)
                    bra.s   .fill40
.endfill40:         add.w   #40,d1
                    lsr.w   #2,d1
                    bra.s   .enterfill4
.fill4:             move.l  (a2)+,(a1)+
.enterfill4         dbra    d1,.fill4
                
                movem.l (a7)+,d0-d7/a0-a6
                rts