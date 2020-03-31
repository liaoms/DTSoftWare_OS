
%include "blfunc.asm"
%include "common.asm"


org BaseOfLoader	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

interface:
	BaseOfStack equ BaseOfLoader	
	BaseOfTarget equ BaseOfKernel		;加载目标为内核文件
	Target db "KERNEL     "
	TarLen	equ ($-Target) 

[section .gdt]	;定义一个源码级别的代码段
; GDT definition
;
;                                 		段基址   			    段界限              段属性
GDT_ENTRY    		:   Descriptor        0,    			      0,                   0        	;全局段入口(0占位)
CODE32_DESC  		:   Descriptor        0,    			Code32SegLen -1,       	DA_C + DA_32 + DA_DPL0		;定义第一个32位代码段描述符,
VIDEO_DESC   		:   Descriptor     0xB8000, 			    0x07FFF,           	DA_DRWA + DA_32 + DA_DPL0	;定义一个显示段范围0xB8000~0xBFFFF，段界限为偏移地址的最大值(0xBFFFF-0xB8000)属性为 已访问的可读写数据段 + 保护模式下32位段
CODE32_FLAT_DESC  	:   Descriptor        0,    				0xFFFFF,       		DA_C + DA_32 + DA_DPL0		;平坦内存模型
DATA32_FLAT_DESC  	:   Descriptor        0,    			    0xFFFFF,      		DA_DRW + DA_32 + DA_DPL0	;定义数据段描述符  
TASK_LDT_DESC     	:   Descriptor        0,    			      0,      		    0	;定义数据段描述符  
TASK_TSS_DESC  	    :   Descriptor        0,    			      0,      		    0	;定义数据段描述符  

; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度 

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0
		
; GDT Selector(定义选择子)

Code32Selector    		equ (0x0001 << 3) + SA_TIG + SA_RPL0  
VideoSelector    		equ (0x0002 << 3) + SA_TIG + SA_RPL0  
Code32FlatSelector    	equ (0x0003 << 3) + SA_TIG + SA_RPL0  
Data32FlatSelector    	equ (0x0004 << 3) + SA_TIG + SA_RPL0  

; end of [section .gdt]


;实模式的代码段定义
[section .s16]
[bits 16]	;16位模式
BLMain:
    mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, SPInitValue
	
	;代码段初始化
	mov esi, CODE32_SEGMENT
	mov edi, CODE32_DESC	
	call InitDescItem
	
	; 初始化GdTPtr结构体值
	mov eax, 0
	mov ax, ds
	shl eax, 4
	add eax, GDT_ENTRY
	mov dword [GdtPtr + 2], eax
	
	call LoadTarget
	
	cmp dx, 0
	jz output
	
	call StoreGlobal
	
	;1-加载全局段描述符表
	lgdt [GdtPtr]
	
	;2-关中断
	cli
	
	;设置IOPL值为3，允许IO端口被访问
	pushf
	pop eax
	
	or eax, 0x3000
	
	push eax
	popf
	
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
	
output:
	mov bp, ErrStr
	mov cx, ErrLen
	call Print

	jmp $

;定义段描述符初始化函数
; esi -> 代码段标签
; edi -> 段描述符标签	
InitDescItem:
	
	push eax
	
	mov eax, 0	;eax寄存器为ax寄存器的延伸，有32位
	mov ax, cs
	shl eax, 4
	add eax, esi
	mov word [edi + 2], ax	;初始化代码段低32位的31-16位的段基地址(位置为增加2字处)
	shr eax, 16
	mov byte [edi + 4], al	;初始化代码段高32位的7-0位的段基地址(位置为增加4字节处)
	mov byte [edi + 7], ah	;初始化代码段高32位的31-14位的段基地址(位置为增加7字节处)
	
	pop eax
	ret
	
	
;
; 加载全局段描述符入口地址到共享内存地址
;
StoreGlobal:
	mov dword [RunTaskEntry], RunTask
	mov eax, [GdtPtr + 2]
	mov dword [GdtEntry], eax
	
	mov dword [GdtSize], GdtLen / 8
	
	ret
	
;
;
;
[section .gfunc]
[bits 32]
;
;参数 -> Task* pt
RunTask:
	push ebp
	mov ebp, esp
	mov esp, [ebp + 8] ;esp指向Task* pt 结构体的第一个成员 gs
	
	lldt word [esp + 200]
	ltr word [esp + 202]
	
	pop gs
	pop fs
	pop es
	pop ds
	
	popad
	
	add esp , 4  ;此刻esp指向任务入口代码的前一个元素，所以需要+4个字节，指向代码入口地址
	
	iret  ;启动任务
	
;定义32位代码段
[section .s32]	
[bits 32]
CODE32_SEGMENT:  

	mov ax, VideoSelector
	mov gs, ax
	
	mov ax, Data32FlatSelector
	mov ds, ax
	mov es, ax
	mov fs, ax

	mov ax, Data32FlatSelector
	mov ss, ax
	mov esp, BaseOfLoader

	jmp dword Code32FlatSelector : BaseOfKernel   ;跳到内核入口地址0xB000处执行 

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限

ErrStr db  "No KERNEL"    	;定义打印字符串
ErrLen equ ($-ErrStr)			;定义字符串长度($(为当前指令地址) - MsgStr(字符串起始地址))
Buffer:	db 0







  