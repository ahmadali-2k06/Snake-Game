.data
# ------------------------------------------------------------------------------
# 1. CONSTANTS (Hardware Addresses & Colors)
# ------------------------------------------------------------------------------
# Bitmap Display Configuration:
# - Unit Width: 8
# - Unit Height: 8
# - Display Width: 256
# - Display Height: 256
# - Base Address: 0x10008000 ($gp)

.eqv RED        0x00FF0000
.eqv GREEN      0x0000FF00
.eqv BLUE       0x000000FF
.eqv BLACK      0x00000000
.eqv WHITE      0x00FFFFFF
.eqv OBSTACLE_COL 0x00808080   # Gray

.eqv ADDR_DSPL  0x10008000     # Heap Base Address for Bitmap Display

# MMIO (Keyboard) Configuration
.eqv ADDR_KBRD  0xffff0000     # Control register
.eqv ADDR_KEY   0xffff0004     # Data register (holds the ASCII key)

# ------------------------------------------------------------------------------
# 2. GAME VARIABLES
# ------------------------------------------------------------------------------

# Snake Data
snakeX:     .word 10, 9, 8, 7, 6   # Initial 5 segments
            .space 380             # Empty space for growing (380 bytes)

snakeY:     .word 10, 10, 10, 10, 10
            .space 380             # Empty space for growing
snakeLen:   .word 3                # Current length of snake
snakeDir:   .word 'd'              # Current direction (w, a, s, d). Default 'd' (Right)

# Game State
score:        .word 0
level:        .word 1
speed:        .word 100            
apples_eaten: .word 0

# Apple Position (Initial dummy values)
appleX:     .word 15
appleY:     .word 10

# Obstacle Data
obstacleX:   .space 40       # Array for 10 obstacles (4 bytes each)
obstacleY:   .space 40       # Array for 10 obstacles
obstacleCnt: .word 0         # How many obstacles are currently active

# Strings for Console Output
str_lvl:     .asciiz "Level "
str_sep:     .asciiz " | Score "
str_high_score: .asciiz " | HIGH SCORE: "
str_nl:      .asciiz "\n"
str_lvl_up:  .asciiz "-----------Level Increased------------\n"
str_game_over: .asciiz "Ouch you collided ! Game over!!\n"
str_start:     .asciiz "----------------------------------\n|   WELCOME TO SNAKE!            |\n|   Press 's' to Start           |\n----------------------------------\n"
str_replay:    .asciiz "----------------------------------\n|   GAME OVER                    |\n|   Press 'r' to Replay          |\n|   Press 'e' to Exit            |\n----------------------------------\n"
str_new_record: .asciiz "\n\n*** GREAT WORK! YOU BEAT YOUR HIGH SCORE! ***\n"

# FILE DATA
file_name:           .asciiz "C:/Users/ytbro/Downloads/snake_game/highscore.txt"
high_score:          .word 0

# File I/O messages
str_debug_fd:        .asciiz "File Descriptor: "
str_debug_written:   .asciiz "Bytes Written: "
str_file_error:      .asciiz "ERROR: Could not open file!\n"
str_success:         .asciiz "✓ File saved successfully!\n"
str_newline:         .asciiz "\n"

.text
.globl main

# ------------------------------------------------------------------------------
# 3. MAIN INITIALIZATION
# ------------------------------------------------------------------------------
main:
   
   jal load_high_score
   
    jal show_start_screen
    
    # 1. Initial Draw of the Apple
    lw $a0, appleX
    lw $a1, appleY
    li $a2, RED
    jal draw_pixel
    
    # 2. Initial Draw of the Snake (So player sees position during wait)
    jal draw_snake

    # 3. Print Initial State (Level 1 | Score 0)
    jal print_status

    # 4. STARTUP DELAY: Wait 3 Seconds (3000 ms)
    li $v0, 32
    li $a0, 3000    # 3000 ms = 3 seconds
    syscall
    
    j main_loop

# ------------------------------------------------------------------------------
# 4. THE GAME LOOP
# ------------------------------------------------------------------------------
main_loop:
   # 1. Clear Screen (REMOVED TO PREVENT BLINKING)
   # jal clear_screen 

    # 2. Draw Snake
    jal draw_snake
    
    # 2b. Draw Obstacles
    jal draw_obstacles
    
    # 3. Draw Apple (Ensure it remains visible)
    lw $a0, appleX
    lw $a1, appleY
    li $a2, RED
    jal draw_pixel

    # 4. Check Input
    jal check_input

    # 5. Update Snake (Move & Smart Redraw)
    jal update_snake
    
    # 6. Check for Collisions (Wall/Self/Obstacles)
    jal check_collisions
    bnez $v0, game_over  # If v0 == 1, Jump to Game Over

    # 7. Check Apple (Eat & Grow & Level Up)
    jal check_apple
    
    # 8. Sleep (Game Speed)
    li $v0, 32        
    lw $a0, speed     
    syscall

    j main_loop      # Repeat 

