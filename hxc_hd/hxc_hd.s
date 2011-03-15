; use the hxc card as a hard disk

                MC68000
                MC68881 -
                MC68851 -
                OPT     C+      ;labels are case-sentitive
                OPT     D-      ;generate debug symbols
                OPT     X-      ;Extended debug symbols (22 chars instead of 8)
                OPT     O+      ;optimisations
                OPT     OW+     ;warn on optimisation
                OPT     OW2-    ;don't warn when optimising d16(An) -> (An)
                OPT     W+      ;show warnings
                OPT     Y-      ;debug source





BUILD_TYPE      equ     0       ;0:release, 1:debug
PROTECTSTACK    equ     0       ;protect against stack overflow. Not needed. If set, rwabs won't be re-entrant.
ZEUS_BRA        equ     1       ;use bra instead of jump in startup
SP_LENGHT       equ     2048


        IFNE    BUILD_TYPE=1
                OPT     X+
                OPT     Y+
        ENDC




                include "..\libext\start_up.s"

                include "..\lib\font.s"
                include "..\lib\util.s"
                include "..\lib\fdc\acc.s"
                include "..\lib\hxc\lba.s"
                include "..\lib\sdc\part.s"
                include "..\lib\sdc\fat32.s"
                include "..\lib\fs\img.s"

MAIN:
                bsr     fontInit

                ;print welcome message
                    pea     WelcomeMsg1(pc)
                    bsr     fontPrintStd
;                    move.l  #MAIN_VERSION1,d0
;                    bsr     fontPrint4D0Ascii
;                    move.l  #MAIN_VERSION2,d0
;                    bsr     fontPrint4D0Ascii
;                    pea     WelcomeMsg2(pc)
;                    bsr     fontPrint
;                    addq.l  #8,a7
        
                pea     SUPER(pc)
                move.w  #$26,-(a7)
                trap    #14
                addq.l  #6,a7
        
                pea     fonteStdBold(pc)
                pea     pushAnyKey(pc)
                bsr     fontPrintCust
                addq.l  #8,a7

                move.w  #7,-(a7)
                trap    #1
                addq.l  #2,a7

                lea     isSuccess(pc),a0
                tst.b   (a0)
                beq.s   .pterm

                lea     _hxcLbaIsHardware(pc),a0
                tst.b   (a0)
                bne.s   .ishardware
                
;.k              
;                pea     prgFname(pc)
;                move.w  #9,-(a7)
;                trap    #1
;                addq.l  #6,a7
;                bra.s  .k

                pea     env(pc)     ;environment
                pea     env(pc)     ;cmdline
                pea     prgFname(pc)
                move.w  #0,-(a7)    ;PE_LOADGO
                move.w  #$4B,-(a7)  ;Pexec()
                ;move.w  #$40,-(a7)  ;Pexec()
                trap    #1
                lea     16(a7),a7
                
                bra.s   .pterm
                

.ishardware:    move.l  BASEPAGE_ADR(pc),a0
                move.l  $c(a0),d0       ;text
                add.l   $14(a0),d0      ;+data
                add.l   $1c(a0),d0	    ;+bss
                IFD SP_LENGHT
                    addi.l	#256+SP_LENGHT,d0	;+pile
                ELSE
                    addi.l	#512,d0
                ENDC
                
                clr.w   -(a7)
                move.l  d0,-(a7)
                move.w  #$31,-(a7)      ;PTERMRES
                trap    #1
          
                
.pterm          clr.w   -(sp)
                trap    #1
pushAnyKey:     dc.b    "Push any key",13,10,0
prgFname:       dc.b    "shell.prg",0
                EVEN
env:            dc.w    0

                

;init all hardware and software layers
;output: d0=0: ok d0=-1:nok
initLayers: movem.l d1-d7/a0-a6,-(a7)
            bsr     fdcAccEnter
            bne.s   .errshow
            bsr     hxcLbaEnter
            bne.s   .errshow
            bsr     sdcPartEnter
            bne.s   .errshow
            bsr     sdcFat32Enter
            bne.s   .errshow
            bsr     fsImgEnter
            bne.s   .errshow
            
            ;success
            moveq   #0,d0
            bra.s   .return
            
.err:       dc.b    "Failed at initializing.",10,0
            even

