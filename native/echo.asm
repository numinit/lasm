	;; Conventions:
	;; Nothing!
LC3_ECHO:
	trap %GETC
	trap %NOT
	trap %OUTC
	ld &NEGATIVE
	br &LC3_ECHO
NEGATIVE: .fill 0xffff
