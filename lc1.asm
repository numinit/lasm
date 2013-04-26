;;; MSP430: LC-1 Emulator
;;; Morgan Jones and Alex Sokolyk

;;; ======== REGISTER CONVENTIONS ========

;;; ---- MSP430 ----
;;; r0 - MSP430 PC
;;; r1 - MSP430 SP
;;; r2 - MSP430 SR
;;; r3 - MSP430 CG

;;; ---- LC-1 ----
;;; r4 - LC-1 PC  (global)
;;; r5 - LC-1 SP  (global)
;;; r6 - LC-1 ACC (global)
;;; r7 - LC-1 IR  (global)
;;; r8 - LC-1 MAR (global)
;;; r15 - LC-1 CR (global)

;;; --- Emulation ----
;;; r9 - Temporary storage             (not saved)
;;; r10 - 16-bit function argument     (saved/restored)
;;; r11 - 16-bit function return value (saved/restored)

    .cdecls C, LIST, "msp430.h"

  	;; The LC-1's program counter.
    .asg r4, LC1_PC

  	;; The LC-1's stack pointer.
    .asg r5, LC1_SP

  	;; The LC-1's accumulator.
    .asg r6, LC1_ACC

  	;; The LC-1's instruction register.
    .asg r7, LC1_IR

  	;; The LC-1's memory address register.
    .asg r8, LC1_MAR

  	;; A register functioning as a 16-bit temporary value.
    .asg r9, LC1_TMP_REG

  	;; A register functioning as a 16-bit function argument.
    .asg r10, LC1_FUNC_ARG

  	;; A register functioning as a 16-bit return value.
    .asg r11, LC1_FUNC_RET

  	;; The LC-1's conditional register.
    .asg r15, LC1_CR

	;; Bitmasks
    .asg 0x1fff, LC1_MAR_MASK
    .asg 0x000e, LC1_OPCODE_MASK

    ;; Offset for memory access
    .asg 0x1400, LC1_RAM_OFFSET

	;; Beginning and ending addresses for program code
    .asg 0x2400, LC1_PROG_CODE_BEGIN
    .asg 0xfb00, LC1_PROG_FLASH_BEGIN
    .asg 0x24fe, LC1_PROG_CODE_END

	;; Beginning and ending addresses for trap code
    .asg 0x2500, LC1_TRAP_CODE_BEGIN
    .asg 0xfc00, LC1_TRAP_FLASH_BEGIN
    .asg 0x27fe, LC1_TRAP_CODE_END

	;; Stack pointer bounds
    .asg 0x2900, LC1_STACK_BEGIN
    .asg 0x2930, LC1_STACK_END

	;; Panic conditions
    .asg 0x0000, LC1_PANIC_STOP
    .asg 0x0001, LC1_PANIC_ILLEGAL
    .asg 0x0002, LC1_PANIC_STACK_OVERFLOW
    .asg 0x0003, LC1_PANIC_STACK_UNDERFLOW
    .asg 0x0004, LC1_PANIC_BUS_ERROR

    .text 	                        ; Stick the remaining code in the .text section
    .retain                         ; Override ELF conditional linking and retain current section
    .retainrefs                     ; Additionally, retain any sections that have references to current section

;;; ======== RESET ========
RESET
            mov.w   #__STACK_END, SP		     ; Initialize the stack pointer
	        mov.w   #(WDTPW | WDTHOLD), &WDTCTL  ; Stop WDT
	        mov.b	#0x00, &P9DIR	             ; setup P9.4-P9.7 as input
	       	mov.b	#0x0f, &P4DIR 	             ; setup P4.0-P4.3 as output
	       	mov.b   #0x0f, &P3DIR 	        	 ; setup P3.0-P3.3 as output

	        call 	#LC1_INIT					 ; Initialize the state machine
	        jmp		LC1_FETCH					 ; Jump to FETCH

