;; ==========
;; Header - NESASM3
;; ==========

  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;; ==========
;; Variables
;; ==========
; Syntax: <name> .rs <#-bytes>
; Convention: Lower snake case

; Starting memory address
    .rsset $0000

    sleeping        .rs 1 ; Synchronize game updates with frame rate
    controller_1    .rs 1 ; Player 1 buttons

;; ==========
;; Constants
;; ==========
; Syntax: <NAME> = $<VALUE>
; Convention: Upper snake case

;; ==========
;; Data & Interrupt vectors
;; ==========

.bank 1
  .org $E000

  .include "data.asm"

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial

;; ==========
;; Main()
;; Logic handled in Main
;; Graphics updates held in buffer @ $0300
;; Exclusively graphics updates handled in NMI, copied from secondary buffer
;; ==========

    .bank 0
    .org $C000

;; Boilerplate power on / reset code
RESET:
    SEI          ; disable IRQs
    CLD          ; disable decimal mode
    LDX #$40
    STX $4017    ; disable APU frame IRQ
    LDX #$FF
    TXS          ; Set up stack
    INX          ; now X = 0
    STX $2000    ; disable NMI
    STX $2001    ; disable rendering
    STX $4010    ; disable DMC IRQs

;; First wait for vblank to make sure PPU is ready
    JSR WaitVBlank
    JSR ZeroMemory
    JSR WaitVBlank
;; PPU is ready
    JSR LoadGraphicsData

MainLoop:
;; This loop is allowed to run up to once per frame
;; May run less often than this if NMI comes before the loop cycles
    INC sleeping
WaitForEndOfNMI:
    LDA sleeping
    BNE WaitForEndOfNMI
;; Process updates for the next frame
    JSR UpdateGameState

;; End of GameLogic
MainLoopEnd:
    JMP MainLoop

NMI:
;; ==========
;; Lasts for ~2250 cycles
;; Which allows for approx 400-800 opcodes
;; ==========

;; Main loop is running somewhere. 
;; Hopefully it's in the sleeping loop, but there's no guarantee
;; We need to preserve the register states
;; Push registers A, X, Y => Stack
    PHA ; A => Stack
    TXA ; X => A
    PHA ; X => Stack
    TYA ; Y => A
    PHA ; Y => Stack

    JSR PrepareNextFrame
    JSR AudioEngine

;; Pop registers Stack => Y, X, A
    PLA ; Stack => A
    TAY ; A => Y
    PLA ; Stack => A
    TAX ; A => X
    PLA ; Stack => X
;; Clear the sleeping flag to allow the game loop to run 1 iteration
    LDA #$00
    STA sleeping
;; Return from NMI
    RTI 

;; ==========
;; Additional methods
;; ==========

    .include "subroutines.asm"

;; ==========
;; Graphics assets
;; ==========

  .bank 2
  .org $0000
  .incbin "mario.chr"