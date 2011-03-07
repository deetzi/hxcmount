getFontInfo:
; get font informations
                        rsset   4+5*4  ; INPUT:
_gfin_iReturnAddr:      rs.l    1
_gfin_iFontAddr:        rs.l    1

                movem.l a0-a2/d0-d1,-(a7)
                
                move.l  _gfin_iFontAddr(a7),a0
                cmp.l   #"FORM",(a0)+
                bne     .exception
                move.l  (a0)+,d0
                lea     0(a0,d0),a1                 ; a1: end of file
                cmp.l   #"MFNT",(a0)+
                bne.s   .exception

; find the "INFO" Chunk
.infoSearch:    move.l  a0,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                move.l  d0,a0
                cmp.l   #"INFO",(a0)+
                beq.s   .infoFound
                add.l   (a0)+,a0
                cmp.l   a1,a0                       ; eof ?
                bge.s   .exception
                bra.s   .infoSearch

; "INFO" Chunk found.
.infoFound:     move.l  a0,a2
                add.l   (a0)+,a2
                cmp.l   a1,a2                       ; eof ?
                bgt.s   .exception

                move.l  _gfin_iReturnAddr(a7),a1    ;a1:fontinfo addr
                move.l  a0,_font_nameAddr(a1)
.skipname:      tst.b   (a0)+
                bne.s   .skipname

                moveq   #0,d1
                move.b  (a0)+,d0                    ;bold
                cmp.b   #'B',d0
                bne.s   .boldset
                moveq   #1,d1
.boldset        move.b  d1,_font_isBold(a1)

                moveq   #0,d1
                move.b  (a0)+,d0                    ;italic
                cmp.b   #'I',d0
                bne.s   .itaset
                moveq   #1,d1
.itaset         move.b  d1,_font_isItalic(a1)

                moveq   #0,d0
                moveq   #0,d1                       ;size
.nxtsiz         move.b  (a0)+,d0
                beq.s   .sizok
                sub.w   #'0',d0
                mulu    #10,d1
                add.w   d0,d1
                bra.s   .nxtsiz
.sizok:         move.w  d1,_font_size(a1)

                move.b  (a0)+,d0                    ;d0=000000xx
                move.w  d0,_font_lineHeight(a1)
                move.b  (a0)+,d0
                move.w  d0,_font_lineBase(a1)
                
                bra.s   .return

.exception:     lea.l   5*4(a7),a7
                ILLEGAL
.return:        movem.l (a7)+,a0-a2/d0-d1
                rts