# ------------------------------------------------------------------------------
# GAME OVER STATE
# ------------------------------------------------------------------------------
game_over:
    # Print Game Over Message
    li $v0, 4
    la $a0, str_game_over
    syscall
    
    j show_game_over_screen

    # Exit Program
    li $v0, 10
    syscall
    
    
# ------------------------------------------------------------------------------
# Function: draw_pixel (FIXED)
# Arguments: $a0 = X coordinate, $a1 = Y coordinate, $a2 = Color
# ------------------------------------------------------------------------------
draw_pixel:
    # 1. Check bounds (Safety check)
    blt $a0, 0, dp_ret
    bge $a0, 32, dp_ret
    blt $a1, 0, dp_ret
    bge $a1, 32, dp_ret

    # 2. Calculate Offset: (Y * 32 + X) * 4
    mul $t0, $a1, 32     # t0 = Y * 32
    add $t0, $t0, $a0    # t0 = (Y * 32) + X
    mul $t0, $t0, 4      # t0 = index * 4 (offset in bytes)
    
    # 3. Add to Base Address (THE FIX IS HERE)
    li $t1, ADDR_DSPL    # Load 0x10008000 safely
    add $t0, $t1, $t0    # t0 = Base + Offset

    # 4. Draw
    sw $a2, 0($t0)       # Store color at that address

dp_ret:
    jr $ra               # Return
# ------------------------------------------------------------------------------
# Function: draw_snake
# Arguments: None
# Description: Loops through snakeX and snakeY arrays and draws them.
# ------------------------------------------------------------------------------
draw_snake:
    addi $sp, $sp, -4    
    sw $ra, 0($sp)

    la $t0, snakeX      
    la $t1, snakeY        
    lw $t2, snakeLen      
    
    li $t3, 0            

ds_loop:
    bge $t3, $t2, ds_end # If i >= length, stop

    # Load X and Y from arrays
    lw $a0, 0($t0)       # a0 = snakeX[i]
    lw $a1, 0($t1)       # a1 = snakeY[i]
    
    # Set Color
    li $a2, GREEN        
    
    move $s0, $t0
    move $s1, $t1
    move $s2, $t2
    move $s3, $t3
    
    jal draw_pixel       # Call draw function
    
    # Restore temp registers
    move $t0, $s0
    move $t1, $s1
    move $t2, $s2
    move $t3, $s3

    # Advance array pointers (4 bytes per int)
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    
    # Increment loop counter
    addi $t3, $t3, 1
    j ds_loop

ds_end:
    lw $ra, 0($sp)       # Restore return address
    addi $sp, $sp, 4
    jr $ra

# ------------------------------------------------------------------------------
# Function: clear_screen
# Description: Overwrites the whole screen with Black
# ------------------------------------------------------------------------------
clear_screen:
    li $t0, ADDR_DSPL    # Start address
    li $t1, 1024         # Total pixels (32 * 32 = 1024)
    li $t2, BLACK        # Color

cs_loop:
    sw $t2, 0($t0)       # Color the pixel
    addi $t0, $t0, 4    
    addi $t1, $t1, -1 
    bnez $t1, cs_loop    
    
    jr $ra
    
# ----------------------------------------------------------------------------------------------------------------------------------------------------
# Function: check_input 
# Description: Checks MMIO for keypress and updates snakeDir
# ------------------------------------------------------------------------------
check_input:
   
    li $t0, ADDR_KBRD    # Load 0xffff0000 into t0
    lw $t1, 0($t0)       # Read the control register value
    
    andi $t1, $t1, 1     # Check the "Ready" bit (bit 0)
    beqz $t1, ci_ret     # If 0 (not ready), return immediately


    li $t0, ADDR_KEY     # Load 0xffff0004
    lw $t1, 0($t0)       # Read the ASCII key value ($t1 = new key)
    lw $t2, snakeDir     # Load current direction ($t2 = current direction)

    # --- 180 TURN PROTECTION ---
    # If key is 'w' (up), check if currently going 's' (down)
    beq $t1, 'w', ci_check_up
    beq $t1, 's', ci_check_down
    beq $t1, 'a', ci_check_left
    beq $t1, 'd', ci_check_right
    j ci_ret

