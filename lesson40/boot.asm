
BaseOfBoot equ 0x7C00

org BaseOfBoot	;起始位置

%include "blfunc.asm"

interface:
	BaseOfStack equ BaseOfBoot
	BaseOfTarget equ 0x9000
	Target db "LOADER     "
	TarLen	equ ($-Target)


BLMain:
    mov ax, cs
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov sp, SPInitValue	;栈顶地址赋值到sp寄存器

	call LoadTarget
	
	cmp dx, 0
	jz output
	jmp BaseOfTarget

output:
	mov bp, ErrStr
	mov cx, ErrLen
	call Print

	jmp $
	

ErrStr db  "No LOADER"    	;定义打印字符串
ErrLen equ ($-ErrStr)			;定义字符串长度($(为当前指令地址) - MsgStr(字符串起始地址))
Buffer:	
    times 510-($-$$) db 0x00 ;512字节剩下的部分0填充，并以0x55 0xaa结束
    db 0x55, 0xaa