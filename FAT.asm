\** MMFS ROM by Martin Mather
\** Compiled using BeebAsm V1.04
\** June/July 2011

\\ ******* FAT CODE ********

	\\ ******* LOAD FAT ROOT DIRECTORY ******

fatdirsize%=&C1		; word
fatclustsize%=&C3	; byte
fattype%=tempbuffer%+&00 ;
fatclustersec%=fattype%+1 ; 3 bytes
;filecluster%=fatclustersec%+4 ; 4 bytes
; NB sec%= &BE three bytes BE BF C0
;
; &BC &BD used as dataptr for catalogue read & E00 to &F00
.FATLoadRootDirectory
{
	\\ Read sector 0 (MBR)
	LDA #&DD
	STA CurrentCat
	LDA #0
	STA sec%
	STA sec%+1
	STA sec%+2
	; get MBR?
	JSR isfat
	BEQ fat				; FAT not recognised Assume sector 0 is start of image
	CLC				; return C=0 to indicate no FAT
	RTS

	\\ FAT signature word?
.isfat
	JSR MMC_ReadCatalogue
	LDA cat%+&1FE
	CMP #&55
	BNE ifx
	LDA cat%+&1FF
	CMP #&AA
.ifx
	RTS

\\ Boot sector signature 0x55 0xAA found

\\ Test for presence of FAT Partition Boot Sector
\\ 0x000 = 0xEB xx 0x90 is a good indicator
\\ If this is not found, then assume sector 0 is an MBR

.fat
   LDA cat%
   CMP #&EB
   BNE mbr
   LDA cat%+2
   CMP #&90
   BNE mbr
   LDA cat%+&C
   CMP #&02
   BEQ nombr

.mbr
	\\ sec = cat!&1C6 * 2
	LDA cat%+&1C6  \\ get first partition
	ASL A
	STA sec%
	LDA cat%+&1C7
	ROL A
	STA sec%+1
	LDA cat%+&1C8
	ROL A
	BCS faterr1
	STA sec%+2
	LDA cat%+&1C9
	BNE faterr1
	; get VBR
	JSR isfat
	BNE faterr1

	\\ Sec size = 512?

	LDA cat%+&B
	BNE faterr1
	LDA cat%+&C
	CMP #2
	BEQ validsectorsize

.faterr1
	JSR ReportError
	EQUB &FF
	EQUS "Card format?",0
.nombr
.validsectorsize
	\\ cluster size
	LDA cat%+&D
	STA fatclustsize%

	\\ Calc Start of FAT

	\\ sec = sec + Reserved sectors * 2
	LDA cat%+&E
	ASL A
	ROL cat%+&F
	BCS faterr1

	ADC sec%
	STA sec%
	STA fatclustersec%
	LDA cat%+&F
	ADC sec%+1
	STA sec%+1
	STA fatclustersec%+1
	BCC skipinc1
	INC sec%+2
.skipinc1
	LDA sec%+2
	STA fatclustersec%+2

	\\ &11-&12  Number of root directory entries (224)
	\\		  0 for FAT32. 512 is recommended for FAT16.
	\\ fatdirsize = (max dir entries / 16) * 2
	LDA cat%+&11
	STA fatdirsize%
	LDA cat%+&12
	LSR A : ROR fatdirsize%
	LSR A : ROR fatdirsize%
	LSR A : ROR fatdirsize%
	STA fatdirsize%+1
	ORA fatdirsize%
	STA fattype%
	BEQ fat32
	\\ Make FAT16 look like FAT32
	\\ &16-&17 Sectors per FAT for FAT16
	\\ &24-&27 Sectors per FAT for FAT32
	LDA cat%+&16
	STA cat%+&24
	LDA cat%+&17
	STA cat%+&25
	LDA #0
	STA cat%+&26
	STA cat%+&27
.fat32

	\\ fat size = fat sectors * 2

	ASL cat%+&24
	ROL cat%+&25
	ROL cat%+&26
	ROL cat%+&27
	BCS faterr1 \\ error if we have more than

	\\ sec = sec + fat copies * fat size
	LDX cat%+&10			; fat copies ( Always 2 on fat 32)
.loop
	CLC
	LDA sec%
	ADC cat%+&24
	STA sec%
	LDA sec%+1
	ADC cat%+&25
	STA sec%+1
	LDA sec%+2
	ADC cat%+&26
	STA sec%+2
	DEX
	BNE loop
	JSR MMC_ReadCatalogue		; Root Dir
	SEC				; return C=1 to indicate FAT
	RTS
}


	\\ **** SEARCH FOR FILE ****
	\\ Exit: C=0 = File found

