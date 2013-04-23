;;; MSP430       :: LC-1 Emulator
;;; Morgan Jones :: 2013 :: ELEC220

;;; Register conventions
;;; r0 - MSP430 PC
;;; r1 - MSP430 SP
;;; r2 - MSP430 SR
;;; r3 - MSP430 CG
;;; r4 - LC-1 PC
;;; r5 - LC-1 SP
;;; r6 - LC-1 ACC
;;; r7 - LC-1 IR
;;; r8 - LC-1 MAR
;;; r15 - LC-1 CR

    .cdecls C, LIST, "msp430.h"

PUSH    .macro

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

  ;; An immediate register functioning as a 16-bit function argument.
    .asg r10, LC1_FUNC_ARG

  ;; An immediate register functioning as a 16-bit return value.
    .asg r11, LC1_FUNC_RET

  ;; The LC-1's conditional register.
    .asg r15, LC1_CR

    .asg 0x1fff, LC1_IMM_MASK
    .asg 0x0007, LC1_OPCODE_MASK
    .asg 0x1400, LC1_RAM_OFFSET

    .asg 0x2400, LC1_PC_RAM_BEGIN
    .asg 0xfb00, LC1_PC_FLASH_BEGIN
    .asg 0x24fe, LC1_PC_RAM_END

    .asg 0x2500, LC1_TRAP_RAM_BEGIN
    .asg 0xfc00, LC1_TRAP_FLASH_BEGIN
    .asg 0x27fe, LC1_TRAP_RAM_END

    .asg 0x2900, LC1_STACK_BEGIN
    .asg 0x2930, LC1_STACK_END

    .asg 0x0000, LC1_PANIC_ILLEGAL
    .asg 0x0001, LC1_PANIC_STACK_OVERFLOW
    .asg 0x0002, LC1_PANIC_STACK_UNDERFLOW

    .text 	                        ; Stick the remaining code in the .text section
    .retain                         ; Override ELF conditional linking and retain current section
    .retainrefs                     ; Additionally, retain any sections that have references to current section

LC1_RESET
            mov.w   #__STACK_END, SP		     ; Initialize the stack pointer
	        mov.w   #(WDTPW | WDTHOLD), &WDTCTL  ; Stop WDT
	        mov.w   #LC1_PC_RAM_BEGIN, LC1_PC    ; R4 is the PC
	        mov.w   #LC1_STACK_BEGIN, LC1_SP     ; R5 is the SP
	        mov.w   #0, LC1_ACC                  ; R6 is the ACC
	        mov.w   #0, LC1_CR                   ; R15 is the CR

	        mov.b	0x0f, &P4DIR 	             ; setup P4.0-P4.3 as output
	        mov.b	0x00, &P9DIR	             ; setup P9.4-P9.7 as input

LC1_INIT
            ;; Two pointers: one to the beginning of the application code in RAM,
            ;; the other to the beginning of the application code in flash.
            ;; Compare to the end of RAM every loop.
            mov.w #LC1_PC_FLASH_BEGIN, r7
            mov.w #LC1_PC_RAM_BEGIN, r8
            mov.w #LC1_PC_RAM_END, r9
LC1_INIT_LOOP
            mov.w @r7+, @r8+
            cmp r7, r9
            jne LC1_INIT_LOOP

LC1_FETCH
            mov.w @LC1_PC+, LC1_IR                      ; Fetch an instruction and post-increment the PC
LC1_DECODE_IMMEDIATE
            mov.w #LC1_MAR_MASK, LC1_MAR                ; 0x1fff = 0001 1111 1111 1111 (low 13 bits, address)
            and.w LC1_IR, LC1_MAR                       ; The MAR now stores the address, without the offset.
            rlc.w LC1_IR                                ; Time for a trick. Shift the instruction register LEFT through carry.
            rlc.w LC1_IR                                ; Why left? Well, we have to test bit 12, right?
            rlc.w LC1_IR                                ; If we shift it four times... the carry bit will store bit 12 of the immediate value...
            rlc.w LC1_IR                                ; and the lowest 3 bits will have the opcode.
            jnc   LC1_DECODE_OPCODE                     ; If the carry is cleared, we don't need to offset it.
            add.w #LC1_RAM_OFFSET, LC1_IMM              ; Otherwise, add the RAM offset to the MAR.
LC1_DECODE_OPCODE
            and.w #LC1_OPCODE_MASK, LC1_IR              ; 0x0007 = 0000 0000 0000 0111 (low 3 bits, opcode)
LC1_EXECUTE
            call LC1_INSTRUCTIONS(LC1_IR)               ; Indirect call to the instruction at LC1_INSTRUCTIONS + IR
            br #LC1_FETCH

;;; -------- LC-1 Call --------
LC1_CALL
            mov.w LC1_PC, LC1_FUNC_ARG
            call LC1_SPUSH
            mov.w LC1_IMM, LC1_PC
            ret

;;; -------- LC-1 Return --------
LC1_RET
            call LC1_SPOP
            mov.w LC1_FUNC_RET, L1_PC
            ret

