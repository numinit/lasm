TEST_OUTC:
	ld &outp
	trap %outc
	trap %stop
outp:	.fill 0x0003
