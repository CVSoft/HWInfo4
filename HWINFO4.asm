; HWINFO4 ver. MS4

;.define TI82
;.define TI8219006
;.define TI83
.define TI83PLUS

; uncomment one of the above lines to change the target model
; only keep one line uncommented, except TI8219006 which should
; be uncommented alongside TI82 in order to build for CrASH 19.006
.ifdef TI82
 .binarymode ti82
 .ifndef TI8219006
  #include "ti82ash.inc"
  .org userMem-3
  .db $D9,$0,$30 ; what
  .db "HWInfo 4",0
 .else
  #include "CrASH196.inc"
  .org userMem-3
  .db $D9,$0,$30 ; what
  .db "HWInfo 4 for 19.006",0
 .endif
.elseifdef TI83
 .binarymode ti83
 .tivariabletype $05
 .unsquish
 .define bcall(xxxx) call xxxx
 #include "ti83.inc"
 .org userMem
.elseifdef TI83PLUS
 .binarymode TI8X
 #include "ti83plus.inc"
 .org userMem-2
 .db t2ByteTok,tAsmCmp
.endif


; Test results are stored in e, so be careful that the register is preserved
.define TestReg1 e
.define TestReg2 d
; the following are bits used in e
IsTI82	.equ	0 ; TI-82 test succeeds
IsTI83	.equ	1 ; TI-83 test succeeds, fails if IsTI82 set
Is15MHz	.equ	2 ; 15 MHz capable bit is set (calc has extended ASIC ports)
T6C79	.equ	3 ; T6C79 bit is set (ignore this if not a TI-83)
Z180	.equ	4 ; Z180 test succeeds
FauxZ80	.equ	5 ; Zilog Z80 test fails
IsTI73	.equ	6 ; TI-73 test succeeds
; d is preserved but not used for anything (yet?)

.define ResModelTableEntries 9
.define ResASICTableEntries 14

; Models We Can Detect:
HWInconclusive	.equ	0
HWTI73Like	.equ	1
HWTI82Like	.equ	2 ; The test for this is rather flimsy
HWTI83Like	.equ	3
HWTI83Plus	.equ	4
HWTI83PlusSE	.equ	5
HWTI84Plus	.equ	6
HWTI84PlusSE	.equ	7
HWTI84PlusCSE	.equ	8 ; nothing can test for this yet

; ASICs we can detect
ASICInconclusive	.equ	0
ASICTC14L82	.equ	1 ; 82 early
ASICTC14L83	.equ	2 ; 83 early
ASICT6C79	.equ	3 ; 82/83 cost reduction 1
ASICZ180	.equ	4 ; 83 HW 'O'?
ASIC9815455	.equ	5 ; 73 early
ASIC9815455II	.equ	6 ; 83+ early
ASIC6SI837	.equ	7 ; 83+ cost reduction 1
ASIC83PL2MTA2	.equ	8 ; 83+SE
ASIC738X	.equ	9 ; 73/83+ cost reduction 1, 83 cost reduction 2
ASICUSBTA2	.equ	10; 84+/SE early
ASICUSBTA3	.equ	11; 84+/SE cost reduction 1
ASICUSBTA1	.equ	12; 84+/SE cost reduction 2
ASICUSBOther	.equ	13; 15 MHz calculator with unknown port 15 data


Main:
 .ifdef TI8219006
  call _ClrDisplay
  ld hl,0
  ld (curRow),hl
 .elseifdef TI82
  call _ClrScreenFull ; probably not the call i'm looking for
  ld hl,0
  ld (curRow),hl
 .endif
 ld e,0 ;results register
 call CheckTI83
 call CheckTI82
 call CheckT6C79
 call CheckCPU
 call CheckZ180
 ; we should have a fully defined 82/83 by now
 ; let's work on 83/83+
 bit IsTI82,TestReg1
 jr nz,Main_Skipped8X
 bit IsTI83,TestReg1
 jr nz,Main_Skipped8X
 call Check15MHz
 call CheckTI73
 call CheckExtendedASIC
 ; 83+ is fully defined to the best of our abilities
 bit Is15MHz,TestReg1
 jr z,Main_Skipped8X
 call CheckExtendedModel
 ; call CheckPort21RAM
 ; call CheckPort21ROM
 ; more tests
 call ResetCPUSpeed
 Main_Skipped8X:
 call SmallPrintModelResults
 call SmallPrintASICResults
 .ifdef TI82
  call KeyWait
 .else
  res donePrgm,(iy+doneFlags)
 .endif
 ret