ci_check_up:
    beq $t2, 's', ci_ret  # If moving Down, ignore Up
    j ci_update
ci_check_down:
    beq $t2, 'w', ci_ret  # If moving Up, ignore Down
    j ci_update
ci_check_left:
    beq $t2, 'd', ci_ret  # If moving Right, ignore Left
    j ci_update
ci_check_right:
    beq $t2, 'a', ci_ret  # If moving Left, ignore Right
    j ci_update

ci_update:
    sw $t1, snakeDir    

ci_ret:
    jr $ra
    
# ------------------------------------------------------------------------------
# Function: update_snake
# Description: Erases tail, shifts body, updates head based on direction.
# ------------------------------------------------------------------------------
update_snake:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # 1. ERASE TAIL (Draw Black at the last coordinate)
    lw $t0, snakeLen     # Get length (e.g., 5)
    sub $t0, $t0, 1      # Index of tail = len - 1
    sll $t0, $t0, 2      # Multiply by 4 for byte offset

    la $t1, snakeX
    add $t1, $t1, $t0    
    lw $a0, 0($t1)       

    la $t1, snakeY
    add $t1, $t1, $t0   
    lw $a1, 0($t1)       

    li $a2, BLACK
    jal draw_pixel       # Paint it Black!

    # 2. SHIFT BODY (Move index i-1 to i)
    lw $t2, snakeLen
    sub $t2, $t2, 1      

us_loop:
    blez $t2, us_head    # If i <= 0, done shifting, go to Head logic

    # Get addresses for index i and i-1
    sll $t3, $t2, 2      
    addi $t4, $t2, -1    
    sll $t4, $t4, 2      

    # Shift X
    la $t5, snakeX
    add $t6, $t5, $t4    
    lw $t7, 0($t6)      
    add $t6, $t5, $t3    
    sw $t7, 0($t6)      

    # Shift Y
    la $t5, snakeY
    add $t6, $t5, $t4
    lw $t7, 0($t6)       
    add $t6, $t5, $t3    
    sw $t7, 0($t6)       

    sub $t2, $t2, 1      # i--
    j us_loop

    # 3. UPDATE HEAD (snakeX[0] and snakeY[0])
us_head:
    lw $t0, snakeDir     # Load direction
    lw $t1, snakeX       # Load current Head X
    lw $t2, snakeY       # Load current Head Y

    beq $t0, 'w', move_up
    beq $t0, 's', move_down
    beq $t0, 'a', move_left
    beq $t0, 'd', move_right
    j us_draw            

move_up:
    sub $t2, $t2, 1      
    j us_save
move_down:
    add $t2, $t2, 1      
    j us_save
move_left:
    sub $t1, $t1, 1    
    j us_save
move_right:
    add $t1, $t1, 1      
    j us_save

us_save:
    # Save new head coordinates
    sw $t1, snakeX
    sw $t2, snakeY

us_draw:
    # 4. DRAW HEAD (Green)
    move $a0, $t1
    move $a1, $t2
    li $a2, GREEN
    jal draw_pixel

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ------------------------------------------------------------------------------
# Function: check_apple (MODIFIED FOR CONSOLE OUTPUT)
# ------------------------------------------------------------------------------
check_apple:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # 1. Load Head and Apple
    lw $t0, snakeX       # Head X
    lw $t1, snakeY       # Head Y
    lw $t2, appleX
    lw $t3, appleY

    bne $t0, $t2, ca_ret
    bne $t1, $t3, ca_ret 

    # --- EATEN ---

    # 2. Increase Score
    lw $t0, score
    addi $t0, $t0, 10
    sw $t0, score
    
    # 3. Increase Apples Eaten
    lw $t0, apples_eaten
    addi $t0, $t0, 1
    sw $t0, apples_eaten

    # 4. Grow Snake
    lw $t0, snakeLen      
    sub $t1, $t0, 1       
    sll $t1, $t1, 2      
    la $t2, snakeX
    add $t3, $t2, $t1    
    lw $t4, 0($t3)        
    sw $t4, 4($t3)        
    la $t2, snakeY
    add $t3, $t2, $t1   
    lw $t4, 0($t3)        
    sw $t4, 4($t3)       
    addi $t0, $t0, 1
    sw $t0, snakeLen

    # 5. Check Levels (Testing Mode)
    lw $t0, apples_eaten
    
    # Check for Level 2 (2 Apples)
    li $t1, 2
    beq $t0, $t1, trigger_level_2

    # Check for Level 3 (4 Apples)
    li $t1, 4
    beq $t0, $t1, trigger_level_3
    
    # If no level up, just print score
    jal print_status

    # Generate New Apple (Normal Case)
    jal generate_apple
    j ca_ret