LC1_INIT
	        mov.w   #LC1_PROG_CODE_BEGIN, LC1_PC ; R4 is the PC
	        mov.w   #LC1_STACK_BEGIN, LC1_SP     ; R5 is the SP
	        mov.w   #0, LC1_ACC                  ; R6 is the ACC
	        mov.w   #0, LC1_CR                   ; R15 is the CR

	        mov.b	#0x0f, &P4OUT 	             ; clear the first display
			mov.b   #0x0f, &P3OUT 	        	 ; clear the second display

;;; ======== COPY ========
LC1_COPY
            mov.w #LC1_PROG_FLASH_BEGIN, r7		 ; get beginning of code in flash
            mov.w #LC1_PROG_CODE_BEGIN, r8		 ; get beginning of code in RAM
            mov.w #LC1_TRAP_CODE_END, r9		 ; also get the end of traps
LC1_COPY_LOOP
            mov.w @r7+, r10						 ; get value at the address of r7, and increment it
            mov.w r10, 0(r8)				 	 ; move that value into the memory at the address of r8
            incd.w r8							 ; increment r8
            cmp r8, r9							 ; r9 - r8
            jge LC1_COPY_LOOP					 ; PC = (r9 - r8 >= 0 ? LC1_COPY_LOOP : PC + 2)
            ret

;;; ======== FETCH ========
LC1_FETCH
            mov.w @LC1_PC+, LC1_IR                      ; Fetch an instruction and post-increment the PC

;;; ======== DECODE ========
LC1_DECODE_IMMEDIATE
            mov.w #LC1_MAR_MASK, LC1_MAR                ; 0x1fff = 0001 1111 1111 1111 (low 13 bits, address)
            and.w LC1_IR, LC1_MAR                       ; The MAR now stores the address, without the offset.
            rlc.w LC1_IR                                ; Time for a trick. Shift the instruction register LEFT through carry.
            rlc.w LC1_IR                                ; Why left? Well, we have to test bit 12, right?
            rlc.w LC1_IR                                ; If we shift it four times... the carry bit will store bit 12 of the immediate value...
            rlc.w LC1_IR                                ; and the lowest 3 bits will have the opcode.
            jnc   LC1_DECODE_OPCODE                     ; If the carry is cleared, we don't need to offset it.
            add.w #LC1_RAM_OFFSET, LC1_MAR              ; Otherwise, add the RAM offset to the MAR.
LC1_DECODE_OPCODE
			rla.w LC1_IR								; Align the pointer to 2 bytes
            and.w #LC1_OPCODE_MASK, LC1_IR              ; 0x0007 = 0000 0000 0000 1110 (low 3 bits, opcode offset)

;;; ======== VERIFY (extra step) ========
LC1_VERIFY_ALIGNMENT
			cmp.w #0xc, LC1_IR 							; If this isn't a trap, verify that we're accessing even memory addresses only
			jeq LC1_EXECUTE
			mov.w #1, LC1_TMP_REG						; AND the MAR with 1, and verify that it's 0
			and.w LC1_MAR, LC1_TMP_REG
			jz LC1_EXECUTE
LC1_VERIFY_ALIGNMENT_PANIC
			push LC1_FUNC_ARG							; Misaligned memory address. Don't let this crash the host processor.
			mov.w #LC1_PANIC_BUS_ERROR, LC1_FUNC_ARG	; Panic reason: Bus error
			call #LC1_PANIC
			pop LC1_FUNC_ARG
			br #LC1_FETCH

;;; ======== EXECUTE ========
LC1_EXECUTE
            call LC1_INSTRUCTIONS(LC1_IR)               ; Indirect call to the instruction at LC1_INSTRUCTIONS + IR
            br #LC1_FETCH								; Back to Fetch

