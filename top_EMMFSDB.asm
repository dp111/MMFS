_MASTER_=FALSE          ; Master version
_ELECTRON_=TRUE         ; Electron version
_SWRAM_=FALSE           ; Sideways RAM Version
_BP12K_=FALSE           ; B+ private RAM version
_ROMS_=TRUE             ; Include *ROMS command (i.e. No DFS or 8271 DFS)
_UTILS_=TRUE            ; Include utilites (*DUMP etc.) (i.e. No DFS)
_TUBEHOST_=TRUE         ; Include Tube Host (i.e. no DFS or DFS 0.90)
_VIA_BASE=&FCB0         ; Base Address of 6522 VIA
_TUBE_BASE=&FCE0        ; Base Address of Tube
_LARGEFILES=TRUE        ; true = enable long (>64K) file support
_DEBUG=FALSE            ; true = enable debugging of service calls, etc
_DEBUG_MMC=TRUE         ; true = enable debugging of MMC initialization

MACRO BASE_NAME
	EQUS "Electron MMFS"
ENDMACRO

INCLUDE "mmfs100.asm"