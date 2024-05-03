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

.CMD_TYPE
	JSR Utils_FilenameAtXY
	LDA #&00
	BEQ type

.CMD_LIST
	JSR Utils_FilenameAtXY
	LDA #&FF
.type
	STA &AB
	LDA #&40
	JSR OSFIND			; Open file for input
	TAY 				; Y=handle
	LDA #&0D
	CPY #&00
	BNE list_loop_entry		; If file opened

.utils_filenotfound
	JMP err_FILENOTFOUND

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
	BMI dump_loop			; Escape?
.list_loop_entry
	AND &AB
	CMP #&0D			; Carriage return?
	PHP 				; (Always false if CMD_TYPE)
	JMP list_loop
.list_eof
	PLP	 			; Print newline + exit
	JSR OSNEWL

.Utils_CloseFile_Yhandle
	LDA #&00
	JMP OSFIND

.CMD_DUMP
	JSR Utils_FilenameAtXY
	LDA #&40
	JSR OSFIND			; Open file for input
	TAY 				; Y=handle
	BEQ utils_filenotfound
	JSR Utils_SetBufPtr
.dump_loop
{
	BIT &FF				; Check escape
	BMI Utils_ESCAPE_CloseFileY
	LDA &A9				; word A8 is the offset counter
	JSR PrintHexSPL
	LDA &A8
	JSR PrintHexSPL
	JSR PrintSpaceSPL		; exits with C=0
	LDA #&08
	STA &AC
	LDX #&00
.dump_getbytes_loop
	JSR OSBGET
	BCS dump_eof			; If eof
	STA (&AC,X)			; save byte (usually &1800-&1807)
	JSR PrintHexSPL
	JSR PrintSpaceSPL		; exits with C=0
	DEC &AC
	BNE dump_getbytes_loop
.dump_eof
	PHP
	BCC dump_noteof			; If not eof
.dump_padnum_loop
	LDA #&2A			; Pad end of line with "** "
	JSR OSASCI
	JSR OSASCI
	JSR PrintSpaceSPL		; exits with C=0
	LDA #&00
	STA (&AC,X)
	DEC &AC
	BNE dump_padnum_loop
.dump_noteof
	JSR dump_printchars
	JSR OSNEWL
	LDA #&08
	CLC
	ADC &A8
	STA &A8
	BCC dump_inc
	INC &A9
.dump_inc
	PLP
	BCS Utils_CloseFile_Yhandle
	BCC dump_loop			; always
.dump_printchars
	LDA #&08
	STA &AC
.dump_chr_loop
	LDX #&00			; Print characters
	LDA (&AC,X)

	; Chr or "."

{
	AND #&7F			; If A<&20 OR >=&7F return "."
	CMP #&7F			; Ignores bit 7
	BEQ showchrdot
	CMP #&20
	BCS showchrexit
.showchrdot
	LDA #&2E			; "."
.showchrexit

}

	JSR OSASCI
	DEC &AC
	BNE dump_chr_loop
	RTS
}

.Utils_ESCAPE_CloseFileY
	JSR osbyte7E_ackESCAPE2		; Acknowledge escape, close
	JSR Utils_CloseFile_Yhandle	; file Y and report error!
	JMP ReportESCAPE

.CMD_BUILD
{
	JSR Utils_FilenameAtXY		; XY points to filename
	LDA #&80			; Open file for OUTPUT only
	JSR OSFIND
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
	LDA #&00			; Reset line counter
	STA &A8				; word &A8
	STA &A9
	PHA				; preserve A, but it's 0?
	TYA				; YX=TextPtr+Y
	CLC				; Used to pass to OSFIND
	ADC TextPointer			; ie. Filename
	TAX
	LDA TextPointer+1
	ADC #&00
	TAY
	PLA
	RTS

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
