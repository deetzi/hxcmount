
;Ce programme scanne les secteurs d'une disquette (face 0 uniquement) ou la SDCARD du HxC Floppy Emulator
;Utilisation:
;taper s puis le numéro du secteur  et ENTER
;taper t puis le numéro de la piste et ENTER  (255 pour aller lire la SDCARD)
;une fois sur la piste 255:
;  le secteur 0 est le secteur de controle de la Hxc
;  les secteurs 1 à 8 représentent les secteurs de la SDCARD, à partir de LBA
;  taper l puis le numéro LBA puis entrer pour lire 8 secteurs à partir du LBA spécifié.
; En cas d'erreur de lecture, il n'y a pas de gestion d'erreur et le secteur précédent se raffiche (!).

                bra     main
                include "..\lib\font.s"
                include "..\lib\util.s"
                include "..\lib\fdc\acc.s"


main:
                bsr     fontInit
        
                pea     SUPER(pc)
                move.w  #$26,-(a7)
                trap    #14
                addq.l  #6,a7
        
                move.l  fonteStdBold(pc),-(a7)
                pea     pushAnyKey(pc)
                bsr     fontPrintCust
                addq.l  #8,a7

                move.w  #7,-(a7)
                trap    #1
                addq.l  #2,a7
                
                clr.w   -(sp)
                trap    #1
pushAnyKey:     dc.b    "Push any key",13,10,0
        EVEN

dumpToScreen:   movem.l d0-d7/a0-a6,-(a7)
    
                move.l  4+15*4(a7),a0                       ;adresse à dumper
                moveq   #0,d6                               ;d6:offset depuis début
                
.ligne:         lea     ligne(pc),a6                        ;a6: buffer ligne à afficher
                tst.w   d6
                beq.s   .nolf
                move.b  #10,(a6)+                           ;LF

.nolf:          ;affiche l'adresse:
                    ;bits 8-15
                    move.w  d6,d0
                    lsr.w   #8,d0
                    bsr     byteToHex
                    move.b  d1,(a6)+
                    lsr.w   #8,d1
                    move.b  d1,(a6)+
                    
                    ;bits 0-7
                    move.w  d6,d0
                    bsr     byteToHex
                    move.b  d1,(a6)+
                    lsr.w   #8,d1
                    move.b  d1,(a6)+
                    move.b  #":",(a6)+
                    move.b  #" ",(a6)+
DUMPX equ 24
                lea     0(a0,d6.w),a1                       ;a1:pointeur sur la ligne à afficher
                moveq   #0,d7                               ;d7:offset depuis le début de la ligne
                lea     DUMPX*3+1(a6),a5
.byte:          move.b  0(a1,d7.w),d0                       ;d0:byte
                bsr     byteToHex                           ;d1.w: 2 chars
                move.b  d1,(a6)+
                lsr.w   #8,d1
                move.b  d1,(a6)+
                move.b  #' ',(a6)+
                
                cmp.b   #32,d0
                bhs.s   .affchar
                move.b  #'.',d0
.affchar:       move.b  d0,(a5)+
                
                addq.w  #1,d7
                cmp.w   #DUMPX,d7
                bne.s   .byte
                
                move.b  #' ',(a6)+
                ;move.b  #' ',(a6)+
                clr.b   (a5)+                               ;eol
                
                move.l  fonteDump(pc),-(a7)
                pea     ligne(pc)
                bsr     fontPrintCust
                addq.l  #8,a7
                
                add.w   #DUMPX,d6
                cmp.w   #$200,d6
                blt     .ligne

                movem.l (a7)+,d0-d7/a0-a6
                rts

ligne:  dcb.b   119,32
        dc.b    0
        EVEN



        
        
SUPER:
            bsr     fdcAccEnter
            bne.s   .errshow

            bsr     fdcAccWait
            bsr     fdcAccSelectDriveASide0
        
            move.w  #0,d0                                   ;track 0
            bsr     fdcAccTrackRegSet
            
            bsr     fdcAccIrqCountReset
            move.w  #3,d0                                   ;RESTORE, no verify, 3ms
            bsr     fdcAccControlRegSet
            bsr     fdcAccIrqCountWait

            clr.w   track
            clr.w   tracklast
            move.w  #1,sector

            bra.s   main_loop