.ifdef TI82
 KeyWait:
  ; on the TI-82, the shell will take control back and obscure
  ; the results of the program. therefore, we need a pause.
  push de
  KeyWait_Loop:
   bcall(_getCSC)
   halt
   cp $0
   jr z,KeyWait_Loop
  pop de
  ret
.endif


SmallPrintModelResults:
 ld hl,ResModelTableStart
 ld a,(FoundModel)
 cp ResModelTableEntries
 jr nc,ModelDataOutOfRange
 SmallPrintResults_Sub:
  add a,a
  call AddAtoHL
  push de
  bcall(_ldHLind) ; avoid this? we seem to have it on all platforms
  bcall(_puts)
  bcall(_newline)
  pop de
 ret
ModelDataOutOfRange:
 ld a,0
 jr SmallPrintResults_Sub

SmallPrintASICResults:
 ld hl,ResASICTableStart
 ld a,(FoundASIC)
 cp ResASICTableEntries
 jr nc,ModelDataOutOfRange ; would do the same as ASICDataOutOfRange
 jr SmallPrintResults_Sub

; some utility routines to make life somewhat easier

AddAtoHL:
 push bc
 ld b,0
 ld c,a
 add hl,bc
 pop bc
 ret

FtoA:
 push bc
 push af
 pop bc
 ld a,c
 pop bc
 ret

; Various tests to perform to narrow down model/ASIC

CheckCPU:
 ld a,$0ff
 cp $aa
 call FtoA
 and %00101000
 ret nz
 set FauxZ80,TestReg1
 ret

CheckZ180:
 res Z180,e
 ld a,$00
 dec a
 daa
 cp $99
 ret z
 set Z180,TestReg1
 ld a,ASICZ180
 ld (FoundASIC),a
 ret

CheckTI73:
 ; CHECK IF 15 MHZ (OR MAKE SET6MHZ SET THE FLAG)
 res IsTI73,TestReg1
 call Set6MHz
 in a,($02)
 and %00000010
 jr nz,CheckTI73_ProbablyAn83Plus
 set IsTI73,TestReg1
 ld a,HWTI73Like
 ld (FoundModel),a
 ret
 CheckTI73_ProbablyAn83Plus:
 bit Is15MHz,TestReg1
 ret nz
 ld a,HWTI83Plus
 ld (FoundModel),a
 ret

CheckTI82:
 ; On the TI-82 ONLY, port $05 is mirroring port $01. This is the keypad port.
 ; Since we're already making sure that port reads $FF, we can use it for
 ; comparison. 
 ; Problem: I wouldn't expect this to be true on the 738X-based TI-82 and it
 ; may be pretty hard to tell that apart from an 83 without looking at ROM.
 ; For this case, checking if port $06 is zero (rule out 83+) and if bits
 ; %11111100 are zero (rule out 83) may be a better course of action, but we
 ; would also need to check link status
 halt ; ISR will reset the port to $FF if keypress? is that how this works?
 res IsTI82,TestReg1
 push bc
 in a,($05)
 ld b,a
 in a,($04)
 cp b
 pop bc
 ret nz
 set IsTI82,TestReg1
 ld a,HWTI82Like
 ld (FoundModel),a
 ret

