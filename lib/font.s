
            include "..\libext\rasteriz\structs.s"
            include "..\libext\rasteriz\charinfo.s"
            include "..\libext\rasteriz\fontinfo.s"
            include "..\libext\rasteriz\noclip\bitplane\drawch.s"
            include "..\libext\rasteriz\noclip\bitplane\drawline.s"
            include "..\libext\rasteriz\noclip\scrollTa.s"




fontInit:       movem.l d0-d7/a0-a6,-(a7)
                move.l  #-1,-(a7)
                move.w  #3,-(a7)                                    ; logbase
                trap    #14
                addq.l  #6,a7
        
                move.l  d0,a6                                       ; a6:scrAddr
        
                moveq   #3,d7               ; d7:next bitplanes dec (low rez:3, med:2, high:1)
                move.w  #160,d6             ; d6:line length
                move.w  #320,d5             ; d5=screen W
                move.w  #200,d4             ; d4=screen H

                move.w  #4,-(a7)
                trap    #14                 ; getrez
                addq.l  #2,a7
                cmp.w   #0,d0
                beq.s   .rezok
                cmp.w   #1,d0
                beq.s   .medrez
                cmp.w   #2,d0
                beq.s   .higrez
                bra.s   .return
.medrez:        moveq   #2,d7
                lsl.w   #1,d5               ;d5=640
                bra.s   .rezok
.higrez:        moveq   #1,d7
                lsr.w   #1,d6               ;d6h=80
                lsl.w   #1,d5               ;d5=640
                lsl.w   #1,d4               ;d4=400

.rezok:

                ;init boxinfo
                lea     boxinfo(pc),a0
                move.w  #0,_tar_x(a0)                                               ;démarre à 0,0
                move.w  #0,_tar_y(a0)
                move.w  #0,_tar_boxX(a0)                                            ;box: 0 x 0 -> 320|640 x 200|400
                move.w  #0,_tar_boxY(a0)
                move.w  d5,_tar_boxW(a0)
                move.w  d4,_tar_boxH(a0)
                move.l  a6,_tar_addr(a0)                                            ;adresse de l'écran
                move.w  d7,_tar_bitplanes(a0)
                move.w  d6,_tar_lineLen(a0)
                st      _tar_fScroll(a0)
                
                bsr.s   fontClearScreen
                
.return:        movem.l (a7)+,d0-d7/a0-a6
                rts
                
                ;pea     adresse_texte(pc)
                ;pea     adresse_police(pc)
                ;pea     boxinfo(pc)
                ;bsr     draw_line_bitplane_noclip
                ;lea     12(a7),a7



fontClearScreen:
                movem.l d0-d1/a0-a1,-(a7)
                lea     boxinfo(pc),a0
                move.l  _tar_addr(a0),a1
                move.l  #32000/4-1,d0
                moveq   #0,d1
.cls:           move.l  d1,(a1)+
                dbra    d0,.cls
                move.w  d1,_tar_x(a0)
                move.w  d1,_tar_y(a0)
                movem.l (a7)+,d0-d1/a0-a1
                rts


;fontCr:         movem.l d0/a0,-(a7)
;
;                lea     fontinfo(pc),a0
;                pea     FONTE(pc)
;                pea     fontinfo(pc)
;                bsr     getFontInfo
;                addq.l  #8,a7
                
;                move.w  _font_lineBase(a0),d0

;                lea     boxinfo(pc),a0
;                add.w   d0,_tar_y(a0)
;                clr.w   _tar_x(a0)

;                movem.l (a7)+,d0/a0
;                rts

;4(sp):line to print
fontPrintStd:   move.l  4(a7),-(a7)
                pea     fonteStd(pc)
                pea     boxinfo(pc)
                bsr     draw_line_bitplane_noclip
                lea     12(a7),a7
                rts

;4(sp): line to print
;8(sp): font to use
fontPrintCust:  move.l  4(sp),-(sp)
                move.l  8+4(sp),-(sp)
                pea     boxinfo(pc)
                bsr     draw_line_bitplane_noclip
                lea     12(a7),a7
                rts


;a0: boxinfo
;d0: 4 chars to print 
;fontPrint4D0Ascii:
;                movem.l d0-d7/a0-a6,-(a7)
;
;                lea     .tmpspace(pc),a0
;
;                move.l  d0,(a0)                            
;
;                pea     (a0)
;                pea     fonteStd(pc)
;                pea     boxinfo(pc)
;                bsr     draw_line_bitplane_noclip
;                lea     12(a7),a7
;                
;                movem.l (a7)+,d0-d7/a0-a6
;                rts
;.tmpspace:      ds.b    6



                SECTION BSS

charinfo:       ds.b    _char_rsLength
                EVEN
boxinfo:        ds.b    _tar_rsLength
                EVEN
fontinfo:       ds.b    _font_rsLength
                EVEN

                SECTION TEXT

               