trigger_level_2:
    # Print Level Up Message
    li $v0, 4
    la $a0, str_lvl_up
    syscall

    li $t0, 2
    sw $t0, level
    
    jal print_status     # Print new status (Level 2 | Score XX)

    jal init_level_2     # Spawns 5 obstacles
    jal generate_apple
    j ca_ret

trigger_level_3:
    # Print Level Up Message
    li $v0, 4
    la $a0, str_lvl_up
    syscall

    li $t0, 3
    sw $t0, level

    jal print_status     # Print new status (Level 3 | Score XX)

    jal init_level_3     # Spawns 5 MORE obstacles (Total 10)
    jal generate_apple
    j ca_ret

ca_ret:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
# ------------------------------------------------------------------------------
# Function: generate_apple 
# ------------------------------------------------------------------------------
generate_apple:
    addi $sp, $sp, -4
    sw $ra, 0($sp)        # Save Return Address

    # 1. Random X
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    sw $a0, appleX

    # 2. Random Y
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    sw $a0, appleY

    # 3. Draw
    lw $a0, appleX
    lw $a1, appleY
    li $a2, RED
    jal draw_pixel      

    lw $ra, 0($sp)        # Restore Return Address
    addi $sp, $sp, 4
    jr $ra

# ------------------------------------------------------------------------------
# Function: check_collisions (MODIFIED)
# Description: Checks Bounds, Body, AND Obstacles
# Returns: $v0 = 1 if crash, 0 if safe
# ------------------------------------------------------------------------------
check_collisions:
    # 1. Load Head
    lw $t0, snakeX
    lw $t1, snakeY

    # 2. Check Walls (Bounds)
    blt $t0, 0, cc_crash
    bge $t0, 32, cc_crash
    blt $t1, 0, cc_crash
    bge $t1, 32, cc_crash

    # 3. Check Self-Collision
    lw $t2, snakeLen
    li $t3, 1             

cc_loop:
    bge $t3, $t2, cc_obs_check # If i >= len, done body check, go to obstacles

    la $t4, snakeX
    sll $t5, $t3, 2    
    add $t4, $t4, $t5
    lw $t6, 0($t4)        

    bne $t0, $t6, cc_next # If HeadX != BodyX, check next

    la $t4, snakeY
    add $t4, $t4, $t5
    lw $t6, 0($t4)       

    beq $t1, $t6, cc_crash # If HeadY == BodyY too... CRASH!

cc_next:
    addi $t3, $t3, 1
    j cc_loop

    # 4. Check Obstacles
cc_obs_check:
    lw $t2, obstacleCnt  # How many obstacles?
    li $t3, 0            # Counter

cc_obs_loop:
    bge $t3, $t2, cc_safe

    # Load Obstacle X
    la $t4, obstacleX
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t6, 0($t4)

    bne $t0, $t6, cc_obs_next

    # Load Obstacle Y
    la $t4, obstacleY
    add $t4, $t4, $t5
    lw $t6, 0($t4)

    beq $t1, $t6, cc_crash  # HEAD HITS OBSTACLE -> Game Over

cc_obs_next:
    addi $t3, $t3, 1
    j cc_obs_loop

cc_crash:
    # Return 1 for Game Over (Caller handles printing)
    li $v0, 1            
    jr $ra

cc_safe:
    li $v0, 0           
    jr $ra

# ------------------------------------------------------------------------------
# Function: init_level_2
# Description: Spawns 5 random obstacles, ensuring they don't hit the snake
# ------------------------------------------------------------------------------
init_level_2:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Set obstacle count to 5
    li $t0, 5
    sw $t0, obstacleCnt

    li $s0, 0       # Loop counter (obstacles created)

obs_gen_loop:
    beq $s0, 5, obs_done  # If 5 created, finish

    # 1. Generate Random X
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    move $s1, $a0   # s1 = Candidate X

    # 2. Generate Random Y
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    move $s2, $a0   # s2 = Candidate Y

    # 3. SAFETY CHECK: Is this spot taken by the Snake?
    lw $t0, snakeLen
    li $t1, 0       # Body index

check_safety_loop:
    bge $t1, $t0, save_obstacle  # If safe, save it

    la $t2, snakeX
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    lw $t4, 0($t2)      # t4 = snakeX[i]

    bne $s1, $t4, check_next_seg  

    la $t2, snakeY
    add $t2, $t2, $t3
    lw $t4, 0($t2)      # t4 = snakeY[i]

    beq $s2, $t4, obs_gen_loop    # Collision! Try random gen again.

