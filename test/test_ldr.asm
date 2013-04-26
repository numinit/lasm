TEST_LDR:
	ld &test
	trap %ldr
	trap %stop
test:	.fill 0x1234
