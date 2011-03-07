;v01: initial
;v04: changement appel de draw_char

draw_line_bitplane_noclip:
;   Affichage d'une ligne sans clipping - Bitplane mode
                        rsset   4+15*4  ; INPUT:
dlbn_iBoxinfo:          rs.l    1       ; address of boxinfo struct
dlbn_iFontAddr:         rs.l    1       ; address of "megarfont" file
dlbn_iTextAddr:         rs.l    1       ; Line of text to draw

;TODO : clipping at the beginning

;  Theory of operation:
;    for each character != 0 :
;       Call draw_char_bitplane_noclip()

                movem.l a0-a6/d0-d7,-(a7)

                move.l  dlbn_iBoxinfo(a7),a0                    ;a0:boxinfo
                move.l  dlbn_iTextAddr(a7),a2                   ;a2:text
                move.l  dlbn_iFontAddr(a7),a4                   ;a4:font

                lea    -_font_rsLength(a7),a7                   ;MAKE ROOM ON STACK for fontinfo: USE +_font_rsLength(a7) OFFSET
                move.l  a7,a1                                   ;a1:fontinfoStruct
                lea    -_char_rsLength(a7),a7                   ;MAKE ROOM ON STACK for charinfo: USE +_char_rsLength(a7) OFFSET
                move.l  a7,a3                                   ;a3:charinfoStruct

                ;call fontinfo
                    move.l  a4,-(a7)                            ;font
                    move.l  a1,-(a7)                            ;fontinfo return address
                    bsr     getFontInfo
                    addq.l  #8,a7

                ;stack struct pointers
                    move.l  a1,-(a7)
                    move.l  a3,-(a7)                

                ; (a7):struct *charinfo
                ;4(a7):struct *fontinfo

                bsr     scrollIfNeeded
                
.nxtCharNoKern: moveq   #0,d2                                   ;d2:nb kern pairs
.nxtChar:       moveq   #0,d0
                move.b  (a2)+,d0                                ;d0:current char
                beq     .return                                 ;end if 0
                cmp.b   #10,d0                                  ;char=10 : newline
                beq.s   .charIsNewline
                cmp.b   #13,d0
                beq.s   .nxtCharNoKern                          ;char=13 : skip

;a0:boxinfo
;a1:used for charinfo
;a2:next character
;a3:kern pairs address for the previous char (pass>=2)
;a4:font
;d0:current char
;d2:nb kern pairs (pass1:0) (pass>=2)

                ;search kerning pair. The second char (d1) is tested against the first (d0).
                ;Loop until all the kerns pairs fail, or d1>=d0
                subq.w  #1,d2
                bmi.s   .kernend
                
.kernsearch:    move.b  (a3)+,d3                                                ;kern amount
                move.b  (a3)+,d1                                                ;kern next char
                cmp.b   d0,d1
                dbge    d2,.kernsearch                                          ;loop until d2-- != -1 OR d1>=d0
                bne.s   .kernend                                                ;skip if d0!=d1
                ext.w   d3                                                      ;d3:kerning to apply
                add.w   d3,_tar_x(a0)

.kernend:       move.l  (a7),a1                                                 ;a1(stack):charinfo return address
                move.w  d0,-(a7)                                                ;char
                move.l  a4,-(a7)                                                ;font
                move.l  a1,-(a7)                                                ;charinfo return address
                bsr     getCharInfo
                lea     10(a7),a7
                beq.s   .charfound
                
                ;char not found, try to show "?"
                    move.l  (a7),a1                                             ;a1(stack):charinfo return address
                    move.w  #'?',-(a7)                                          ;char
                    move.l  a4,-(a7)                                            ;font
                    move.l  a1,-(a7)                                            ;charinfo return address
                    bsr     getCharInfo
                    lea     10(a7),a7
                    bne.s   .nxtCharNoKern                                      ;still not found : skip

