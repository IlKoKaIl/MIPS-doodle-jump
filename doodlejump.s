#####################################################################
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8					     
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
#
# 
# (features)
# 1. Display the score on screen. The score should be constantly updated as the game progresses. 
#    The final score is displayed on the game-over screen.
# 2. Changing difficulty as game progresses: gradually increase the difficulty of the game 
#    (e.g., shrinking the platforms) as the game progresses.
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#

# - Important: Do not spam the keyboard, by spam I mean holding a key down
# - Score goes up by one each time a new platform is generated
# - Difficulty:
#   - There are 9 levels of difficulty. You start with a platform of length 9, and every time your
#     score increases by 10, the difficulty increases and the length of a platform decreases by 1.
# - Game starts immediately and you are guaranteed to spawn on top of a platform
# - No restart button as Prof. Zhang said it is not necessary (Piazza @881)
#####################################################################

.data
	displayAddress: .word 0x10008000
	
	backgroundColour: .word 0xf5f5dc
	platformColour: .word 0x228c22
	spriteColour: .word 0x187bcd
	spriteColour2: .word 0xff0000
	textColour: .word 0x02075d
	platforms: .space 16
	newline: .asciiz "\n" #for debugging purposes
	restartmessage: .asciiz "Press 's' to restart the game. You have 10 seconds"
		 
.text
main:
	lw $t0, displayAddress	# $t0 stores the base address for display
	la $t1, platforms # t1 stores array of platforms
	jal drawBackground
	jal startingPlatforms
	
	lw $t2, 12($t1) # t2 stores location of sprite
	addi $t2, $t2, -496 #makes sprite 3 pixels above middle of lowest platform
	jal drawSprite
	
	li $t3, 0 #jump counter, if <20, jump up, if 20, jump down until lose/platform
	li $t4, 0 #score counter, score += 1 if new platform is made
	li $t5, 8 #difficulty level. Easiest is lvl 8, hardest is lvl 0
	#difficulty increases each time score goes up by 10
	li $t6, 1 #a variable to help relate score and updating difficulty 
	
mainLoop:
	jal detectInput
	
	beq $t3, 20, fallDown

jumpUp:
	addi $t2, $t2, -128
	addi $t3, $t3, 1
	j mainLoop2
	
fallDown:
	addi $t2, $t2, 128
	jal checkDeath
	jal checkJump

mainLoop2:
	jal checkMoveScreen
	
redrawScreen:
	jal drawBackground
	
	jal drawScoreInGame #difficulty adjusted here
	li $s0, 0
	addi $s0, $t0, 84
	move $s6, $s3
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s4
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s5
	jal drawDigit
	
	jal drawPlatforms
	jal drawSprite
	
	j mainLoop
	
detectInput:
	li $v0, 32
	li $a0, 50
	syscall
	lw $s0, 0xffff0000
	beq $s0, 1, checkInput #there is input
	jr $ra #no input
	
checkInput:
	lw $s1, 0xffff0004
	beq $s1, 0x6a, InputJ #input is J
	beq $s1, 0x6b, InputK #input is K
	jr $ra #input is not J nor K
	
InputJ:
	addi $t2, $t2, -4 #move sprite one pixel to the left
	jr $ra

InputK:
	addi $t2, $t2, 4 #move sprite one pixel to the right
	jr $ra

checkDeath:
	li $s0, 0
	addi $s0, $t0, 4096
	#if sprite location greater than bottom-right pixel location, end game
	bgt $t2, $s0, gameOver
	jr $ra
	
gameOver:
	j exit
	
checkJump:
	li $s0, 0
	li $s1, 4
	la $s2, 0($t1)

checkJumpLoop:
	beq $s0, $s1, checkJumpEnd
	lw $s3, 0($s2)
	li $s4, 0 #leftmost possible pixel
	li $s5, 0 #rightmost possible pixel
	li $s6, 8 #to help adjust rightmost pixel based on difficulty
	sub $s6, $s6, $t5
	mul $s6, $s6, 4
	addi $s4, $s3, -260
	addi $s5, $s3, -220
	sub $s5, $s5, $s6
	bge $t2, $s4, restartJump

checkJumpLoopCont:
	addi $s0, $s0, 1
	addi $s2, $s2, 4
	j checkJumpLoop
	
restartJump:
	bgt $t2, $s5, checkJumpLoopCont
	li $t3, 0	

checkJumpEnd:
	jr $ra
	
checkMoveScreen:
	li $s0, 0
	addi $s0, $t0, 896
	blt $t2, $s0, moveScreen
	jr $ra

