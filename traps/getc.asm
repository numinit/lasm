	;; Conventions:
	;; 0xa: Bitmask, AND argument 1
	;; 0xc: Scratch, AND argument 2
LC1_GETC_TRAP:
	LD	&MASK_VAL
	ST	!0xa

	LD	@0x0280
	TRAP	%NOT
	TRAP	%RR
	TRAP	%RR
	TRAP	%RR
	TRAP	%RR
	ST	!0xc

	LD 	&AND_ADDR
	TRAP	%AND
	RET

MASK_VAL:  .fill 0x000f
AND_ADDR:  .fill !0xa
