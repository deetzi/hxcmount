;drawch_02.s   ;par rapport à 01: boucle déroulée, un peu plus rapide
;drawch_03.s   ;par rapport à 02: getbit optimisé, d5 et d7 plus utilisés
;drawch_04:s    ;paramètres a0&a1 plutot que pile. drawline_04

draw_char_bitplane_noclip:
;   Affichage d'un caractère sans clipping - Bitplane mode

;INPUT:
;a0:boxinfo
;a1:charinfo

;  Theory of operation:
;    Compute screen address and bitmask
;    Draw char

                movem.l a0-a3/d0-d4/d6,-(a7)

                ;compute y address = (_tar_boxY + _char_yoffset) * _tar_lineLen + _scrAddr
                move.w  _tar_y(a0),d0
                add.w   _char_yoffset(a1),d0
                mulu.w  _tar_lineLen(a0),d0
                add.l   _tar_addr(a0),d0                                 ; d0:y address
                
                ;compute x address = _boxX + _char_xoffset
                move.w  _tar_x(a0),d1
                add.w   _char_xoffset(a1),d1
                move.w  _tar_bitplanes(a0),d2
                moveq   #0,d3
                move.w  d1,d3
                lsr.w   #4,d3                                           ; bitplane number
                lsl.w   d2,d3                                           ; xoffsetBytes
                add.l   d3,d0                                           ; d0:xy address
                and.w   #$000f,d1
                add.w   d1,d1
                lea     .scrBitmasks(pc),a2
                move.w  0(a2,d1.w),d1                                   ; d1:scrBitmask



                move.w  _tar_bitplanes(a0),d3
                moveq   #1,d6
                lsl.w   d3,d6                                           ; d6:bitplane offset
                move.w  _char_h(a1),d3                                  
                subq.w  #1,d3                                           ; d3:char_h-1
                move.w  d3,a3                                           ; a3:char_h-1
                move.w  _char_w(a1),d4                                  ; d4:char_w
                move.w  _tar_lineLen(a0),d2                             ; d2:iScrLineLen
                move.l  _char_pixAddr(a1),a0                            ; a0:char_pixel
                move.l  d0,a1                                           ; a1:screen xy addr
                move.l  a1,a2                                           ; a2:screen xy addr
                ; init d0 with high bit set
                moveq.l #-128,d0                                        ; d0.b:fontbits
                

                ;d0:font bits
                ;d1:screen bitmask
                ;d2:_scrLineLen
                ;d3:_char_h-1 (run)
                ;d4:_char_w
                ;d5:*not used*
                ;d6:bitplane length
                ;d7:*not used*
                ;a0:char_pixel
                ;a1:screen xy address (avance horizontale first line)
                ;a2:screen xy address (avance verticale)
                ;a3:_char_h-1 (save)
                ;a4:*not used*
                ;a5:*not used*
                ;a6:*not used*

                subq.w  #1,d4
                ;Bcc timing: no branch:8, branch:10

.nxtVertPix:    ;get next font bit:
                    add.b   d0,d0           ; sets Z, C and X       ;  4
                                            ; if C=0 then pixel=0 else (if Z=0 then pixel=1 ELSE byte is empty)
                    bcc.s   .nopix
                    bne.s   .gotbit1                                ; 10 (if jump)
                    move.b  (a0)+,d0                                ;  8 note: we shift the X flag through -> must init d0.b with $80
                    addx.b  d0,d0           ; sets C and X          ;  4 et remet le bit 0 à 1 pour la prochaine fois (indicateur de dernier bit)
                    bcc.s   .nopix
.gotbit1            or.w    d1,(a2)
.nopix:         
                add.w   d2,a2                               ; next line
                dbra    d3,.nxtVertPix                      ; avance verticale

                ;end of vertical pixels. Go to next column
                lsr.w   #1,d1                               ; next column: shift screen bitmask
                bne.s   .noscradv
                
                ;screenmask: 15 out of 16
                move.w  #$8000,d1                           ; next bitplane: reset to left
                add.w   d6,a1                               ; next bitplane: increment screen address
.noscradv:      move.l  a1,a2                               ; next column: go back to the top
                move.w  a3,d3                               ; char_h-1
                dbra    d4,.nxtVertPix
                bra.s   .return

                
                
.scrBitmasks:   dc.w    $8000, $4000, $2000, $1000, $800, $400, $200, $100, $80, $40, $20, $10, $8, $4, $2, $1
.exception:     lea.l   10*4(a7),a7
                ILLEGAL
.return:        movem.l (a7)+,a0-a3/d0-d4/d6
                rts
