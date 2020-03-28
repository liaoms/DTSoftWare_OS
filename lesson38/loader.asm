%include "inc.asm"

org 0x9000	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

jmp ENTRY_SEGMENT	;跳转执行

[section .gdt]	;定义一个源码级别的代码段
; GDT definition
;
;                                 		段基址   			    段界限              段属性
GDT_ENTRY    		:   Descriptor        0,    			      0,                   0        	;全局段入口(0占位)
CODE32_DESC  		:   Descriptor        0,    			Code32SegLen -1,       	DA_C + DA_32 + DA_DPL3		;定义第一个32位代码段描述符,
VIDEO_DESC   		:   Descriptor     0xB8000, 			    0x07FFF,           	DA_DRWA + DA_32 + DA_DPL3	;定义一个显示段范围0xB8000~0xBFFFF，段界限为偏移地址的最大值(0xBFFFF-0xB8000)属性为 已访问的可读写数据段 + 保护模式下32位段
DATA32_DESC  		:   Descriptor        0,    			Data32SegLen - 1,      	DA_DRW + DA_32 + DA_DPL3	;定义数据段描述符   
STACK32U_DESC 		:   Descriptor        0,    			TopOfStack32U,          DA_DRW + DA_32 + DA_DPL3	;定义32为保护模式下栈段描述符(用户态栈空间)
STACK32K_DESC 		:   Descriptor        0,    			TopOfStack32K,          DA_DRW + DA_32 + DA_DPL0	;定义32位栈段描述符(内核态栈空间)
TSS_DESC 			:   Descriptor        0,    			TSSLen - 1,          	DA_386TSS + DA_DPL0	;TSS段描述符
KERNEL32_DESC 		:   Descriptor        0,    			Kernel32SegLen - 1,     DA_C + DA_32 + DA_DPL0	;内核代码段描述符
; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度 

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0

; GDT Selector(定义选择子)m

Code32Selector    		equ (0x0001 << 3) + SA_TIG + SA_RPL3  ;第一个代码段的选择子下标为1 (0x001),
VideoSelector     		equ (0x0002 << 3) + SA_TIG + SA_RPL3  ;显示段的选择子下标为2 (0x002)
Data32Selector    		equ (0x0003 << 3) + SA_TIG + SA_RPL3  ;数据段的选择子下标为3 (0x003)
Stack32USelector   		equ (0x0004 << 3) + SA_TIG + SA_RPL3  ;32为保护模式下栈段的选择子下标为4 (0x004)
Stack32KSelector   		equ (0x0005 << 3) + SA_TIG + SA_RPL0  ;内核态栈空间选择子
TSSSelector		   		equ (0x0006 << 3) + SA_TIG + SA_RPL0  ;tss段选择子
Kernel32Selector		equ (0x0007 << 3) + SA_TIG + SA_RPL0  ;内核代码段选择子
; end of [section .gdt]

;定义中断描述符表
[section .idt]
align 32
[bits 32]
IDT_ENTRY:
;x85有256个中断描述符，需要补全
;						选择子               偏移值        参数          属性
%rep 32
			Gate	Kernel32Selector,		DefaultHander, 		0,		DA_386IGate + DA_DPL3    ;DA_386IGate表示中断门  要在用户态调用内核态的中断服务程序，中断门的特权级要 <= 用户态
%endrep
	
Int0x20 :	Gate    Kernel32Selector,		TimerHandler,		0,		DA_386IGate + DA_DPL3		;0x20号中断十进制为32，所以要排在中断描述符表的128位，前边0~32,供占128个描述符，所以定义32个默认描述符	
	
%rep 95
			Gate	Kernel32Selector,		DefaultHander, 		0,		DA_386IGate + DA_DPL3    ;DA_386IGate表示中断门
%endrep
	
Int0x80 :	Gate    Kernel32Selector,		Int0x80Handler,		0,		DA_386IGate + DA_DPL3		;0x80号中断十进制为128，所以要排在中断描述符表的128位，前边0~127,供占128个描述符，所以定义128个描述符	

%rep 127
			Gate	Kernel32Selector,		DefaultHander, 		0,		DA_386IGate + DA_DPL3    ;DA_386IGate表示中断门   最后补全127和默认描述符
%endrep

IdtLen equ $ - IDT_ENTRY

IdtPtr:	;中断描述符地址
        dw IdtLen - 1
        dd 0

; end of [section .idt]



TopOfStack16 equ 0x7c00   ;定义常量，16位模式下的栈顶初始值

