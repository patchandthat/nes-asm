;; ==========
;; Preformatted data
;; ==========

Palette:
    .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
    .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

Attributes:


Sprites:
     ;vertical-pos, tile #, attributes, horizontal-pos
    .db INIT_BALL_Y_POS, BALL_SPRITE_TILE, $00, INIT_BALL_X_POS           ;   sprite 0 - ball
    .db PADDLE_Y_POSITION, PADDLE_SPRITE_TILE, $01, INIT_PADDLE_X_POSITON ;   sprite 1 - Paddle

Background: