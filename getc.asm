GETC:	LD	0x0280
	TRAP	&RR
	TRAP	&RR
	TRAP	&RR
	TRAP	&RR
	ST	&AND2
	LD	&ADDRESS
	TRAP	&AND
	RET	
		
AND1:	.fill	0x00f0
AND2:	.fill	0x0000
ADDRESS:	.fill	&AND1