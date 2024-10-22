.equ IO_BASE, 0xff200000
.equ LED,     0x00
.equ SWITCH,  0x40
.equ TOS,     0x04000000
.equ UART,    0x1000
.equ BUTTON, 0x50

.macro push reg
subi sp, sp, 4
stw \reg, 0(sp)
.endm

.macro pop reg
ldw \reg, 0(sp)
addi sp, sp, 4
.endm

.global _start 
_start: 

movia sp,  TOS
movia r23, IO_BASE
movia r2,  0xf     # set initial chips, 4 per f
call  turn_on_led  # load chips into leds
soft_reset:        # resets hand values
call return_led
beq  r2,  r0, bankrupt
movi r22, 0
movi r21, 0
game:
	movia  r2, match_start    # prints start message
	call   write
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	# sets up the game for play
	call game_set_up
	ready:
	mov  r22, r3  #set player hand value
	mov  r21, r4  #sets delealer hand value
	
	player_turn:   #the player decides to draw or stand
		movia  r2, draw_uart        # prints stand or hit
		call   write
		movi   r16, 10              # NEWLINE
		stwio  r16, UART(r23)
		addi   r2, r2, 1
		ldb    r0, 0(r2)            # NULL terminate
		call   check_button
		beq    r3, r0, player_draw  # draws card for player
		br     player_stands        # branches to dealers turn
		
	player_check:  #checks if the player lost or got twenty one
		add  r22, r22, r3           # save value to player hand
		call check_bust_player      # check for bust
		call check_twenty_one_player# check for 21
		br   player_turn            # loop back to player
		
	player_stands:    # if the player stands or reaches 21
	
	dealer_turn:
		call should_draw            # decides if dealer should draw
	dealer_check: 
		add  r21, r21, r3           # save value to dealers hand
		call check_bust_dealer      # see if dealer busted

bankrupt: # executes upon no chips/bankruptcy
	movia  r2, game_over      # prints game over message
	call   write
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	movia  r2, continue       # asks if you want to continue
	call   write
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	call   check_button       # uses input to decide whether to restart
	# supposed to be reminiscent of press any button to continue
	br     _start             # HARD RESETS GAME
	

_stop: br _stop

#####################################
# SUBROUTINES
#####################################	
	
# sets up the game for play
game_set_up: #ARGS: NONE  RETURNS: initial hand values
	#sets up players hand
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	mov   r3, r2            #remembers players card
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	add   r3, r3, r2        #adds player second card to r3
	movia r2,  your_hand
	call  write
	mov   r2, r3            # number to show on UART
	call  num_to_uart        # call subroutine
	movi  r2, 10            # add a newline ASCII 10
	stwio r2, UART(r23)     # and send to UART
	# sets up dealers hand
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	mov   r4, r2            #remembers players card
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	add   r4, r4, r2        #adds player second card to r3
	movia r2,  dealer_hand
	call  write
	mov   r2, r4            # number to show on UART
	call  num_to_uart        # call subroutine
	movi  r2, 10            # add a newline ASCII 10
	stwio r2, UART(r23)     # and send to UART
	br    ready             # starts game after finishing set_up
######  game set-up finished

####### card drawing below
player_draw: #ARGS: NONE    RETURNS: drawn card to r3
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	mov   r3, r2            #remembers players card
	movia r2,  your_hand
	call  write
	add   r2, r3, r22       # number to show on UART
	call  num_to_uart        # call subroutine
	movi  r2, 10            # add a newline ASCII 10
	stwio r2, UART(r23)     # and send to UART
	br    player_check
dealer_draw: #ARGS: NONE    RETURNS: drawn card to r3
	call  random            #random num to r2
	call  return_card_val   #card value to r2
	mov   r3, r2            #remembers dealers card
	movia r2,  dealer_hand
	call  write
	add   r2, r3, r21       # number to show on UART
	call  num_to_uart        # call subroutine
	movi  r2, 10            # add a newline ASCII 10
	stwio r2, UART(r23)     # and send to UART
	br    dealer_check      
#### card drawing above

#### card and hand checks below
should_draw: #args: dealers hand r21  RETURNS: dealer stand(r2=1), draws card
	movi  r2, 17              # moves 17 to r2
	cmpgt r2, r2, r21         # sees if dealers hand is less than 17
	bne   r2, r0, dealer_draw # draws if less than 17
	beq   r2, r0, final_check # branches to a final hand check
	
final_check: #ARGS: dealer and player hands RETURNS: match outcome
	beq   r22,r21, draw #if hands equal, then draw
	cmpgt r2, r22, r21  #sees if player hand greater
	bne   r2, r0,  win  #player wins if higher
	beq   r2, r0,  loss #player loses if lower
	
check_twenty_one_player: #ARGS: player hand r22  RETURNS: NONE
	movi   r2, 21                #puts 21 in r2
	cmpeq  r2, r2, r22           #sees if your hand is equal to 21
	bne    r2, r0, player_stands #branches to dealer perpetual turns
	ret
	
check_bust_player:      #ARGS: r22 hand  RETURNS: NONE
    movi   r2, 21       #puts 21 in r2
	cmpgt  r2, r2, r22  #sees if your hand is higher than 21
	beq    r2, r0, loss #you lose if you bust
	ret	
	