.errshow:   pea     fonteStdBold(pc)
            pea     .err(pc)
            bsr     fontPrintCust
            addq.l  #8,a7

            ;fail
            moveq   #-1,d0
.return:    movem.l (a7)+,d1-d7/a0-a6
            rts


exitLayers: movem.l d1-d7/a0-a6,-(a7)
            bsr     fsImgLeave
            bsr     sdcFat32Leave
            bsr     sdcPartLeave
            bsr     hxcLbaLeave
            bsr     fdcAccLeave
.return:    movem.l (a7)+,d1-d7/a0-a6
            rts




        
        
SUPER:      bsr.s   initLayers
            tst.b   d0
            beq.s   mainPrg
            
mainPrgUnload:
            lea     isSuccess(pc),a0
            sf      (a0)

            bsr.s   exitLayers
            rts





mainPrg:
            move.l  $4c2.w,d0                                                   ;_drvbits

            ;find a free drive letter            
                moveq   #2,d1                                                   ;start at bit 2 = C:
.nxtBit:        btst    d1,d0
                beq.s   .foundLetter
                addq.w  #1,d1
                cmp.w   #17,d1          ;Q: ? c'est trop
                bne.s   .nxtBit
            
            ;no drive letter found
                pea     .printDrv(pc)
                bsr     fontPrintStd
                addq.l  #4,a7
                bra     mainPrgFail            
.printDrv:  dc.b    "No Drive letters available.",13,10,0
            EVEN

;d1=driveLetterNumber (0:A 1:B ...)
;d0=_drvbits
.foundLetter:
;clr.b   $ffffc123.w
                bset    d1,d0
                move.l  d0,$4c2.w
                lea     ourDeviceLetter(pc),a0
                move.w  d1,(a0)+
                lea     my_bpb-4(pc),a1
                move.l  $472.w,(a1)         ;hdv_bpb
                lea     my_rw-4(pc),a1
                move.l  $476.w,(a1)         ;hdv_rw
                lea     my_mediach-4(pc),a1
                move.l  $47e.w,(a1)         ;hdv_mediach

                lea     my_bpb(pc),a0
                move.l  a0,$472.w
                lea     my_rw(pc),a0
                move.l  a0,$476.w
                lea     my_mediach(pc),a0
                move.l  a0,$47e.w

                ;prepare success message
                    ;device letter
                    lea     SuccessMsgLtr(pc),a0
                    move.w  ourDeviceLetter(pc),d0
                    add.b   #'A',d0
                    move.b  d0,(a0)
                    ;device size
                    lea     fsImgBpb(pc),a0
                    move.w  +$e(a0),d0      ;total clusters of disk
                    mulu    +$4(a0),d0      ;*cluster length = total size in bytes
                    lea     SuccessMsgSize(pc),a0
                    bsr     longD0ToHexA0

                ;print success message                
                    pea     fonteStdBold(pc)
                    pea     SuccessMsg(pc)
                    bsr     fontPrintCust
                    addq.l  #8,a7
                
                lea     isSuccess(pc),a0
                st      (a0)
                rts





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                dc.l       "XBRA"
                dc.l       "HCHD"
                dc.l       0
                ;~~Getbpb(dev%)~~
my_bpb:         CARGS   bpbSpDev.w
                move.w  bpbSpDev(sp),d0                     ;d0=device number
                cmp.w   ourDeviceLetter(pc),d0
                beq.s   .ourdevice
                move.l  my_bpb-4(pc),a0                     ;Not our device : jump to previous
                jmp     (a0)
.ourdevice:     lea     fsImgBpb(pc),a0                     ;Our device : returns our BPB
                move.l  a0,d0
                rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                dc.l       "XBRA"
                dc.l       "XCHD"
                dc.l       0
                ;~~Mediach(dev%)~~
my_mediach:     CARGS   chSpDev.w
                move.w  chSpDev(sp),d0                      ;d0=device number
                cmp.w   ourDeviceLetter(pc),d0
                beq.s   .ourdevice
                move.l  my_mediach-4(pc),a0                 ;Not our device : jump to previous
                jmp     (a0)
.ourdevice:     moveq   #0,d0                               ;Our device : returns 0 (no media change)
                rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                dc.l       "XBRA"
                dc.l       "HCHD"
                dc.l       0
                ;~Rwabs(mode.W, buf.L, count.W, recno.W, dev.W[, lrecno.L])~~
