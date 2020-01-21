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
    
    mov bp, MsgStr	;设置打印消息(es:bp指定字符串内存地址)
    mov cx, MsgLen	;cx寄存器保存打印长度
    
    call Print 		;调用Print打印函数

; es:bp --> string address
; cx    --> string length
Print:
    mov ax, 0x1301	;设置关键寄存器
    mov bx, 0x0007
    int 0x10		;触发中断
    ret				;函数结尾标志

MsgStr db  "Hello, DTOS!"    	;定义打印字符串
MsgLen equ ($-MsgStr)			;定义字符串长度($(为当前指令地址) - MsgStr(字符串起始地址))
Buf:	
    times 510-($-$$) db 0x00 ;512字节剩下的部分0填充，并以0x55 0xaa结束
    db 0x55, 0xaa