moveScreen:
	li $s0, 0
	la $s2, 0($t1)
	addi $s0, $s2, 12
	add $s4, $t0, 3968 #location of last row
	lw $s3, 0($s0) #location of bottom platform
	addi $t2, $t2, 128 #sprite go down one row
	bge $s3, $s4, addPlatform

movePlatformsDown:
	li $s5, 0
	li $s6, 16
	li $s4, 0

movePlatformsLoop:
	beq $s5, $s6, movePlatformsEnd
	la $s7, 0($t1)
	add $s4, $s7, $s5
	lw $s3, 0($s4)
	addi $s3, $s3, 128
	sw $s3, 0($s4)
	addi $s5, $s5, 4
	j movePlatformsLoop
	
movePlatformsEnd:
	jr $ra

addPlatform:
	li $v0, 42
	li $a1, 32
	sub $a1, $a1, $t5
	syscall
	
	#multiply random number by 4
	li $s1, 4
	mul $s1, $s1, $a0
	add $s1, $t0, $s1  #location of new platform, one row above screen
	addi $s1, $s1, -128
	
	addi $t4, $t4, 1 #score increases by 1
	
	#now we want to shift the platform array
	li $s5, 12 #loop counter
	li $s6, 0 #loop counter end, we will keep adding 4.
	li $s4, 0

shiftPlatforms:
	beq $s5, $s6, shiftPlatformsEnd
	la $s7, 0($t1)
	add $s4, $s7, $s5 #platform at index ($s5/4) location
	lw $s0, -4($s4) #get previous platform	
	sw $s0, 0($s4) #store at current
	addi $s5, $s5, -4
	j shiftPlatforms

shiftPlatformsEnd:
	li $s4, 0
	la $s7, 0($t1)
	addi $s4, $s7, 0
	sw $s1, 0($s4) #store new platform at index 0 of platform array
	j movePlatformsDown

############################## DRAWING FUNCTIONS ##########################

drawBackground:
	add $s0, $t0, $zero
	li $s1, 0 #loop counter
	li $s2, 1024 #loop counter end condition

drawBackgroundLoop:
	beq $s1, $s2, drawBackgroundEnd #loop condition check
	lw $s3, backgroundColour #s3 stores background colour
	sw $s3, 0($s0) #draw current pixel
	addi $s0, $s0, 4 #increment by 4 (go to next) 
	addi $s1, $s1, 1 #increment loop counter by 1
	j drawBackgroundLoop #back to start of loop

drawBackgroundEnd:
	jr $ra
	
	
startingPlatforms:
	li $s0, 0 #loop counter
	li $s1, 4 #loop counter end 0-3 = 4 platforms
	li $s4, 896 #row 7, if indexing start at 0
	li $s6, 0
	add $s6, $s6, $t1
	
startingPlatformsLoop: #TODO: store it in array
	beq $s0, $s1, startingPlatformsEnd
	#generate a random number from 0-23, platform will be length 9
	li $v0, 42
	li $a1, 24 
	syscall
	
	#multiply random number by 4
	li $s2, 4
	mul $s3, $s2, $a0
	
	#draw the platform
	add $s5, $t0, $s4
	add $s5, $s5, $s3
	lw $s7, platformColour	# $s7 stores the platform colour code
	sw $s7, 0($s5)
	sw $s7, 4($s5)
	sw $s7, 8($s5)
	sw $s7, 12($s5)
	sw $s7, 16($s5)
	sw $s7, 20($s5)
	sw $s7, 24($s5)
	sw $s7, 28($s5)
	sw $s7, 32($s5)
	addi $s4, $s4, 1024
	addi $s0, $s0, 1
	
	#store platform in array of platform
	sw $s5, 0($s6)
	addi $s6, $s6, 4
	
	j startingPlatformsLoop
	

startingPlatformsEnd:
	jr $ra

drawPlatforms:
	li $s0, 0 #loop counter
	li $s1, 4
	la $s2, ($t1)

drawPlatformsLoop:
	beq $s0, $s1, drawPlatformsEnd
	lw $s7, platformColour	# s7 stores the platform colour code
	lw $s5, 0($s2)
	li $s3, 4
	li $s4, 0
	add $s4, $s4, $t5
	addi $s4, $s4, 1
	mul $s4, $s4, $s3
	li $s3, 0

drawPlatformsLoopLoop:
	beq $s3, $s4, drawPlatformsLoop2
	add $s6, $s5, $s3
	sw $s7, 0($s6)
	addi $s3, $s3, 4
	j drawPlatformsLoopLoop

drawPlatformsLoop2:
	addi $s0, $s0, 1
	addi $s2, $s2, 4
	j drawPlatformsLoop

