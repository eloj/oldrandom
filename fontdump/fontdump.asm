; Program: MS-DOS Font Dumper
;          Created by Eddy L O Jasson <srm_dfr@hotmail.com>
;          http://gazonk.org/~eloj

.model tiny
.code
.radix 16
.386

; ----------------------------------------------------
; a working fontdump.com image, should you happen to
; have no assembler:
;
; 00:  BA 8C 01 33 C9 B4 3C CD 21 A3 99 01 06 B8 30 11
; 10:  B7 02 CD 10 07 89 0E 9B 01 1E FA BA C4 03 B8 02
; 20:  04 EF B8 04 07 EF BA CE 03 B8 04 02 EF B8 05 00
; 30:  EF B8 06 00 EF FB B8 00 A0 8E D8 33 F6 BA FF 00
; 40:  8B D9 B8 20 00 2B C3 BF 9D 01 8B CB F3 A4 03 F0
; 50:  4A 75 F7 FA BA C4 03 B8 02 03 EF B8 04 03 EF BA
; 60:  CE 03 B8 04 00 EF B8 05 10 EF B8 06 0E EF FB 1F
; 70:  BA 9D 01 8B 0E 9B 01 C1 E1 08 8B 1E 99 01 B4 40
; 80:  CD 21 8B 1E 99 01 B4 3E CD 21 C3 00 66 6F 6E 74
; 90:  64 75 6D 70 2E 62 69 6E 00
; ----------------------------------------------------

;::: Codeblock :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

org      100h

main:
      mov  dx,offset filename
      xor  cx,cx
      mov  ah,3C
      int  21                         ; Create file
      mov  filehandle,ax

      push es
      mov  ax,1130
      mov  bh,2
      int  10                         ; Get bytes per char (BPC) in cx
      pop  es
      mov  bytes_per_char,cx

      push ds                         ; prepare for a little dark magick

      cli
      mov  dx,3C4
      mov  ax,402
      out  dx,ax                      ; write to VGA sequencer index
      mov  ax,704
      out  dx,ax
      mov  dx,3CE
      mov  ax,204
      out  dx,ax                      ; write to VGA graphics index
      mov  ax,5
      out  dx,ax
      mov  ax,6
      out  dx,ax
      sti

      mov  ax,0A000                   ; font data now available at A000:0000
      mov  ds,ax
      xor  si,si

      mov  dx,0ff                     ; we want all characters
      mov  bx,cx                      ; cx = bytes per char
      mov  ax,20
      sub  ax,bx                      ; calculate "font row skip"
    ; shr  bx,1                       ; could do that and then movsw, but what about odd char heights?
      mov  di, offset fontbuffer
copy_next_char:                       ; copy each character into the buffer
      mov  cx,bx
      rep  movsb
      add  si,ax
      dec  dx
      jnz  copy_next_char

      cli                             ; take us out again
      mov  dx,3C4
      mov  ax,302
      out  dx,ax                      ; write to VGA sequencer index
      mov  ax,304
      out  dx,ax
      mov  dx,3CE
      mov  ax,4
      out  dx,ax                      ; write to VGA graphics index
      mov  ax,1005
      out  dx,ax
      mov  ax,0E06
      out  dx,ax
      sti

      pop  ds                         ; phew, finally

      mov  dx, offset fontbuffer
      mov  cx,bytes_per_char          ; retrieve
      shl  cx,8                       ; multiply by 256 -- giving us size of buffer

      mov  bx,filehandle
      mov  ah,40
      int  21                         ; Write buffer to file

      mov  bx,filehandle
      mov  ah,3E
      int  21                         ; Close file

      ret

;::: Datablock :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
.data
  filename              db 'fontdump.bin',0
  filehandle            dw ?
  bytes_per_char        dw ?
  fontbuffer            db 2000 dup (?)

end     main
