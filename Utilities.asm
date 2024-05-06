\** MMFS ROM by Martin Mather
\** Compiled using BeebAsm V1.04
\** June/July 2011

	\ ****** START OF UTILITIES *****
.Utils_SetBufPtr
IF _SWRAM_
	LDA #UTILSBUF
	STA &AD
ELSE
	LDX PagedRomSelector_RAMCopy
	LDA PagedROM_PrivWorkspaces,X	; Word AC -> 2nd PWSP Page
	AND #&3F			; Bits 7 & 6 are flags
	STA &AD
	INC &AD
ENDIF
	RTS

.CMD_DUMP
{	LDA #&40; Open file for input
	JSR Utils_FilenameAtXY

	LDA #0
	PHA ; low byte
	TAX ; high byte
	BEQ dump_loop

.dump_inc_address
	; C already 0
	ADC #8
	PHA ; low byte
	BCC dump_loop
	INX
.dump_loop

	TXA ; high byte
	JSR PrintHexSPL

	PLA	 ; low byte
	PHA
	JSR PrintHexSPL

	TXA
	PHA ;high byte

	JSR PrintSpaceSPL		; exits with C=0
	LDX #7
.dump_getbytes_loop
	JSR OSBGET
	BCS dump_eof			; If eof
	STA &A8,X				; save byte
	JSR PrintHexSPL
	JSR PrintSpaceSPL		; exits with C=0
	DEX
	BPL dump_getbytes_loop
.dump_eof
	PHP
	BCC dump_noteof			; If not eof
.dump_padnum_loop
	LDA #&2A				; Pad end of line with "** "
	JSR OSASCI
	JSR OSASCI
	JSR PrintSpaceSPL		; exits with C=0
	LDA #&00
	STA &A8,X
	DEX
	BPL dump_padnum_loop
.dump_noteof
	LDX #7
.dump_chr_loop
	LDA &A8,X

	; Chr or "."

	AND #&7F			; If A<&20 OR >=&7F return "."
	CMP #&7F			; Ignores bit 7
	BEQ showchrdot
	CMP #&20
	BCS showchrexit
.showchrdot
	LDA #&2E			; "."
.showchrexit

	JSR OSASCI
	DEX
	BPL dump_chr_loop

	JSR OSNEWL
	PLP
	PLA ; Restore high byte
	TAX
	PLA ; low byte byte
	BIT &FF				; Check escape
	BMI Utils_ESCAPE_CloseFileY

	BCC dump_inc_address

	BCS Utils_CloseFile_Yhandle
}



.CMD_TYPE
	LDA #&00
	BEQ type
.CMD_LIST
	LDA #0
	STA &A8				; word &A8
	STA &A9				; used for line number
	LDA #&FF
.type
{
	STA &AB
	LDA #&40 ; Open file for input
	JSR Utils_FilenameAtXY

	LDA #&0D
.list_loop_entry
	AND &AB
	CMP #&0D			; Carriage return?
	PHP 				; (Always false if CMD_TYPE)
.list_loop
	JSR OSBGET
	BCS list_eof			; EOF exit loop
	CMP #&0A
	BEQ list_loop			; ignore &0A
	PLP
	BNE list_skiplineno		; If don't print line number
	PHA
	JSR Utils_PrintLineNo
	PLA
.list_skiplineno
	JSR OSASCI
	BIT &FF
	BMI Utils_ESCAPE_CloseFileY			; Escape?
	BPL list_loop_entry

.list_eof
	PLP	 			; Print newline + exit
	JSR OSNEWL
}
.Utils_CloseFile_Yhandle
	LDA #&00
	JMP OSFIND

.Utils_ESCAPE_CloseFileY
;	JSR osbyte7E_ackESCAPE2		; Acknowledge escape, close
	JSR Utils_CloseFile_Yhandle	; file Y and report error!
	JMP ReportESCAPE


.CMD_BUILD
{
	LDA #&80			; Open file for OUTPUT only
	JSR Utils_FilenameAtXY		; XY points to filename
	STA &AB	;File handle
.build_loop1
	JSR Utils_PrintLineNo		; Line number prompt:
								; Build Osword control block @ AC
	JSR Utils_SetBufPtr		; Normally ?AD=&18
	LDX #&AC			; Osword ptr YX=&00AC
	LDY #&FF
	STY &AE				; Max length = 256
	STY &B0
	INY
	STY &AC				; So word AC=&1800 (normally)
	LDA #&20
	STA &AF				; min ASCII value accepted
	TYA 				; max value???
	JSR OSWORD			; OSWORD 0, YX=&00AC
	PHP 				; Read line from input
	STY &AA				; Y=line length
	LDY &AB				; Y=file handle
	LDX #&00
	BEQ build_loop2entry		; always
.build_loop2
	LDA (&AC,X)			; Output line to file
	JSR OSBPUT
	INC &AC
.build_loop2entry
	LDA &AC
	CMP &AA
	BNE build_loop2
	PLP
	BCS Utils_ESCAPE_CloseFileY	; Escape pressed so exit
	LDA #&0D			; Carriage return
	JSR OSBPUT
	JMP build_loop1
}

.Utils_FilenameAtXY
	STA &AF
	TSX 				; Return A=0 to OS
	LDA #&00
	STA &0107,X

	DEY
.utils_skipspcloop
	INY 				; Skip spaces
	LDA (TextPointer),Y
	CMP #&20
	BEQ utils_skipspcloop

	CMP #&0D
	BNE utils_notnullstr		; If not end of line
	JMP errSYNTAX			; Syntax Error!

.utils_notnullstr

	TYA				; YX=TextPtr+Y
	CLC				; Used to pass to OSFIND
	ADC TextPointer			; ie. Filename
	TAX
	LDA TextPointer+1
	ADC #&00
	TAY

	LDA &AF
	JSR OSFIND
	BEQ utils_filenotfound
	TAY 				; Y=File handle
	RTS

.utils_filenotfound
	JMP err_FILENOTFOUND

;;.Utils_TextPointerAddY
;;{
;;	TYA 				; TextPointer += Y
;;	CLC 				; (Where is this used?)
;;	ADC TextPointer
;;	STA TextPointer
;;	BCC utils_tpexit
;;	INC TextPointer
;;.utils_tpexit
;;	RTS
;;}

.Utils_PrintLineNo
	LDX #&A8
	JSR bcd_inc16_zp_x		; A = hi byte
	JSR PrintHexSPL
	LDA &A8				; A = lo byte
	JSR PrintHexSPL
	JMP PrintSpaceSPL		; exits with C=0

	\ ********** END OF UTILITIES **********
