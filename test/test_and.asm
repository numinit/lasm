TEST_AND:
	ld &and1
	trap %and
	ld &and3
	trap %and
	trap %stop
	
and1:	.fill 0xaaaa
and2:	.fill 0x5555
and3:	.fill 0x1234
and4:	.fill 0xffff
