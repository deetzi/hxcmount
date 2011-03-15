;sdcFat32
;
;
;TODO : only the first cluster of the root is checked.
;Does not support directories
;




        SECTION TEXT
        
        
;Set the Floppy Controller in LBA Mode
;Disable floppies
;output : d0=0/Z=1 ok, else nok
sdcFat32Enter:
                movem.l d1-d7/a0-a6,-(a7)
                lea     _sdcFat32IsActivated(pc),a0
                tst.b   (a0)
                bne     .return

                ;print message
                    pea     _sdcFat32MsgEntr(pc)
                    bsr     _sdcFat32Print
                    addq.l  #4,a7

                ;call bottom layer enter
                    bsr sdcPartEnter

                lea     _sdcFat32Buffer(pc),a0

                ;read sector 0
                    pea     0.w
                    pea     (a0)
                    bsr     sdcPartSectorGet
                    addq.l  #8,a7
                    
                lea     _sdcFat32Buffer(pc),a0
                ;is boot sector ?
                    cmp.w   #$55aa,510(a0)
                    bne     .nosignature
                
                ;read BPB
                    lea     _sdcFat32Bpb(pc),a1
                    addq.l  #3,a0
                    move.b  (a0)+,(a1)+             ;OEM name
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,(a1)+
                    move.b  (a0)+,1(a1)             ;bytes per sector
                    move.b  (a0)+,(a1)
                    cmp.w   #512,(a1)               ;ensure sector size = 512
                    bne     .nofat32
                    addq.l  #2,a1
                    move.b  (a0)+,(a1)+             ;sectors per cluster
                    move.b  2(a0),(a1)+             ;number of fats
                    move.b  (a0)+,1(a1)             ;reserved sector count
                    move.b  (a0)+,(a1)
                    addq.l  #2,a1
                    addq.l  #1,a0                   ;skip number of fats
                    tst.b   (a0)+                   ;max number of root directory entries
                    bne     .nofat32
                    tst.b   (a0)+                   ;max number of root directory entries
                    bne     .nofat32
                    moveq   #0,d0
                    move.b  (a0)+,d0                ;d0: total sectors (2 bytes)
                    rol.w   #8,d0
                    move.b  (a0)+,d0
                    rol.w   #8,d0
                    addq.l  #7,a0                   ;skip media descriptor.b, sector per FAT.w, sector per track.w, number of heads.w
                    addq.l  #4,a1
                    move.b  (a0)+,-(a1)             ;hidden sectors
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    addq.l  #4,a1
                    tst.w   d0                      ;total sector is 0, read at 0x20
                    bne.s   .nbtrackok
                    move.b  (a0)+,d0                ;total sectors (if d0=0)
                    rol.w   #8,d0
                    move.b  (a0)+,d0
                    rol.w   #8,d0
                    swap    d0
                    move.b  (a0)+,d0
                    lsl.w   #8,d0
                    move.b  (a0)+,d0
                    rol.w   #8,d0
                    swap    d0
                    subq.l  #4,a0
.nbtrackok:         addq.l  #4,a0                   ;a0:Extended BIOS Parameter Block
                    move.l  d0,(a1)+

                ;read extended BPB
                    addq.l  #4,a1                
                    move.b  (a0)+,-(a1)             ;sectors per FAT
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    addq.l  #4,a1
                    addq.l  #2,a0                   ;skip FAT flags
                    move.b  (a0)+,1(a1)             ;version
                    move.b  (a0)+,(a1)
                    addq.l  #2,a1
                    addq.l  #4,a1                
                    move.b  (a0)+,-(a1)             ;cluster number of root
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    addq.l  #6,a1
                    move.b  (a0)+,-(a1)             ;sector number of FSIS
                    move.b  (a0)+,-(a1)
                    addq.l  #6,a1
                    lea     17(a0),a0               ;skip backupsector.w, reserved.12, physical drive number.b, reserved(dirty).b, extended.b
                    move.b  (a0)+,-(a1)             ;ID (serial number)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    move.b  (a0)+,-(a1)
                    addq.l  #4,a1
                    move.b  -6(a0),(a1)+            ;reserved (dirty flags)
                    ;cmp.b   #$29,-5(a0)             ;extended boot signature no test, I got $D0
                    ;bne.s   .nofat32
                    move.b  (a0)+,(a1)+             ;Volume Label   ;sometime garbage
                    move.l  (a0)+,(a1)+
                    move.l  (a0)+,(a1)+
                    move.w  (a0)+,(a1)+
                    cmp.l   #"FAT3",(a0)+
                    bne.s   .nofat32
                    cmp.l   #"2   ",(a0)+
                    bne.s   .nofat32
                
                ;compute some values
                lea     _sdcFat32Bpb(pc),a1
                ;FAT1 sector number
                    moveq   #0,d0
                    move.w  +$0C(a1),d0             ;reserved sectors
                    lea     _sdcFat32FatSector(pc),a2
                    move.l  d0,(a2)
                    
                ;ROOT sector number
                    moveq   #0,d1
                    move.b  +$0B(a1),d1             ;number of fats
                    subq.w  #1,d1
                    move.l  +$16(a1),d2             ;sectors per FAT
