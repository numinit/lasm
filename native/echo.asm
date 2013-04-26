	;; Conventions:
	;; Nothing!
LC3_ECHO:
	trap getc
	trap not
	trap outc
	ld &NEGATIVE
	br &LC3_ECHO
NEGATIVE: .fill 0xffff
