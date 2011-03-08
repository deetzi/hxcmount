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
                tst.b   _hxcLbaIsActivated
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
                    move.b  #$01,(a0)+                          ;CMD_SET_LBA
                    clr.b   (a0)+
                    clr.w   (a0)+
                    move.w  #$00A5,(a0)+                        ;Enable Write Support
                    move.w  #(512-14)/2-1,d0
.clearWrite:        clr.w   (a0)+
                    dbra    d0,.clearWrite

                ;print message "searching hxc"
                    pea     _hxcLbaMsgSear(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                ;select Drive A, Side 0
                    bsr     fdcAccFloppyLock
                    bsr     fdcAccWait
                    bsr     fdcAccSelectDriveASide0

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
                    addq.l  #4,a7

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
                    move.w  d0,_hxcLbaDebugFileHandle

                ;file found
                ;print message
                    pea     _hxcLbaMsgFnd(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                ;bra.s   .success

                
                
                
.success:
                ;set current sector to -$80
                    moveq   #-$80,d0
                    lea     _hxcLbaCurrentSectorsNumber(pc),a0
                    move.l  d0,(a0)

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
                tst.b   _hxcLbaIsActivated
                beq.s   .return

                ;print message
                    pea     _hxcLbaMsgLeav(pc)
                    bsr     _hxcLbaPrint
                    addq.l  #4,a7

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
                    
                ;select Drive A, Side 0
                    bsr     fdcAccFloppyLock
                    bsr     fdcAccWait
                    bsr     fdcAccSelectDriveASide0

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
                
                move.l  9*4+8(a7),d1                                            ;d1=asked sector
                move.l  _hxcLbaCurrentSectorsNumber(pc),d0                      ;d0=currentSectorsNumber
                sub.l   d0,d1                                                   ;d1=asked-current=number in currentSectors
                bcs.s   .miss
                cmp.l   #8,d1
                blt     .hit

.miss:          
                ;-----------------------------------------------------------
                ;the asked sector is not in [sectorBase;sectorBase+7] : MISS
                ;-----------------------------------------------------------

                bsr hxcLbaWriteDirtySectors
                    
                ;dirty sectors written. We can know read another sectors.
                ;   9*4+ 4(a7).L : address to read to
                ;   9*4+ 8(a7).L : LBA sector number
                ;   9*4+12(a7).W : 0 for read, 1 for write

                move.l  9*4+8(a7),d1                                            ;d1=asked sector
                ;d1=asked sector
                
                ;is hardware or file ?
                    lea     _hxcLbaIsHardware(pc),a0
                    tst.b   (a0)
                    beq.s   .readSoftware


.readHardware:  ;real hardware:
                ;d1=asked sector

            ;todo: "backward reading": if the asked sector = current sector base-1, move the sectors 1-7 to 2-8 and read only one sector at sector 1

                ;select Drive A, Side 0
                    bsr     fdcAccFloppyLock
                    bsr     fdcAccWait
                    bsr     fdcAccSelectDriveASide0

                ;fill desired sector to fetch into the control sector
                    lea     _hxcLbaControlWrite+9(pc),a0
                    move.b  d1,(a0)+                            ;LBA[7..0]
                    ror.w   #8,d1
                    move.b  d1,(a0)+                            ;LBA[15..8]
                    swap    d1
                    move.b  d1,(a0)+                            ;LBA[23..16]
                    ror.w   #8,d1
                    move.b  d1,(a0)+                            ;LBA[31..24]

                ;write the control sector
                    lea     _hxcLbaControlWrite(pc),a0
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    bsr     fdcAccDmaWriteMode
                    moveq   #1,d0                                                   ;one sector in the DMA sector count
                    bsr     fdcAccSectorcountRegSet
                    moveq   #0,d0                                                   ;sector 0
                    bsr     fdcAccSectorRegSet
                    move.w  #$a8,d0                                                 ;***WRITE*** SECTOR, no spinup
                    bsr     fdcAccSendCommandWait

                ;read all 8 sectors into currentSectors
                    moveq   #1,d1                                               ;start at sector 1
                    lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    bsr     fdcAccDmaReadMode
                    moveq   #8,d0                                                   ;eight sectors to read in the DMA sector count
                    bsr     fdcAccSectorcountRegSet
.readhard:          move.w  d1,d0                                                   ;sector number
                    bsr     fdcAccSectorRegSet
                    move.w  #$88,d0                                                 ;READ SECTOR, no spinup
                    bsr     fdcAccSendCommandWait
                    addq.w  #1,d1                                                   ;next
                    cmp.w   #9,d1
                    bne.s   .readhard

                bsr     fdcAccFloppyUnlock
                
                bra.s   .readdone






            ;use file instead of hardware:
.readSoftware:  ;d1=asked sector
                    clr.w   -(a7)   ;mode=SEEK_SET
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    lsl.l   #8,d1
                    add.l   d1,d1
                    move.l  d1,-(a7)    ;offset
                    move.w  #$42,-(a7)  ;Fseek
                    trap    #1
                    lea     10(a7),a7
                    pea     _hxcLbaCurrentSectorsBuffer(pc)
                    move.l  #8*512,-(a7)    ;read 8 sectors
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    move.w  #$3f,-(a7)  ;Fread
                    trap    #1
                    lea     12(a7),a7

.readdone:      ;put the asked sector number in currentSectorsNumber
                lea     _hxcLbaCurrentSectorsNumber(pc),a0
                ;   9*4+ 4(a7).L : address to read to
                ;   9*4+ 8(a7).L : LBA sector number
                ;   9*4+12(a7).W : 0 for read, 1 for write

                move.l  9*4+8(a7),(a0)                                             ;d1=asked sector
                
                ;clear currentSectorsStatus
                    lea     _hxcLbaCurrentSectorsStatus(pc),a0
                    moveq   #0,d1                                                   ;d1=number of the sector in currentSectors
                    move.l  d1,(a0)+
                    move.l  d1,(a0)+
                ;d1=0: the asked sector is the first in the cache
                ;proceed to HIT.


.hit:
                ;--------------------------------------------------------
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
                
.return:        movem.l (a7)+,d3-d7/a3-a6
                rts















;input: -
;output: -
;registers: d0-d1/a0-a1
hxcLbaWriteDirtySectors:
                ;check dirty status
                    lea     _hxcLbaCurrentSectorsStatus(pc),a1
                    move.l  (a1),d0
                    or.l    4(a1),d0
                    bne.s   .hasDirtySectors

                rts                    

.hasDirtySectors:
                ;there are some dirty sectors. We must write them before reading others sector on top.
                ;test all 8 sectors and write them if necessary

                ;is hardware or file ?
                    lea     _hxcLbaIsHardware(pc),a0
                    tst.b   (a0)
                    beq.s   .dirtySoftware





.dirtyHardware: 
                ;select Drive A, Side 0
                    bsr     fdcAccFloppyLock
                    bsr     fdcAccWait
                    bsr     fdcAccSelectDriveASide0

                lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                ;a0:_hxcLbaCurrentSectorsBuffer
                ;a1:_hxcLbaCurrentSectorsStatus (modified)

                moveq   #1,d1           ;start at sector 1
.nextDirtyH:        tst.b   (a1)           ;is the current sector dirty ?
                    beq.s   .notdirtyH
                    
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    bsr     fdcAccDmaWriteMode
                    moveq   #1,d0                                                   ;1 sectors to write in the DMA sector count
                    bsr     fdcAccSectorcountRegSet
                    move.w  d1,d0                                                   ;sector number
                    bsr     fdcAccSectorRegSet
                    move.w  #$a8,d0                                                 ;***WRITE*** SECTOR, no spinup
                    bsr     fdcAccSendCommandWait

.notdirtyH:     ;next sector: clear dirty flag
                    clr.b   (a1)+
                    lea     512(a0),a0
                    addq.w  #1,d1           ;next
                    cmp.w   #9,d1
                    bne.s   .nextDirtyH

                bsr     fdcAccFloppyUnlock

                rts





.dirtySoftware: 
                lea     _hxcLbaCurrentSectorsBuffer(pc),a0
                move.l  _hxcLbaCurrentSectorsNumber(pc),d1
                ;a0:_hxcLbaCurrentSectorsBuffer
                ;a1:_hxcLbaCurrentSectorsStatus
                ;d1=_hxcLbaCurrentSectorsNumber

                ;write all 8 sectors to the file
                    clr.w   -(a7)   ;mode=SEEK_SET
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    lsl.l   #8,d1       ;*512
                    add.l   d1,d1
                    move.l  d1,-(a7)    ;offset
                    move.w  #$42,-(a7)
                    trap    #1
                    lea     10(a7),a7
                    pea     _hxcLbaCurrentSectorsBuffer(pc)
                    move.l  #8*512,-(a7)
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    move.w  #$40,-(a7)  ;fwrite
                    trap    #1
                    lea     12(a7),a7
                
                ;clear dirty flag for all sectors
                    clr.l   (a1)+
                    clr.l   (a1)+

                rts






;return Z=0 if at least one sector is dirty (NOT USED)
;hxcLbaIsDirty:  move.l   a0,-(a7)
;                lea     _hxcLbaCurrentSectorsStatus(pc),a0
;                move.l  (a0)+,d0
;                or.l    (a0),d0
;                movem.l (a7)+,a0    ;does not touch CCR
;                rts



                dc.l    "XBRA"
                dc.l    "HCHD"
                dc.l    0
_hxcLbaVbl:     movem.l d0-d1/a0-a1,-(a7)
                move.w  $466+2.w,d0                         ;_frlock : vbl counter, not affected by vblsem
                and.b   #$7f,d0                             ;one time every 128 vbl
                bne.s   .return

                bsr     fdcAccFloppyIsLocked                ;don't perform anything if we're still doing something
                bne.s   .return
                bsr     hxcLbaWriteDirtySectors
                
.return:        movem.l (a7)+,d0-d1/a0-a1
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
_hxcLbaMsgFnd:      dc.b    "Found. ",0
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
_hxcLbaCurrentSectorsStatus:ds.b    8*1                                 ;for each sector: 0=ok, otherwise dirty (needed to be written)
_hxcLbaCurrentSectorsBuffer:ds.b    8*512                               ;8 sectors starting by _fdc_LbaCurrentSector
                
                
        SECTION TEXT