.addseroot:         add.l   d2,d0
                    dbra    d1,.addseroot
                    lea     _sdcFat32RootSector(pc),a2
                    move.l  d0,(a2)
                    
                ;Nb Sectors by Cluster (dec)
                    moveq   #0,d0
                    moveq   #0,d1
                    move.b  +$0a(a1),d0             ;SectorsByCluster
                    lea     _sdcFat32SectorsByCluster(pc),a2
                    move.w  d0,(a2)
.nbdec:             cmp.w   #1,d0
                    beq.s   .nbdecfound
                    addq.w  #1,d1
                    lsr.w   #1,d0
                    bra.s   .nbdec
.nbdecfound:        lea     _sdcFat32ClusterToSecDec(pc),a2
                    move.w  d1,(a2)
                    
;                    lea .test(pc),a0
;                    bsr sdcFat32GetFile
;                    
;                    bra.s    .next
;.test:              dc.b     "IMG4M   IMA"
;                    EVEN                   
;.next:
;
;                    bsr     sdcFat32IsContigous
;                    bne.s   .nofat32
;                    bsr     sdcFat32ClusterToSector

                lea     _sdcFat32IsActivated(pc),a0
                st      (a0)
                
                ;print success
                ;    lea     _sdcFat32MsgSucc2(pc),a0
                ;    move.l  (a1),d0
                ;    bsr     longD0ToHexA0
                ;    lea     _sdcFat32MsgSucc3(pc),a0
                ;    move.l  (a2),d0
                ;    bsr     longD0ToHexA0
                    pea     _sdcFat32MsgSucc(pc)
                    bsr.s   _sdcFat32Print2
                    addq.l  #4,a7

                ;success
                moveq   #0,d0

                bra.s   .return

.nofat32:       ;print fail
                    pea     _sdcFat32MsgFail(pc)
                    bsr.s   _sdcFat32Print2
                    pea     _sdcFat32MsgNoFat(pc)
                    bsr.s   _sdcFat32Print2
                    addq.l  #8,a7
                    bra.s   .fail

.nosignature:   ;print fail
                    pea     _sdcFat32MsgFail(pc)
                    bsr.s   _sdcFat32Print2
                    pea     _sdcFat32MsgNoSig(pc)
                    bsr.s   _sdcFat32Print2
                    addq.l  #8,a7


.fail:          ;fail                    
                moveq   #-1,d0

.return:
                movem.l (a7)+,d1-d7/a0-a6
                tst.w   d0
                rts







sdcFat32Leave:
                movem.l d0-d7/a0-a6,-(a7)
                lea     _sdcFat32IsActivated(pc),a0
                tst.b   (a0)
                beq.s   .return

                ;print message
                    pea     _sdcFat32MsgLeav(pc)
                    bsr.s   _sdcFat32Print
                    addq.l  #4,a7

                lea _sdcFat32IsActivated(pc),a0
                sf  (a0)

               ;print message
                    pea     _sdcFat32MsgSucc0(pc)
                    bsr.s   _sdcFat32Print2
                    addq.l  #4,a7

.return:
                movem.l (a7)+,d0-d7/a0-a6
                rts
                
                

_sdcFat32Print: movem.l d0-d2/a0-a2,-(a7)
                pea     _sdcFat32Msg00(pc)
                bsr     fontPrintStd
                move.l  6*4+4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #8,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts
_sdcFat32Print2:movem.l d0-d2/a0-a2,-(a7)
                move.l  6*4+4(sp),-(sp)
                bsr     fontPrintStd
                addq.l  #4,a7
                movem.l (a7)+,d0-d2/a0-a2
                rts








;input:  d0:number of the cluster
;output: d0:number of the sector
sdcFat32ClusterToSector:
                move.w  d1,-(a7)
                subq.l  #2,d0                               ;cluster begin at cluster #2
                move.w  _sdcFat32ClusterToSecDec(pc),d1
                lsl.l   d1,d0
                add.l   _sdcFat32RootSector(pc),d0          ;start sector
                move.w  (a7)+,d1
                rts










