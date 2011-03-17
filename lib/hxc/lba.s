;hxcLba
;
;
;
;


;        include "acc.s"

        SECTION TEXT
        
        
;Set the Floppy Controller in LBA Mode
;Disable floppies
;output : d0=0/Z=1 ok, else nok
hxcLbaEnter:
                movem.l d1-d7/a0-a6,-(a7)
                lea     _hxcLbaIsActivated(pc),a0
                tst.b   (a0)
                bne     .return

                ;print message
                    pea     _hxcLbaMsgEntr(pc)
                    bsr     _hxcLbaPrint
                    addq.l  #4,a7

                ;save state
                    lea     _hxcLbaSave(pc),a0
                    move.w  $4a6.w,(a0)+                                        ;_nflops
                    move.w  $4c2+2.w,(a0)+                                      ;(_drvbits+2)

                ;call fdcAccEnter
                    bsr fdcAccEnter

                ;prepare _hxcLbaControlWrite
                    lea     _hxcLbaControlWrite(pc),a0
                    move.l  #"HxCF",(a0)+                       ;Signature
                    move.l  #"EDA"<<8,(a0)+                     ;Signature
                    move.l  #$01000000,(a0)+                    ;CMD_SET_LBA, adr0, adr1, adr2
                    move.l  #$00A50000+HXCLBACACHESIZE<<8,(a0)+ ;adr3, Enable Write Support, number of sectors, 00
                    move.w  #(512-16)/2-1,d0
