	;; Conventions:
	;; 0x8: Scratch
	;; 0xa: AND argument 1
	;; 0xc: AND argument 2
LC1_OUTC_TRAP:
	ADD	!8		; shift the accumulator left a bunch
	ADD	!8
	ADD	!8
	ADD	!8
	ADD	!8
	ADD	!8
	ADD	!8
	ADD	!8
	ST	!8		; save it

	LD	@0x0222		; load the I/O port
	ST	!0xa		; save it

	LD	&MASK		; load the bitmask
	ST	!0xc		; save it

	LD	&ADDR		; load the address
	TRAP	%AND		; perform the bitwise AND

	ADD	!8		; add in the upper byte
	ST	@0x0222		; write it
	RET

MASK:	.fill	0x00ff
ADDR:	.fill	!0xa