.err:       dc.b    "Failed at initializing.",10,0
            even

.errshow:   move.l  fonteStdBold(pc),-(a7)
            pea     .err(pc)
            bsr     fontPrintCust
            addq.l  #8,a7

            rts
        
main_loop:
            tst.w   sector
            bmi     restoreAndExit

            lea.l   buffer(pc),a0
            move.l  a0,d0
            bsr     fdcAccDmaAdrSet
        
            bsr     fdcAccDmaReadMode

            move.w  track(pc),d0                                                ;track number
            cmp.w   tracklast(pc),d0
            beq.s   .noseek
            bsr     fdcAccDataRegSet

            bsr     fdcAccIrqCountReset
            move.w  #$13,d0                                                     ;SEEK, no verify, 3ms
            bsr     fdcAccControlRegSet
            bsr     fdcAccIrqCountWait
            
            move.w  track(pc),tracklast                                         ;track number

.noseek:    move.w  #1,d0                                                       ;one sector in the DMA sector count
            bsr     fdcAccSectorcountRegSet
        
            move.w  sector(pc),d0                                               ;sector number
            bmi     restoreAndExit
            bsr     fdcAccSectorRegSet

            bsr     fdcAccIrqCountReset
            cmp.w   #255,tracklast
            beq.s   .track255
            move.w  #$80,d0                                                     ;READ SECTOR, spinup
            bra.s   .readsector
.track255:  move.w  #$88,d0                                                     ;READ SECTOR, no spinup
.readsector:bsr     fdcAccControlRegSet
            bsr     fdcAccIrqCountWait

            bsr     display
            
            bsr     ask
            bra     main_loop


restoreAndExit: ;bsr     fdcAccUnselect                                         ;don't let the system deselect for us.
                bsr     fdcAccLeave
                rts




display:        movem.l d0-d7/a0-a6,-(a7)

                move.l  fonteSmall(pc),-(a7)
                pea     promptMsg(pc)
                bsr     fontPrintCust
                addq.l  #8,a7
                
                lea     ligne(pc),a0
                ;affichage Track
                    move.b  #'T',(a0)+
                    move.w  track(pc),d0
                    bsr     byteToHex
                    move.b  d1,(a0)+
                    lsr.w   #8,d1
                    move.b  d1,(a0)+
                move.b  #' ',(a0)+
                ;affichage Sector
                    move.b  #'S',(a0)+
                    move.w  sector(pc),d0
                    bsr     byteToHex
                    move.b  d1,(a0)+
                    lsr.w   #8,d1
                    move.b  d1,(a0)+
                move.b  #':',(a0)+
                move.b  #10,(a0)+
                clr.b   (a0)+
                
                move.l  fonteSmall(pc),-(a7)
                pea     ligne(pc)
                bsr     fontPrintCust
                addq.l  #8,a7
                
                pea     buffer(pc)
                bsr     dumpToScreen
                addq.l  #4,sp
                movem.l (a7)+,d0-d7/a0-a6
                rts





ask:            movem.l d0-d7/a0-a6,-(a7)

                lea     tmpVal(pc),a6                                           ;a6:tmpVal
                clr.w   (a6)
                clr.l   2(a6)

.keyin:         move.w  #7,-(a7)
                trap    #1
                addq.l  #2,a7
                
                cmp.w   #' ',d0
                beq.s   .space
                cmp.w   #'q',d0
                beq.s   .quit
                cmp.w   #'s',d0
                beq.s   .setMode
                cmp.w   #'t',d0
                beq.s   .setMode
                cmp.w   #'l',d0
                beq.s   .setMode
                cmp.w   #13,d0
                beq.s   .enter
                cmp.w   #'0',d0
                blt.s   .notnumber
                cmp.w   #'9',d0
                bls.s   .number
.notnumber                

                bra.s   .keyin