.FATSearchRootDirectory
fatfilename%=workspace%+&F0
{
fatptr%=&BC ; was &C4 &C5		; word
fatclust%=&C3		; 24-bits (3 bytes)

	\\ Search dir
	LDA sec%+2 :PHA
	LDA sec%+1 :PHA
	LDA sec%   :PHA
.FATSearchRootDirectoryloop
	LDX #0
	STX fatptr%
	LDA #HI(cat%)
	STA fatptr%+1

	INX
.dirloop
	LDY #&B				; is file deleted?
	LDA (fatptr%),Y
	AND #&F
	BNE nextfile

	DEY				; compare filenames
.comploop
	LDA (fatptr%),Y
	BEQ filenotfound ;  end of FAT
	CMP fatfilename%,Y
	BNE nextfile			; no match
	DEY
	BPL comploop
	BMI filefound			; file found!

.nextfile
	CLC				; next file?
	LDA fatptr%
	ADC #32
	STA fatptr%
	BNE dirloop
	INC fatptr%+1
	DEX
	BPL dirloop

.incfatsector

	inc sec%+0
	inc sec%+0
	BNE readnextfatsector
	inc sec%+1
	BNE readnextfatsector
	inc sec%+2
.readnextfatsector
	JSR MMC_ReadCatalogue
	JMP FATSearchRootDirectoryloop

.filenotfound
	PLA
	PLA
	PLA
	SEC
.jmprts
	RTS

	\\ file found
.filefound

filecluster% = &C1; 2 bytes
fileclusterhigh% = fatclustersec%+4
	\\ sec = sec + max dir entries ( FAT32 = 0, FAT16 typically 64  )
	CLC
	PLA
	ADC fatdirsize%
	STA sec%
	PLA
	ADC fatdirsize%+1
	STA sec%+1
	PLA
	ADC #0
	STA sec%+2

	LDX fatclustsize% ; This is the number of sectors per cluster

	\\ cluster = file cluster - 2

	\\ In FAT32 the file start cluster is 32 bits and is stored the directory entry
	\\ offsets &15, &14, &1B, &1A (MSB .. LSB).
	\\
	\\ In FAT16, offset &15 and &14 are reserved and should be zero
	\\
	\\ MMFS only deals with 24-bit sector addresses so we ignore bits 31..24
	\\ A 24-bit sector address allows for the file system to be upto 8GB
	\\
	\\ Note: Originally MMFS treated the file start cluster as a 16 bit value.
	\\ With a cluster size of 8 (4KB) that cause problems if the file start
	\\ was more that 128MB into the file system. This was fixed in MMFS 1.51.

	SEC
	LDY #&1A
	LDA (fatptr%),Y		; bits 0..7 of file start cluster in &1A
	STA filecluster%
	SBC #2
	STA fatclust%

	INY
	LDA (fatptr%),Y		; bits 15..8 of file start cluster in &1B
	STA filecluster%+1
	SBC #0
	PHA

	LDY #&14
	LDA (fatptr%),Y		; bits 23..16 of file start cluster in &14
	STA fileclusterhigh%
	SBC #0
	STA fatclust%+2
	PLA
	STA fatclust%+1

	ORA fatclust%+1
	ORA fatclust%
	BEQ jmprts			; if cluster = 0

.nowscalecluster
	\\ fatclust% now equals fatclust-2

	\\ cluster = cluster * 2
	ASL fatclust%
	ROL fatclust%+1
	ROL fatclust%+2

	\\ sec = sec + cluster * size (X)
.clustloop
	CLC
	LDA sec%
	ADC fatclust%
	STA sec%
	LDA sec%+1
	ADC fatclust%+1
	STA sec%+1
	LDA sec%+2
	ADC fatclust%+2
	STA sec%+2
	DEX
	BNE clustloop
; Do Fragmentation check
IF 1
	\\ save sec%
	LDA sec%+0: PHA
	LDA sec%+1: PHA
	LDA sec%+2: PHA

\\ check cluster increment until we get to FF FF for FAT16 or FF FF FF 0F for FAT32
	\\ fattype% = 0 FAT 32, non zero FAT16
	LDA fattype%
	BEQ fat32clustercheck
	LDA #128
	STA fattype%


.fat32clustercheck
	; filecluster needs to *4 to find the starting byte in the cluster table
	ASL filecluster%+0	; *2
	ROL filecluster%+1
	ROL fileclusterhigh%

	ASL filecluster%+0	; *2
	ROL filecluster%+1
	ROL fileclusterhigh%

	CLC
	LDA fatclustersec%+0 : ADC filecluster%+1 : PHA : AND #&FE :STA sec%+0
	LDA fatclustersec%+1 : ADC fileclusterhigh% : STA sec%+1
	LDA fatclustersec%+2 : ADC #0               : STA sec%+2

	\\ fatclustersec%
	\\ filecluster

temp% = &C3 ; 4 bytes
.clusterreadsector
	JSR MMC_ReadCatalogue
	CLC
	PLA
	AND #1
	ADC #HI(cat%)
	STA fatptr%+1

	LDY filecluster%+0
	; Follow cluster chain to check it is in sequence
	; assume the first cluster isn't the end of the cluster chain
	LDX fattype%
	TXA
	ROL A
	BMI clustercheckloop
	ROR A
	ORA #64 : STA fattype%
	; first time prep temp variable
	CLC
	LDA (fatptr%),Y: ADC #1 : STA temp%+0 : INY
	LDA (fatptr%),Y: ADC #0 : STA temp%+1 : INY
	TXA
	BMI fat16skipsetup
	LDA (fatptr%),Y: ADC #0 : STA temp%+2 : INY
	LDA (fatptr%),Y: ADC #0 : STA temp%+3 : INY
.fat16skipsetup

.clustercheckloop
	CLC
	LDA (fatptr%),Y : EOR temp%+0 : BNE chainnotequal1 :LDA (fatptr%),Y : ADC #1 : STA temp%+0 : INY
	LDA (fatptr%),Y : EOR temp%+1 : BNE chainnotequal2 :LDA (fatptr%),Y : ADC #0 : STA temp%+1 : INY
	TXA
	BMI fat16skipinc
	LDA (fatptr%),Y : EOR temp%+2 : BNE chainnotequal3 :LDA (fatptr%),Y : ADC #0 : STA temp%+2 : INY
	LDA (fatptr%),Y : EOR temp%+3 : BNE chainnotequal4 :LDA (fatptr%),Y : ADC #0 : STA temp%+3 : INY

.fat16skipinc
	TYA
	BNE clustercheckloop
	INC fatptr%+1
	LDA fatptr%+1
	CMP #HI(cat%)+2
	BNE clustercheckloop

	; inc sector
	INC sec%+0
	INC sec%+0 : BNE clusterreadsectorjmp
	INC sec%+1 : BNE clusterreadsectorjmp
	INC sec%+2 : BNE clusterreadsectorjmp
	; we have got to the end of 4GBytes
	; cluster too far into catalogue
	; so give error
	; This case is so unlikely , may be impossible

.clusterreadsectorjmp
	TYA
	STY filecluster%+0
	PHA
	JMP clusterreadsector

.chainnotequal4
	DEY
.chainnotequal3
	DEY
.chainnotequal2
	DEY
.chainnotequal1
	LDA (fatptr%),Y : CMP #&F0 : BCC fragmented : INY
	LDA (fatptr%),Y : CMP #&FF : BNE fragmented : INY
	TXA: BMI clustercheckdone
	LDA (fatptr%),Y : CMP #&FF : BNE fragmented : INY
	LDA (fatptr%),Y : AND #&0F: CMP #&0F : BEQ clustercheckdone

.fragmented
	; print error
	JSR PrintStringSPL
	EQUS "Fragmented!":EQUB 13:EQUB 13
	NOP
.clustercheckdone
	\\ restore sec%
	PLA: STA sec%+2
	PLA: STA sec%+1
	PLA: STA sec%+0
ENDIF
.exit
	CLC
	RTS
}
	\\ End of FAT routine
