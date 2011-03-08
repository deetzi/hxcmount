;fdcAcc
;
;
;
;





        SECTION TEXT
        
        
;save state, install our fdc Irq, set _flock
fdcAccEnter:
                movem.l d0-d7/a0-a6,-(a7)
                lea     _fdcAccIsActivated(pc),a1
                tst.b   (a1)
                bne.s   .return

                ;print message
                    pea     _fdcAccMsgEntr(pc)
                    bsr     _fdcAccPrint
                    addq.l  #4,a7

                ;save
                    lea     _fdcAccSave(pc),a0
                    move.w  $11c.w,(a0)+
;                    move.w  $43e.w,(a0)+                                        ;flock
                    move.b  $fffffa09.w,d0
                    moveq   #0,d1
                    btst    #7,d0                   ;was enabled ?
                    beq.s   .xbrasav                ;yes:old address no:0.l
                    move.l  $11c.w,d0
.xbrasav:           lea     _fdcAccIrq-4(pc),a1
                    move.l  d1,(a1)
                    move.b  d0,(a0)+
                    move.b  $fffffa15.w,(a0)+
                
                ;install our IRQ
                    lea     _fdcAccIrq(pc),a0
                    move.l  a0,$11c.w
                    bset    #7,$fffffa09.w
                    bset    #7,$fffffa15.w
;                    st      $43e.w                                              ;flock
                
                lea     _fdcAccIsActivated(pc),a1
                st  (a1)

                ;print message
                    pea     _fdcAccMsgSucc(pc)
                    bsr     _fdcAccPrint2
                    addq.l  #4,a7

                ;success
                moveq   #0,d0

.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts



;remove our fdc irq
fdcAccLeave:
                movem.l d0-d7/a0-a6,-(a7)
                lea _fdcAccIsActivated(pc),a1
                tst.b   (a1)
                beq.s   .return

                ;print message
                    pea     _fdcAccMsgLeav(pc)
                    bsr     _fdcAccPrint
                    addq.l  #4,a7

                ;restore
                    lea     _fdcAccSave(pc),a0
                    move.w  (a0)+,$11c.w                                        ;irq
;                    move.w  (a0)+,$43e.w                                        ;flock
                    move.b  (a0)+,d0                                            ;ierb
                    and.b   #$80,d0
                    move.b  $fffffa09.w,d1
                    and.b   #$7f,d1
                    or.b    d0,d1
                    move.b  d1,$fffffa09.w
                    move.b  (a0)+,d0                                            ;imrb
                    and.b   #$80,d0
                    move.b  $fffffa15.w,d1
                    and.b   #$7f,d1
                    or.b    d0,d1
                    move.b  d1,$fffffa15.w
                    
                sf  (a1)

                ;print message
                    pea     _fdcAccMsgSucc(pc)
                    bsr     _fdcAccPrint2
                    addq.l  #4,a7
                
.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts







;Select DriveA, Side0
fdcAccSelectDriveASide0:
                move.w  d0,-(sp)
                move.w  sr,-(sp)
                or.w    #$700,sr
                ;PSG set drive/side
                move.b  #14,$ffff8800.w     ;select register 14
                move.b  $ffff8800.w,d0      ;read register 14
                and.b   #$f8,d0             ;clear bits
                or.b    #5,d0               ;%abc a:/driveb b:/drivea c:/side (5:driveA, side0)
                move.b  d0,$ffff8802.w
                move.w  (sp)+,sr
                move.w  (sp)+,d0
                rts

;Unselect drives and sides
fdcAccUnselect:
                move.w  d0,-(sp)
                move.w  sr,-(sp)
                or.w    #$700,sr
                ;PSG set drive/side
                move.b  #14,$ffff8800.w     ;select register 14
                move.b  $ffff8800.w,d0      ;read register 14
                or.b    #7,d0               ;%abc a:/driveb b:/drivea c:/side (5:driveA, side0)
                move.b  d0,$ffff8802.w
                move.w  (sp)+,sr
                move.w  (sp)+,d0
                rts

fdcAccFloppyLock:
                move.l  a0,-(a7)
                ;wait for the hardware to be ready, then claim the resource
                    lea     _fdcAccIsActivated+1(pc),a0
.waitSemaphore:     tas     (a0)
                    bne.s   .waitSemaphore
                st      $43e.w  ;flock
                move.l  (a7)+,a0
                rts

fdcAccFloppyUnlock:
                move.l  a0,-(a7)
                ;free the hardware resource semaphore
                    lea     _fdcAccIsActivated+1(pc),a0
                    sf     (a0)
                sf      $43e.w      ;flock
                move.l  (a7)+,a0
                rts

fdcAccFloppyIsLocked:   ;returns Z=0 if floppy locked, Z=1 otherwise
                move.l  a0,-(a7)
                lea     _fdcAccIsActivated+1(pc),a0
                tst.b    (a0)
                movem.l  (a7)+,a0   ; movem leaves CR
                rts

;Ecrit d0 dans les registres FDC ou lit un registre dans d0
;entrée : d0.w si set
;sortie : d0.w si get
;registres utilisés: -
fdcAccStatusRegGet:
                move.w  d1,-(sp)
                move.w  #$80,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  $ffff8604.w,d0
                move.w  (sp)+,d1
                rts
fdcAccControlRegSet:
                move.w  d1,-(sp)
                move.w  #$80,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  d0,$ffff8604.w
                move.w  (sp)+,d1
                rts
fdcAccTrackRegGet:
                move.w  d1,-(sp)
                move.w  #$82,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  $ffff8604.w,d0
                move.w  (sp)+,d1
                rts
