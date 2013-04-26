	;; Conventions:
	;; 0x0e: Generated opcode
	;; 0x10: Return
LC1_LDR_TRAP:
	ADD	&LOAD
	ST	!0x0e
	LD	&RETURN
	ST	!0x10
	LD	&NEGATIVE
	BR	!0x0e
RETURN:
	RET
LOAD:
	LD	0x0000

NEGATIVE: .fill 0xffff