;定义一个tss段，用于设定不用特权级下所使用的栈
[section .tss]
[bits 32]
TSS_SEGMENT:
	dd		0	
	dd		TopOfStack32K		;0特权级使用的栈
	dd		Stack32KSelector		
	dd		0					;1特权级
	dd		0	
	dd 		0					;2特权级
	dd		0	
	times 4*18 dd 	0
	dw		0
	dw 		$ - TSS_SEGMENT + 2
	db		0xFF

TSSLen	equ $ - TSS_SEGMENT


;定义一个实模式的数据段
[section .data16]
DATA16_SEGMENT:
	MEM_ERR_MSG db "[FAILED] memory check error ..."
	MEM_ERR_MSG_LEN equ $ - MEM_ERR_MSG

Data16SegLen equ $ - DATA16_SEGMENT


;定义一个32位模式的数据段
[section .dat]
[bits 32]
DATA32_SEGMENT:
	DTOS    db "D.T.OS!", 0  ;以0结尾的字符串 "D.T.OS!"
	DTOS_LEN equ $ - DTOS		;当前地址 - 字符串起始地址 
	DTOS_OFFSET equ DTOS - $$ ;字符串"D.T.OS!" 在数据段的偏移地址(字符串起始地址 - 段起始地址)
	
	INT_80H    db "int 0x80", 0  ;以0结尾的字符串 "D.T.OS!"
	INT_80H_LEN equ $ - INT_80H		;当前地址 - 字符串起始地址 
	INT_80H_OFFSET equ INT_80H - $$ ;字符串"D.T.OS!" 在数据段的偏移地址(字符串起始地址 - 段起始地址)

Data32SegLen equ $ - DATA32_SEGMENT  ;数据段长度


;实模式的代码段定义
[section .s16]
[bits 16]	;16位模式
ENTRY_SEGMENT:
    mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16

	
	;代码段初始化
	mov esi, CODE32_SEGMENT
	mov edi, CODE32_DESC	
	call InitDescItem
	
	;数据段初始化
	mov esi, DATA32_SEGMENT
	mov edi, DATA32_DESC	
	call InitDescItem
	
	;32位保护模式用户态栈段初始化
	mov esi, STACK32U_SEGMENT
	mov edi, STACK32U_DESC
	call InitDescItem
	
	;32位内核态态栈段初始化
	mov esi, STACK32K_SEGMENT
	mov edi, STACK32K_DESC
	call InitDescItem
	
	;tss段初始化
	mov esi, TSS_SEGMENT
	mov edi, TSS_DESC
	call InitDescItem
	
	;内核代码段初始化
	mov esi, KERNEL32_SEGMENT
	mov edi, KERNEL32_DESC
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
	
	;1-加载全局段描述符表
	lgdt [GdtPtr]
	
	;2-关中断
	cli
	
	lidt [IdtPtr]   ;加载中断描述符表
	
	pushf
	pop eax
	
	or eax, 0x3000   ;将eflags的第12-13位置1(只能在特权级0下通过此种方式修改)，使得用户态与内核态都能正常访问IO                                                                                                                                                        

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
	
	;5-加载TSS段
	mov ax, TSSSelector
	ltr ax
	
	;6-从16位模式跳转到32位模式
	;jmp dword Code32Selector : 0
	
	;通过retf降特权级执行用户态的代码段
	push Stack32USelector
	push TopOfStack32U
	push Code32Selector
	push 0
	
	retf


	
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
	
;定义32位用户态代码段
[section .s32]	
[bits 32]
CODE32_SEGMENT:  
    mov ax, VideoSelector    ;加载显示段
	mov gs, ax
	
	mov ax, Stack32USelector ;设置栈空间(32位模式下有打印函数调用)
	mov ss, ax
	
	mov eax, TopOfStack32U
	mov esp, eax  ;设置32位保护模式的栈顶
	
	;设置参数并调用打印函数
	mov ax, Data32Selector ;设置数据段
	mov ds, ax
	
	;打印函数
	mov ebp, DTOS_OFFSET  ;
	mov dh, 12 ;打印位置 12行33列
	mov dl, 33
	
	call Printf   ;调用用户态打印函数，内部通过中断门调用内核态的中断函数，统一通过0x80中断调用(类似系统调用)
	
	call InitDevInt	;同上
	
	call EnableTimer
	
	jmp $   
	
