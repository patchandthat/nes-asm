  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

  ;;;;

;; Variable space
; syntax example
; <varName> .rs 1 ; reserve space, 1 byte, for varName
    .rsset $0000
buttons                 .rs 1 ; Button data, A, B, Sel, Sta, Up, Down, Left, Right
buttons_debounce        .rs 1 ; Hold the previous button states
                              ; So that we can detect key-up

game_state              .rs 1 ; 0 = Paused
                              ; 1 = Running

ball_x_pos              .rs 1 ; Ball X position
ball_y_pos              .rs 1 ; Ball Y position

ball_x_direction        .rs 1 ; X direction of the ball
                              ; 0 => Moving left
                              ; 1 => Moving right
ball_y_direction        .rs 1 ; Y direction of the ball
                              ; 0 => Moving up
                              ; 1 => Moving down

ball_x_speed            .rs 1 ; Horizontal speed of the ball
ball_y_speed            .rs 1 ; Vertical speed of the ball

;; Constants
; syntax example
; MYCONSTANT = $FF ; Value 255, aka MYCONSTANT

STATE_PAUSED            = $00
STATE_PLAYING           = $01

CONTROLLER_START        = %00010000
CONTROLLER_LEFT         = %00000010
CONTROLLER_RIGHT        = %00000001

X_DIRECTION_LEFT        = $00
X_DIRECTION_RIGHT       = $01
Y_DIRECTION_UP          = $00
Y_DIRECTION_DOWN        = $01

BALL_SPRITE_TILE        = $75 ; Tile# for the ball
INIT_BALL_X_POS         = $80 ; Initial Ball X Pos
INIT_BALL_Y_POS         = $C0 ; Initial Ball Y Pos
INIT_BALL_X_DIRECTION   = $01
INIT_BALL_Y_DIRECTION   = $00
INIT_BALL_X_SPEED       = $01
INIT_BALL_Y_SPEED       = $01

BOUNDARY_TOP            = $10
BOUNDARY_BOTTOM         = $E0
BOUNDARY_LEFT           = $08
BOUNDARY_RIGHT          = $F4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    .bank 0
    .org $C000
RESET:
    SEI        ; ignore IRQs
    CLD        ; disable decimal mode
    LDX #$40
    STX $4017  ; disable APU frame IRQ
    LDX #$ff
    TXS        ; Set up stack
    INX        ; now X = 0
    STX $2000  ; disable NMI
    STX $2001  ; disable rendering
    STX $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; If the user presses Reset during vblank, the PPU may reset
    ; with the vblank flag still true.  This has about a 1 in 13
    ; chance of happening on NTSC or 2 in 9 on PAL.  Clear the
    ; flag now so the @vblankwait1 loop sees an actual vblank.
    BIT $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
vblankwait1:  
    BIT $2002
    BPL vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    TXA
clrmem:
    STA $000,x
    STA $100,x
    STA $300,x
    STA $400,x
    STA $500,x
    STA $600,x
    STA $700,x  ; Remove this if you're storing reset-persistent data

    ; We skipped $200,x on purpose.  Usually, RAM page 2 is used for the
    ; display list to be copied to OAM.  OAM needs to be initialized to
    ; $EF-$FF, not 0, or you'll get a bunch of garbage sprites at (0, 0).

    INX
    BNE clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.
   
vblankwait2:
    BIT $2002
    BPL vblankwait2

; INIT PPU
; Load palettes
LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

;   Sprites
;   Load sprite data into memory at $0200 and onwards
;   UpdateGameScreen will feed this address to PPU
LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$04              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

;   Backgrounds
    ; N/A

;   Initial game state
    JSR ResetGameState
    
;   Enable NMI, sprites, PPU flags, etc
    LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
    STA $2000

    LDA #%01010000   ; enable sprites
    STA $2001

Forever:
    ; Loop forever, wait for NMI
    JMP Forever

NMI:
    JSR UpdateGameScreen
    JSR ReadController
    JSR UpdateGameState

    RTS

UpdateGameScreen:
    ; Sprite data starts at $0200
    LDA #$00
    STA $2003       ; set the low byte (00) of the RAM address
    LDA #$02
    STA $4014       ; set the high byte (02) of the RAM address, start the transfer

    ;This is the PPU clean up section, so rendering the next frame starts properly.
    LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
    STA $2000
    LDA #%01010000   ; enable sprites, tint green background
    STA $2001

    RTS