;;; ======== LC-1 Call ========
LC1_CALL
            push LC1_FUNC_ARG							; Push the function argument
            mov.w LC1_PC, LC1_FUNC_ARG					; Store the PC into it
            call #LC1_SPUSH								; Push the PC onto the stack
            mov.w LC1_MAR, LC1_PC						; MAR => PC
            pop LC1_FUNC_ARG							; Pop the function argument
            ret

;;; ======== LC-1 Return ========
LC1_RET
            call #LC1_SPOP								; Pop the stack into LC1_FUNC_RET
            mov.w LC1_FUNC_RET, LC1_PC					; LC1_FUNC_RET => PC
            ret

;;; ======== LC-1 Branch ========
LC1_BR
            tst LC1_CR									; Test condition register
            jz LC1_BR_OUT								; Bail out if it's zero
            mov.w LC1_MAR, LC1_PC						; Otherwise, MAR => PC
LC1_BR_OUT
            ret

;;; ======== LC-1 Add ========
LC1_ADD
            mov.w @LC1_MAR, LC1_TMP_REG 				; Take the memory at MAR and store it into TMP_REG
            add.w LC1_TMP_REG, LC1_ACC  				; Add TMP_REG to the accumulator
            jn LC1_ADD_NEGATIVE         				; If it's negative, set the negative flag
            ret
LC1_ADD_NEGATIVE
            mov.w #1, LC1_CR
            ret

;;; ======== LC-1 Load ========
LC1_LD
			mov.w @LC1_MAR, LC1_ACC     				; Take the memory at MAR and store it into ACC
            tst LC1_ACC                 				; Test ACC
            jn LC1_LD_NEGATIVE          				; If it's negative, set the negative flag
            ret
LC1_LD_NEGATIVE
            mov.w #1, LC1_CR
            ret

;;; ======== LC-1 Store ========
LC1_ST
			mov.w LC1_ACC, 0(LC1_MAR)  				; Move the accumulator into the address pointed to by MAR
            ret

;;; ======== LC-1 Trap ========
LC1_TRAP
            rla.w LC1_MAR								; Align the trap to a 2-byte boundary
			and.w #0x01fe, LC1_MAR						; Truncate traps to 8 bits only (and set flags)
            jz LC1_TRAP_STOP							; Get the special case of STOP
            mov.w LC1_TRAP_VECTORS(LC1_MAR), LC1_MAR	; Get the trap vector address
            call #LC1_CALL								; Call the trap (push PC and jump to vector)
            ret
LC1_TRAP_STOP
            push LC1_FUNC_ARG							; Push the function argument
            mov.w #LC1_PANIC_STOP, LC1_FUNC_ARG			; Panic reason: STOP
            call #LC1_PANIC								; Actually panic
            pop LC1_FUNC_ARG							; Pop the function argument
            ret

;;; ======== LC-1 Illegal Opcode ========
LC1_ILLEGAL
            push LC1_FUNC_ARG
            mov.w #LC1_PANIC_ILLEGAL, LC1_FUNC_ARG
            call #LC1_PANIC
            pop LC1_FUNC_ARG
            ret

;;; ======== LC-1 Panic ========
;;; This function is called when the emulator encounters an illegal condition and cannot continue.
LC1_PANIC
            mov.b #0x0f, &P4OUT				; Clear the first display
            mov.b LC1_FUNC_ARG, &P3OUT      ; Output the panic reason to the second display
            bis.w #LPM3, SR	            	; Enable Low Power Mode, and wait for an interrupt
            call #LC1_INIT					; Reinitialize the state machine
            ret								; Continue the instruction cycle

;;; ======== LC-1 Stack Push ========
;;; Pushes the value stored in R9 onto the LC-1's stack, detecting a stack overflow.
LC1_SPUSH
            mov.w #LC1_STACK_END, LC1_TMP_REG
            cmp.w LC1_SP, LC1_TMP_REG
            jge LC1_SPUSH_COMMIT

            push LC1_FUNC_ARG
            mov.w #LC1_PANIC_STACK_OVERFLOW, LC1_FUNC_ARG
            call #LC1_PANIC
            pop LC1_FUNC_ARG
            ret