.clearWrite:        clr.w   (a0)+
                    dbra    d0,.clearWrite

                ;print message "searching hxc"
                    pea     _hxcLbaMsgSear(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                bsr     fdcAccFloppyLock

                ;seek to track 255
                    move.w  #255,d0                                             ;track number
                    bsr     fdcAccDataRegSet
                    moveq   #$13,d0                                             ;SEEK, no verify, 3ms
                    bsr     fdcAccSendCommandWait
                    
                ;read sector 0
                    lea     _hxcLbaControlRead(pc),a0
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    bsr     fdcAccDmaReadMode
                    moveq   #1,d0                                               ;one sector in the DMA sector count
                    bsr     fdcAccSectorcountRegSet
                    moveq   #0,d0                                               ;sector 0
                    bsr     fdcAccSectorRegSet
                    move.w  #$88,d0                                             ;READ SECTOR, no spinup
                    bsr     fdcAccSendCommandWait

                bsr     fdcAccFloppyUnlock

                ;verify if HxC Floppy Emulator is present
                    lea     _hxcLbaControlWrite(pc),a1
                    cmp.l   (a0)+,(a1)+                                         ;signature
                    bne.s   .softwaresimul
                    cmp.l   (a0)+,(a1)+                                         ;signature
                    bne.s   .softwaresimul


.hardwarefound: ;hxcHardware found
                    lea     _hxcLbaIsHardware(pc),a1
                    st      (a1)

               ;print message hardware found
                    pea     _hxcLbaMsgFnd(pc)
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaControlRead+8(pc)                            ;firmware version
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaMsgFnd2(pc)
                    bsr     _hxcLbaPrint2
                    lea     12(a7),a7

                ;remove floppies from system
                    clr.w   $4a6.w                                                  ;_nflops
                    and.w   #$fffc,$4c2+2.w                                         ;(_drvbits+2)
                
                bra.s   .success


.softwaresimul: ;no hardware found. Try to use file
                    lea     _hxcLbaIsHardware(pc),a1
                    sf      (a1)

                ;print message "hxc not found, reverting to file xxxxx"
                    pea     _hxcLbaMsgSearRev(pc)
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaDebugFileName(pc)
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaMsgSearRev2(pc)
                    bsr     _hxcLbaPrint2
                    lea     12(a7),a7

                ;use a file on the ST computer instead of HxC hardware
                    clr.w  -(a7)    ;readonly
                    pea     _hxcLbaDebugFileName(pc)
                    move.w  #$3d,-(a7)      ;Fopen
                    trap    #1
                    addq.l  #8,a7
                    tst.w   d0
                    bmi.s   .filenotfound
                    lea     _hxcLbaDebugFileHandle(pc),a0
                    move.w  d0,(a0)

                ;file found
                ;print message
                    pea     _hxcLbaMsgFnd(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                ;bra.s   .success

                
                
                
.success:
                ;set current sector to -$80 and currentSectorsStatus to empty
                    moveq   #-$80,d0
                    lea     _hxcLbaCurrentSectorsNumber(pc),a0
                    move.l  d0,(a0)
                    moveq   #0,d0
                    lea     _hxcLbaCurrentSectorsStatus(pc),a0
                    IFNE HXCLBACACHESIZE>>2>0
                        REPT HXCLBACACHESIZE>>2
                            move.l  d0,(a0)+
                        ENDR
                    ENDC
                    IFNE HXCLBACACHESIZE&3>0
                        REPT HXCLBACACHESIZE&3
                            move.b  d0,(a0)+
                        ENDR
                    ENDC

                ;install our VBL
                    lea     _hxcLbaVbl(pc),a0
                    move.l  $70.w,-4(a0)
                    move.l  a0,$70.w
                    
                ;set flag isActivated
                    lea     _hxcLbaIsActivated(pc),a0
                    st      (a0)
                
                ;print success
                    pea     _hxcLbaMsgSucc(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                ;success
                moveq   #0,d0

                bra.s   .return

.filenotfound:  ;print
                    pea     _hxcLbaMsgNotFnd(pc)
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaMsgFail(pc)
                    bsr     _hxcLbaPrint
                    addq.l  #8,a7

                ;fail
                moveq   #-1,d0

.return:
                movem.l (a7)+,d1-d7/a0-a6
                tst.w   d0
                rts







;Set the Floppy Controller in Normal Mode
;Re-enable floppies
hxcLbaLeave:
                movem.l d0-d7/a0-a6,-(a7)
                lea     _hxcLbaIsActivated(pc),a0
                tst.b   (a0)
                beq.s   .return

                ;print message
                    pea     _hxcLbaMsgLeav(pc)
                    bsr     _hxcLbaPrint
                    addq.l  #4,a7

                bsr     fdcAccFloppyLock

                ;write dirty sectors, if any, otherwise, write will be lost
                    bsr     hxcLbaWriteDirtySectors

                ;remove our VBL
                    lea     _hxcLbaVbl-4(pc),a0
                    move.l  (a0),$70.w

                ;restore
                    lea     _hxcLbaSave(pc),a0
                    move.w  (a0)+,$4a6.w                                        ;_nflops
                    move.w  (a0)+,d0
                    and.w   #3,d0                                               ;only drive a&b
                    or.w    d0,$4c2+2.w                                         ;(_drvbits+2)
                    
                ;seek to track 0 (restore)
                    moveq   #$03,d0                                             ;RESTORE, no verify, 3ms
                    bsr     fdcAccSendCommandWait

                bsr     fdcAccFloppyUnlock

                lea _hxcLbaIsHardware(pc),a0
                tst.b   (a0)
                bne.s   .realhardware

                ;using file instead of hardware
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    move.w  #$3e,-(a7)  ;Fclose
                    trap    #1
                    addq.l  #4,a7

.realhardware:  lea _hxcLbaIsActivated(pc),a0
                sf  (a0)

               ;print message
                    pea     _hxcLbaMsgSucc(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts






;Read a sector from the SDcard or a file
;parameters:
;   4(a7).L : address to read to
;   8(a7).L : LBA sector number
;  12(a7).W : 0 for read, 1 for write
;registers modified:a0-a2/d0-d2
hxcLbaSectorGet:
                movem.l d3-d7/a3-a6,-(a7)
                
                bsr     fdcAccFloppyLock
                move.l  9*4+8(a7),d1                                            ;d1=asked sector
                move.l  _hxcLbaCurrentSectorsNumber(pc),d0                      ;d0=currentSectorsNumber
                sub.l   d0,d1                                                   ;d1=asked-current=number in currentSectors
                bcs.s   .cacheOut                               ;if < 0 : out of cache
                cmp.l   #HXCLBACACHESIZE,d1
                bge.s   .cacheOut                               ;if >=8 : out of cache

                ;asked sector is in the cache segment [0;7]. HxC LBA start=sector 0 of the cache segment
                ;d0=currentSectorsNumber
                ;d1=number of the sector in the segment [0;7]

                ;check sector status. Can be empty(0), read(80) or dirty(FF)                
                    lea     _hxcLbaCurrentSectorsStatus(pc),a0
                    tst.b   0(a0,d1.w)
                    bne.s   .hit                                ;read or dirty : **HIT**
                
                ;sector status=empty.
                ;Read ? Sector must be read in the cache. Tag "read". Then goto HIT (get data from the cache, tag OK)
                ;Write ? Then Goto HIT (fill the cache, tag "dirty")
                
                tst.w   9*4+12(a7)  ;read=0 or write ?
                bne.s   .hit

                ;read one sector in the cache
                                                                    ;d1=number of sector in the currentSectors [0;7]
                    moveq   #-1,d2                                  ;d2=LBA base -1 = no change
                    moveq   #1,d3                                   ;d3=1 sector to read
                    moveq   #0,d4                                   ;d4=0 read
                    bsr     _hxcLbaCacheSectors
                
                bra.s   .hit


.cacheOut:          
                ;-----------------------------------------------------------
                ;the asked sector is not in [sectorBase;sectorBase+7] : MISS
                ;-----------------------------------------------------------

                bsr hxcLbaWriteDirtySectors
                
                ;clear hxcLbaCurrentSectorsStatus to "0" (empty)
                    lea     _hxcLbaCurrentSectorsStatus(pc),a0
                    IFNE HXCLBACACHESIZE>>2>0
                        REPT HXCLBACACHESIZE>>2
                            clr.l   (a0)+
                        ENDR
                    ENDC
                    IFNE HXCLBACACHESIZE&3>0
                        REPT HXCLBACACHESIZE&3
                            clr.b   (a0)+
                        ENDR
                    ENDC
                    
                ;dirty sectors written. We can know read 8 sectors into the cache, then returns the first one _or_ just copy the sector to the cache and return it
                ;   9*4+ 4(a7).L : address to read to
                ;   9*4+ 8(a7).L : LBA sector number
                ;   9*4+12(a7).W : 0 for read, 1 for write

                moveq   #0,d1                                                   ;d1=sector number [0-7]
                move.l  9*4+8(a7),d2                                            ;d2=asked sector
                bsr     _hxcLbaBaseChange
                move.w  9*4+12(a7),d4                                           ;d4:0 for read
                bne.s   .readdone                                               ;if write, goto readdone (will actually write one to cache)
                ;read:
                moveq   #HXCLBACACHESIZE,d3                                     ;d3=read 8 sectors
                bsr     _hxcLbaCacheSectors


.readdone:      moveq   #0,d1                                                   ;d1=sector number [0-7]=0

                ;proceed to HIT.

.hit:           ;--------------------------------------------------------
                ;the asked sector *is* in [sectorBase;sectorBase+7] : HIT
                ;--------------------------------------------------------
                ;d1=number of the sector in currentSectors [0-7]

                lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                move.w  d1,d2                                                       ;d2=currentSector number [0-7]
                add.w   d1,d1
                lsl.w   #8,d1                               ;512                    ;d1=byte offset in currentSectors
                lea     0(a0,d1.w),a0                                               ;a0=addr of the asked sector
                move.l  9*4+4(a7),a1                                                ;a1=addr to write the sector to
                
                tst.w   9*4+12(a7)  ;read=0 or write ?
                beq.s   .copysector
                
                ;writeoperation: exchange source<-->destination, mark the sector dirty
                    exg.l   a0,a1
                    lea     _hxcLbaCurrentSectorsStatus(pc),a2
                    st      0(a2,d2.w)

.copysector:    ;copy the sector
                ;verify that a0 and a1 are even
                    ;at least one of (a0,a1) is even (because we read/write to our buffer)
                    move.w  a0,d0
                    move.w  a1,d1
                    or.b    d1,d0
                    btst    #0,d0
                    bne.s   .odd
                
                ;even
                    movem.l (a0)+,d0-d7/a2-a6           ; 52 bytes
                    movem.l d0-d7/a2-a6,(a1)            ; 52 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,52(a1)          ;104 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,104(a1)         ;156 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,156(a1)         ;208 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,208(a1)         ;260 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,260(a1)         ;312 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,312(a1)         ;364 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,364(a1)         ;416 bytes copied
                    movem.l (a0)+,d0-d7/a2-a6
                    movem.l d0-d7/a2-a6,416(a1)         ;468 bytes copied
                    movem.l (a0)+,d0-d7/a2-a4           ; 44 bytes
                    movem.l d0-d7/a2-a4,468(a1)         ;512 bytes copied
                bra.s   .return

.odd            ;odd
                    moveq   #512/4-1,d0
    .oddcopy:       move.b  (a0)+,(a1)+                    
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    dbra    d0,.oddcopy
                
.return:        bsr     fdcAccFloppyUnlock
                movem.l (a7)+,d3-d7/a3-a6
                rts







_hxcLbaCacheSectors:
; read sectors from the floppy to the cache OR write sectors from the cache to the floppy
; clears sectorsStatus to OK in both cases.
;d1.w: start sector [0;7] (will read/write sector 1 to 8)
;d2.l: LBA base sector (-1.L : no change)
;d3.w: nb sectors to read/write [1;8]
;d4.w: read(0) or write
;modifies d0,d2,d3,d5,a0,a1,a2

                bsr     _hxcLbaBaseChange

                move.w  d1,d5
                ext.l   d5
                lea     _hxcLbaIsHardware(pc),a0
                tst.b   (a0)
                bne.s   _hxcLbaCacheHardware

_hxcLbaCacheSoftware:
;d5.w: start sector [0;7] (will read/write sector 1 to 8)
;d2.l: LBA base sector (-1.L : no change)
;d3.w: nb sectors to read/write [1;8]
;d4.w: read(0) or write
;modifies d0,d2,d3,d5,a0,a1,a2

                add.l   d5,d2                                                   ;d2=absolute number of the sector

                ;seek
                    clr.w   -(a7)   ;mode=SEEK_SET
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    lsl.l   #8,d2
                    add.l   d2,d2
                    move.l  d2,-(a7)    ;offset
                    move.w  #$42,-(a7)  ;Fseek
                    trap    #1
                    lea     10(a7),a7

                ;compute cache address
                    lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                    move.w  d5,d2                                           ;d2=currentSector number [0-7]
                    add.w   d2,d2
                    lsl.w   #8,d2                               ;*512       ;d2=byte offset in currentSectors
                    lea     0(a0,d2.w),a0                                   ;a0=addr for the asked sector

                ;compute currentSectorsStatus address
                    lea     _hxcLbaCurrentSectorsStatus(pc),a1
                    lea     0(a1,d5.w),a1                                       ;a1=addr of the first sector status

                subq.w  #1,d3                                                   ;for dbra
.readwritenxt:  ;read/write
                    movem.l a0/a1,-(a7)
                    pea     (a0)
                    pea     512.w
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    tst.w   d4
                    bne.s   .write
                    ;read:
                    move.w  #$3f,-(a7)  ;Fread
                    trap    #1
                    lea     12(a7),a7
                    movem.l (a7)+,a0/a1
                    move.b  #$80,(a1)+                                          ;sector is OK
                    add.w   #512,a0
                    dbra    d3,.readwritenxt

                    bra.s   .return

.write:             move.w  #$40,-(a7)  ;Fwrite
                    trap    #1
                    lea     12(a7),a7
                    movem.l (a7)+,a0/a1
                    move.b  #$80,(a1)+                                          ;sector is OK
                    add.w   #512,a0
                    dbra    d3,.readwritenxt

.return:            
                rts



_hxcLbaCacheHardware:
;d2.l: LBA base sector (-1.L : no change)
;d3.w: nb sectors to read/write [1;8]
;d4.w: read(0) or write
;d5.w: start sector [0;7] (will read/write sector 1 to 8)
;modifies d0,d2,d3,d5,a0,a1

                ;compute currentSectorsStatus address
                    lea     _hxcLbaCurrentSectorsStatus(pc),a1
                    lea     0(a1,d5.w),a1                                       ;a1=addr of the first sector status

                ;compute DMA address
                    lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                    move.w  d5,d2                                           ;d2=currentSector number [0-7]
                    add.w   d2,d2
                    lsl.w   #8,d2                               ;512        ;d2=byte offset in currentSectors
                    lea     0(a0,d2.w),a0                                   ;a0=addr for the asked sector

                ;set DMA address
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    
                tst.w   d4
                bne.s   .write
                
                ;read
                bsr     fdcAccDmaReadMode
                move.w  d3,d0                                               ;nb sectors to process by DMA
                bsr     fdcAccSectorcountRegSet
                subq.w  #1,d3                                               ;sector to read-1 (for dbra)
.readnxt:       addq.w  #1,d5                                               ;sector number starts at 1
                move.w  d5,d0                                               ;sector number
                bsr     fdcAccSectorRegSet
                move.w  #$88,d0                                             ;READ SECTOR, no spinup
                bsr     fdcAccSendCommandWait
                move.b  #$80,(a1)+                                          ;sector is read
                dbra    d3,.readnxt

                bra.s   .return

                
.write:         ;write
                bsr     fdcAccDmaWriteMode
                move.w  d3,d0                                               ;nb sectors to process by DMA
                bsr     fdcAccSectorcountRegSet
                subq.w  #1,d3                                               ;sector to read-1 (for dbra)
.writenxt:      addq.w  #1,d5                                               ;sector number starts at 1
                move.w  d5,d0                                               ;sector number
                bsr     fdcAccSectorRegSet
                move.w  #$A8,d0                                             ;***WRITE*** SECTOR, no spinup
                bsr     fdcAccSendCommandWait
                move.b  #$80,(a1)+                                          ;sector is read
                dbra    d3,.writenxt

.return:        rts







;input: -
;output: -
;registers: d0-d2/a0-a2
hxcLbaWriteDirtySectors:
                movem.l d3-d5/a3,-(a7)
                lea     _hxcLbaCurrentSectorsStatus(pc),a3

                moveq   #0,d1                                                   ;start at sector 0
.nextDirty:         cmp.b   #$ff,(a3)                                           ;is the current sector dirty ?
                    bne.s   .notdirty
                    
                    move.l  _hxcLbaCurrentSectorsNumber(pc),d2                  ;LBA base
                    moveq   #1,d3                                               ;1 sector
                    moveq   #1,d4                                               ;write
                    bsr     _hxcLbaCacheSectors
                    
                    move.b  #$80,(a3)                                           ;tag sector "OK"
.notdirty:     ;next sector:
                    addq.l  #1,a3
                    addq.w  #1,d1                                               ;next
                    cmp.w   #HXCLBACACHESIZE,d1
                    bne.s   .nextDirty

                movem.l (a7)+,d3-d5/a3
                rts




;d2.l:  new LBA sector base; -1: no change
;registers: -
_hxcLbaBaseChange:
                movem.l d0/a0-a1,-(a7)

                cmp.l   #-1,d2
                beq.s   .return
                lea     _hxcLbaCurrentSectorsNumber(pc),a0
                cmp.l   (a0),d2
                beq.s   .return
                
                ;write the new LBA base
                move.l  d2,(a0)+

                lea     _hxcLbaIsHardware(pc),a1
                tst.b   (a1)
                beq.s   .return                                                 ;if software, just returns
                
                ;fill desired sector to fetch into the control sector
                    lea     _hxcLbaControlWrite+9(pc),a1
                    move.b  -(a0),(a1)+                            ;LBA[7..0]
                    move.b  -(a0),(a1)+                            ;LBA[15..8]
                    move.b  -(a0),(a1)+                            ;LBA[23..16]
                    move.b  -(a0),(a1)+                            ;LBA[31..24]

                ;write the control sector
                    lea     _hxcLbaControlWrite(pc),a0
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    bsr     fdcAccDmaWriteMode
                    moveq   #1,d0                                                   ;one sector in the DMA sector count
                    bsr     fdcAccSectorcountRegSet
                    moveq   #0,d0                                                   ;sector 0
                    bsr     fdcAccSectorRegSet
                    move.w  #$A8,d0                                                 ;***WRITE*** SECTOR, no spinup
                    bsr     fdcAccSendCommandWait
                
.return:        movem.l (a7)+,d0/a0-a1
                rts












                dc.l    "XBRA"
                dc.l    "HCHD"
                dc.l    0
_hxcLbaVbl:     movem.l d0-d2/a0-a2,-(a7)
                move.w  $466+2.w,d0                         ;_frlock : vbl counter, not affected by vblsem
                and.b   #$7f,d0                             ;one time every 128 vbl
                bne.s   .return

                bsr     fdcAccFloppyIsLocked                ;don't perform anything if we're still doing something
                bne.s   .return

                bsr     fdcAccFloppyLock
                bsr     hxcLbaWriteDirtySectors
                bsr     fdcAccFloppyUnlock

.return:        movem.l (a7)+,d0-d2/a0-a2
                move.l  _hxcLbaVbl-4(pc),-(a7)
                rts






_hxcLbaPrint:   movem.l d0-d2/a0-a2,-(a7)
                pea     _hxcLbaMsg00(pc)
                bsr     fontPrintStd
                move.l  6*4+4+4(a7),-(a7)
                bsr     fontPrintStd
                addq.l  #8,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts
_hxcLbaPrint2:  movem.l d0-d2/a0-a2,-(a7)
                move.l  6*4+4(a7),-(a7)
                bsr     fontPrintStd
                addq.l  #4,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts


_hxcLbaMsg00:       dc.b    "hxcLba: ",0
_hxcLbaMsgEntr:     dc.b    "Entering HxC Floppy Emulator LBA driver... ",0
_hxcLbaMsgSear:     dc.b    "searching for HxC Floppy Emulator hardware at A:... ",0
_hxcLbaMsgFnd:      dc.b    "Found HxC Floppy Emulator with firmware ",0
_hxcLbaMsgFnd2:     dc.b    ". ",0
_hxcLbaMsgSearRev:  dc.b    "Not found. Using file ",0
_hxcLbaMsgSearRev2: dc.b    " instead... ",0
_hxcLbaMsgNotFnd:   dc.b    " file not found. Cannot proceed.",13,10,0
_hxcLbaMsgSucc:     dc.b    "Success.",13,10,0
_hxcLbaMsgFail:     dc.b    "FAILED.",13,10,0
_hxcLbaMsgLeav:     dc.b    "Leaving HxC Floppy Emulator LBA driver... ",0
_hxcLbaDebugFileName:   dc.b    "c:\tmp\img32c.ima",0
        EVEN
_hxcLbaDebugFileHandle: dc.w    0
        EVEN

        SECTION BSS
_hxcLbaIsActivated:         ds.b    1                                   ;is the FDC in LBA Mode ? 0:no -1:yes
_hxcLbaIsHardware:          ds.b    1                                   ;FF:HxcHardware, 00:file
                EVEN
_hxcLbaSave:                ds.w    1                                   ;_nflops(4a6)
                            ds.w    1                                   ;_drvbits+2(4c2+2)
_hxcLbaControlWrite:        ds.b    512                                 ;used to change LBA base address, by WRITING to sector 0
_hxcLbaControlRead:         ds.b    512
_hxcLbaCurrentSectorsNumber:ds.l    1                                   ;current start sector
_hxcLbaCurrentSectorsStatus:ds.b    HXCLBACACHESIZE*1                   ;for each sector: 0=empty, 80=ok, FF=dirty (need to be written)
                            EVEN
_hxcLbaCurrentSectorsBuffer:ds.b    HXCLBACACHESIZE*512                 ;8 sectors starting by _fdc_LbaCurrentSector
                
                
        SECTION TEXT