my_rw:          CARGS   rwSpMode.w,rwSpBuf.l,rwSpCount.w,rwSpRecno.w,rwSpDev.w,rwSpLrecno.l
                move.w  rwSpDev(sp),d0                          ;d0=device number
                cmp.w   ourDeviceLetter(pc),d0
                beq.s   .ourdevice
                move.l  my_rw-4(pc),a0                      ;Not our device : jump to previous
                jmp     (a0)
.ourdevice:     moveq   #0,d0                               ;Our device
                move.w  rwSpRecno(sp),d0                    ;d0:recno
                cmp.w   #-1,d0
                bne.s   .recno
                move.l  rwSpLrecno(sp),d0                   ;d0:lrecno
.recno:         ;d0:[l]recno
                move.w  rwSpCount(sp),d1                    ;d1:count.w
                move.l  rwSpBuf(sp),a0                      ;a0:dest buf
                move.w  rwSpMode(sp),d2                     ;d2:mode: bit0=r/w, bit1=nomediach, bit2=noretries, bit3=notranslate
                IFNE    PROTECTSTACK
                    move.l  a7,savestack
                    lea     tmpstack(pc),a7
                ENDC
                btst    #0,d2
                bne.s   .writeN
                bra.s   .readN
                
    .read1:    ;read d1 sectors
                movem.l d0-d1/a0,-(a7)
                    move.l  d0,-(a7)
                    pea     (a0)
                    bsr     fsImgSectorGet
                    addq.l  #8,a7
                movem.l (a7)+,d0-d1/a0
                ;next sector:
                lea     512(a0),a0
                addq.l  #1,d0
.readN:         dbra    d1,.read1

                bra.s   .success


    .write1:    ;write d1 sectors
                movem.l d0-d1/a0,-(a7)
                    move.l  d0,-(a7)
                    pea     (a0)
                    bsr     fsImgSectorSet
                    addq.l  #8,a7
                movem.l (a7)+,d0-d1/a0
                ;next sector:
                lea     512(a0),a0
                addq.l  #1,d0
.writeN:        dbra    d1,.write1

.success:       ;success
                moveq   #0,d0
                IFNE    PROTECTSTACK
                    move.l  savestack,a7
                ENDC
                rts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;










mainPrgFail: 
                pea     fonteStdBold(pc)
                pea     FailMsg(pc)
                bsr     fontPrintCust
                addq.l  #8,a7
                bra     mainPrgUnload
                rts

        SECTION DATA
WelcomeMsg1:    dc.b    "Welcome to HXC_HD. This program allows you to mount a hard disk image file on your Atari ST. "
                dc.b    "It needs a HxC Floppy Emulator SDCard by Jean-Francois Del Nero "
                dc.b    "(http://hxc2001.free.fr/floppy_drive_emulator/ for more informations). ",13,10
                dc.b    "Driver software by G.Bouthenot.",13,10
                dc.b    "Software version : V0.1 alpha 2"
                dc.b    " (PREVIEW VERSION). Not suitable for production !",13,10,13,10
                dc.b    "The SDCard must be FAT32-formatted. It must contain a file named 'IMG*.IMA'"
                dc.b    " with a Atari-compliant file system. (usually FAT-16).",13,10,13,10,0
SuccessMsg:     dc.b    "Success. New drive mounted as "
SuccessMsgLtr:  dc.b    "X:, data size=0x"
SuccessMsgSize: dc.b    "00000000 bytes.",13,10,0
FailMsg:        dc.b    "FAILED.",13,10,0
isSuccess:      ds.b    1
        EVEN
        
        
fonteStd:
_FONTESTD:      incbin  "..\libext\rasteriz\fonts\tahoma13.iff"
                EVEN
fonteStdBold:
_FONTESTDBOLD   incbin  "..\libext\rasteriz\fonts\taho13b.iff"
                EVEN




        
        
        SECTION BSS

;sauvegarde de l'état (ne pas changer ordre)
ourDeviceLetter:    ds.w    1           ;2 for C:, 3 for D:...


        IFNE    PROTECTSTACK
savestack:      ds.l    1
                ds.b    1024
tmpstack:       ;valeur ci dessus
        ENDC