LC1_SPUSH_COMMIT
            ;; Commit the stack changes.
            mov.w LC1_FUNC_ARG, 0(LC1_SP)
            incd.w LC1_SP
            ret

;;; ======== LC-1 Stack Pop ========
;;; Pops the top value from the LC-1's stack into R9, detecting a stack underflow.
LC1_SPOP
            mov.w #LC1_STACK_BEGIN, LC1_TMP_REG
            cmp.w LC1_SP, LC1_TMP_REG
            jl  LC1_SPOP_COMMIT

            ;; Panic: emulator stack underflow!
            push LC1_FUNC_ARG
            mov.w #LC1_PANIC_STACK_UNDERFLOW, LC1_FUNC_ARG
            call #LC1_PANIC
            pop LC1_FUNC_ARG
            ret

LC1_SPOP_COMMIT
            ;; Commit the stack changes
            decd.w LC1_SP
            mov.w  @LC1_SP, LC1_FUNC_RET
            ret

;;; ======== LC-1 Instructions ========
;;; This is simply a table of pointers to functions.
;;; One of these pointers is called during the Execute phase of the instruction cycle.
LC1_INSTRUCTIONS
            .word LC1_CALL
            .word LC1_RET
            .word LC1_ADD
            .word LC1_BR
            .word LC1_LD
            .word LC1_ST
            .word LC1_TRAP
            .word LC1_ILLEGAL

;;; ======== LC-1 Traps ========
LC1_TRAP_VECTORS
			.word 0xffff 	; Bad trap
			.word 0x2700	; GETC
			.word 0x2750	; OUTC
			.word 0x2670	; RR
			.word 0x2500	; NOT
			.word 0x254e	; AND
			.word 0x2600	; LDR

; -------------------------------------------------------------------------------
;;; LC1 Code Section
; -------------------------------------------------------------------------------
	.sect ".LC1_Code"   ; LC1 code (0xFB00, 0x2400)
    .retain             ; Override ELF conditional linking
                        ; and retain current section
    .retainrefs         ; Additionally retain any sections
                        ; that have references to current
                        ; section
			.word    0xc001      ; 0x2400 [1100000000000001] [lc3_echo] trap %getc
			.word    0xc002      ; 0x2402 [1100000000000010] trap %outc
			.word    0x9008      ; 0x2404 [1001000000001000] ld &negative
			.word    0x7000      ; 0x2406 [0111000000000000] br &lc3_echo
			.word    0xffff      ; 0x2408 [1111111111111111] [negative] fill 0xffff

; -------------------------------------------------------------------------------
;;; LC1 Trap Section
; -------------------------------------------------------------------------------
    .sect .NOT_Trap     ; LC-1 NOT trap (0xFC00, 0x2500)
	.retain             ; Override ELF conditional linking
                        ; and retain current section
    .retainrefs         ; Additionally retain any sections
                        ; that have references to current
                        ; section
LC1_NOT_TRAP
			.word    0B400h     ;    Store ACC to 2800
			.word    913Eh      ;    Load 0
			.word    0B402h     ;    Sto 0 to bit not 2802
			.word    913Ch      ;    Load 1
			.word    0B404h     ;    Store 1 bound
			.word    9400h      ;    loading num
			.word    7114h      ;    branch if negative to inc loop remember it's in flash

			.word    9402h      ;    load bitnot
			.word    513Ch      ;    add 1 from flash (the first bit is 0, so not gives a one)
			.word    0B402h     ;    store bitnot

			.word    9404h      ;    Load Bound
			.word    712Ch      ;    branch to end
			.word    5404h      ;    add bound (increment by double)
			.word    0B404h     ;    store bound
			.word    9402h      ;    load bitnot
			.word    5402h      ;    add bitnot to itself (increment by double)
			.word    0B402h     ;    store to memory
			.word    9400h      ;    load num
			.word    5400h      ;    add num (now look at the second bit from the left, move to the left by double)
			.word    0B400h     ;    store num (move from accumulator to 260h)
			.word    913Ah      ;    load neg (set the condition bit)
			.word    710Ah      ;    Branch to loop

			.word    9402h      ;    load bitnot
			.word    2000h      ;	 return
			.word    0h         ;    wasted space
			.word    0h         ;    wasted space
			.word    0h         ;    wasted space
			.word    0h         ;    wasted space
			.word    0h         ;    wasted space
			.word    0FFFFh     ;    negative
			.word    1h         ;    constant 1
			.word    0h         ;    constant 0

