
                OPT     X+
                OPT     Y+

ZEUS_BRA        equ     1       ;use bra instead of jump in startup
SP_LENGHT       equ     2048



                include "..\libext\start_up.s"
MAINPRG_START:
                include "..\lib\font.s"
                include "..\lib\util.s"
                include "..\lib\fdc\acc.s"
                include "..\lib\hxc\lba.s"

MAIN:
                clr.l       -(a7)
                move.w      #$20,-(a7)  ;SUPER: go to supervisor mode
                trap        #1
                addq.l      #6,a7
                move.l      d0,-(a7)
                
                bsr     fontInit
                
                bsr     fdcAccEnter
                bsr     hxcLbaEnter
                bsr     MAIN2
                bsr     hxcLbaLeave
                bsr     fdcAccLeave
                
                move.w      #$20,-(a7)  ;SUPER: go to supervisor mode
                trap        #1
                addq.l      #6,a7

                pea     pushAnyKey(pc)
                bsr     fontPrintStd
                addq.l  #4,a7

                move.w  #7,-(a7)
                trap    #1
                addq.l  #2,a7
.pterm          clr.w   -(sp)
                trap    #1
pushAnyKey:     dc.b    "Push any key",13,10,0
WRITEMODE:      dc.b    0
                EVEN



MAIN2:
                moveq   #1,d7           ;number of sectors
                move.l  #128,d6         ;number of times
                move.b  #0,WRITEMODE
                bsr     bench
                move.b  #$5a,WRITEMODE
                bsr     bench
                
                moveq   #8,d7           ;number of sectors
                move.l  #64,d6          ;number of times
                move.b  #0,WRITEMODE
                bsr     bench
                move.b  #$5a,WRITEMODE
                bsr     bench

                moveq   #63,d7          ;number of sectors
                move.l  #16,d6          ;number of times
                move.b  #0,WRITEMODE
                bsr     bench
                move.b  #$5a,WRITEMODE
                bsr     bench

                rts






bench:
;d7: number of sectors
;d6: number of tests
                movem.l d0-d7/a0-a6,-(a7)
                
                ;print "reading"/"writing"
                    lea     msgRead(pc),a0
                    moveq   #0,d5           ;read
                    move.b  WRITEMODE,d0
                    beq.s   .isread
                    lea     msgWrite(pc),a0
                    moveq   #1,d5           ;write
.isread:            pea     (a0)
                    bsr     fontPrintStd
                    addq.l  #4,a7

                ;print number of sectors
                    move.l  d7,d0
                    lea     hexvalue(pc),a0
                    bsr     longD0ToHexA0
                    pea     (a0)
                    bsr     fontPrintStd
                    pea     msgSectors(pc)
                    bsr     fontPrintStd
                    addq.l  #8,a7

                ;print number of times
                    move.l  d6,d0
                    lea     hexvalue(pc),a0
                    bsr     longD0ToHexA0
                    pea     (a0)
                    bsr     fontPrintStd
                    pea     msgTimes(pc)
                    bsr     fontPrintStd
                    addq.l  #8,a7


               
                move.l  #$000,d4          ;start at sector $000
                lea     buffer(pc),a4       ;start address
                move.w  d6,d3
                subq.w  #1,d3

                move.l  $4ba.w,time1


.loop:          move.w  d7,-(a7)
                move.w  d5,-(a7)
                move.l  d4,-(a7)
                pea     (a4)
                bsr     hxcLbaRwabs
                lea     12(a7),a7

                ;update address
                    move.l  d7,d0               ;number of sector
                    lsl.l   #8,d0
                    add.l   d0,d0               ;*512
                    lea     0(a4,d0.l),a4
                
                ;update sector number
                    add.l   d7,d4
                
                dbra    d3,.loop
                
                move.l  $4ba.w,time2
                
                pea     msgRes1(pc)
                bsr     fontPrintStd
                addq.l  #4,a7

                mulu    d7,d6                   ;d6=number of sectors
                lsl.l   #8,d6                   ;d6=number of bytes/2
                add.l   d6,d6                   ;d6=number of bytes
                move.l  time2,d0
                sub.l   time1,d0                ;d0=time taken in 1/200s
                
                exg     d6,d0
                divu    d6,d0
                mulu    #200,d0
                
                lea     hexvalue(pc),a0
                bsr     longD0ToHexA0

                pea     (a0)
                bsr     fontPrintStd
                addq.l  #4,a7

                pea     msgRes2(pc)
                bsr     fontPrintStd
                addq.l  #4,a7
                
                movem.l (a7)+,d0-d7/a0-a6
                rts

msgRead:        dc.b    " Reading $",0
msgWrite:       dc.b    " Writing $",0
msgSectors:     dc.b    " sectors, $",0
msgTimes:       dc.b    " times...",0
msgRes1:        dc.b    "Rate: $",0
msgRes2:        dc.b    " B/s",13,10,0


    SECTION BSS
time1:      ds.l    1
time2:      ds.l    1
hexvalue:   ds.b    10
buffer:     ds.b    63*512*16