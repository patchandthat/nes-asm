;; ==========
;; Read controller input into byte vector
;; 76543210
;; ||||||||
;; |||||||+- RIGHT button
;; ||||||+-- LEFT Button
;; |||||+--- DOWN Button
;; ||||+---- UP Button
;; |||+----- START Button
;; ||+------ SELECT Button
;; |+------- B Button
;; +-------- A Button

ReadControllers:
    JSR StashPreviousButtonStates ; Store button states from last frame
    JSR LatchControllers          ; latch states on controllers
    JSR PollControllerButtons     ; read latched states
    JMP DetectRisingEdges         ; detect new button presses
;; No need for final RTS, use RTS from rising edge sub


StashPreviousButtonStates:
    LDA controller_1
    STA controller_1_last_frame
    LDA controller_2
    STA controller_2_last_frame
    RTS


LatchControllers:
    LDA #$01        ; both controllers to constantly poll
    STA $4016
    LDA #$00        ; both controllers to store current state for reading
    STA $4016       
    RTS

;; Read controller 1 from $4016
;; Read controller 2 from $4017

PollControllerButtons:
    LDY #$00   ; 2 controllers total
               ; Controller 2 state is the byte 
               ; directly after controller 1 state
PollControllerOuterLoop:
    LDX #$00   ; 8 buttons total
PollControllerInnerLoop:
    LDA $4016, y  ; Read button
    LSR A      ; shift right into carry flag
    ROL controller_1, y ; rotate into LSB of controller byte
    INX
    CPX #$08
    BNE PollControllerInnerLoop
    INY
    CPY #$02
    BNE PollControllerOuterLoop
    RTS ; Both controllers read


DetectRisingEdges:
    LDX #$00
DetectRisingEdgesLoop:
    LDA controller_1_last_frame, x
    EOR #$FF        ; Find all the bits that were low in the last frame (set high in A)
    AND controller_1, x ; AND to the the current high bits to get the buttons that went high this frame
    STA controller_1_rising_edges, x ; store for convenience
    INX
    CPX #$02
    BNE DetectRisingEdgesLoop
    RTS
