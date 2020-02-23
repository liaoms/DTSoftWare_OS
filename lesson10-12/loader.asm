%include "inc.asm"

org 0x9000	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

jmp CODE16_SEGMENT	;跳转执行

[section .gdt]	;定义一个源码级别的代码段
; GDT definition
;
;                                 段基址       段界限              段属性
GDT_ENTRY    :     Descriptor        0,          0,                   0        ;全局段入口(0占位)
CODE32_DESC  :     Descriptor        0,    Code32SegLen -1,       DA_C + DA_32 ;定义第一个32位代码段

; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0
		
; GDT Selector(定义选择子)

Code32Selector    equ (0x001 << 3) + SA_TIG + SA_RPL0

; end of [section .gdt]

;实模式的代码段定义
[section .s16]
[bits 16]	;16位模式
CODE16_SEGMENT:
    mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, 0x7c00

	;初始化32位的代码段的段基地址
	mov eax, 0	;eax寄存器为ax寄存器的延伸，有32位
	mov ax, cs
	shl eax, 4
	add eax, CODE32_SEGMENT
	mov word [CODE32_DESC + 2], ax	;初始化代码段低32位的31-16位的段基地址(位置为增加2字处)
	shr eax, 16
	mov byte [CODE32_DESC + 4], al	;初始化代码段高32位的7-0位的段基地址(位置为增加4字节处)
	mov byte [CODE32_DESC + 7], ah	;初始化代码段高32位的31-14位的段基地址(位置为增加7字节处)
	
	; 初始化GdTPtr结构体值
	mov eax, 0
	mov ax, ds
	shl eax, 4
	add eax, GDT_ENTRY
	mov dword [GdtPtr + 2], eax
	
	;1-加载全局段描述符表
	lgdt [GdtPtr]
	
	;2-关中断
	cli
	
	;3-打开 A20地址线
	in al, 0x92
	or al, 00000010b
	out 0x92, al
	
	;4-通知处理器进入保护模式
	mov eax, cr0
	or eax, 0x01
	mov cr0, eax
	
	;5-从16位模式跳转到32位模式
	jmp dword Code32Selector : 0
	
;定义32位代码段
[section .s32]	
[bits 32]
CODE32_SEGMENT:  
	mov eax, eax
    jmp CODE32_SEGMENT

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限










    