fdcAccTrackRegSet:
                move.w  d1,-(sp)
                move.w  #$82,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  d0,$ffff8604.w
                move.w  (sp)+,d1
                rts
fdcAccSectorRegGet:
                move.w  d1,-(sp)
                move.w  #$84,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  $ffff8604.w,d0
                move.w  (sp)+,d1
                rts
fdcAccSectorRegSet:
                move.w  d1,-(sp)
                move.w  #$84,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  d0,$ffff8604.w
                move.w  (sp)+,d1
                rts
fdcAccDataRegGet:
                move.w  d1,-(sp)
                move.w  #$86,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  $ffff8604.w,d0
                move.w  (sp)+,d1
                rts
fdcAccDataRegSet:
                move.w  d1,-(sp)
                move.w  #$86,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  d0,$ffff8604.w
                move.w  (sp)+,d1
                rts
fdcAccSectorcountRegSet:
                move.w  d1,-(sp)
                move.w  #$90,d1
                add.w   _fdcAccDmaMode(pc),d1
                move.w  d1,$ffff8606.w
                move.w  d0,$ffff8604.w
                move.w  (sp)+,d1
                rts
fdcAccDmaReadMode:
                move.l  a0,-(sp)
                lea     $ffff8606.w,a0
                move.w  #$90, (a0)
                move.w  #$190,(a0)
                move.w  #$90, (a0)
                lea     _fdcAccDmaMode(pc),a0
                clr.w   (a0)
                move.l  (sp)+,a0
                rts
fdcAccDmaWriteMode:
                move.l  a0,-(sp)
                lea     $ffff8606.w,a0
                move.w  #$190,(a0)
                move.w  #$90, (a0)
                move.w  #$190,(a0)
                lea     _fdcAccDmaMode(pc),a0
                move.w  #$100,(a0)
                move.l  (sp)+,a0
                rts
fdcAccDmaAdrSet:move.l  d0,-(sp)      
                move.b  d0,$ffff860d.w      ;set address low
                lsr.w   #8,d0
                move.b  d0,$ffff860b.w      ;set address mid
                swap d0
                move.b  d0,$ffff8609.w      ;set address high
                move.l  (sp)+,d0
                rts
fdcAccDmaAdrGet:moveq   #0,d0
                move.b  $ffff8609.w,d0      ;load address high
                swap d0
                move.b  $ffff860b.w,d0      ;load address mid
                lsr.w   #8,d0
                move.b  d0,$ffff860d.w      ;load address low
                rts
fdcAccIrqCountReset:
                move.l  a0,-(sp)
                lea     _fdcAccIrqCounter(pc),a0
                clr.w   (a0)
                move.l  (sp)+,a0
                rts
fdcAccSendCommandWait:
                bsr.s   fdcAccIrqCountReset
                bsr     fdcAccControlRegSet
                bsr.s   fdcAccIrqCountWait
                rts
                dc.l    "XBRA"
                dc.l    "HXHD"
                dc.l    0
_fdcAccIrq:     move.l  a0,-(a7)
                lea     _fdcAccIrqCounter(pc),a0
                addq.w  #1,(a0)
                bclr    #7,$fffffa11.w
                lea     _fdcAccIrq-4(pc),a0
                tst.l   (a0)
                beq.s   .xbraret
                ;xbra
                lea     .xbraret(pc),a0
                move.l  a0,-(a7)        ;stack return address
                move.w  sr,-(a7)
                move.l   _fdcAccIrq-4(pc),a0
                jmp     (a0)
                ;xbra returns here
.xbraret:       move.l  (a7)+,a0
                rte
fdcAccIrqCountWait:
                move.l  a0,-(sp)
                lea     _fdcAccIrqCounter(pc),a0
.wait:          tst.w   (a0)
                beq.s   .wait
                move.l  (sp)+,a0
                rts
fdcAccWait:     move.w  d1,-(sp)
                move.w  #$80,d1
                move.w  d1,$ffff8606.w
.busy:          move.w  $ffff8604.w,d1
                btst    #0,d1
                bne.s   .busy
                move.w  (sp)+,d1
                rts

_fdcAccPrint:   movem.l d0-d2/a0-a2,-(a7)
                pea     _fdcAccMsg00(pc)
                bsr     fontPrintStd
                move.l  6*4+4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #8,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts
_fdcAccPrint2:  movem.l d0-d2/a0-a2,-(a7)
                move.l  6*4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #4,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts


_fdcAccMsg00:       dc.b    "fdcAcc: ",0
_fdcAccMsgEntr:     dc.b    "Entering Floppy Controller Driver... ",0
_fdcAccMsgSucc:     dc.b    "Success.",13,10,0
_fdcAccMsgLeav:     dc.b    "Leaving Floppy Controller Driver... ",0
        EVEN


        SECTION BSS
_fdcAccIsActivated: ds.b    1                                   ;is our IRQ installed ? 0:no -1:yes
                    ds.b    1                                   ;semaphore. When set, an access is occuring, no other operation can be made

                    EVEN
_fdcAccSave:        ds.l    1                                   ;fdc interrupt ($11c)
                    ds.b    1                                   ;ierb ($fffa09)
                    ds.b    1                                   ;imrb ($fffa15)
                    EVEN
_fdcAccIrqCounter:  ds.w    1                                   ;counter of fdc Irqs
_fdcAccDmaMode:     ds.w    1                                   ;0 for read-mode. $100 for write-mode
        SECTION TEXT
