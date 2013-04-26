	;; Conventions:
	;; 0x0e: Generated opcode
	;; 0x10: Return
LC1_TRAP_LDR:
	ADD	&OPCODE
	ST	!0x0e
	LD	&RETURN
	ST	!0x10
	LD	&NEGATIVE
	BR	!0x0e
RETURN:
	RET
NEGATIVE: .fill 0xffff
OPCODE:   .fill	0x8000