.space:         cmp.w   #'t',(a6)
                beq.s   .incTrack
                addq.w  #1,sector
                bra.s   .return
.incTrack:          addq.w  #1,track
                    bra.s   .return
.setMode:       move.w  d0,(a6)                                                 ;go to sector/track mode
                clr.l   2(a6)                                                   ;reset value
                bra.s   .keyin
.quit:          move.w  #-1,sector
                bra.s   .return                
.enter:         cmp.w   #'t',(a6)
                beq.s   .setTrack
                cmp.w   #'l',(a6)
                beq.s   .setLba
                move.w  2+2(a6),sector      ;low word
                bra.s   .return
.setTrack:          move.w  2+2(a6),track   ;low word
                    bra.s   .return
.setLba:            cmp.w   #255,track
                    bne     .keyin
                    moveq   #0,d0
                    move.l  2(a6),d0
                    bsr     writeControlSector
                    move.w  #1,sector
                    bra.s  .return
.number:        move.w  2(a6),d1            ;high word
                move.w  2+2(a6),d2          ;low word
                mulu    #10,d1              ;d1=10*high
                mulu    #10,d2              ;d2=10*low
                swap    d1
                add.l   d2,d1               ;d1.L = 10*(high|low)
                ext.l   d0
                sub.w   #'0',d0
                add.l   d0,d1               ;d1.L = 10*(high|low) + char
                move.l  d1,2(a6)
                bra     .keyin
                    
.return:        movem.l (a7)+,d0-d7/a0-a6
                rts



;in: d0.l:LBA
writeControlSector:
                movem.l  d0-d7/a0-a6,-(a7)

                lea     writeSector(pc),a0
                move.l  #"HxCF",(a0)+                       ;Signature
                move.l  #"EDA"<<8,(a0)+                     ;Signature
                move.b  #$01,(a0)+                          ;CMD_SET_LBA
                move.b  d0,(a0)+                            ;LBA[7..0]
                ror.w   #8,d0
                move.b  d0,(a0)+                            ;LBA[15..8]
                swap    d0
                move.b  d0,(a0)+                            ;LBA[23..16]
                ror.w   #8,d0
                move.b  d0,(a0)+                            ;LBA[31..24]

                lea     writeSector(pc),a0
                move.l  a0,d0
                bsr     fdcAccDmaAdrSet
        
                bsr     fdcAccDmaWriteMode

                move.w  #1,d0                                                   ;one sector in the DMA sector count
                bsr     fdcAccSectorcountRegSet
        
                moveq   #0,d0                                                   ;sector 0
                bsr     fdcAccSectorRegSet

                bsr     fdcAccIrqCountReset
                move.w  #$a8,d0                                                 ;***WRITE*** SECTOR, no spinup
                bsr     fdcAccControlRegSet
                bsr     fdcAccIrqCountWait
                
.return:        movem.l(a7)+,d0-d7/a0-a6
                rts





track:          dc.w    0
sector:         dc.w    0
tracklast:      dc.w    0
tmpVal:         dc.w    0
                dc.l    0
promptMsg:      dc.b    10,"Enter sector,ENTER ;  T,track,ENTER ;  Space:next ;  Q:quit",10,0
            EVEN


        SECTION DATA
_FONTEDUMP:     incbin  "..\libext\rasteriz\fonts\droid10b.iff"
                EVEN
;FONTE:         incbin  "..\libext\rasteriz\fonts\droid15.iff"
                EVEN
_FONTESMALL:    incbin  "..\libext\rasteriz\fonts\tahoma11.iff"
                EVEN
_FONTESTD:      incbin  "..\libext\rasteriz\fonts\tahoma13.iff"
                EVEN
_FONTESTDBOLD   incbin  "..\libext\rasteriz\fonts\taho13b.iff"
                EVEN

fonteDump:      dc.l    _FONTEDUMP
fonteStd:       dc.l    _FONTESTD
fonteStdBold:   dc.l    _FONTESTDBOLD
fonteSmall:     dc.l    _FONTESMALL





        SECTION BSS
buffer:             ds.b    512
writeSector:        ds.b    512
