	;; Conventions:
	;; 0: Argument 0
	;; 2: Argument 1
	;; 4: Result
	;; 6: Counter/Temp

LC1_TRAP_AND:
	ST	!6
	TRAP	&LDR
	ST	!0
	LD	!6
	ADD	&ONE
	ADD	&ONE
	TRAP	&LDR
	ST	!2
	LD	&ZERO
	ST	!4
	LD	&N16
	ST	!6
LOOP:
	LD	!6
	BR	&INCREMENT
	LD	!4
	RET
INCREMENT:
	ADD	&ONE
	ST	!6
TEST_A:
	LD	!0
	BR	&TEST_B
	CALL	&SHIFT
	BR	&LOOP
TEST_B:
	LD	!2
	BR	&NEXT
	CALL	&SHIFT
	BR	&LOOP
NEXT:
	LD	!4
	ADD	&ONE
	ST	!4
	CALL	&SHIFT
	BR	&LOOP

SHIFT:
	LD	!0
	ADD	!0
	ST	!0
	LD	!2
	ADD	!2
	ST	!2
	LD	!4
	ADD	!4
	ST	!4
	LD	&N16
	RET

ZERO:	.fill	0x0000
ONE:	.fill	0x0001
N16:	.fill	0xfff0
