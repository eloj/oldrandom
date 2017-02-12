; Program: Skeleton for a generic scan-byte patcher.
;          Created by Saruman / DFR Research & Engineering (srm_dfr@hotmail.com)
; Version: 1.2
; Updated: 97-10-17 skeleton
;          97-10-19 crack (Allfix)
;          97-10-19 Instable? register-nuking fixed problem (ecx in scanner)
;                   Now uses pointers into a structure, which allows for
;                   Simple recompilation to manage many patches in different
;                   files.
;          97-10-20 Now preserves file-attribute and date/time
;          97-11-12 Now calculates the length of scan/patch strings.
;          97-11-16 Added output of product information under logo
;
; To do:
;    DOESN'T WORK WITH NEGATIVE RELATIVE OFFSETS!
;    Warn if not 386.
;    Capture CTRL+C (INT 23)

 NL                 EQU    0Dh,0Ah
 SEARCHBUFFERSIZE   EQU    04000h
 PROGRESSMAX        EQU    040d
 PROGRESSDELAY      EQU    032d

.model tiny
.code
.radix 16
.386 

;::: Codeblock :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

org	 100h

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;::: Program Entrypoint ::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
main:    jmp  skipmessage
         db 8,8,8,'   ',NL,'ScanPatcher v1.2 [97-10-20] by Saruman / DFR Research & Engineering.'
         db NL,'If you rip this to use for your cracks, please.. atleast greet me?',NL,'',NL
skipmessage:
         mov  ax,3
         int  10h                                ; Clear screen / set mode
         mov  ah,3
         int  10
         mov  cursor,cx                          ; Save cursor
         mov  ah,1
         mov  cx,2000
         int  10                                 ; Hide cursor

         push es
         mov  si,offset LOGO
         mov  ax,0B800h
         mov  es,ax
         xor  di,di
         mov  cx,LOGO_LENGTH+1E0
         rep  movsb                              ; Output logo + 3 lines
         pop  es

         mov  ah,2
         xor  bh,bh
         xor  dl,dl
         mov  dh,LOGO_DEPTH+3
         int  10                                 ; Move cursor in under logo..

         mov  si,offset PATCH1
         call setup_pointers
         mov  filenameptr,offset FILENAME1
         call process_file

;         mov  si,offset PATCH2
;         call setup_pointers
;         call process_file

         mov  ah,9
         mov  dx,offset S_BYEMSG
         int  21

         jmp  doexit


;::
;:: Scan buffer
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
sc_buffer:
         cld
         mov   di,offset SEARCHBUFFER
         mov   bx,di
         xor   ecx,ecx
         mov   cx,SEARCHLEN
         mov   dx,SCANLEN
         test  dx,dx
         jz    sc_error
         mov   si,scanbufptr
         lodsb
         dec   dx
         sub   cx,dx
         jbe   sc_error
sc_next:
         repne scasb
         jne  sc_error
         test dx,dx
         jz   sc_found
         push cx
         push di
         push si
         mov  cx,dx
         repe cmpsb
         pop  si
         pop  di
         pop  cx
         jne  sc_next
sc_found:
         dec  di
         mov  ax,di
         sub  ax,bx
         jmp  sc_done
sc_error:
         xor  ax,ax
         dec  ax
sc_done: ret

;::
;:: Update progress 'bar'
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
progress_update:
         dec  progressslow
         jnz  progress_ret
         mov  progressslow,PROGRESSDELAY
         mov  al,progressdir
         cmp  al,1
         je   progress_add
         mov  ah,9
         mov  dx,offset s_dbs
         int  21
         dec  progressnum
         mov  al,progressnum
         cmp  al,0
         jne  progress_ret
         mov  progressdir,1
         jmp  progress_ret

progress_add:
         mov  ah,2
         mov  dl,'ú'
         int  21
         inc  progressnum
         mov  al,progressnum
         cmp  al,progressmax
         jne  progress_ret
         mov  progressdir,0
progress_ret:
         ret         


;::
;:: Output the number stored in AX
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
printn:  mov  di,offset result+4                 ;end of buffer
         mov  bx,010d                            ;base
         std
loop1:   xor  dx,dx
         div  bx
         xchg ax,dx
         add  al,30
         stosb
         mov  ax,dx
         cmp  al,0                               ;last digit?
         jne  loop1
         inc  di                                 ;adjust to last digit offset
         mov  dx,di                              ;start of buffer
         mov  ah,9
         int  21
         ret
result   db  5 dup(0),'$'