CheckTI83:
 ; there's two ways to check for a TI-83:
 ; 1: in a,($00) \ and %00011100 \ NZ if TI-83 \ Z if TI-82 or TI-8X
 ; 2: in a,($05) \ and %11001000 \ NZ if TI-82 or TI-83 \ Z if TI-8X
 ; 3: in a,($04) \ or %00000001 \ ld b,a \ in a,($14) \ cp b \ Z if TI-82 or TI-83 \ NZ if TI-8X
 ; if we do both, we can exclude both the TI-82 and TI-8X
 ; but since we're checking 
 res IsTI83,TestReg1
 in a,($00)
 and %00011100
 ret z
 set IsTI83,TestReg1
 ld a,HWTI83Like
 ld (FoundModel),a
 ret

CheckT6C79:
 ; On T6C79, bits 0 and 1 on port $00 are set, while on TC14L-1450 they are low
 ; 738X: ports $04-$07 all read 0 on 83
 res T6C79,TestReg1
 bit IsTI82,TestReg1
 jr nz,NeedsT6C79Check
 bit IsTI83,TestReg1
 jr nz,NeedsT6C79Check
 ret
 NeedsT6C79Check:
 in a,($00)
 and %00000001
 jr z, NeedsTC14LCheck
 bit IsTI82,TestReg1
 jr nz,NeedsTC14LCheck ; port $00 reads %00000011 on a TI-82 with TC14L
 in a,($04)
 cp $00
 jr z,HasTI738X
 set T6C79,TestReg1
 ld a,ASICT6C79
 ld (FoundASIC),a
 ret
 NeedsTC14LCheck:
 bit IsTI82,TestReg1
 jr nz,HasTC14L82
 ld a,ASICTC14L83
 CheckT6C79_TC14LExit:
 ld (FoundASIC),a
 ret
 HasTC14L82:
 ld a,ASICTC14L82
 jr CheckT6C79_TC14LExit
 HasTI738X:
 ld a,ASIC738X
 jr CheckT6C79_TC14LExit

Check15MHz:
 ; set the 15 MHz flag if available
 res Is15MHz,TestReg1
 in a,($02)
 and %10000000
 ret z
 set Is15MHz,TestReg1
 ret

CheckExtendedModel:
 ; locate calculator model
 ; uses the test described on WikiTI
 bit Is15MHz,TestReg1
 ret z
 in a,($21)
 and %00000011
 jr z,Found84Plus
 in a,($02)
 and %00100000
 jr z,Found83PlusSE
 ld a,HWTI84PlusSE
 CEMExit:
  ld (FoundModel),a
  ret
 Found84Plus:
  ld a,HWTI84Plus
  jr CEMExit
 Found83PlusSE:
  ld a,HWTI83PlusSE
  jr CEMExit

CheckExtendedASIC:
 ; uses the port 15 stuff
 ; not available on 6 MHz calcs
 ; destroys a
 bit Is15MHz,TestReg1
 jr z,Try83PlusASICFind
 in a,($15)
 cp $33
 jr z,Found83SETA2
 cp $44
 jr z,Found84TA2
 cp $45
 jr z,Found84TA3
 cp $55
 jr z,Found84TA1
 ld a,ASICUSBOther
 CEAExit:
 ld (FoundASIC),a
 ret
 Found83PlusLikeWithRealCPU:
 bit IsTI73,TestReg1
 jr nz,Found739815455
 ld a,ASIC9815455II
 jr CEAExit
 Found739815455:
 ld a,ASIC9815455
 jr CEAExit
 Found83SETA2:
 ld a,ASIC83PL2MTA2
 jr CEAExit
 Found84TA2:
 ld a,ASICUSBTA2
 jr CEAExit
 Found84TA3:
 ld a,ASICUSBTA3
 jr CEAExit
 Found84TA1:
 ld a,ASICUSBTA1
 jr CEAExit
 Try83PlusASICFind:
 bit IsTI82,TestReg1
 ret nz
 bit IsTI83,TestReg1
 ret nz
 call CheckCPU
 bit FauxZ80,TestReg1
 jr z,Found83PlusLikeWithRealCPU
 ; differentiate 6SI837 from 738X here!
 ld a,ASIC6SI837
 jr CEAExit

