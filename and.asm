AND:	ST	&TEMP
	TRAP	&LDR
	ST	&A
	LD	&TEMP
	ADD	&ONE
	TRAP	&LDR
	ST	&B
	LD	&ZERO
	ST	&C
	LD	&N16
	ST	&CTR
		
LOOP:	LD	&CTR
	BR	&AND_TEST_A
	RET	
		
AND_TEST_A:	ADD	&ONE
	ST	&CTR
	LD	&A
	BR	&AND_TEST_B
	CALL	&SHIFT
	BR	&LOOP
		
AND_TEST_B:	LD	&B
	BR	&NEXT
	CALL	&SHIFT
	BR	&LOOP
		
NEXT:	LD	&C
	ADD	&ONE
	ST	&C
	CALL	&SHIFT
	BR	&LOOP
		
SHIFT:	LD	&A
	ADD	&A
	ST	&A
	LD	&B
	ADD	&B
	ST	&B
	LD	&C
	ADD	&C
	ST	&C
	LD	&N16
	RET	

N16:	.fill	0xfff0
ZERO:	.fill	0x0000
ONE:	.fill	0x0001

A:	.fill	0x0000
B:	.fill	0x0000
C:	.fill	0x0000
CTR:	.fill	0x0000
TEMP:	.fill	0x0000