;::
;:: Output error-string, indexed by AX.
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
outputerror:
         push si
         push bx
         push dx

         push ax                       ; Let's output a nice 'pre-text'
         mov  ah,9
         mov  dx,offset S_EOL
         int  21
         mov  dx,offset S_IOERROR
         int  21
         pop  ax

         mov  si,offset ERRORS_TABLE
         mov  dx,offset ERRORS_BASE
         mov  bx,ax
         cmp  bx,ERRORS_ENTRIES
         jb   outputerror_continue
         mov  bx,ERRORS_ENTRIES
outputerror_continue:
         dec  bx
         shl  bx,1
         add  dx,word ptr ds:si[bx]
         mov  ah,9
         int  021h
         mov  ah,2
         mov  dl,010d
         int  21
         mov  dl,013d
         int  21
         pop  dx
         pop  bx
         pop  si
         ret

;::
;:: Initialize variables
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
init_vars:
         mov  filehandle,0
         mov  fileptr,0
         mov  progressdir,0
         mov  progressnum,PROGRESSMAX
         mov  progressslow,PROGRESSDELAY
         mov  patchcount,0
         xor  eax,eax
         xor  ebx,ebx
         xor  ecx,ecx
         xor  edx,edx
         cld
         push ds
         pop  es
         ret

;::
;:: Setup the pointers into the patch-data buffer. Indexed by SI
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
setup_pointers:
         mov  ax,[si]
         mov  patchofs,ax
         mov  ax,[si+2]
         mov  patchlen,ax
         add  si,4
         mov  patchbufptr,si
         add  si,patchlen
         mov  ax,[si]
         mov  scanlen,ax
         add  si,2
         mov  scanbufptr,si
         add  si,ax
         mov  messageptr,si
         ret

;::
;:: Exit with errorlevel 00
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
doexit:
         mov  ah,1
         mov  cx,cursor
         int  10                                 ; Restore cursor

         mov  ax,04c00h
         int  021h

;::
;:: Process the file pointed to by 'filenameptr'
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
process_file:
         call init_vars

         mov  ah,9
         mov  dx,offset S_PATCHMSG
         int  21
         mov  dx,messageptr
         int  21                                 ; Output message

         mov  ah,2
         mov  dl,']'
         int  21
         
         mov  ah,9
         mov  dx,offset S_SCANNING
         int  21
         mov  dx,filenameptr
         int  21

         mov  ax,4300
         int  21                                 ; Get attrib (filen @ ds:dx)
         jnc  proceed1                           ; Did the file exist? >--+
         call outputerror                        ;                        |
         jmp  process_exit                       ; No - exit  <-----------+
proceed1:                                        ;                        |
         mov  fileattribute,cx                   ; Yes - Save attribute <-+

         mov  ax,4301
         xor  cx,cx
         int  21                                 ; Clear file attributes

         mov  ax,3D02                            ; 02 => 12 ?! (Deny all)
         int  21                                 ; Open file (ds:dx)
         mov  filehandle,ax                      ; Save filehandle

         mov  bx,ax
         mov  ax,5700
         int  21                                 ; Get file date/time
         mov  filetime,cx
         mov  filedate,dx

         mov  ah,2
         mov  dl,'['
         int  21

         mov  ah,3
         xor  bh,bh
         int  10                                 ; Get video info.
         mov  progresspos,dx                     ; Save cursor position

         mov  cx,PROGRESSMAX
         mov  ah,2
         mov  dl,'ú'
loopz1:  int  21
         loop loopz1                             ; output cx*[dl]
         mov  dl,']'
         int  21
         mov  dl,8
         int  21
repeat:
XOR EAX,EAX ;**
         mov  ah,3F
         mov  bx,filehandle
         mov  cx,SEARCHBUFFERSIZE
         mov  dx,offset SEARCHBUFFER
         int  21                                 ; Read bytes into buffer
         jnc  proceed2                           ; Error? No = Proceed
         call outputerror                        ; else output error..
         jmp  process_exit                       ; ... and quit

proceed2:
         mov  searchlen,ax                       ; store bytes actually read.
         add  fileptr,eax

         call sc_buffer                         ; scan thru buffer..
         cmp  ax,0FFFF                          ; Scanstring found?
         je   proceed3                          ; No - Jump

         inc  patchcount                        ; Yes baby - come to papa!
         mov  ecx,fileptr
         mov  bx,searchlen
         sub  ecx,ebx
         add  ecx,eax
         mov  ax,PATCHOFS
         add  ecx,eax
;         sub  ecx,128                          ; allow for negative offsets
         mov  fileptr,ecx
         mov  ax,4200
         mov  bx,filehandle
         mov  cx,word ptr [fileptr+2]
         mov  dx,word ptr [fileptr]
         int  21                                ; Seek to patch-offs in file
         jnz  proceeda
         call outputerror
         jmp  process_exit