;CheckPort21RAM:
; ; TODO this
; ; Isn't this always 0?
; bit Is15MHz,TestReg1
; ret z
; in a,($21)
; and %00110000
; ret
;
;CheckPort21ROM:
; ; TODO this
; ; The CheckModel test kinda makes this obsolete
; bit Is15MHz,TestReg1
; ret z
; in a,($21)
; and %00000011
; ret

; The TI-73 test requires that we be in 6 MHz mode

Set6MHz:
 call Check15MHz
 bit Is15MHz,TestReg1
 ret z
 in a,($20)
 and %00000011
 ld (LastCPUSpeed),a
 ld a,$00
 out ($20),a
 ret

ResetCPUSpeed:
 in a,($02)
 and %10000000
 ret z
 ld a,(LastCPUSpeed)
 out ($20),a
 ret

; some data storage for results and states

FoundModel:
 .db $00

FoundASIC:
 .db $00

LastCPUSpeed:
 .db $00

; Data tables for pretty output
; These first two tables of addresses correlate hardware numbers in HW... to
; string locations
; eg. HWTI82Like is 2, so it's the (2+1)rd entry in here
; ResASICTableStart works the same way
; Msg strings don't need to be in any particular order since the addresses
; are defined here, but it helps to do so in order to remain sane
;
; THE VALUES IN Res*TableEntries PREVENTS OVERRUNS, BE SURE IT'S CORRECT

ResModelTableStart:
 .dw MsgHWInconclusive
 .dw MsgTI73
 .dw MsgTI82
 .dw MsgTI83
 .dw MsgTI83Plus
 .dw MsgTI83PlusSE
 .dw MsgTI84Plus
 .dw MsgTI84PlusSE
 .dw MsgTI84PlusCSE

ResASICTableStart:
 .dw MsgAInconclusive
 .dw MsgATC14L82
 .dw MsgATC14L83
 .dw MsgAT6C79
 .dw MsgAZ180
 .dw MsgA9815455
 .dw MsgA9815455II
 .dw MsgA6SI837
 .dw MsgA83PLM2TA2
 .dw MsgA738X
 .dw MsgA83PLUSBTA2
 .dw MsgA84PLUSBTA3
 .dw MsgA84PLCRTA1
 .dw MsgAUSBNew

MsgHWInconclusive:
 .db "Unknown Calc",0
MsgTI73:
 .db "TI-73",0
MsgTI82:
 .db "TI-82",0
MsgTI83:
 .db "TI-83",0
MsgTI83Plus:
 .db "TI-83 Plus",0
MsgTI83PlusSE:
 .db "TI-83 Plus SE",0
MsgTI84Plus:
 .db "TI-84 Plus",0
MsgTI84PlusSE:
 .db "TI-84 Plus SE",0
MsgTI84PlusCSE:
 .db "TI-84 Plus CSE",0

MsgAInconclusive:
 .db "Unknown ASIC",0
MsgATC14L82:
 .db "TC14L-1273",0
MsgATC14L83:
 .db "TC14L-1450",0
MsgAT6C79:
 .db "T6C79",0
MsgAZ180:
 .db "Z1A00108FSC",0
MsgA9815455:
 .db "9815455",0
MsgA9815455II:
 .db "9815455GAII",0
MsgA6SI837:
 .db "Inventec 6SI837",0
MsgA83PLM2TA2:
 .db "83PLM2TA2",0
MsgA738X:
 .db "TI-738X",0
MsgA83PLUSBTA2:
 .db "83PLUSB/TA2",0
MsgA84PLUSBTA3:
 .db "84PLUSB/TA3",0
MsgA84PLCRTA1:
 .db "84PLCR/TA1",0
MsgAUSBNew:
 .db "15MHz ASIC New",0

.ifdef TI83
 .squish
 .db $3F,$D4,$3F,$30,$30,$30,$30,$3F,$D4
.endif
.end