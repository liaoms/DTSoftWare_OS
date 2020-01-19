org 0x7c00 ;指定起始地址为0x7c00

start:   ;关键寄存器清零
    mov ax, cs
    mov ss, ax
    mov ds, ax
    mov es, ax

    mov si, msg  ;将msg地址放入si寄存器中

print:
    mov al, [si]   ;取si寄存器中的一个字节数据
    add si, 1
    cmp al, 0x00   ;比较al是否到达信息尾
    je last
    mov ah, 0x0e
    mov bx, 0x0f
    int 0x10   ;调用中断，打印字符
    jmp print 

last:
    hlt
    jmp last

msg:
    db 0x0a, 0x0a   ;定义换行符
    db "Hello,DTOS!"  ;定义要打印的字符串
    db 0x0a, 0x0a
    times 510 - ($-$$) db 0x00  ;times 510 - ($-$$)为0占位符，确保启动程序为512字节
    db 0x55, 0xaa