;用户态的打印函数
; ds:ebp  ->打印字符串的地址
; dx -> dh:行  dl:列
Printf:
	;使用0x80号软中断实现
	push ax
	push bx
	
	mov ax, 1    
	mov bx, 0x0c
	
	int 0x80
	
	pop bx
	pop ax
	
	ret
	
;外部设备中断初始化
InitDevInt:
	push ax
	
	mov ax, 0	
	int 0x80

	sti  ;打开外部中断总开关
	
	pop ax
	
	ret
	
;开启时钟中断
EnableTimer:
	push ax
	
	mov ax, 2	
	int 0x80
	
	pop ax
	
	ret

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限

;创建一个内核代码段
[section .knl]
[bits 32]
KERNEL32_SEGMENT:
	
;默认中断服务程序
DefaultHanderFun:

	iret

DefaultHander equ DefaultHanderFun - $$   ;保护模式下，需要计算偏移地址
	
;0x80中断服务程序
Int0x80HandlerFun:

;初始化外部中断，通过ax的值不同，调用走不同的分支，即实现不同的系统调用功能
ax0:	
	cmp ax, 0
	jnz ax1
	call InitDevIntFunc
	iret

;字符串打印
ax1:
	cmp ax, 1
	jnz ax2
	call PrintString

	iret
;开启时钟中断
ax2:
	cmp ax, 2
	jnz ax2
	call EnableTimerFunc

	iret
	
ax3:
	iret

Int0x80Handler equ Int0x80HandlerFun - $$  ;保护模式下，需要计算偏移地址

;外部时钟中断服务程序
TimerHandlerFun:
	push ax
	push dx
	
	mov ax, [gs:((80*14 + 36) * 2)]  ;提取现存中，14行36列
	
	cmp al, '9'
	je throate
	inc al
	
	jmp thsow

throate:
	mov al, '0'
	
thsow:
	mov [gs:((80*14 + 36) * 2)], al  ;把值放回显存

	mov dx, MASTER_OCW2_PORT
	call WriteEOI

	pop dx
	pop ax
		
	iret

TimerHandler equ TimerHandlerFun - $$  ;保护模式下，需要计算偏移地址

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

;初始化8259A
InitDevIntFunc:
	push ax
	push dx
	
	call Init8259A  ;初始化8259A
 	
	mov ax, 0xFF  ;初始化完成后屏蔽所有外部中断
	mov dx, MASTER_IMR_PORT
	call WriteIMR
	
	pop dx
	pop ax
	
	ret
	
;触发时钟中断
EnableTimerFunc:
	push ax
	push dx
	
	mov ah, 0x0c
	mov al, '0'
	mov [gs:((80*14 + 36) * 2)], ax   ;显存放入一个字符
	
	mov dx, MASTER_IMR_PORT
	call ReadIMR  ;读主片中断屏蔽寄存器，结果在ax寄存器中

	and ax, 0xFE    ;将最低位置0(开启外部时钟中断开关)，即外部时钟所在应交IR0
	
	call WriteIMR   ;将ax写会dx表示的中断屏蔽寄存器
 	
	pop dx
	pop ax
	
	ret
	
;打印函数
PrintString:	
	push ebp
	push eax
	push edi
	push dx
	push cx
		
print:
	mov cl, [ds:ebp] ;一个个加载字符串内容
	cmp cl, 0
	je end
	mov eax, 80  
	mul dh  ;计算位置(行)
	add al, dl ;打印位置(列)
	shl eax, 1 ; * 2
	mov edi, eax
	mov ah, bl ;打印属性
	mov al, cl ;打印内容
	mov [gs:edi], ax ;放到显存中
	inc ebp	;下一个打印字符
	inc dl  ;下一个打印位置
	
	jmp print
		
end:
	pop cx
	pop dx
	pop edi
	pop eax
	pop ebp
	
	ret


Kernel32SegLen equ $ - KERNEL32_SEGMENT



;定义32位栈段,专用于保护模式、用户态
[section .gsu]
[bits 32]
STACK32U_SEGMENT:
	times 1024 * 4 db 0 ;定义一个4K的空间
	
Stack32USegLen equ $ - STACK32U_SEGMENT ;栈长度
TopOfStack32U equ Stack32USegLen - 1  ;栈顶位置

;定义32位栈段,专用于内核态
[section .gsk]
[bits 32]
STACK32K_SEGMENT:
	times 1024 * 4 db 0 ;定义一个4K的空间
	
Stack32KSegLen equ $ - STACK32K_SEGMENT ;栈长度
TopOfStack32K equ Stack32KSegLen - 1  ;栈顶位置







  