check_next_seg:
    addi $t1, $t1, 1
    j check_safety_loop

save_obstacle:
    # Store X
    la $t0, obstacleX
    sll $t1, $s0, 2     
    add $t0, $t0, $t1
    sw $s1, 0($t0)

    # Store Y
    la $t0, obstacleY
    add $t0, $t0, $t1
    sw $s2, 0($t0)

    addi $s0, $s0, 1    # Increment count
    j obs_gen_loop

obs_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ------------------------------------------------------------------------------
# Function: draw_obstacles
# ------------------------------------------------------------------------------
draw_obstacles:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, obstacleCnt # Number of obstacles
    li $t1, 0           # Counter

do_loop:
    bge $t1, $t0, do_end

    # Get X
    la $t2, obstacleX
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    lw $a0, 0($t2)

    # Get Y
    la $t2, obstacleY
    add $t2, $t2, $t3
    lw $a1, 0($t2)

    li $a2, OBSTACLE_COL  # Grey Color
    
    # Save temp regs before calling draw_pixel
    move $s0, $t0
    move $s1, $t1
    
    jal draw_pixel

    # Restore
    move $t0, $s0
    move $t1, $s1

    addi $t1, $t1, 1
    j do_loop

# Function: init_level_3
# Description: Adds 5 MORE obstacles (Total 10)
# ------------------------------------------------------------------------------
init_level_3:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Update total count to 10
    li $t0, 10
    sw $t0, obstacleCnt

    li $s0, 5       # Start loop at 5 (Keep existing 0-4 safe)

obs_gen_loop_3:
    beq $s0, 10, obs_done_3  # If 10 total created, finish

    # 1. Generate Random X
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    move $s1, $a0   # s1 = Candidate X

    # 2. Generate Random Y
    li $v0, 42
    li $a0, 0
    li $a1, 32
    syscall
    move $s2, $a0   # s2 = Candidate Y

    # 3. SAFETY CHECK A: Is this spot taken by the Snake?
    lw $t0, snakeLen
    li $t1, 0       

check_safety_snake:
    bge $t1, $t0, check_safety_obs  # Snake safe? Check obstacles next.

    la $t2, snakeX
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    lw $t4, 0($t2)      
    bne $s1, $t4, check_next_seg_3  

    la $t2, snakeY
    add $t2, $t2, $t3
    lw $t4, 0($t2)      
    beq $s2, $t4, obs_gen_loop_3    # Hit Snake! Retry.

check_next_seg_3:
    addi $t1, $t1, 1
    j check_safety_snake

    # 4. SAFETY CHECK B: Is this spot taken by an EXISTING Obstacle?
check_safety_obs:
    li $t1, 0       # Check indices 0 to s0-1

check_obs_loop:
    bge $t1, $s0, save_obstacle_3 # Safe from obstacles too! Save it.

    la $t2, obstacleX
    sll $t3, $t1, 2
    add $t2, $t2, $t3
    lw $t4, 0($t2)
    bne $s1, $t4, check_next_obs

    la $t2, obstacleY
    add $t2, $t2, $t3
    lw $t4, 0($t2)
    beq $s2, $t4, obs_gen_loop_3  # Hit existing Obstacle! Retry.

check_next_obs:
    addi $t1, $t1, 1
    j check_obs_loop

save_obstacle_3:
    # Store X
    la $t0, obstacleX
    sll $t1, $s0, 2     
    add $t0, $t0, $t1
    sw $s1, 0($t0)

    # Store Y
    la $t0, obstacleY
    add $t0, $t0, $t1
    sw $s2, 0($t0)

    addi $s0, $s0, 1    # Increment count
    j obs_gen_loop_3

obs_done_3:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


do_end:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
# ------------------------------------------------------------------------------
# [NEW] Function: print_status
# Description: Prints "Level X | Score Y" to the console
# -----------------------------------------------------------------------------
print_status:
    # Print "Level "
    li $v0, 4
    la $a0, str_lvl
    syscall

    li $v0, 1
    lw $a0, level
    syscall

    # Print " | Score "
    li $v0, 4
    la $a0, str_sep
    syscall

    li $v0, 1
    lw $a0, score
    syscall
    
    # --- NEW: Print " | HIGH SCORE " ---
    li $v0, 4
    la $a0, str_high_score
    syscall

    li $v0, 1
    lw $a0, high_score
    syscall
    # -----------------------------------

    # Print Newline
    li $v0, 4
    la $a0, str_nl
    syscall

    jr $ra