;input: a0: pointer to "NAME    EXT"
;output: d0.L: number of the first cluster or -1.L if not found. Can be 0 if file found with filesize=0
;        d1.L: filesyze
;        d2.W: attribute
;        d3.L: file name "1234"
;        d4.L: file name "56  "
;        d5.W: "EXT "
;        Z=0 if file found, Z=1: file not found
;registers:-
sdcFat32GetFile:
                movem.l d6-d7/a0-a6,-(a7)
                move.l  _sdcFat32Bpb+$1C(pc),d0             ;cluster number of root
                bsr.s   _sdcFat32GetFileInCluster
                movem.l (a7)+,d6-d7/a0-a6
                cmp.l   #-1,d0
                rts




;input: a0: pointer to "NAME    EXT". Supports "?" for any character
;       d0: cluster number to search in
;output: d0.L: number of the first cluster or -1.L if not found. Can be 0 if file found with filesize=0
;        d1.L: filesyze
;        d2.W: attribute
;        d3.L: file name "123456  "
;        d4.W: "EXT "
;registers:all
_sdcFat32GetFileInCluster:
                move.l  d0,d1                               ;d1=cluster number
                
                bsr.s   sdcFat32ClusterToSector             ;d0=first sector number of the cluster

                move.w  _sdcFat32SectorsByCluster(pc),d2
                subq.w  #1,d2
                
                ;for each sector of the cluster, search the file
                ;a0: pointer to "NAME    EXT"
                ;d0: current sector number
                ;d2: number of sectors to search -1
.nxtSector:     ;get the sector
                    lea     _sdcFat32Buffer(pc),a1
                    movem.l d0-d2/a0-a2,-(a7)
                    move.l  d0,-(a7)
                    pea     (a1)
                    bsr     sdcPartSectorGet
                    addq.l  #8,a7
                    movem.l (a7)+,d0-d2/a0-a2
                
                move.w  #512/32-1,d3                         ;d3=number of entries to try-1
.nxtEntry:      ;is the entry pointed by a1 the asked entry ?
                movem.l a0/a1/d0/d2,-(a7)
                moveq   #'?',d0

                ;name1
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn2
                cmp.b   d2,d1
                bne     .notThis
.fn2:           ;name2
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn3
                cmp.b   d2,d1
                bne     .notThis
.fn3:           ;name3
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn4
                cmp.b   d2,d1
                bne     .notThis
.fn4:           ;name4
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn5
                cmp.b   d2,d1
                bne     .notThis
.fn5:           ;name5
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn6
                cmp.b   d2,d1
                bne     .notThis
.fn6:           ;name6
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn7
                cmp.b   d2,d1
                bne     .notThis
.fn7:           ;name7
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .fn8
                cmp.b   d2,d1
                bne.s   .notThis
.fn8:           ;name8
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .ext1
                cmp.b   d2,d1
                bne.s   .notThis
.ext1:          ;ext1
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .ext2
                cmp.b   d2,d1
                bne.s   .notThis
.ext2:          ;ext2
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .ext3
                cmp.b   d2,d1
                bne.s   .notThis
.ext3:          ;ext3
                move.b  (a1)+,d1
                move.b  (a0)+,d2
                cmp.b   d0,d2
                beq.s   .entryFound
                cmp.b   d2,d1
                bne.s   .notThis

.entryFound:    movem.l (a7)+,a0/a1/d0/d2
                ;entry found !
                ;a1:entry

                ;get file name
                    move.l  (a1),d3
                    move.l  4(a1),d4

                ;get file ext
                    move.l  8(a1),d5
                    clr.b   d5

                ;get attribute
                    moveq   #0,d2
                    move.b  $b(a1),d2

                ;first cluster
                    move.b  $15(a1),d0
                    lsl.w   #8,d0
                    move.b  $14(a1),d0
                    swap    d0
                    move.b  $1b(a1),d0
                    lsl.w   #8,d0
                    move.b  $1a(a1),d0

                ;filesize
                    move.b  $1f(a1),d1
                    lsl.w   #8,d1
                    move.b  $1e(a1),d1
                    swap    d1
                    move.b  $1d(a1),d1
                    lsl.w   #8,d1
                    move.b  $1c(a1),d1
                
                bra.s   .return
                
                
.notThis:       movem.l (a7)+,a0/a1/d0/d2
                lea     32(a1),a1                           ;a1:next entry
                dbra    d3,.nxtEntry
                addq.l  #1,d0                               ;next sector
                dbra    d2,.nxtSector

                ;TODO: search next cluster

                ;file not found
                moveq   #-1,d0

.return:        rts





