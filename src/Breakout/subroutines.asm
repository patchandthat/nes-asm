;; Todo: Partition this into separate files
;; Startup / Main / PPU / Audio

.include "controllers.asm"

;; ==========
;; Startup / Reset
;; ==========

WaitVBlank:       
    BIT $2002
    BPL WaitVBlank
    RTS

ZeroMemory:
    LDA #$00
    STA $0000, x
    STA $0100, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    LDA #$FE
    STA $0200, x
    INX
    BNE ZeroMemory
    RTS

LoadGraphicsData
    JSR LoadPalettes
    JSR LoadAttributes
    JSR LoadBackgrounds
    JSR LoadSprites  
    RTS

LoadPalettes:
    LDA $2002             ; read PPU status to reset the high/low latch
    LDA #$3F
    STA $2006             ; write the high byte of $3F00 address
    LDA #$00
    STA $2006             ; write the low byte of $3F00 address
    LDX #$00              ; start out at 0
LoadPalettesLoop:
    LDA Palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
    STA $2007             ; write to PPU
    INX                   ; X = X + 1
    CPX #$20              ; Compare X to hex $20, decimal 32 - copying 32 bytes, bg & fg palette
    BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down    

LoadAttributes:
    ;; Todo
LoadBackgrounds:
    ;; Todo
LoadSprites:
    ;; Todo
    RTS

;; ==========
;; Main Loop stuff
;; ==========

UpdateGameState:
    ;; Todo: Read controller
    ;; Process inputs
    RTS

;; ==========
;; NMI Stuff
;; ==========

PrepareNextFrame:
    RTS

;; ==========
;; Audio Stuff
;; ==========

AudioEngine:
    RTS