# ==============================================================================
# UPDATED VISUAL SCREENS (High Quality "SNAKE" Title)
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: show_start_screen
# Description: Draws a gradient background and "SNAKE" title with text.
# ------------------------------------------------------------------------------
show_start_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # 1. Draw gradient background
    jal draw_gradient_bg
    
    # 2. Draw "SNAKE" text (Improved Version)
    jal draw_snake_title_text
    
    # 3. Draw "PRESS S" text below
    jal draw_press_s_text

    # 4. Print Message to Console
    li $v0, 4
    la $a0, str_start
    syscall

    # 5. Wait for 's' Key
ss_simple_wait:
    li $t0, ADDR_KBRD
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, ss_simple_wait

    li $t0, ADDR_KEY
    lw $t1, 0($t0)
    bne $t1, 's', ss_simple_wait

    # 6. Clear screen before playing
    jal clear_screen
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ------------------------------------------------------------------------------
# Function: show_game_over_screen
# Description: Red Flash effect, shows "GAME OVER" text, waits for Restart.
# ------------------------------------------------------------------------------
show_game_over_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # 1. Flash Effect (Fade from Black to Red)
    li $s7, 0
gos_flash:
    li $t0, ADDR_DSPL
    li $t1, 1024
    
    sll $t2, $s7, 16
    andi $t2, $t2, 0x00ff0000
    
gos_fill:
    sw $t2, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bnez $t1, gos_fill
    
    addi $s7, $s7, 32
    blt $s7, 256, gos_flash
    
    # 2. Draw "GAME OVER" text (Shows "OUCH")
    jal draw_game_over_text_pixels
    
    jal save_high_score
    
    # 3. Console Messages
    li $v0, 4
    la $a0, str_game_over
    syscall
    
    jal print_status
    
    li $v0, 4
    la $a0, str_replay
    syscall

    # 4. Wait for 'r' or 'e'
gos_wait:
    li $t0, ADDR_KBRD
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, gos_wait

    li $t0, ADDR_KEY
    lw $t1, 0($t0)
    
    beq $t1, 'e', gos_exit
    beq $t1, 'r', reset_game_data
    
    j gos_wait

gos_exit:
    li $v0, 10
    syscall

# ------------------------------------------------------------------------------
# Function: reset_game_data
# Description: Resets variables to game defaults.
# ------------------------------------------------------------------------------
reset_game_data:
    li $t0, 1
    sw $t0, level
    
    li $t0, 0
    sw $t0, score
    sw $t0, apples_eaten
    sw $t0, obstacleCnt
    
    li $t0, 5
    sw $t0, snakeLen
    
    li $t0, 'd'
    sw $t0, snakeDir
    
    la $t0, snakeX
    li $t1, 10
    sw $t1, 0($t0)
    li $t1, 9
    sw $t1, 4($t0)
    li $t1, 8
    sw $t1, 8($t0)
    li $t1, 7
    sw $t1, 12($t0)
    li $t1, 6
    sw $t1, 16($t0)
    
    la $t0, snakeY
    li $t1, 10
    sw $t1, 0($t0)
    sw $t1, 4($t0)
    sw $t1, 8($t0)
    sw $t1, 12($t0)
    sw $t1, 16($t0)

    j main

# ==============================================================================
# TEXT DRAWING FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: draw_gradient_bg
# ------------------------------------------------------------------------------
draw_gradient_bg:
    li $t0, ADDR_DSPL
    li $t1, 0
    
dgb_row_loop:
    sll $t2, $t1, 11
    addiu $t2, $t2, 0x00001122
    
    li $t3, 0
    
dgb_col_loop:
    sw $t2, 0($t0)
    addi $t0, $t0, 4
    addi $t3, $t3, 1
    blt $t3, 32, dgb_col_loop
    
    addi $t1, $t1, 1
    blt $t1, 32, dgb_row_loop
    
    jr $ra

# ------------------------------------------------------------------------------
# Function: draw_snake_title_text
# Description: Draws "SNAKE" with a diagonal 'N' and a Green Snake Underline
# ------------------------------------------------------------------------------
draw_snake_title_text:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    
    # Base Y position for text
    li $s1, 8            # Y = 8 
    li $a2, 0x00ffff00   # Yellow Text

    # --- LETTER S (x=6) ---
    # Top
    li $a0, 6
    move $a1, $s1
    li $s0, 3
dst_s1: jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dst_s1
    # Left Top
    li $a0, 6
    move $a1, $s1
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    # Mid
    li $a0, 6
    move $a1, $s1
    addi $a1, $a1, 2
    li $s0, 3