;input: 
;        d0.L: number of the first cluster
;        d1.L: filesize
;ouput: Z=1 : all clusters are contigous
;registers:-
sdcFat32IsContigous:
                movem.l d0-d7/a0-a6,-(a7)
                
                ;compute cluster size
                    moveq   #64,d2
                    lsl.w   #3,d2                           ;d2=512.l
                    move.w  _sdcFat32ClusterToSecDec(pc),d3
                    lsl.l   d3,d2                           ;d2=size of a cluster
                
                ;need to check the next cluster ?
.nxtcluster:        sub.l   d2,d1
                    bls.s   .success                        ;0 ou négatif: good !
                
                move.l  d0,d3                               ;save current cluster
                bsr.s   _sdcFat32GetNextCluster             ;get next cluster
                addq.l  #1,d3
                cmp.l   d0,d3
                beq.s   .nxtcluster
                
                ;fail
                and     #$fb,CCR                            ;Z=0
                bra.s   .return
.success:       or      #4,CCR                              ;Z=1
.return:        movem.l (a7)+,d0-d7/a0-a6
                rts


;input:  d0.L: number of the cluster
;output: d0.L: number ot the next cluster
;registers: -
_sdcFat32GetNextCluster:
                movem.l d1-d2/a1,-(a7)
                ;128 FAT entries by sector
                    move.l  _sdcFat32FatSector(pc),d1   ;d1:First sector number of the FAT
                    move.l  d0,d2
                    lsr.l   #7,d2
                    add.l   d2,d1                       ;d1:sector of the asked fat entry
                    and.w   #127,d0                     ;d0:entry number
                    lsl.w   #2,d0                       ;d0:entry offset
                
                lea     _sdcFat32Buffer(pc),a1
                ;read sector
                    movem.l d0-d2/a0-a2,-(a7)
                    move.l  d1,-(a7)
                    pea     (a1)
                    bsr     sdcPartSectorGet
                    addq.l  #8,a7
                    movem.l (a7)+,d0-d2/a0-a2
                
                ;get next cluster number
                    adda.w  d0,a1                       ;a1:next cluster pointer
                    addq.l  #4,a1
                    move.b  -(a1),d0
                    lsl.w   #8,d0
                    move.b  -(a1),d0
                    swap    d0
                    move.b  -(a1),d0
                    lsl.w   #8,d0
                    move.b  -(a1),d0
                                    
                movem.l (a7)+,d1-d2/a1
                rts
                
                
                
                
                




_sdcFat32Msg00:     dc.b    "sdcFat32: ",0
_sdcFat32MsgEntr:   dc.b    "Entering FAT32 driver... ",0
_sdcFat32MsgSucc0:  dc.b    "Success.",13,10,0
_sdcFat32MsgSucc:   dc.b    "Success: partition file system is FAT32",13,10,0
_sdcFat32MsgFail:   dc.b    "FAILED: ",0
_sdcFat32MsgLeav:   dc.b    "Leaving FAT32 driver... ",0
_sdcFat32MsgNoSig:  dc.b    "sector 0 does not have a boot sector signature",13,10,0
_sdcFat32MsgNoFat:  dc.b    "the partition is not FAT32 formatted",13,10,0
        EVEN

        SECTION BSS
_sdcFat32IsActivated:
                ds.b    1                                   ;is the driver activated ? 0:no -1:yes
                EVEN
_sdcFat32Buffer:ds.b    512                                 ;Internal buffer
                                                            ;steem
_sdcFat32Bpb:   ds.b    8   ;+$00 oem name                       ;WINIMAGE
                ds.w    1   ;+$08 bytes per sector               ;$200
                ds.b    1   ;+$0A sectors per cluster            ;8
                ds.b    1   ;+$0B number of fats                 ;2
                ds.w    1   ;+$0C reserved sector count          ;$26
                ds.l    1   ;+$0e hidden sectors                 ;$20
                ds.l    1   ;+$12 total sectors                  ;$2134
                ;ebpb: offset +$16
                ds.l    1   ;+$16 sectors per FAT                ;$80->9
                ds.w    1   ;+$1A version                        ;$0
                ds.l    1   ;+$1C cluster number of root         ;$2
                ds.w    2   ;+$20 sector number of FSIS          ;$1
                ds.l    1   ;+$24 ID (serial number)             ;$B87C00BC
                ds.b    1   ;+$28 reserved (dirty flags)         ;$8E
                ds.b    11  ;+$29 Volume Label
                EVEN
;root sector= reservedSsectors + numberFats*sectorsFat = $38
;           =    $26           +       2  * $80
;           =                                9 ???

_sdcFat32FatSector:         ds.l    1
_sdcFat32RootSector:        ds.l    1
_sdcFat32SectorsByCluster:  ds.w    1
_sdcFat32ClusterToSecDec:   ds.w    1   ;(number of dec)
                
        SECTION TEXT