;;; -------- LC-1 Branch --------
LC1_BR
            ret

;;; -------- LC-1 Add --------
LC1_ADD
            ret

;;; -------- LC-1 Load --------
LC1_LD
            ret

;;; -------- LC-1 Store --------
LC1_ST
            ret

;;; -------- LC-1 Trap --------
LC1_TRAP
            ret

;;; -------- LC-1 Illegal Opcode --------
LC1_ILLEGAL
            call LC1_PANIC
            ret

;;; -------- LC-1 Panic --------
LC1_PANIC
            mov.w #0x0000, r9   ; special case of the trap operation, stops the CPU
            jmp LC1_TRAP
            ret

;;; Pushes the value stored in R9 onto the LC-1's stack, detecting a stack overflow.
LC1_SPUSH
            ;; Check for a stack overflow. If none was detected, continue.
            ;; Otherwise, panic.
            cmp #LC1_STACK_END, LC1_SP
            jl LC1_SPUSH_COMMIT

            ;; Panic: emulator stack overflow!
            push LC1_FUNC_ARG
            mov.w #LC1_PANIC_STACK_OVERFLOW, LC1_FUNC_ARG
            call LC1_PANIC
            pop LC1_FUNC_ARG
            ret

LC1_SPUSH_COMMIT
            ;; Commit the stack changes. We can just use a post-increment here instead of incd.
            mov.w LC1_FUNC_ARG, @LC1_SP+
            ret

;;; Pops the top value from the LC-1's stack into R9, detecting a stack underflow.
LC1_SPOP
            ;; Check for a stack underflow. If none was detected, continue.
            ;; Otherwise, panic.
            cmp LC1_SP, #LC1_STACK_BEGIN
            jl  LC1_SPOP_COMMIT

            ;; Panic: emulator stack underflow!
            push LC1_FUNC_ARG
            mov.w #LC1_PANIC_STACK_UNDERFLOW, LC1_FUNC_ARG
            call LC1_PANIC
            pop LC1_FUNC_ARG
            ret

LC1_SPOP_COMMIT
            ;; Commit the stack changes
            mov.w  @LC1_SP, LC1_FUNC_RET
            decd.w LC1_SP
            ret

LC1_INSTRUCTIONS
            .word #LC1_CALL
            .word #LC1_RET
            .word #LC1_ADD
            .word #LC1_BR
            .word #LC1_LD
            .word #LC1_ST
            .word #LC1_TRAP
            .word #LC1_ILLEGAL

;-------------------------------------------------------------------------------
           	.sect ".LC1_Code"                 ; LC1 code (REAL: 0xFB00) (VIRTUAL: 0x2400)
           	.retain                         ; Override ELF conditional linking
                                            ; and retain current section
        	.retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------
; enter your LC-1 code here, when your code is complete the following code should
; mimick lab3 part 2



;-------------------------------------------------------------------------------
; LC1 Trap Section
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
           .sect .NOT_Trap               ; LC-1 NOT trap (FLASH: 0xFC00) (RAM: 2500)
;written already, this trap performs a bitwise NOT on the value in the accumulator

			.retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------
           .sect .AND_Trap                  ; LC1 AND Trap (0xFC4E)
; computes a bitwise AND between the two consecutive addresses, with the first pointed to by the accumulator, and then stores that value back to the accumulator
; uses trap RAM locations x2800 (temporary for original ACC), x2802 (result), and x2804 (counter/boundary)
			.retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------
;initialization of boundaries and counters section






;-------------------------------------------------------------------------------
           .sect .LDR_Trap                  ; LC1 LDR Trap (Flash: 0xFD00) (Ram: 2600)
;an indirect load, loads the data pointed to by the address specified in the LC-1 accumulator
; uses trap RAM locations x280E and x2810 to store the self modified code
			.retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------





;-------------------------------------------------------------------------------
           .sect .RR_Trap                  ; LC1 RR Trap (0xFD70)
;written for us, this trap rotates the value in the accumulator one bit right
;uses trap RAM locations x2800 and x2802
			.retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------
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



;-------------------------------------------------------------------------------

        .sect .GETc_Trap                  ; LC1 Getc Trap (0xFE00)
		.retain                         ; Override ELF conditional linking
                                        ; and retain current section
        .retainrefs                     ; Additionally retain any sections
                                        ; that have references to current
                                        ; section
; Read in the input switches from the IO board: read address 0x00280.
;  Uses trap ram locations x280A(first operand for AND trap), x280C(second operand for AND trap)
;-------------------------------------------------------------------------------






;-------------------------------------------------------------------------------
        .sect .OUTc_Trap                  ; LC1 Out Trap (0xFE50)
;outputs the value in the accumulator to the P1_OUT out register
			.retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;           Stack Pointer definition
;-------------------------------------------------------------------------------
    .global __STACK_END
    .sect 	.stack

 ;---------------------setup the reset code section-------------------
        .sect ".reset"          ; labels this section of code as the reset vector for the final linker/assembler
        .word RESET				; drop the reset vector in this final memory location
