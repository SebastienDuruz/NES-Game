.include "constants.inc"

.segment "ZEROPAGE"
.importzp player_x, player_y, player_speed, player_life, coin_x, coin_y, random, score, score_x, scroll_y

.segment "CODE"
.import main
.export reset_handler
.proc reset_handler
  SEI
  CLD
  LDX #$00
  STX PPUCTRL
  STX PPUMASK

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

  LDX #$00
	LDA #$ff

clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

vblankwait2:
	BIT PPUSTATUS
	BPL vblankwait2

  LDA #$80
  STA player_x
  STA random
  LDA #$81
  STA coin_x
  LDA #$a1
  STA player_y
  LDA #$00
  STA player_speed
  STA score
  STA score_x
  LDA #$01
  STA coin_y
  LDA #$04
  STA player_life

  JMP main
.endproc
