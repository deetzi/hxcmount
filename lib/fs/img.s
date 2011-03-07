;fsImg
;
;
;




        SECTION TEXT
        
        
;Set the Floppy Controller in LBA Mode
;Disable floppies
;output : d0=0/Z=1 ok, else nok
fsImgEnter:
                movem.l d1-d7/a0-a6,-(a7)
                tst.b   _fsImgIsActivated
                bne     .return

                ;print message
                    pea     _fsImgMsgEntr(pc)
                    bsr     _fsImgPrint
                    addq.l  #4,a7

                ;call bottom layer enter
                    bsr sdcFat32Enter
                    
                lea     .fname(pc),a0
                bsr     sdcFat32GetFile
                beq     .notfound
                
                ;d0:first cluster of the file
                ;d1:filesize
                ;d2:attribute
                ;d3:Filename "1234"
                ;d4:Filename "56  "
                ;d5.w:"EXT",0

                ;print message
                    pea     _fsImgMsgFnd(pc)
                    bsr     _fsImgPrint2
                    addq.l  #4,a7

                lea     .fname(pc),a0
                move.l  d3,(a0)
                move.l  d4,4(a0)
                move.l  d5,8(a0)

                pea     (a0)
                bsr     _fsImgPrint2
                addq.l  #4,a7

                ;format filesize
                    exg     d1,d0
                    lea     _fsImgMsgFnd3(pc),a0
                    bsr     longD0ToHexA0
                    exg     d1,d0

                ;print message
                    pea     _fsImgMsgFnd2(pc)
                    bsr     _fsImgPrint2
                    addq.l  #4,a7

                bra.s    .next

.fname:         dc.b     "IMG?????IMA",0
                EVEN                   
.next:
                ;d0:first cluster of the file
                ;d1:filesize
                ;d2:attribute
                ;d3:Filename "12345678"
                ;d4.w:"EXT",0

                bsr     sdcFat32IsContigous
                bne     .nocontig
                
                ;print not fragmented, good
                    pea     _fsImgMsgFragOk(pc)
                    bsr     _fsImgPrint2
                    addq.l  #4,a7

                bsr     sdcFat32ClusterToSector

                ;store the base sector number, and file size
                    lea     _fsImgSectorBase(pc),a0
                    move.l  d0,(a0)+
                    move.l  d1,(a0)

                lea     _fsImgBuffer(pc),a0
                ;fetch bootsector
                    pea     0.w
                    pea     (a0)
                    bsr     fsImgSectorGet
                    addq.l  #8,a7

                lea     _fsImgBuffer(pc),a0
                lea     fsImgBpb(pc),a1
                ;fill BPB
                    move.b  +$0c(a0),(a1)+      ;recsiz:bytes per sector
                    move.b  +$0b(a0),(a1)+
                    moveq   #0,d0
                    move.b  +$d(a0),d0
                    move.w  d0,(a1)+            ;clsiz:sectors per cluster
                    mulu    -4(a1),d0
                    move.w  d0,(a1)+            ;clsizb:bytes per cluster
                    move.b  +$12(a0),d0         ;max number of root directory entries
                    lsl.w   #8,d0
                    move.b  +$11(a0),d0
                    lsl.w   #5,d0               ;d0=nb root entries * $20
                    divu    -6(a1),d0           ;/bytes per sector
                    move.w  d0,(a1)+            ;rdlen: nb sectors of root dir
                    move.b  +$17(a0),(a1)+      ;fsiz: sectors per FAT
                    move.b  +$16(a0),(a1)+
                    move.b  +$0f(a0),d0         ;reserved sector count=start of 1st FAT
                    lsl.w   #8,d0
                    move.b  +$0e(a0),d0
                    add.w   -2(a1),d0           ;+sector per FAT=start of 2nd FAT
                    move.w  d0,(a1)+            ;fatrec:starting sector of second FAT
                    add.w   -4(a1),d0           ;+sector per FAT=start of root
                    add.w   -6(a1),d0           ;+len of root=start of data
                    move.w  d0,(a1)+            ;datrec=start of data
                    move.b  +$14(a0),d0         ;d0=size of disk, in sectors if <65535
                    lsl.w   #8,d0
                    move.b  +$13(a0),d0
                    tst.w   d0
                    bne.s   .oktot
                    move.b  +$23(a0),d0         ;d0=size of disk, in sectors if >=65536
                    lsl.w   #8,d0
                    move.b  +$22(a0),d0
                    swap    d0
                    move.b  +$21(a0),d0
                    lsl.w   #8,d0
                    move.b  +$20(a0),d0
.oktot:             ;compute the number of clusters; d0=total nb of sectors
                    moveq   #0,d1
                    move.w  -2(a1),d1           ;-start of data
                    sub.l   d1,d0               ;=nb sectors for data
                    divu    -12(a1),d0          ;/sectors per cluster=nb clusters for data
                    addq.w   #2,d0              ;2 clusters are reserved and not used. Count them
                    move.w  d0,(a1)+            ;numcl:total clusters for disk
                    cmp.w   #4096,d0
                    bls.s   .fat12              ;4096 -> 0-4095 : fat12  else  fat16
                    moveq   #1,d0               ;FAT16
                    bra.s   .fatok
.fat12:             moveq   #0,d0               ;FAT12
.fatok:             move.w  d0,(a1)+            ;bflags: bit0=FAT12/FAT16; bit1:twoFats/oneFat (TOS2.6+)

                lea     _fsImgIsActivated(pc),a0
                st      (a0)
                
                ;print success
                    pea     _fsImgMsgSucc(pc)
                    bsr.s   _fsImgPrint2
                    addq.l  #4,a7

                ;success
                moveq   #0,d0

                bra.s   .return

.notfound:      ;print fail
                    pea     _fsImgMsgFail(pc)
                    bsr.s   _fsImgPrint
                    pea     _fsImgMsgNotFnd(pc)
                    bsr.s   _fsImgPrint2
                    addq.l  #8,a7
                bra.s   .return

.nocontig:      ;print fail
                    pea     _fsImgMsgFail(pc)
                    bsr.s   _fsImgPrint
                    pea     _fsImgMsgContig(pc)
                    bsr.s   _fsImgPrint2
                    addq.l  #8,a7

                ;fail                    
                moveq   #-1,d0

.return:
                movem.l (a7)+,d1-d7/a0-a6
                tst.w   d0
                rts







fsImgLeave:
                movem.l d0-d7/a0-a6,-(a7)
                tst.b   _fsImgIsActivated
                beq.s   .return

                ;print message
                    pea     _fsImgMsgLeav(pc)
                    bsr.s   _fsImgPrint
                    addq.l  #4,a7

                lea _fsImgIsActivated(pc),a0
                sf  (a0)

               ;print message
                    pea     _fsImgMsgSucc(pc)
                    bsr.s   _fsImgPrint2
                    addq.l  #4,a7

.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts
                
                

_fsImgPrint:    movem.l d0-d2/a0-a2,-(a7)
                pea     _fsImgMsg00(pc)
                bsr     fontPrintStd
                move.l  6*4+4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #8,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts
_fsImgPrint2:   movem.l d0-d2/a0-a2,-(a7)
                move.l  6*4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #4,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts





;Read a sector of the image file
;parameters:
;   4(a7).L : address to read to
;   8(a7).L : LBA sector number
;registers modified:a0-a2/d0-d2
fsImgSectorGet:
                move.l  8(a7),d0                                           ;d0=asked sector
                move.l  4(a7),a0                                           ;a0=adress to read to

                ;standard rout:
                    add.l   _fsImgSectorBase(pc),d0
                    ;move.l  d0,-(a7)
                    ;pea     (a0)
                    ;bsr     sdcPartSectorGet
                    ;addq.l  #8,a7

                ;shortcut to sdcPartSectorGet:                
                    add.l   _sdcPartStart(pc),d0
                    clr.w   -(a7)
                    move.l  d0,-(a7)
                    pea     (a0)
                    bsr     hxcLbaSectorGet
                    lea     10(a7),a7

                rts
fsImgSectorSet:
                move.l  8(a7),d0                                           ;d0=asked sector
                move.l  4(a7),a0                                           ;a0=adress to read to

                ;standard rout:
                    add.l   _fsImgSectorBase(pc),d0
                    ;move.l  d0,-(a7)
                    ;pea     (a0)
                    ;bsr     sdcPartSectorGet
                    ;addq.l  #8,a7

                ;shortcut to sdcPartSectorGet:                
                    add.l   _sdcPartStart(pc),d0
                    move.w  #1,-(a7)
                    move.l  d0,-(a7)
                    pea     (a0)
                    bsr     hxcLbaSectorGet
                    lea     10(a7),a7

                rts








_fsImgMsg00:     dc.b    "fsImg: ",0
_fsImgMsgEntr:   dc.b    'Entering Image File driver... Searching for a file named "IMG*.IMA"... ',0
_fsImgMsgFnd:    dc.b    'Found file "',0
_fsImgMsgFnd2:   dc.b    '", filesize=0x'
_fsImgMsgFnd3:   dc.b    "00000000 bytes. Checking fragmentation... ",0
_fsImgMsgFragOk: dc.b    "file is not fragmented, ok. Loading Image File... ",0
_fsImgMsgSucc:   dc.b    "Success.",13,10,0
_fsImgMsgFail:   dc.b    "FAILED: ",0
_fsImgMsgLeav:   dc.b    "Leaving Image File driver driver; unloading image file... ",0
_fsImgMsgNotFnd  dc.b    "no file found",13,10,0
_fsImgMsgContig  dc.b    "cannot load image file because the file is fragmented. Please defragment the SDcard, or copy the file to a freshly formatted media.",13,10,0
        EVEN

        SECTION BSS
_fsImgIsActivated:  ds.b    1                               ;is the driver activated ? 0:no -1:yes
                EVEN
fsImgBpb:           ds.w    1   ;recsiz
                    ds.w    1   ;clsiz
                    ds.w    1   ;clsizb
                    ds.w    1   ;rdlen
                    ds.w    1   ;fsiz
                    ds.w    1   ;fatrec
                    ds.w    1   ;datrec
                    ds.w    1   ;numcl
                    ds.w    1   ;bflags

_fsImgBuffer:       ds.b    512
_fsImgSectorBase:   ds.l    1                               ;sector number in partition
_fsImgSize:         ds.l    1                               ;file size
        SECTION TEXT

