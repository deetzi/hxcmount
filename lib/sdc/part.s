;sdcPart
;
;
;
;




        SECTION TEXT
        
        
;Set the Floppy Controller in LBA Mode
;Disable floppies
;output : d0=0/Z=1 ok, else nok
sdcPartEnter:
                movem.l d1-d7/a0-a6,-(a7)
                lea     _sdcPartIsActivated(pc),a0
                tst.b   (a0)
                bne     .return

                ;print message
                    pea     _sdcPartMsgEntr(pc)
                    bsr     _sdcPartPrint
                    addq.l  #4,a7

                ;call bottom layer enter
                    bsr hxcLbaEnter

                lea     _sdcPartBuffer(pc),a0

                ;read sector 0
                    move.w  #1,-(a7)    ;1 sector
                    clr.w   -(a7)       ;read
                    pea     0.w         ;sector 0
                    pea     (a0)        ;address
                    bsr     hxcLbaRwabs
                    lea     12(a7),a7
                    
                lea     _sdcPartBuffer(pc),a0
                ;is MBR ?
                    cmp.w   #$55aa,510(a0)
                    bne.s   .nombr

                lea     $1be(a0),a0                                         ;a0:1st partition record
                ;first partition status should be 0x080 (bootable) or 0x00 (not bootable)
                    tst.b   (a0)
                    beq.s   .ismbr
                    cmp.b   #$80,(a0)
                    bne.s   .nombr
                
.ismbr:         addq.l  #8,a0                                              ;a0:LBA start, LE format
                ;read LBA start
                    lea     _sdcPartStart+4(pc),a1
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)

                ;a0:number of sector, LE format
                ;a1:start LBA

                ;read LBA length
                    lea     8(a1),a2
                    move.b  (a0)+,-(a2)
                    move.b  (a0)+,-(a2)
                    move.b  (a0)+,-(a2)
                    move.b  (a0)+,-(a2)

                ;a1:LBA start
                ;a2:LBA length

                ;validate LBA sectors and length
                    move.l  (a1),d0
                    move.l  (a2),d1
                    cmp.l   #$10000,d0                                      ;start>=$10000 ?
                    bhs.s   .nombr
                    cmp.l   #100,d1                                         ;length<=100 sectors (51 Ko) ?
                    bls.s   .nombr

                ;print success
                    lea     _sdcPartMsgSucc2(pc),a0
                    move.l  (a1),d0
                    bsr     longD0ToHexA0
                    lea     _sdcPartMsgSucc3(pc),a0
                    move.l  (a2),d0
                    bsr     longD0ToHexA0
                    pea     _sdcPartMsgSucc(pc)
                    bsr.s   _sdcPartPrint2
                    addq.l  #4,a7
                    pea     _sdcPartMsgSucc0(pc)
                    bsr.s   _sdcPartPrint2
                    addq.l  #4,a7

                ;success
                bra.s   .return

.nombr:         ;print fail
                    pea     _sdcPartMsgNoMbr(pc)
                    bsr.s   _sdcPartPrint2
                    pea     _sdcPartMsgFail(pc)
                    bsr.s   _sdcPartPrint2
                    addq.l  #8,a7
 
                ;start=end=0                   
                    lea     _sdcPartStart(pc),a1
                    clr.l   (a1)+
                    clr.l   (a1)+
                
                ;fail : same code as SUCCESS (skipping)
.return:
                ;always success
                    moveq   #0,d0
                    lea     _sdcPartIsActivated(pc),a0
                    st      (a0)

                movem.l (a7)+,d1-d7/a0-a6
                tst.w   d0
                rts







sdcPartLeave:
                movem.l d0-d7/a0-a6,-(a7)
                lea     _sdcPartIsActivated(pc),a0
                tst.b   (a0)
                beq.s   .return

                ;print message
                    pea     _sdcPartMsgLeav(pc)
                    bsr.s   _sdcPartPrint
                    addq.l  #4,a7

                lea _sdcPartIsActivated(pc),a0
                sf  (a0)

               ;print message
                    pea     _sdcPartMsgSucc0(pc)
                    bsr.s   _sdcPartPrint2
                    addq.l  #4,a7

.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts
                
                

_sdcPartPrint:  movem.l d0-d2/a0-a2,-(a7)
                pea     _sdcPartMsg00(pc)
                bsr     fontPrintStd
                move.l  6*4+4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #8,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts
_sdcPartPrint2: movem.l d0-d2/a0-a2,-(a7)
                move.l  6*4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #4,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts








;Read/write sectors of the partition
;parameters:
;   4(a7).L : address to read to/write from
;   8(a7).L : LBA sector number
;  12(a7).W : 0 for read, 1 for write
;  14(a7).w : number of sectors to read/write
;registers modified:a0-a2/d0-d2
sdcPartRwabs:
                move.l  8(a7),d0
                add.l   _sdcPartStart(pc),d0
                move.l  d0,8(a7)
                bra     hxcLbaRwabs






_sdcPartMsg00:      dc.b    "sdcPart: ",0
_sdcPartMsgEntr:    dc.b    "Entering SDCard Partition layer... Searching partition table ... ",0
_sdcPartMsgSucc0:   dc.b    "Success.",13,10,0
_sdcPartMsgSucc:    dc.b    "Found partition at 0x"
_sdcPartMsgSucc2:   dc.b    "00000000, length 0x"
_sdcPartMsgSucc3:   dc.b    "00000000 sectors. ",0
_sdcPartMsgFail:    dc.b    "The SDCard root sector is not a partition table. Skipping this layer.",13,10,0
_sdcPartMsgLeav:    dc.b    "Leaving SDCard Partition layer... ",0
_sdcPartMsgNoMbr:   dc.b    "sector 0 is not a valid MBR: no partition table. ",0
        EVEN

        SECTION BSS
_sdcPartIsActivated:
                ds.b    1                                   ;is the driver activated ? 0:no -1:yes
                EVEN
_sdcPartBuffer: ds.b    512                                 ;Internal buffer
_sdcPartStart:  ds.l    1                                   ;LBA of the first absolute sector in the partition
_sdcPartLen:    ds.l    1                                   ;Number of sectors in partition                
        SECTION TEXT