; -------------------------------------------------------------------------------
	.sect .AND_Trap     ; LC1 AND Trap (0xFC4E, 0x254e)
	.retain             ; Override ELF conditional linking
                        ; and retain current section
    .retainrefs         ; Additionally retain any sections
                        ; that have references to current
                        ; section
; -------------------------------------------------------------------------------
;;; Computes a bitwise AND between the two consecutive addresses,
;;; with the first pointed to by the accumulator, and then stores that value back to the accumulator.
;;; Uses trap RAM locations 0x2800 (arg 0), 0x2802 (arg 1), 0x2804 (result), and 0x2806 (counter)
; -------------------------------------------------------------------------------
LC1_AND_TRAP
			.word    0xb406      ; 0x254e [1011010000000110] [lc1_and_trap] st !6
			.word    0xc006      ; 0x2550 [1100000000000110] trap %ldr
			.word    0xb400      ; 0x2552 [1011010000000000] st !0
			.word    0x9406      ; 0x2554 [1001010000000110] ld !6
			.word    0x51a4      ; 0x2556 [0101000110100100] add &one
			.word    0x51a4      ; 0x2558 [0101000110100100] add &one
			.word    0xc006      ; 0x255a [1100000000000110] trap %ldr
			.word    0xb402      ; 0x255c [1011010000000010] st !2
			.word    0x91a2      ; 0x255e [1001000110100010] ld &zero
			.word    0xb404      ; 0x2560 [1011010000000100] st !4
			.word    0x91a6      ; 0x2562 [1001000110100110] ld &n16
			.word    0xb406      ; 0x2564 [1011010000000110] st !6
			.word    0x9406      ; 0x2566 [1001010000000110] [loop] ld !6
			.word    0x716e      ; 0x2568 [0111000101101110] br &increment
			.word    0x9404      ; 0x256a [1001010000000100] ld !4
			.word    0x2000      ; 0x256c [0010000000000000] ret
			.word    0x51a4      ; 0x256e [0101000110100100] [increment] add &one
			.word    0xb406      ; 0x2570 [1011010000000110] st !6
			.word    0x9400      ; 0x2572 [1001010000000000] [test_a] ld !0
			.word    0x717a      ; 0x2574 [0111000101111010] br &test_b
			.word    0x118c      ; 0x2576 [0001000110001100] call &shift
			.word    0x7166      ; 0x2578 [0111000101100110] br &loop
			.word    0x9402      ; 0x257a [1001010000000010] [test_b] ld !2
			.word    0x7182      ; 0x257c [0111000110000010] br &next
			.word    0x118c      ; 0x257e [0001000110001100] call &shift
			.word    0x7166      ; 0x2580 [0111000101100110] br &loop
			.word    0x9404      ; 0x2582 [1001010000000100] [next] ld !4
			.word    0x51a4      ; 0x2584 [0101000110100100] add &one
			.word    0xb404      ; 0x2586 [1011010000000100] st !4
			.word    0x118c      ; 0x2588 [0001000110001100] call &shift
			.word    0x7166      ; 0x258a [0111000101100110] br &loop
			.word    0x9400      ; 0x258c [1001010000000000] [shift] ld !0
			.word    0x5400      ; 0x258e [0101010000000000] add !0
			.word    0xb400      ; 0x2590 [1011010000000000] st !0
			.word    0x9402      ; 0x2592 [1001010000000010] ld !2
			.word    0x5402      ; 0x2594 [0101010000000010] add !2
			.word    0xb402      ; 0x2596 [1011010000000010] st !2
			.word    0x9404      ; 0x2598 [1001010000000100] ld !4
			.word    0x5404      ; 0x259a [0101010000000100] add !4
			.word    0xb404      ; 0x259c [1011010000000100] st !4
			.word    0x91a6      ; 0x259e [1001000110100110] ld &n16
			.word    0x2000      ; 0x25a0 [0010000000000000] ret
			.word    0x0000      ; 0x25a2 [0000000000000000] [zero] fill 0x0000
			.word    0x0001      ; 0x25a4 [0000000000000001] [one] fill 0x0001
			.word    0xfff0      ; 0x25a6 [1111111111110000] [n16] fill 0xfff0

