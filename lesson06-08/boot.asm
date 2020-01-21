org 0x7c00	;起始位置

jmp short start  ;三个字节预制,jmp一个、start一个，nop占空符一个
nop

define:
    BaseOfStack equ 0x7c00 ;定义栈顶地址(定义函数时需要有栈，保存函数调用寄存器信息) ，equ方式不占内存

header:	;FAT12系统文件0扇区主引导区结构
    BS_OEMName     db "D.T.Soft"
    BPB_BytsPerSec dw 512
    BPB_SecPerClus db 1
    BPB_RsvdSecCnt dw 1
    BPB_NumFATs    db 2
    BPB_RootEntCnt dw 224
    BPB_TotSec16   dw 2880
    BPB_Media      db 0xF0
    BPB_FATSz16    dw 9
    BPB_SecPerTrk  dw 18
    BPB_NumHeads   dw 2
    BPB_HiddSec    dd 0
    BPB_TotSec32   dd 0
    BS_DrvNum      db 0
    BS_Reserved1   db 0
    BS_BootSig     db 0x29
    BS_VolID       dd 0
    BS_VolLab      db "D.T.OS-0.01"
    BS_FileSysType db "FAT12   "

start:
    mov ax, cs
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov sp, BaseOfStack	;栈顶地址赋值到sp寄存器
	
	mov ax, 34 ;读取的扇区为34号扇区,将34扇区号赋值到ax寄存器(读取扇区函数中除法用到)
	mov cx, 1	;读取1个扇区
	mov bx, Buf	;设置读取后存放内存位置,保存到Buf标签内存处
	
	call ReadSector	;读取扇区

	mov bp, Buf	;设置打印消息
	mov cx, 29	;设置打印长度
    
    ;mov bp, MsgStr	;设置打印消息(es:bp指定字符串内存地址)
    ;mov cx, MsgLen	;cx寄存器保存打印长度
    
    call Print 		;调用Print打印函数

; es:bp --> string address
; cx    --> string length
Print:
    mov ax, 0x1301	;设置关键寄存器
    mov bx, 0x0007
    int 0x10		;触发中断
    ret				;函数结尾标志
	
; no parameter
ResetPloppy:	;重置软驱函数
	push ax		;设置ah、dl寄存器前，先将对应的ax、dx寄存器入栈
	push dx
	mov ah, 0x00
	mov dl, [BS_DrvNum]	;设置逻辑扇区号(驱动器号)
	int 0x13
	pop dx	;重置软驱成功后恢复ax、dx寄存器值
	pop ax
	ret 
	
;ax ->保存逻辑扇区号
;cx ->保存读取扇区数
; es:bx ->保存读取的内容
ReadSector:	;读取软驱数据函数
	push bx
	push cx
	push dx
	push ax
	call ResetPloppy
	
	push bx
	push cx
	
	mov bl, [BPB_SecPerTrk]	;柱面扇区数赋值到bl寄存器
	div bl 		;做除法， (被除数默认存在ax寄存器)逻辑扇区号 / 柱面扇区数
	mov cl, ah	;获取余数(余数放在ah)
	add cl, 1	;获取扇区号(存入cl),余数+1为起始扇区号(存入cl)
	mov ch, al	;获取商(商放在al)
	shr ch, 1	;商右移一位，得到柱面号(存入ch)
	mov dh, al	
	and dh, 1	;商&1得到磁头号，存入dh
	mov dl, [BS_DrvNum]	;设置逻辑扇区号(驱动器号)

	pop ax
	pop bx
	
	mov ah, 0x02	;固定格式

read:	
	int 0x13	;触发软盘读取数据中断
	jc read		;读错时重读
	
	pop ax
	pop dx
	pop cx
	pop bx
	
	ret
MsgStr db  "Hello, DTOS!"    	;定义打印字符串
MsgLen equ ($-MsgStr)			;定义字符串长度($(为当前指令地址) - MsgStr(字符串起始地址))
Buf:	
    times 510-($-$$) db 0x00 ;512字节剩下的部分0填充，并以0x55 0xaa结束
    db 0x55, 0xaa
