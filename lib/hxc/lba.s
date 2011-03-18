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
                    move.w  #$0100,(a0)+                        ;CMD_SET_LBA
                    move.w  #(512-10)/2-1,d0
.clearWrite:        clr.w   (a0)+
                    dbra    d0,.clearWrite

                ;print message "searching hxc"
                    pea     _hxcLbaMsgSear(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                bsr     fdcAccLock

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

                bsr     fdcAccUnlock

                ;verify if HxC Floppy Emulator is present
                    lea     _hxcLbaControlWrite(pc),a1
                    cmp.l   (a0)+,(a1)+                                         ;signature
                    bne.s   .softwaresimul
                    cmp.l   (a0)+,(a1)+                                         ;signature
                    bne.s   .softwaresimul


.hardwarefound: ;hxcHardware found
                    lea     _hxcLbaIsHardware(pc),a1
                    st      (a1)

                lea     _hxcLbaControlRead+8(pc),a1                             ;firmware version

               ;print message hardware found
                    pea     _hxcLbaMsgFnd(pc)
                    bsr     _hxcLbaPrint2
                    pea     (a1)                                                ;firmware version
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaMsgFnd2(pc)
                    bsr     _hxcLbaPrint2
                    lea     12(a7),a7

                ;check firmware version
                    cmp.l   #"V1.5",(a1)+
                    blt     .firmTooOld
                    bgt.s   .firmOk
                    cmp.l   #".2.0",(a1)+
                    blt     .firmTooOld
                    bgt.s   .firmOk
                    cmp.w   #"m"<<8,(a1)+
                    blt.s   .firmTooOld
                
.firmOk:        ;remove floppies from system
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
                    pea     _hxcLbaMsgFnd3(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #4,a7

                ;bra.s   .success

                
                
                
.success:
                ;set flag isActivated
                    lea     _hxcLbaIsActivated(pc),a0
                    st      (a0)
                
                ;locked = false
                    lea     _hxcLbaIsLocked(pc),a0
                    sf      (a0)

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
                    bsr     _hxcLbaPrint2
                    addq.l  #8,a7
                bra.s   .fail
.firmTooOld:  ;print
                    pea     _hxcLbaMsgTooOld(pc)
                    bsr     _hxcLbaPrint2
                    pea     _hxcLbaMsgFail(pc)
                    bsr     _hxcLbaPrint2
                    addq.l  #8,a7
                ;bra.s   .fail

                ;fail
.fail:          moveq   #-1,d0

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

                bsr     fdcAccLock

                ;restore
                    lea     _hxcLbaSave(pc),a0
                    move.w  (a0)+,$4a6.w                                        ;_nflops
                    move.w  (a0)+,d0
                    and.w   #3,d0                                               ;only drive a&b
                    or.w    d0,$4c2+2.w                                         ;(_drvbits+2)
                    
                ;seek to track 0 (restore)
                    moveq   #$03,d0                                             ;RESTORE, no verify, 3ms
                    bsr     fdcAccSendCommandWait

                bsr     fdcAccUnlock

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






;hxcLbaRwabs: read/write sectors from/to the SDcard or a file
;parameters:
;   4(a7).L : address to read to/write from
;   8(a7).L : LBA sector number
;  12(a7).W : 0 for read, 1 for write
;  14(a7).w : number of sectors to read/write
;registers modified:a0-a2/d0-d2
hxcLbaRwabs:    movem.l d3/a3-a4,-(a7)
                
                move.w  12+14(a7),d3            ;d3=nb sectors
                move.l  12+8(a7),a3             ;a3=sector number
                move.l  12+4(a7),a4             ;a4=address

                ;check if address is even
                    move.l  a4,d0
                    btst    #0,d0
                    bne     .oddRwEnter
                
.sectorsLoop:
                sub.w   #63,d3
                bcs.s   .last
                
                move.w  #63,-(a7)               ;nb sectors
                move.w  12+2+12(a7),-(a7)       ;read/write (+2 due to stack usage)
                pea     (a3)                    ;sector number
                pea     (a4)                    ;address
                bsr.s   _hhxcLbaRwabs
                lea     12(a7),a7
                lea     63(a3),a3               ;sector number + 63
                lea     63*512(a4),a4           ;address + 63 sectors
                bra.s   .sectorsLoop
                
.last:          add.w   #63,d3                  ;d3 was < 0
                beq.s   .return

                move.w  d3,-(a7)                ;nb sectors
                move.w  12+2+12(a7),-(a7)       ;read/write (+2 due to stack usage)
                pea     (a3)                    ;sector number
                pea     (a4)                    ;address
                bsr.s   _hhxcLbaRwabs
                lea     12(a7),a7

                bra.s   .return

.oddSectorsLoop:
                ;read or write ?
                    tst.w   12+12(a7)
                    beq.s   .oddRw
                ;write operation: copy sector to our buffer first
                    lea     _hxcLbaBuffer(pc),a0
                    moveq   #512/4-1,d0
.oddWriteCpy:       move.b  (a4)+,(a0)+
                    move.b  (a4)+,(a0)+
                    move.b  (a4)+,(a0)+
                    move.b  (a4)+,(a0)+
                    dbra    d0,.oddWriteCpy
                
.oddRw:         move.w  #1,-(a7)                ;nb sectors
                move.w  12+2+12(a7),-(a7)       ;read/write (+2 because of stack usage just above)
                pea     (a3)                    ;sector number
                pea     _hxcLbaBuffer(pc)       ;address
                bsr.s   _hhxcLbaRwabs
                lea     12(a7),a7
                addq.l  #1,a3                   ;sector number + 1

                ;read or write ?
                    tst.w   12+12(a7)
                    bne.s  .oddRwNext
                ;read operation: our buffer to dest address
                    lea     _hxcLbaBuffer(pc),a0
                    moveq   #512/4-1,d0
.oddReadCpy:        move.b  (a0)+,(a4)+
                    move.b  (a0)+,(a4)+
                    move.b  (a0)+,(a4)+
                    move.b  (a0)+,(a4)+
                    dbra    d0,.oddReadCpy

.oddRwNext:
.oddRwEnter:    dbra    d3,.oddSectorsLoop

.return:        movem.l (a7)+,d3/a3-a4
                rts


_hhxcLbaRwabs:
;parameters:
;   4(a7).L : address to read to/write from
;   8(a7).L : LBA sector number
;  12(a7).W : 0 for read, 1 for write
;  14(a7).w : number of sectors to read/write (63 max)
;registers modified:a0-a2/d0-d2

                bsr     hxcLbaLock
                movem.l d3-d7/a3-a6,-(a7)

                move.l  9*4+4(a7),a0            ;address
                move.l  9*4+8(a7),d2            ;asked sector
                move.w  9*4+14(a7),d3           ;number of sectors
                move.w  9*4+12(a7),d4           ;0 for read, 1 for write

                bsr     _hxcLbaBaseChange
                move.w  d3,d2

                bsr.s   _hxcLbaCacheSectors

                movem.l (a7)+,d3-d7/a3-a6
                bsr     hxcLbaUnlock
                rts
                




























_hxcLbaCacheSectors:
; read sectors from the floppy to the cache OR write sectors from the cache to the floppy
;a0.l: address
;d2.w: nb sectors to read/write [1;8]
;d4.w: read(0) or write
;modifies d0,d1,d2,a0,a1,a2

                lea     _hxcLbaIsHardware(pc),a1
                tst.b   (a1)
                bne.s   _hxcLbaCacheHardware

_hxcLbaCacheSoftware:
;a0.l: address
;d2.w: nb sectors to read/write [1;63]
;d4.w: read(0) or write
;modifies d0,d1,d2,a0,a1,a2

                ext.l   d2              ;d2=nb sectors *512
                lsl.l   #8,d2
                add.l   d2,d2
                
                pea     (a0)
                move.l  d2,-(a7)
                move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                tst.w   d4
                bne.s   .write
                ;read:
                move.w  #$3f,-(a7)  ;Fread
                trap    #1
                lea     12(a7),a7
                bra.s   .return

.write:         move.w  #$40,-(a7)  ;Fwrite
                trap    #1
                lea     12(a7),a7

.return:        rts



_hxcLbaCacheHardware:
;a0.l: address
;d2.w: nb sectors to read/write [1;63]
;d4.w: read(0) or write
;modifies d0,d1,d2

                ;set DMA address
                    move.l  a0,d0
                    bsr     fdcAccDmaAdrSet
                    
                moveq   #1,d1                                               ;start sector

                tst.w   d4
                bne.s   .write
                
                ;read
                bsr     fdcAccDmaReadMode
                move.w  d2,d0                                               ;nb sectors to process by DMA
                bsr     fdcAccSectorcountRegSet
                subq.w  #1,d2                                               ;number of sectors to read-1 (for dbra)
.readnxt:       move.w  d1,d0                                               ;sector number
                bsr     fdcAccSectorRegSet
                move.w  #$88,d0                                             ;READ SECTOR, no spinup
                bsr     fdcAccSendCommandWait
                addq.w  #1,d1                                               ;next sector
                dbra    d2,.readnxt

                bra.s   .return

                
.write:         ;write
                bsr     fdcAccDmaWriteMode
                move.w  d2,d0                                               ;nb sectors to process by DMA
                bsr     fdcAccSectorcountRegSet
                subq.w  #1,d2                                               ;number of sectors to read-1 (for dbra)
.writenxt:      move.w  d1,d0                                               ;sector number
                bsr     fdcAccSectorRegSet
                move.w  #$A8,d0                                             ;***WRITE*** SECTOR, no spinup
                bsr     fdcAccSendCommandWait
                addq.w  #1,d1                                               ;next sector
                dbra    d2,.writenxt

.return:        rts







;d2.l: new LBA sector base; -1: no change
;d3.w: number of sectors
;d4.w: 0 for read, 1 for write
;registers: -
_hxcLbaBaseChange:
                movem.l d0-d2/d4/a0-a2,-(a7)

                lea     _hxcLbaIsHardware(pc),a1
                tst.b   (a1)
                beq.s   .software
                
                ;hardware
                ;fill desired sector to fetch into the control sector
                    lea     _hxcLbaControlWrite+9(pc),a1
                    move.b  d2,(a1)+                                ;LBA[7..0]
                    ror.w   #8,d2
                    move.b  d2,(a1)+                                ;LBA[15..8]
                    swap    d2
                    move.b  d2,(a1)+                                ;LBA[23..16]
                    ror.w   #8,d2
                    move.b  d2,(a1)+                                ;LBA[31..24]
                
                ;read or write ?
                    tst.w   d4
                    beq.s   .ok
                    move.b  #$5A,d4                                 ;$5A:Write only, $A5:Write enabled
                    .ok:
                    move.b  d4,(a1)+                                ;write enable (0 for read $5A for write)
                    
                ;number of sectors
                    move.b  d3,(a1)+

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
                
                bra.s   .return

.software:
;d2.l: new LBA sector base; -1: no change
                    clr.w   -(a7)   ;mode=SEEK_SET
                    move.w  _hxcLbaDebugFileHandle(pc),-(a7)
                    lsl.l   #8,d2
                    add.l   d2,d2
                    move.l  d2,-(a7)    ;offset
                    move.w  #$42,-(a7)  ;Fseek
                    trap    #1
                    lea     10(a7),a7


.return:        movem.l (a7)+,d0-d2/d4/a0-a2
                rts








hxcLbaLock:     move.l  a0,-(a7)
                ;wait for the hardware to be ready, then claim the resource
                    lea     _hxcLbaIsLocked(pc),a0
.waitSemaphore:     tas     (a0)
                    bne.s   .waitSemaphore
                move.l  (a7)+,a0
                bsr     fdcAccLock
                rts

hxcLbaUnlock:
                move.l  a0,-(a7)
                ;free the hardware resource semaphore
                    lea     _hxcLbaIsLocked(pc),a0
                    sf     (a0)
                move.l  (a7)+,a0
                bsr     fdcAccUnlock
                rts

hxcLbaIsLocked: ;returns Z=0 if floppy locked, Z=1 otherwise
                bsr     fdcAccIsLocked
                bne.s   .return     ;Z=0: floppy locked
                move.l  a0,-(a7)
                lea     _hxcLbaIsLocked(pc),a0
                tst.b    (a0)
                movem.l  (a7)+,a0   ; movem leaves CR
.return:        rts





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
_hxcLbaMsgTooOld:   dc.b    "Your firmware version is too old ! You must upgrade it. ",0
_hxcLbaMsgFnd3:     dc.b    "File found. ",0
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
_hxcLbaIsLocked:            ds.b    1
_hxcLbaIsHardware:          ds.b    1                                   ;FF:HxcHardware, 00:file
                EVEN
_hxcLbaSave:                ds.w    1                                   ;_nflops(4a6)
                            ds.w    1                                   ;_drvbits+2(4c2+2)
_hxcLbaControlWrite:        ds.b    512                                 ;used to change LBA base address, by WRITING to sector 0
_hxcLbaControlRead:         ds.b    512
_hxcLbaBuffer:              ds.b    512                                 ;used to read/write to/from odd address
                
        SECTION TEXT