; -------------------------------------------------------------------------------
	.sect .LDR_Trap     ; LC1 LDR Trap (0xFD00, 0x2600)
	.retain             ; Override ELF conditional linking
                        ; and retain current section
    .retainrefs         ; Additionally retain any sections
                        ; that have references to current
                        ; section
; -------------------------------------------------------------------------------
;;; An indirect load, loads the data pointed to by the address specified in the LC-1 accumulator
;;; Uses trap RAM locations 0x280e and 0x2810 to store the self modified code.
; -------------------------------------------------------------------------------
LC1_LDR_TRAP
			.word    0x520e      ; 0x2600 [0101001000001110] [lc1_ldr_trap] add &load
			.word    0xb40e      ; 0x2602 [1011010000001110] st !0x0e
			.word    0x920c      ; 0x2604 [1001001000001100] ld &return
			.word    0xb410      ; 0x2606 [1011010000010000] st !0x10
			.word    0x9210      ; 0x2608 [1001001000010000] ld &negative
			.word    0x740e      ; 0x260a [0111010000001110] br !0x0e
			.word    0x2000      ; 0x260c [0010000000000000] [return] ret
			.word    0x8000      ; 0x260e [1000000000000000] [load] ld 0x0000
			.word    0xffff      ; 0x2610 [1111111111111111] [negative] fill 0xffff

; -------------------------------------------------------------------------------
	.sect .RR_Trap       ; LC1 RR Trap (0xFD70, 0x2670)
	.retain              ; Override ELF conditional linking
                         ; and retain current section
    .retainrefs          ; Additionally retain any sections
                         ; that have references to current
                         ; section
; -------------------------------------------------------------------------------
;;; Written for us, this trap rotates the value in the accumulator one bit right.
;;; Uses trap RAM locations 0x2800 and 0x2802.
; -------------------------------------------------------------------------------
LC1_RR_TRAP
			.word 0B400h	; Store number
			.word 928Eh		; Load 0
			.word 0B402h	; store zero to count

			.word 9400h		; load number

			.word 5290h		; Subtract 2
			.word 7288h		; Branch exit
			.word 0B400h	; Store number
			.word 9402h		; Load count
			.word 528Ch		; add one to count
			.word 0B402h	; Store count
			.word 9290h		; Load a negative number
			.word 7276h		; branch to loop

			.word 9402h		; Load count

			.word 2000h		; return
			.word 1h		;
			.word 0h		; Zero
			.word 0FFFEh	; Negative 2

; -------------------------------------------------------------------------------
	.sect .GETc_Trap     ; LC1 Getc Trap (0xFE00, 0x2700)
	.retain              ; Override ELF conditional linking
                         ; and retain current section
    .retainrefs          ; Additionally retain any sections
                         ; that have references to current
                         ; section