check_bust_dealer:      #ARGS: r21 hand  RETURNS: NONE
    movi   r2, 21       #puts 21 in r2
	cmpgt  r2, r2, r21  #sees if dealer hand is higher than 21
	beq    r2, r0, win  #you lose if dealers busts
	br     dealer_turn
#### card and hand checks above

#### game outcomes below
loss: #ARGS: NONE   RETURNS: message and alters led
	call  shift_right    #"lose" a chip
	return_loss:
	movia  r2, round_lost    #print loss message
	call   write 
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	br     soft_reset     #begin next match
	
win:  #ARGS: NONE   RETURNS: message and alters led
	call  shift_left          #"add" a chip
	return_win:
	movia  r2, round_won      #print win message
	call   write
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	br     soft_reset         #begin next match
	
draw:  #ARGS: NONE   RETURNS: message of draw
	movia  r2, round_draw    #print win message
	call   write
	movi   r16, 10            # NEWLINE
	stwio  r16, UART(r23)
	addi   r2, r2, 1
	ldb    r0, 0(r2)          # NULL terminate
	br     soft_reset         #begin next match
#### game outcomes above


#### Button stuff below
check_button:     #ARGS: Push Buttons   RETURNS: hit(0) or stand(1) in r3
    movia r4, 0b10
	ldwio r2, BUTTON(r23)      # read buttons
	andi  r2, r2, 0b01         # bit mask for button0
	bne   r2, r0, pressed0     # branch if button0 down
	ldwio r2, BUTTON(r23)      # read buttons
	andi  r2, r2, 0b10         # bit mask for button0
	beq   r2, r4, pressed1     # branch if button1 down
	br    check_button
	pressed0:
	movia r3, 0                #sets r3 to 0 for dealing
	br wait_for_up0
	pressed1:                  # set r3 to 1 for standing
	movia r3, 1
	br wait_for_up1
	wait_for_up0:
	ldwio r2, BUTTON(r23)      # read buttons
	bne   r2, r0, wait_for_up0 # if down wait till up
	ret
	wait_for_up1:
	ldwio r2, BUTTON(r23)      # read buttons
	beq   r2, r4, wait_for_up1 # if down wait till up
	ret
####### button stuff above

####### card values below
return_card_val:  #ARG: NONE           RETURN: returns 1-10 card value
	push       r3
	ldw       r2, rand_numb(r0)   # gets random value 
	cmpeqi    r3, r2, 0           # checks for face card: 0,11,12
	bne       r3, r0, elif        # branches if face card
	cmpeqi    r3, r2, 11          # checks for face card: 0,11,12
	bne       r3, r0, elif        # branches if face card
	cmpeqi    r3, r2, 12          # checks for face card: 0,11,12
	bne       r3, r0, elif        # branches if face card
	pop       r3
	ret                           # no change and returns
	elif:	 # if face card, sets to 10 and returns
		pop   r3
		movia r2, 10              # set r2 to 10
 		ret                       # returns
###### care values above

###### LEDs below
return_led:       #ARG: r2 LED         RETURN: LED Value
	ldwio r2, LED(r23)
	ret
	
turn_on_led:     #ARG: r2 LED pattern  RETURN: none
	stwio r2, LED(r23)
	ret
	
                 #The below shifts bits and change the LEDs 
                 #ARG: r2 bit to shift RETURN: shifted bits
shift_left:
	call return_led
	slli r2, r2, 1        #shift bit position left by 1
	addi r2, r2, 1
	call turn_on_led      # turn on the LED
	br   return_win
                 #ARG: r2 bit to shift RETURN: shifted bits 
shift_right:
	call return_led
	srli r2, r2, 1        #shift bit position left by 1
	call turn_on_led      # turn on the LED
	br   return_loss
####### LEDs above


#####################################
# MARVIN'S SUBROUTINES
#####################################

# NIOS II Assembly Language Example
#
# Purpose: Send word to and from UART
# Author: Marvin Johnson Jr
write: # r2 address of string
	push  r16 # stack
	write_char:
		ldwio r16, UART+4(r23)    # read control register
		beq   r16, r0, write_char # does buffer have room ?
		ldb   r16, (r2)           # get string character
		beq   r16, r0, _write     # break if NULL terminator
		stwio r16, UART(r23)      # else write to UART
		addi  r2, r2, 1           # index next character
		br write_char             # loop
	_write:
		pop   r16                 # unstack
		ret
read: # r2 array r3 end
	push r16 # stack
	push r17 #
	read_char:
		ldwio  r16, UART(r23)     # read data register
		andi   r17, r16, 0x8000   # 15th bit RVALID
		beq    r17, r0, read_char # does buffer have room ?
		andi   r17, r16, 0xff     # get char
		cmpeqi r16, r17, 10       # is it a NEWLINE ?
		bne    r16, r0, _read     # if NEWLINE break
		stb    r17, 0(r2)         # else write to array
		stwio  r17, UART(r23)     # echo
		addi   r2, r2, 1
		bne    r2, r3, read_char  # loop if not at end
	_read:
		movi   r16, 10            # NEWLINE
		stwio  r16, UART(r23)
		addi   r2, r2, 1
		ldb    r0, 0(r2)          # NULL terminate
		pop    r17 			      #
		pop    r16 				  # unstack
		ret