dst_s2: jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dst_s2
    # Right Bot
    li $a0, 8
    move $a1, $s1
    addi $a1, $a1, 2
    jal draw_pixel
    addi $a1, $a1, 1
    jal draw_pixel
    # Bot
    li $a0, 6
    move $a1, $s1
    addi $a1, $a1, 4
    li $s0, 3
dst_s3: jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dst_s3

    # --- LETTER N (x=10) [IMPROVED DIAGONAL] ---
    # Left Column
    li $a0, 10
    move $a1, $s1
    li $s0, 5
dst_n1: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_n1
    # Right Column
    li $a0, 12
    move $a1, $s1
    li $s0, 5
dst_n2: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_n2
    # The Diagonal Connection
    li $a0, 11
    move $a1, $s1
    addi $a1, $a1, 1   # Pixel at (11, Y+1)
    jal draw_pixel
    addi $a1, $a1, 1   # Pixel at (11, Y+2)
    jal draw_pixel

    # --- LETTER A (x=14) ---
    # Left Col
    li $a0, 14
    move $a1, $s1
    addi $a1, $a1, 1   
    li $s0, 4
dst_a1: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_a1
    # Right Col
    li $a0, 16
    move $a1, $s1
    addi $a1, $a1, 1
    li $s0, 4
dst_a2: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_a2
    # Top
    li $a0, 15
    move $a1, $s1
    jal draw_pixel
    # Mid
    li $a0, 15
    move $a1, $s1
    addi $a1, $a1, 2
    jal draw_pixel

    # --- LETTER K (x=18) ---
    # Left Col
    li $a0, 18
    move $a1, $s1
    li $s0, 5
dst_k1: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_k1
    # Diagonal Top
    li $a0, 20
    move $a1, $s1
    jal draw_pixel
    li $a0, 19
    addi $a1, $a1, 1
    jal draw_pixel
    li $a0, 19
    addi $a1, $a1, 1   # Center
    jal draw_pixel
    # Diagonal Bot
    li $a0, 19
    addi $a1, $a1, 1
    jal draw_pixel
    li $a0, 20
    addi $a1, $a1, 1
    jal draw_pixel

    # --- LETTER E (x=22) ---
    # Left Col
    li $a0, 22
    move $a1, $s1
    li $s0, 5
dst_e1: jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dst_e1
    # Top
    li $a0, 23
    move $a1, $s1
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel
    # Mid
    li $a0, 23
    move $a1, $s1
    addi $a1, $a1, 2
    jal draw_pixel
    # Bot
    li $a0, 23
    move $a1, $s1
    addi $a1, $a1, 4
    jal draw_pixel
    addi $a0, $a0, 1
    jal draw_pixel

    # ==========================================
    # DECORATION: GREEN SNAKE UNDERLINE
    # ==========================================
    
    # Draw Green Line below text
    li $a2, GREEN
    li $a0, 5           # Start X
    move $a1, $s1
    addi $a1, $a1, 6    # 6 pixels below text top (Y=14)
    li $s0, 21          # Length of line
dst_line: 
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dst_line

    # Draw "Head" pixel raised up at the end
    li $a0, 26
    move $a1, $s1
    addi $a1, $a1, 5
    jal draw_pixel

    # Draw Red Tongue
    li $a2, RED
    li $a0, 27
    move $a1, $s1
    addi $a1, $a1, 5
    jal draw_pixel

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# ------------------------------------------------------------------------------
# Function: draw_press_s_text
# Description: Draws "PRESS S" below title
# ------------------------------------------------------------------------------
draw_press_s_text:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    
    li $a2, 0x00ffffff    # White
    
    # P (x=9)
    li $a0, 9
    li $a1, 18
    li $s0, 4
dps_p_left:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dps_p_left
    li $a0, 10
    li $a1, 18
    jal draw_pixel
    li $a0, 10
    li $a1, 19
    jal draw_pixel
    li $a0, 9
    li $a1, 19
    jal draw_pixel
    
    # R (x=12)
    li $a0, 12
    li $a1, 18
    li $s0, 4
dps_r_left:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dps_r_left
    li $a0, 13
    li $a1, 18
    jal draw_pixel
    li $a1, 19
    jal draw_pixel
    li $a0, 13
    li $a1, 20
    jal draw_pixel
    
    # S (x=15)
    li $a0, 15
    li $a1, 18
    li $s0, 2
dps_s_top:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dps_s_top
    li $a0, 15
    li $a1, 19
    jal draw_pixel
    li $a0, 16
    jal draw_pixel
    li $a0, 15
    li $a1, 20
    li $s0, 2
dps_s_bot:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dps_s_bot
    
    # S (x=18)
    li $a0, 18
    li $a1, 18
    li $s0, 2