; -------------------------------------------------------------------------------
; Read in the input switches from the IO board: read address 0x0280.
; Uses trap ram locations 0x280a (first operand for AND trap) and 0x280C (second operand for AND trap)
; -------------------------------------------------------------------------------
LC1_GETC_TRAP
			.word    0x9318      ; 0x2700 [1001001100011000] [lc1_getc_trap] ld &mask_val
			.word    0xb40a      ; 0x2702 [1011010000001010] st !0xa
			.word    0x8280      ; 0x2704 [1000001010000000] ld @0x0280
			.word    0xc004      ; 0x2706 [1100000000000100] trap %not
			.word    0xc003      ; 0x2708 [1100000000000011] trap %rr
			.word    0xc003      ; 0x270a [1100000000000011] trap %rr
			.word    0xc003      ; 0x270c [1100000000000011] trap %rr
			.word    0xc003      ; 0x270e [1100000000000011] trap %rr
			.word    0xb40c      ; 0x2710 [1011010000001100] st !0xc
			.word    0x931a      ; 0x2712 [1001001100011010] ld &and_addr
			.word    0xc005      ; 0x2714 [1100000000000101] trap %and
			.word    0x2000      ; 0x2716 [0010000000000000] ret
			.word    0x000f      ; 0x2718 [0000000000001111] [mask_val] fill 0x000f
			.word    0x140a      ; 0x271a [0001010000001010] [and_addr] fill !0xa

; -------------------------------------------------------------------------------
    .sect .OUTc_Trap     ; LC1 Out Trap (0xFE50, 0x2750)
	.retain              ; Override ELF conditional linking
                         ; and retain current section
    .retainrefs          ; Additionally retain any sections
                         ; that have references to current
                         ; section
; -------------------------------------------------------------------------------
; Save the accumulator to the LED display.
; Uses trap ram locations 0x2808 (scratch), 0x280a (AND argument 1), and 0x280c (AND argument 2)
; -------------------------------------------------------------------------------
LC1_OUTC_TRAP
			.word    0x5408      ; 0x2750 [0101010000001000] [lc1_outc_trap] add !8
			.word    0x5408      ; 0x2752 [0101010000001000] add !8
			.word    0x5408      ; 0x2754 [0101010000001000] add !8
			.word    0x5408      ; 0x2756 [0101010000001000] add !8
			.word    0x5408      ; 0x2758 [0101010000001000] add !8
			.word    0x5408      ; 0x275a [0101010000001000] add !8
			.word    0x5408      ; 0x275c [0101010000001000] add !8
			.word    0x5408      ; 0x275e [0101010000001000] add !8
			.word    0xb408      ; 0x2760 [1011010000001000] st !8
			.word    0x8222      ; 0x2762 [1000001000100010] ld @0x0222
			.word    0xb40a      ; 0x2764 [1011010000001010] st !0xa
			.word    0x9374      ; 0x2766 [1001001101110100] ld &mask
			.word    0xb40c      ; 0x2768 [1011010000001100] st !0xc
			.word    0x9376      ; 0x276a [1001001101110110] ld &addr
			.word    0xc005      ; 0x276c [1100000000000101] trap %and
			.word    0x5408      ; 0x276e [0101010000001000] add !8
			.word    0xa222      ; 0x2770 [1010001000100010] st @0x0222
			.word    0x2000      ; 0x2772 [0010000000000000] ret
			.word    0x00ff      ; 0x2774 [0000000011111111] [mask] fill 0x00ff
			.word    0x140a      ; 0x2776 [0001010000001010] [addr] fill !0xa

; -------------------------------------------------------------------------------
;;; Stack Pointer definition
; -------------------------------------------------------------------------------
    .global __STACK_END
    .sect 	.stack

; -------------------------------------------------------------------------------
;;; Reset Vector definition
; -------------------------------------------------------------------------------
    .sect ".reset"          ; labels this section of code as the reset vector for the final linker/assembler
    .word RESET				; drop the reset vector in this final memory location