# NIOS II Assembly Language Example
#
# Purpose: Send number to UART
# Author: Marvin Johnson Jr

num_to_uart:   # ARG: r2 number 0-999999999
 push r2                # \
 push r3                #  \
 push r4                #   stack
 push r5                #  /
 push r6                # /
 push r7                #/
 
 movia r3, 1000000000   # highest divider
 movi  r4, 10           # fixed 10
 movi  r7, 0            # flag determines if send character to UART
 
 div_loop:
  div   r5, r2, r3      # divide number by divider
  bne    r7, r0, send   # send is flag already set
  cmpeqi r8, r3, 1      # or send if in 1's place
  bne    r8, r0, send   #
  bne    r5, r0, send   # or send if value not zero
  br    skip_send
  send:
  movi  r7, 1           # set send flag
  addi  r6, r5, 0x30    # convert number to ASCII
  stwio r6, UART(r23)   # send to UART 
  skip_send:
  mul   r6, r5, r3      # get remainder of number
  sub   r2, r2, r6      # subtract remainder from number       
  div   r3, r3, r4      # new divider / 10
  bne   r3, r0, div_loop# stop loop when divider is zero
   
 pop  r7                #\
 pop  r6                # \
 pop  r5                #  unstack
 pop  r4                #  /
 pop  r3                # /
 pop  r2                #/
 ret

# NIOS II Assembly Language Example
#
# Purpose: Random Number Generator
# Author: Marvin Johnson Jr
# Based on ideas from The Art of Computer Programming, Volume 2 (Donald Knuth)

# call random                 # generate random number
# ldw r2, rand_numb(r0)       # load it from memory

random:
 push   r16                 # stack
 push   r17                 #
 ldw    r16, rand_seed(r0)  #  / fetch seed
 addi   r16, r16, 1         # /
 movia  r17, 3141592621     #|  make new seed
 mul    r16, r16, r17       # \ 
 stw    r16, rand_seed(r0)  #  \ store new seed
 ldw    r17, rand_max(r0)   # generate number
 mulxuu r16, r16, r17       # by pulling the hi 32-bits 
 stw    r16, rand_numb(r0)  # random number stored in "rand"
 pop    r17                 # unstack 
 pop    r16                 # 
 ret

###############################
# DATA
###############################
.org 0x1000
.data
rand_max:  .word 13      # maximum number (e.g. 100 gets 0-99)
rand_seed: .word 1234567  # seed for random number generator
rand_numb: .word 0        # store random number here
# Prompts
continue: .asciz "Continue?"
game_over: .asciz "  GAME OVER"
round_draw: .asciz "DRAW"
match_start: .asciz "  NEW MATCH"
round_won: .asciz "Round Won!"
round_lost: .asciz "Round Lost!"
draw_uart: .asciz "Stand or Hit? "
continue_uart: .asciz "Continue?"
dealer_hand: .asciz "Dealer Hand: "
your_hand: .asciz "Your Hand: "
first_prompt: .asciz "First Name: "
last_prompt: .asciz "Last Name: "
welcome_msg: .byte 'W','e','l',0x63,0x6f,'m','e',' ',0x00 # crazy
# example
space: .asciz " "
# Arrays to store answers
first_name: .skip 15
first_end: .skip 1
last_name: .skip 15
last_end: .skip 1
.end
# Instructions to play are below
# The game does not follow all blackjack conventions
# Excuse: Home rules
# An ace is just 1
# You can increase the chip capacity by expanding total leds
# You can change starting leds right after _start on line 23
# After each match your hand and the dealers hand will reset
# When asked to hit or stand you will use the push buttons
# pushing 0 will indicate hit
# pushing 1 will indicate stand
# you must unpress the button to continue
# The the game will deal two cards to dealer and player
# Along with a message it will show the value of your, and dealers hand
# You decide to stand or hit here(0 or 1)
# You can keep hitting till certain condition are met
# It will automatically go to the dealers turn if you get 21
# You will automatically lose if you go over 21
# If you stand(1) it will start the dealers turn 
# The dealer follows standard blackjack conventions
# Draws if 16 or less and stands if higher
# If the dealer goes over 21, you win
# If not it compares values first to determine a winner
# Whoevers hand is higher, wins. Draw otherwise
# A win adds to your chips(leds)
# A loss takes away from your chips(leds)
# A draw has no affect on your chips(leds)
# If you lose all your chips the current game ends
# You can Push any button and unpush it to continue
# Your chips will return to their starting value
# !!!!!!!! LASTLY !!!!!!!!!
# There is a problem; Function calls nested to many levels(>32)
# You can turn off, Function nesting to deep, in the settings
# Settings are on the left side, check the box after scrolling down
# I ran the game for a long time without issue with this off
# It popped up only after I had everything set-up, sorry
# The link attached to the message said its not technically an error
# Soooo yeah(fingers crossed)
