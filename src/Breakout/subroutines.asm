;; Todo: Partition this into separate files
;; Startup / Main / PPU / Audio

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
    ;; Todo
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

PrepareNextFrame
    RTS

;; ==========
;; Audio Stuff
;; ==========

AudioEngine:
    RTS