proceeda:
         mov  ah,40
         mov  bx,filehandle
         mov  cx,patchlen
         mov  dx,patchbufptr
         int  21                                ; Apply patch-data
         jnc  proceed3
         call outputerror
         jmp  process_exit

proceed3:
         mov  ax,SEARCHLEN
         cmp  ax,SEARCHBUFFERSIZE                ; Last read reached EoF?
         jne  close                              ; Yes - close down.
         mov  ax,4200                            ; no - let's seek back...
         mov  bx,filehandle
         mov  cx,SCANLEN
         sub  fileptr,ecx
         mov  cx,word ptr[fileptr+2]
         mov  dx,word ptr[fileptr]
         int  21                                 ; Move filepointer back
;         call progress_update
         jmp  repeat                             ; Process next block

close:
         mov  ah,2
         xor  bh,bh
         mov  dx,progresspos
         int  10                                 ; Move curs to start of progr.
         xor  ch,ch
         mov  cl,PROGRESSMAX
         mov  dl,'ú'
         mov  ah,2
loopz2:  int  21                                 ; func 2!
         loop loopz2                             ; output cx*[dl]
proceed4:
         mov  ah,9
         mov  dx,offset S_DOT
         int  21
         mov  ax,patchcount
         call printn
         mov  dx,offset S_PATCHED1
         int  21
         cmp  patchcount,1
         je   no_s
         mov  dl,'s'
         mov  ah,2
         int  21
no_s:    mov  ah,9
         mov  dx,offset S_PATCHED2
         int  21

process_exit:
         cmp  filehandle,0
         je   xit

         mov  ax,5701
         mov  bx,filehandle
         mov  cx,filetime
         mov  dx,filedate
         int  21                                 ; Restore file date/time

         mov  ah,3E
         int  21                                 ; Close file (BX=handle)

         mov  ax,4301
         mov  dx,filenameptr
         mov  cx,fileattribute
         int  21                                 ; Restore attribute

xit:     ret

;::: Datablock :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.data

.radix 10
include               sarucity.inc
.radix 16

                      db 'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',8
                      db 'Ä',7,'Ä',7,'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',7,'Ä',8,'Ä',8
                      db 'Ä',7,'Ä',8,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'-',7,'Ä',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'-',7,'Ä',7,'Ä',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7
                      db '-',8,'-',8,'Ä',7,'Ä',7,'-',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7
                      db '-',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'Ä',7,'Ä',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',8,'Ä',7,'Ä',8
                      db 'Ä',8,'Ä',7,'Ä',7,'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',8

include               product.inc

                      db 'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'-',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'-',7,'Ä',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7
                      db 'Ä',7,'-',8,'-',8,'Ä',7,'Ä',7,'-',7,'Ä',7,'Ä',7,'Ä',7
                      db 'Ä',7,'-',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'-',7,'Ä',7,'Ä',7
                      db 'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',7,'Ä',8,'Ä',7
                      db 'Ä',8,'Ä',8,'Ä',7,'Ä',7,'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',8
                      db 'Ä',8,'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',8,'Ä',7,'Ä',8,'Ä',8
                      db 'Ä',7,'Ä',7,'Ä',8,'Ä',8,'Ä',8,'Ä',7,'Ä',8,'Ä',8

s_dot                 db NL,' ú $'
s_scanning            db NL,' ú Scanning $'
s_patchmsg            db ' ú Processing patch [$'
s_patched1            db ' occurence$'
s_patched2            db ' patched.',NL,'$'
s_ioerror             db ' ú I/O Error: $'
s_eol                 db NL,'$'
s_dbs                 db 8,' ',8,'$'
s_byemsg              db ' ú Saruman / DFR Research & Engineering signing off.$'

include               errors.inc

;:: Patch 1 - Registration-crack
;::
patch1         dw 6                               ; relative patch offset
               dw offset pdataend1-$-2
               db 1                               ; ... patch with this
pdataend1      dw offset sdataend1-$-2
               db 0C6,5,68,27,44,0,0              ; ... scan for this
sdataend1      db ' *REGISTRATION* $' ; patch name
;:: end-of-patch 1

filename1             db 'SPATCH.COM',0,'$'

;;; Pointers
patchofs              dw ?
patchlen              dw ?
patchbufptr           dw ?
scanlen               dw ?
scanbufptr            dw ?
messageptr            dw ?

filenameptr           dw ?

filetime              dw ?
filedate              dw ?
fileattribute         dw ?
filehandle            dw ?
fileptr               dd ?

progresspos           dw ?
progressdir           db ?
progressnum           db ?
progressslow          db ?
patchcount            dw ?

cursor                dw ?

searchlen             dw ?
searchbuffer          db SEARCHBUFFERSIZE dup (?)

end	main
