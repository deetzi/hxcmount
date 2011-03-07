;fill the supplied charInfoStruct with the specified character from the specified font
;input: Stack: (charinfoStructAddr.L, fontAddr.L, charCode.w)
;output: Z=1 if char found, otherwise 0
;registers:-

getCharInfo:
; get character pixel address, width, height...
                        rsset   4+5*4  ; INPUT:
_cddi_return_addr:      rs.l    1
_ccdi_font_addr:        rs.l    1
_ccdi_char_code:        rs.w    1

                movem.l a0-a2/d0-d1,-(a7)
                
                move.l  _ccdi_font_addr(a7),a0
                cmp.l   #"FORM",(a0)+
                bne     .exception
                move.l  (a0)+,d0
                lea     0(a0,d0),a1                 ; a1: end of file
                cmp.l   #"MFNT",(a0)+
                bne     .exception

; find the "CHLI" Chunk
.chliSearch:    move.l  a0,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                move.l  d0,a0
                cmp.l   #"CHLI",(a0)+
                beq.s   .chliFound
                add.l   (a0)+,a0
                cmp.l   a1,a0                       ; eof ?
                bge     .exception
                bra.s   .chliSearch

; "CHLI" Chunk found.
.chliFound:     move.l  (a0)+,d0
                lea     0(a0,d0),a2                 ; a2: enf of CHLI chunk

; Search for the asked character                
                move.w  _ccdi_char_code(a7),d0
.chliChLoop:    move.l  (a0)+,d1                    ;d1=(offset.w)(nbkern.b)(chcode.b)
                cmp.b   d0,d1
                beq.s   .chliChFound
                cmp.l   a2,a0                       ; end of chunk ?
                blt.s   .chliChLoop
                    ;char not found:
                    and.b   #255-4,CCR              ;Z=0
                    bra    .return

; Asked character found in d1=(offset.w)(nbkern.b)(chcode.b)
.chliChFound:   lsr.w   #8,d1                       ; d1=(offset.w)(0.b)(nbkern.b)


;now, find the CHDA Chunk: remember a1=eof, a2=end of CHLI chunk. KEEP d1
.chdaSearch:    move.l  a2,d0
                addq.l  #1,d0
                and.b   #$fe,d0
                move.l  d0,a2
                cmp.l   #"CHDA",(a2)+
                beq.s   .chdaFound
                add.l   (a2)+,a2
                cmp.l   a1,a2                       ; eof ?
                bge     .exception
                bra.s   .chdaSearch

; "CHDA" Chunk found.
.chdaFound:     addq.l  #4,a2                       ; we don't need the chunk length. We know where the data are (offset)

                move.l  _cddi_return_addr(a7),a0    ; a0=_charInfo_struct

                swap    d1                          ; d1=(0.b)(nbkern.b)(offset.w)
                add.w   d1,a2                       ; skip to the character data (kern, spef, then pixels)
                move.l  a2,_char_kernAddr(a0)
                swap    d1                          ; d1=(offset.w)(0.b)(nbkern.b)
                move.w  d1,_char_kernNb(a0)

; Skip nbkerns*2
                add.w   d1,d1                       ; each kern = 2 bytes
                add.w   d1,a2                       ; skip the kernings


;_ccdo_char_kern_addr

                moveq   #0,d0                       ;char_w
                move.b  (a2)+,d0
                cmp.b   #$ff,d0
                bne.s   .spef1
                move.b  (a2)+,d0
                lsl.w   #8,d0
                move.b  (a2)+,d0
.spef1:         move.w  d0,_char_w(a0)

                moveq   #0,d0                       ;char_h
                move.b  (a2)+,d0
                cmp.b   #$ff,d0
                bne.s   .spef2
                move.b  (a2)+,d0
                lsl.w   #8,d0
                move.b  (a2)+,d0
.spef2:         move.w  d0,_char_h(a0)

                moveq   #0,d0                       ;char_xoffset
                move.b  (a2)+,d0
                ext.w   d0
                cmp.b   #$7f,d0
                bne.s   .spef3
                move.b  (a2)+,d0
                lsl.w   #8,d0
                move.b  (a2)+,d0
.spef3:         move.w  d0,_char_xoffset(a0)
                
                moveq   #0,d0                       ;char_yoffset
                move.b  (a2)+,d0
                ext.w   d0
                cmp.b   #$7f,d0
                bne.s   .spef4
                move.b  (a2)+,d0
                lsl.w   #8,d0
                move.b  (a2)+,d0
.spef4:         move.w  d0,_char_yoffset(a0)

                moveq   #0,d0                       ;char_xadvance
                move.b  (a2)+,d0
                ext.w   d0
                cmp.b   #$7f,d0
                bne.s   .spef5
                move.b  (a2)+,d0
                lsl.w   #8,d0
                move.b  (a2)+,d0
.spef5:         move.w  d0,_char_xadvance(a0)
                
                move.l  a2,_char_pixAddr(a0)
                or.b   #4,CCR                        ;Z=1

                bra.s   .return

.exception:     lea.l   5*4(a7),a7
                ILLEGAL
.return:        movem.l (a7)+,a0-a2/d0-d1
                rts