drawPlatformsEnd:
	jr $ra

drawSprite:
	lw $s1, spriteColour # $s1 stores the sprite colour code
	move $s0, $t2
	sw $s1, 0($s0)
	sw $s1, -128($s0)
	sw $s1, -4($s0)
	sw $s1, 124($s0)
	sw $s1, 4($s0)
	sw $s1, 132($s0)
	jr $ra
	
drawScoreInGame:
	lw $s1, textColour
	
	#get hundredth, tenth, and ones digits
	li $s2, 100
	div $t4, $s2
	mflo $s3 #hundredth
	
	li $s2, 10
	mfhi $s4  #tenth
	div $s4, $s2
	mflo $s4
	mfhi $s5  #last digit
	
	beq $s4, 0, drawScoreInGameEnd
	beq $s5, 0, updateDifficulty
	
drawScoreInGameEnd:
	jr $ra

updateDifficulty:
	beq $t5, 0, drawScoreInGameEnd
	bne $t6, $s4, drawScoreInGameEnd
	addi $t6, $t6, 1
	addi $t5, $t5, -1
	j drawScoreInGameEnd
	
drawDigit:
	beq $s6, 0, drawSmallZero
	beq $s6, 1, drawSmallOne
	beq $s6, 2, drawSmallTwo
	beq $s6, 3, drawSmallThree
	beq $s6, 4, drawSmallFour
	beq $s6, 5, drawSmallFive
	beq $s6, 6, drawSmallSix
	beq $s6, 7, drawSmallSeven
	beq $s6, 8, drawSmallEight
	beq $s6, 9, drawSmallNine
	addi $s0, $s0, 16
	jr $ra 

drawG:
	#s0 has location of G
	lw $s1, textColour
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 12($s0)
	sw $s1, 16($s0)
	sw $s1, 128($s0)
	sw $s1, 148($s0)
	sw $s1, 256($s0)
	sw $s1, 276($s0)
	sw $s1, 384($s0)
	sw $s1, 512($s0)
	sw $s1, 640($s0)
	sw $s1, 768($s0)
	sw $s1, 896($s0)
	sw $s1, 1028($s0)
	sw $s1, 1032($s0)
	sw $s1, 1036($s0)
	sw $s1, 1040($s0)
	sw $s1, 784($s0)
	sw $s1, 788($s0)
	sw $s1, 792($s0)
	sw $s1, 920($s0)
	sw $s1, 916($s0)
	sw $s1, 1048($s0)
	jr $ra
	
drawExclamation:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 384($s0)
	sw $s1, 512($s0)
	sw $s1, 640($s0)
	sw $s1, 896($s0)
	sw $s1, 1024($s0)
	jr $ra
	
drawSmallZero:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 384($s0)
	sw $s1, 512($s0)
	sw $s1, 516($s0)
	sw $s1, 520($s0)
	sw $s1, 392($s0)
	sw $s1, 264($s0)
	sw $s1, 136($s0)
	jr $ra
	
drawSmallOne:
	lw $s1, textColour
	sw $s1, 4($s0)
	sw $s1, 132($s0)
	sw $s1, 128($s0)
	sw $s1, 260($s0)
	sw $s1, 388($s0)
	sw $s1, 516($s0)
	jr $ra
	
drawSmallTwo:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 384($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawSmallThree:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 512($s0)
	sw $s1, 516($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawSmallFour:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawSmallFive:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawSmallSix:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	sw $s1, 384($s0)
	jr $ra
	
drawSmallSeven:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawSmallEight:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 384($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawSmallNine:
	lw $s1, textColour
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawScoreEndGame:
	lw $s1, textColour
	
	#get hundredth, tenth, and ones digits
	li $s2, 100
	div $t4, $s2
	mflo $s3 #hundredth
	
	li $s2, 10
	mfhi $s4  #tenth
	div $s4, $s2
	mflo $s4
	mfhi $s5  #last digit
	
	jr $ra 

####################################################### GAME OVER #############################################################
	
exit:
	jal drawBackground
	add $s0, $t0, 276
	
	jal drawG
	add $s0, $s0, 32
	jal drawG
	add $s0, $s0, 32
	jal drawExclamation
	add $s0, $s0, 4
	jal drawExclamation
	add $s0, $s0, 8
	jal drawExclamation
	add $s0, $s0, 4
	jal drawExclamation
	
	jal drawScoreEndGame
	li $s0, 0
	addi $s0, $t0, 1944
	move $s6, $s3
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s4
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s5
	jal drawDigit
	
	li $v0, 10 #terminate the program gracefully
	syscall
