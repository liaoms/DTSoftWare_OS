
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

;定义中断描述符表
[section .idt]
align 32
[bits 32]
IDT_ENTRY:
;x85有256个中断描述符，需要补全
;						选择子               偏移值        参数          属性
%rep 256
			Gate	Code32Selector,		DefaultHander, 		0,		DA_386IGate + DA_DPL0    ;DA_386IGate表示中断门
%endrep

IdtLen equ $ - IDT_ENTRY

IdtPtr:	;中断描述符地址
        dw IdtLen - 1
        dd 0

; end of [section .idt]


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
	
	; 初始化IdTPtr结构体值
	mov eax, 0
	mov ax, ds
	shl eax, 4
	add eax, IDT_ENTRY
	mov dword [IdtPtr + 2], eax
	
	call LoadTarget
	
	cmp dx, 0
	jz output
	
	call StoreGlobal
	
	;1-加载全局段描述符表
	lgdt [GdtPtr]
	
	;2-关中断
	cli
	
	lidt [IdtPtr]   ;加载中断描述符表
	
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
	
	;内核函数入口填入共享内存地址
	mov dword [RunTaskEntry], RunTask
	mov dword [InitInterruptEntry], InitInterrupt  
	mov dword [EnableTimertEntry], EnableTimer
	mov dword [SendEOIEntry], SendEOI
	
	;全局段描述符表放到共享内存
	mov eax, [GdtPtr + 2]    
	mov dword [GdtEntry], eax
	
	mov dword [GdtSize], GdtLen / 8
	
	;中断描述符表放到共享内存
	mov eax, [IdtPtr + 2]
	mov dword [IdtEntry], eax
	
	mov dword [IdtSize], IdtLen / 8
	
	ret

;
; 与中断相关的函数定义
;
[section .sfunc]
[bits 32]
;延时函数
Delay:
	%rep 5
	nop
	%endrep
	ret

;初始化8259A	
Init8259A:
	push ax
	
	;master 主片
	;ICW1 0x20端口
	mov al, 00010001B
	out MASTER_ICW1_PORT, al   ;0x20端口,边沿触发中断， 多片级联
	call Delay
	
	;ICW2  0x21端口
	mov al, 0x20   ;
	out MASTER_ICW2_PORT, al ;0x21端口,IR0中断向量为0x20
	call Delay
	
	;ICW3  0x21端口
	mov al, 00000100B
	out MASTER_ICW3_PORT, al ;0x21端口,从片级联值IR2引脚
	call Delay
	
	;ICW14   0x21端口
	mov al, 00010001B
	out MASTER_ICW4_PORT, al  ;0x21端口,特殊全嵌套，非缓冲数据连接，手动结束中断
	call Delay

	;Slave  从片
	;ICW1
	mov al, 00010001B
	out SLAVE_ICW1_PORT, al ;0xA0端口，边沿触发中断，多篇级联
	call Delay
	
	;ICW2
	mov al, 0x28
	out SLAVE_ICW2_PORT, al ;0xA1端口，IR0中断向量为0x28
	call Delay
	
	;ICW3
	mov al, 00000010B
	out SLAVE_ICW3_PORT, al ;0xA1端口，级联值至主片IR2引脚
	call Delay
	
	;ICW4
	mov al, 00000001B
	out SLAVE_ICW4_PORT, al ;0xA1端口，普通全嵌套，非缓冲数据连接，手动结束中断
	call Delay
	
	pop ax
	
	ret

;写中断屏蔽寄存器函数
; al -> 要写的值
; dx -> 8259A的端口
WriteIMR:
	out dx, al
	call Delay
	ret

;读中断屏蔽寄存器函数
; al -> 返回值
; dx -> 8259A的端口
ReadIMR:
	in ax, dx
	call Delay
	ret
	
;手工结束中断控制字
; dx -> 8259A的端口
WriteEOI:
	push ax
	
	mov al, 0x20
	out dx, al
	call Delay
	
	pop ax
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
	
;
; 初始化外部中断(8259A)
InitInterrupt:
	push ebp
	mov ebp, esp
	
	push ax
	push dx
	
	call Init8259A  ;初始化8259A
 	
	sti   ;打开总开关
	
	mov ax, 0xFF  ;初始化完成后屏蔽所有外部中断
	mov dx, MASTER_IMR_PORT
	call WriteIMR
	
	pop dx
	pop ax
	
	leave
	ret
	
;启用时钟中断函数
EnableTimer:
	push ebp
	mov ebp, esp
	
	push ax
	push dx
	
	mov dx, MASTER_IMR_PORT
	call ReadIMR  ;读主片中断屏蔽寄存器，结果在ax寄存器中

	and ax, 0xFE    ;将最低位置0(开启外部时钟中断开关)，即外部时钟所在应交IR0
	
	call WriteIMR   ;将ax写会dx表示的中断屏蔽寄存器
 	
	pop dx
	pop ax
	
	leave
	ret
	
;手工结束中断控制字 void SendEOI(uint port)
; port -> 8259A的端口
SendEOI:
	push ebp
	mov ebp, esp

	mov dx, [ebp + 8] ;获取参数port的值
	
	
	mov al, 0x20
	out dx, al
	
	call Delay
	
	leave
	ret
	
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
	
;默认中断服务程序
DefaultHanderFun:

	iret

DefaultHander equ DefaultHanderFun - $$   ;保护模式下，需要计算偏移地址

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限

ErrStr db  "No KERNEL"    	;定义打印字符串
ErrLen equ ($-ErrStr)			;定义字符串长度($(为当前指令地址) - MsgStr(字符串起始地址))
Buffer:	db 0







  