dps_s2_top:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dps_s2_top
    li $a0, 18
    li $a1, 19
    jal draw_pixel
    li $a0, 19
    jal draw_pixel
    li $a0, 18
    li $a1, 20
    li $s0, 2
dps_s2_bot:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dps_s2_bot
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ------------------------------------------------------------------------------
# Function: draw_game_over_text_pixels
# Description: Draws "OUCH" in pixel art
# ------------------------------------------------------------------------------
draw_game_over_text_pixels:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    
    li $a2, BLACK         # Black text on red
    
    # O (x=7, y=13)
    li $a0, 7
    li $a1, 13
    li $s0, 3
dgo_o_top:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_o_top
    
    li $a0, 7
    li $a1, 14
    jal draw_pixel
    li $a1, 15
    jal draw_pixel
    
    li $a0, 9
    li $a1, 14
    jal draw_pixel
    li $a1, 15
    jal draw_pixel
    
    li $a0, 7
    li $a1, 16
    li $s0, 3
dgo_o_bot:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_o_bot
    
    # U (x=11, y=13)
    li $a0, 11
    li $a1, 13
    li $s0, 4
dgo_u_left:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_u_left
    
    li $a0, 13
    li $a1, 13
    li $s0, 4
dgo_u_right:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_u_right
    
    li $a0, 12
    li $a1, 16
    jal draw_pixel
    
    # C (x=15, y=13)
    li $a0, 15
    li $a1, 13
    li $s0, 3
dgo_c_top:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_c_top
    
    li $a0, 15
    li $a1, 14
    jal draw_pixel
    li $a1, 15
    jal draw_pixel
    
    li $a0, 15
    li $a1, 16
    li $s0, 3
dgo_c_bot:
    jal draw_pixel
    addi $a0, $a0, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_c_bot
    
    # H (x=19, y=13)
    li $a0, 19
    li $a1, 13
    li $s0, 4
dgo_h_left:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_h_left
    
    li $a0, 21
    li $a1, 13
    li $s0, 4
dgo_h_right:
    jal draw_pixel
    addi $a1, $a1, 1
    addi $s0, $s0, -1
    bnez $s0, dgo_h_right
    
    li $a0, 20
    li $a1, 14
    jal draw_pixel
    li $a1, 15
    jal draw_pixel
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra
# ------------------------------------------------------------------------------
# Function: load_high_score
# ------------------------------------------------------------------------------
load_high_score:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Open file for reading
    li $v0, 13
    la $a0, file_name
    li $a1, 0            # Read mode
    li $a2, 0
    syscall
    move $s0, $v0
    
    # If file doesn't exist, skip
    bltz $s0, lhs_skip
    
    # Read 4 bytes
    li $v0, 14
    move $a0, $s0
    la $a1, high_score
    li $a2, 4
    syscall
    
    # Close file
    li $v0, 16
    move $a0, $s0
    syscall
    
lhs_skip:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
# ------------------------------------------------------------------------------
# Function: save_high_score
# ------------------------------------------------------------------------------
save_high_score:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    
    # 1. Compare scores
    lw $t0, score
    lw $t1, high_score
    ble $t0, $t1, shs_skip   # If Score <= High Score, do nothing
    
    # 2. Update RAM variable
    sw $t0, high_score
    
    # 3. Print "New Record" Message
    li $v0, 4
    la $a0, str_new_record
    syscall
    
    # 4. Open file (Force Create)
    li $v0, 13
    la $a0, file_name        # MUST BE: "C:/snake_game/highscore.txt"
    li $a1, 1                # 1 = Write Only (Create if missing, Truncate if exists)
    li $a2, 511              # 511 is 0777 in Octal (Full RWX Permissions)
    syscall
    move $s0, $v0            # Save File Descriptor
    
    # --- DEBUGGING OUTPUT ---
    li $v0, 4
    la $a0, str_debug_fd
    syscall
    
    li $v0, 1
    move $a0, $s0
    syscall
    
    li $v0, 4
    la $a0, str_newline
    syscall
    # ------------------------

    # 5. Check if Open Failed (-1)
    bltz $s0, shs_error      # Jump to error if -1
    
    # 6. Write to file
    li $v0, 15
    move $a0, $s0            # Use FD
    la $a1, high_score       # Address of data
    li $a2, 4                # Length (4 bytes)
    syscall
    
    # 7. Close file
    li $v0, 16
    move $a0, $s0
    syscall
    
    # 8. Success Message
    li $v0, 4
    la $a0, str_success
    syscall
    
    j shs_skip

shs_error:
    li $v0, 4
    la $a0, str_file_error
    syscall

shs_skip:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra
    