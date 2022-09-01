.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
	player_x: .res 1
	player_y: .res 1
	player_speed: .res 1
	player_life: .res 1
	coin_x: .res 1
	coin_y: .res 1
	random: .res 1
	score: .res 1
	score_x: .res 1
.exportzp player_x, player_y, player_speed, player_life, coin_x, coin_y, random, score, score_x

.segment "CODE"
	; Interrupt Request, do nothing
	.proc irq_handler
		RTI
	.endproc

	; Preparing the next frame (60x/sec)
	.proc nmi_handler
		LDA #$00
		STA OAMADDR
		LDA #$02
		STA OAMDMA
		LDA #$00
		
		JSR update_coin
		JSR update_player_pos
		JSR draw_coin
		JSR draw_player
		JSR update_player_life
		JSR update_score_counter
		JSR check_end_game

		LDA #$00
		STA PPUSCROLL
		STA PPUSCROLL
		RTI
	.endproc

	.import reset_handler

	.export main

	.proc main
		; write a palette
		LDX PPUSTATUS
		LDX #$3f
		STX PPUADDR
		LDX #$00
		STX PPUADDR

		; Load the palette as a loop
		load_palettes:
			LDA palettes,X
			STA PPUDATA
			INX
			CPX #$20
			BNE load_palettes

			JSR load_background
  
		vblankwait:       ; wait for another vblank before continuing
			BIT PPUSTATUS
			BPL vblankwait

			LDA #%10010000  ; turn on NMIs, sprites use first pattern table
			STA PPUCTRL
			LDA #%00011110  ; turn on screen
			STA PPUMASK

		forever:
			JMP forever
	.endproc

	.proc load_background
		PHP	
		PHA
		TXA
		PHA
		TYA
		PHA

		LDY #$e1 ; Start of the ground position
		single_ground:
			LDA PPUSTATUS
			LDA #$22
			STA PPUADDR
			TYA
			STA PPUADDR
			LDX #$01
			STX PPUDATA
			INY
			CPY #$ff
			BNE single_ground ; Restart loop until all the line is populated

		; Load lifes
		LDA PPUSTATUS
		LDA #$27
		STA PPUADDR
		LDA #$9d
		STA PPUADDR
		LDX #$03
		STX PPUDATA

		LDA PPUSTATUS
		LDA #$27
		STA PPUADDR
		LDA #$9e
		STA PPUADDR
		LDX #$03
		STX PPUDATA

		LDA PPUSTATUS
		LDA #$27
		STA PPUADDR
		LDA #$9f
		STA PPUADDR
		LDX #$03
		STX PPUDATA

		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc update_player_pos
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		readInputs:
			LDA #$01
			STA P1INPUTS
			LDA #$00
			STA P1INPUTS

		readA:
			LDA P1INPUTS ; A
			AND #%00000001
			BEQ endReadA
			INC player_speed
			INC random
			INC random

		endReadA:	
			LDA P1INPUTS ; B
			LDA P1INPUTS ; Select
			LDA P1INPUTS ; Start
			LDA P1INPUTS ; Up
			LDA P1INPUTS ; Down

		readLeft:
			LDA P1INPUTS ; Left
			AND #%00000001
			BEQ endReadLeft

			; In bounds ?
			LDA player_x
			CMP #$05
			BCS applyLeft
			JMP endReadPlayerInputs

		applyLeft:
			DEC player_x
			INC random
			INC random

			; Speed Detection (A Pressed)
			LDA player_speed
			CMP #$00
			BEQ endReadPlayerInputs

			; In bounds ?
			LDA player_x
			CMP #$07
			BCS applySpeedLeft
			JMP endReadPlayerInputs

		applySpeedLeft:
			DEC player_x
			DEC player_x
			DEC player_x
			INC random
			
			JMP endReadPlayerInputs
		endReadLeft:

		readRight:
			LDA P1INPUTS ; Right
			AND #%00000001
			BEQ endReadPlayerInputs

			; In bounds ?
			LDA player_x
			CMP #$ec
			BCS endReadPlayerInputs
			
			INC player_x

			; Speed Detection (A Pressed)
			LDA player_speed
			CMP #$00
			BEQ endReadPlayerInputs

			; In bounds ?
			LDA player_x
			CMP #$ea
			BCS endReadPlayerInputs

			INC player_x
			INC player_x
			INC player_x
			INC random
			
		endReadPlayerInputs:
			LDA #$00
			STA player_speed ; Reset the speed

		; all done, clean up and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc draw_player
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		; write player
		LDA #$04
		STA $0201
		LDA #$05
		STA $0205
		LDA #$06
		STA $0209
		LDA #$07
		STA $020d
		LDA #$08
		STA $0211
		LDA #$09
		STA $0215

		; write player
		; use palette 0
		LDA #$00
		STA $0202
		STA $0206
		STA $020a
		STA $020e
		STA $0212
		STA $0216

		; store tile locations
		; top left tile:
		LDA player_y
		STA $0200
		LDA player_x
		STA $0203

		; top right tile (x + 8):
		LDA player_y
		STA $0204
		LDA player_x
		CLC
		ADC #$08
		STA $0207

		; middle left tile (y + 8):
		LDA player_y
		CLC
		ADC #$08
		STA $0208
		LDA player_x
		STA $020b

		; middle right tile (x + 8, y + 8)
		LDA player_y
		CLC
		ADC #$08
		STA $020c
		LDA player_x
		CLC
		ADC #$08
		STA $020f

		; left foot (y + 16)
		LDA player_y
		CLC
		ADC #$0e
		STA $0210
		LDA player_x
		STA $0213

		; right foot (x + 8, y + 16)
		LDA player_y
		CLC
		ADC #$0e
		STA $0214
		LDA player_x
		CLC
		ADC #$08
		STA $0217

		; restore registers and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc update_score_counter
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		loadScore:
			LDA score
			CMP #$00
			BEQ endScore
			LDA PPUSTATUS
			LDA #$23
			STA PPUADDR
			LDA #$7e ; VAR to change -> up to score value
			ADC score
			STA PPUADDR
			LDX #$02
			STX PPUDATA
  		endScore:

		; restore registers and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc update_player_life
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		checkLife:
			LDA player_life
			CMP #$00
			BEQ endLife
			LDA PPUSTATUS
			LDA #$23
			STA PPUADDR
			LDA #$9B ; VAR to change -> up to player_life value
			ADC player_life
			STA PPUADDR
			LDX #$04
			STX PPUDATA
		endLife:

		; restore registers and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc update_coin
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		; Check if touch the player Y
		LDA coin_y
		CMP player_y
		BEQ checkPlayerCollisionX ; EQUAL -> Check collision X
		JMP checkGround

		checkPlayerCollisionX:
			LDA player_x
			CMP coin_x
			BCS checkGround ; playerX > coinX ? OUT
			;playerX < coinX
			LDA player_x
			ADC #$10 ; Add 16 to the playerX value
			CMP coin_x
			BCS addScore ; playerX + 16 > coin_x ? TOUCHED

		; Check if touch the ground
		checkGround:
			LDA coin_y
			CMP #$af
			BEQ removeLife ; touch the ground
			INC coin_y ; INCREASE coin_y
			JMP endUpdateCoin

		addScore:
			INC score
			JMP resetCoin

		removeLife:
			DEC player_life
			
		resetCoin:
			LDA #$00
			STA coin_y
			LDA random

		; Is in bounds ? LEFT SIDE
		inBoundsXCheck:
			CMP #$05
			BCS inBoundsYCheck
		loadMinX:
			LDA #$05
		inBoundsYCheck:
			CMP #$f2
			BCS loadMaxX
			JMP loadCoinX
		loadMaxX:
			LDA #$f2

		loadCoinX:
			STA coin_x
			JMP endUpdateCoin

		endUpdateCoin:

			; restore registers and return
			PLA
			TAY
			PLA
			TAX
			PLA
			PLP
			RTS
	.endproc

	.proc draw_coin
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA
		
		LDA #$0a
		STA $0221

		; use palette 3
		LDA #$03
		STA $0222

		LDA coin_y
		STA $0220
		LDA coin_x
		STA $0223

		INC random

		; restore registers and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

	.proc check_end_game
		; save registers
		PHP
		PHA
		TXA
		PHA
		TYA
		PHA

		checkLifes:
			LDA player_life
			CMP #$01
			BEQ resetGame
		checkScore:
			LDA score
			CMP #$0A
			BNE continueGame
		resetGame:
			JSR reset_handler ; Reset the console state

		continueGame:

		; restore registers and return
		PLA
		TAY
		PLA
		TAX
		PLA
		PLP
		RTS
	.endproc

; Save the Interrupts Vectors addresses
.segment "VECTORS"
	.addr nmi_handler, reset_handler, irq_handler

; Data that will stay static
.segment "RODATA"
palettes:
	.byte $0f, $15, $22, $25
	.byte $0f, $2b, $3c, $39
	.byte $0f, $0c, $07, $13
	.byte $0f, $19, $09, $29

	.byte $0f, $2d, $10, $15
	.byte $0f, $19, $09, $29
	.byte $0f, $19, $09, $29
	.byte $0f, $19, $09, $29

.segment "CHR"
	.incbin "graphics.chr"