UpdateGameState:
    ;
    ; If start is pressed, flip game state, Paused / Playing
    ; Check the previous button states to debounce

    ; bug here: If you hold START, everything locks up
    LDA buttons
    AND #CONTROLLER_START   ; Test the start button bit
                            ; If start isn't pressed, zero flag will be set
    BEQ SkipTogglePause     ; BEQ jumps when zero flag is set
    LDA buttons_debounce
    AND #CONTROLLER_START   ; same test on previous button states
                            ; To detect rising edge
    BNE SkipTogglePause     ; If zero flag is set, we have the rising edge
    JSR TogglePause         ; This is the first frame where start is pressed

SkipTogglePause:
    ; If we're paused, return early
    LDA game_state
    CMP #STATE_PAUSED
    BEQ ReturnFromUpdateGameState

    ; Process game updates
    ; Movement
HorizontalMovement:
    LDA ball_x_direction
    BEQ MoveLeft
MoveRight:
    LDA ball_x_pos
    CLC
    ADC ball_x_speed
    STA ball_x_pos
    JMP HorizontalMovementDone
MoveLeft:
    LDA ball_x_pos
    SEC
    SBC ball_x_speed
    STA ball_x_pos
HorizontalMovementDone:

VerticalMovement:
    LDA ball_y_direction
    BEQ MoveUp
MoveDown:
    LDA ball_y_pos
    CLC
    ADC ball_y_speed
    STA ball_y_pos
    JMP VerticalMovementDone
MoveUp:
    LDA ball_y_pos
    SEC
    SBC ball_y_speed
    STA ball_y_pos
VerticalMovementDone:

    ; Detect collisions
HorizontalCollisions:
    LDA ball_x_pos
    CMP #BOUNDARY_RIGHT          ; Carry flag set if A > M => Ball_x > right boundary
    BCS FlipHorizontalDirection ; Flip x direction
    CMP #BOUNDARY_LEFT           ; ball > left boudary
    BCS HorizontalCollisionsDone
FlipHorizontalDirection:
    LDA ball_x_direction
    EOR #$01
    STA ball_x_direction
HorizontalCollisionsDone:

VerticalCollisions:
    LDA ball_y_pos
    CMP #BOUNDARY_TOP
    BCC FlipVerticalDirection
    CMP #BOUNDARY_BOTTOM
    BCC VerticalCollisionsDone 
FlipVerticalDirection:
    LDA ball_y_direction
    EOR #$01
    STA ball_y_direction
VerticalCollisionsDone:

ReturnFromUpdateGameState:
    ; Write the ball sprite position for the next frame
    LDA ball_x_pos
    STA $0203
    LDA ball_y_pos
    STA $0200
    ; Store the previous button states for debouncing
    LDA buttons
    STA buttons_debounce
    RTS ; Return

TogglePause:
    ; XOR Game state with 1
    ; 1^1 => 0
    ; 0^1 => 1
    LDA game_state
    EOR #$01
    STA game_state
    RTS

ResetGameState:
    ; Set game variables to initial states
    LDA #STATE_PAUSED
    STA game_state

    LDA #INIT_BALL_X_POS 
    STA ball_x_pos

    LDA #INIT_BALL_Y_POS
    STA ball_y_pos

    LDA #INIT_BALL_X_DIRECTION
    STA ball_x_direction

    LDA #INIT_BALL_Y_DIRECTION
    STA ball_y_direction

    LDA #INIT_BALL_X_SPEED
    STA ball_x_speed

    LDA #INIT_BALL_Y_SPEED
    STA ball_y_speed

    LDA #$00
    STA buttons
    STA buttons_debounce

    RTS

ReadController:
    ; Fill the buttons variable with bitwise flags for button presses
    ; A, B, Select, Start, Up, Down, Left, Right
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016
    LDX #$08
ReadControllerLoop:
    LDA $4016           ; Get next button flag
    LSR A               ; Right shift Accumulator bit0 into Carry flag
    ROL buttons         ; Left shift carry flag into buttons
    DEX
    BNE ReadControllerLoop
    RTS

  ;;;;;;;;;;;;;;  
    
  
  .bank 1
  .org $E000
palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vertical-pos, tile #, attributes, horizontal-pos
  .db INIT_BALL_Y_POS, BALL_SPRITE_TILE, $00, INIT_BALL_X_POS   ;sprite 0 - ball

;;;;;;;;;;;;;;;

  .org $FFFA     ; Interrupt vector table
  .dw NMI        ; Start of Vblank
  .dw RESET      ; Power/Reset
  .dw 0          ; IRQ disabled
  
  
;;;;;;;;;;;;;;  

  
  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1