.charfound:     ;wrap ? test if the char will exceed _tar_boxX+_tar_boxW                
                move.w  _tar_x(a0),d2
                add.w   _char_xoffset(a1),d2
                add.w   _char_w(a1),d2                                          ;d2:rightmost pixel
                sub.w   _tar_boxX(a0),d2
                sub.w   _tar_boxW(a0),d2
                bls.s   .wrapend

                ;the line must be wraped
                bsr.s   newLineSR
                bcc.s   .return                                                 ;return if bottom of screen

.wrapend:       ;PARAMETER a1:charinfo
                ;PARAMETER a0:targetinfo
                bsr     draw_char_bitplane_noclip
                
                ;x advance
                    move.w  _char_xadvance(a1),d2                               ;xadvance
                    add.w   d2,_tar_x(a0)                                       ;add to x coordinate

                ;set kerning info
                    move.w  _char_kernNb(a1),d2                                 ;d2:nb kern pairs
                    move.l  _char_kernAddr(a1),a3                               ;a3:kern pairs address

                bra.s   .nxtChar



.charIsNewline: ;skip to the next line and reset kern
                bsr.s   newLineSR
                bcs     .nxtCharNoKern
                bra.s   .return






.exception:     lea     15*4+4+4+_font_rsLength+_char_rsLength(a7),a7
                ILLEGAL
.return:        lea     4+4+_font_rsLength+_char_rsLength(a7),a7                ;REMOVE ROOM FROM STACK
                movem.l (a7)+,a0-a6/d0-d7
                rts







;Subroutine: Go to the next line
;update boxinfo with new _tar_x, _tar_y
;input: a0:targetinfo
;       8(sp):struct *fontinfo
;output:
;       C=0 if end of screen reached and fScroll=0
;       C=1 otherwise
;registers: -
newLineSR:      movem.l  d2/a3,-(a7)
                ;a0:boxinfo
                ;12(a7):struct *charinfo (not used)
                ;16(a7):struct *fontinfo
                
                move.l  16(a7),a3                                               ;a3:fontinfo
                move.w  _tar_boxX(a0), _tar_x(a0)                               ;reset to left
;                move.w  _font_lineHeight(a3),d2                                 ;nb vertical pixels to skip
                move.w  _font_lineBase(a3),d2                                   ;nb vertical pixels to skip
                add.w   d2,_tar_y(a0)
                bra.s   scrollIfNeeded2

;Subroutine: Go to the next line
;input: a0:targetinfo
;       8(sp):struct *fontinfo
;output:
;       C=0 if end of screen reached and fScroll=0
;       C=1 otherwise
;registers: -
scrollIfNeeded:
                movem.l  d2/a3,-(a7)
                ;a0:boxinfo
                ;12(a7):struct *charinfo (not used)
                ;16(a7):struct *fontinfo
                move.l  16(a7),a3                                               ;a3:fontinfo

scrollIfNeeded2:
                ;test if the char will exceed _tar_boxY+_tar_boxH
                move.w  _tar_y(a0),d2
                add.w   _font_lineHeight(a3),d2                                 ;d2:max bottom y for the next char
                sub.w   _tar_boxY(a0),d2
                ;;;;subq.w  #2,d2
                tst.b   _tar_fScroll(a0)                                        ;can we scroll ?
                bne.s   .canscroll

                ;scroll not allowed
                sub.w   _tar_boxH(a0),d2
                ; IF (_tar_y + _font_lineHeight) > (_tar_boxY+_tar_boxH), then C=0

.return:        movem.l  (a7)+,d2/a3   ;don't affect ccr
                rts

.canscroll:     ;scroll allowed
                sub.w   _tar_boxH(a0),d2
                ; IF (_tar_y + _font_lineHeight) > (_tar_boxY+_tar_boxH), then C=0
                bcs.s   .return                                                 ;is C=1, all is ok
                
                ;we must scroll the screen, and decrease _tar_y
                
                ;a0:targetinfo
                ;a3:fontinfo

                ;;;;move.w  _font_lineHeight(a3),d2                                 ;d2:nb vertical pixels to scroll

                ;a0:targetinfo
                ;d2:number of pixel lines to scroll up
                bsr.s   scrollTarget

                or      #1,ccr                                                  ;C=1, all is ok
                bra.s   .return
