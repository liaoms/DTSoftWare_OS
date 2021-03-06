%include "inc.asm"

org 0x9000	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

jmp ENTRY_SEGMENT	;跳转执行

[section .gdt]	;定义一个源码级别的代码段
; GDT definition
;
;                                 段基址       段界限              段属性
GDT_ENTRY    :     Descriptor        0,          0,                   0        ;全局段入口(0占位)
CODE32_DESC  :     Descriptor        0,    Code32SegLen -1,       DA_C + DA_32 + DA_DPL1 ;定义第一个32位代码段描述符,代码段特权级为地特权级3，默认为高特权级0
VIDEO_DESC   :     Descriptor     0xB8000,     0x07FFF,           DA_DRWA + DA_32  + DA_DPL2 ;	定义一个显示段范围0xB8000~0xBFFFF，段界限为偏移地址的最大值(0xBFFFF-0xB8000)属性为 已访问的可读写数据段 + 保护模式下32位段
DATA32_DESC  :     Descriptor        0,    Data32SegLen - 1,      DA_DR + DA_32  + DA_DPL2  ; 定义数据段描述符   
STACK32_DESC :     Descriptor        0,    TopOfStack32,          DA_DRW + DA_32  + DA_DPL1 ;定义32为保护模式下栈段描述符(栈空间)
FUNCTION_DESC   :  Descriptor        0,     FunctionSegLen - 1,   DA_C + DA_32 + DA_DPL1
NEW_DESC     :  Descriptor           0,     NewSegLen - 1,   	  DA_CCO + DA_32 + DA_DPL0   ;DA_CCO表示一致性代码段

;非一致性代码段只能平级跳转 即 CPL = DPL,如 CODE32_DESC 跳转到FUNCTION_DESC，特权级必须相等，描述符的特权级，一般与选择子的特权级保持一致
;一致性代码段跳到一致性代码段，需要CPL >= DPL  ,如CODE32_DESC 跳转到NEW_DESC，CODE32_DESC 特权级必须 <= NEW_DESC的特权级


; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度 

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0
		
; GDT Selector(定义选择子)

Code32Selector    equ (0x0001 << 3) + SA_TIG + SA_RPL1  ;第一个代码段的选择子下标为1 (0x001), 跟随特权级改动为RPL3
VideoSelector     equ (0x0002 << 3) + SA_TIG + SA_RPL2  ;显示段的选择子下标为2 (0x002)
Data32Selector    equ (0x0003 << 3) + SA_TIG + SA_RPL2  ;数据段的选择子下标为3 (0x003)
Stack32Selector   equ (0x0004 << 3) + SA_TIG + SA_RPL1  ;32为保护模式下栈段的选择子下标为4 (0x004)
FunctionSelector  equ (0x0005 << 3) + SA_TIG + SA_RPL1  
NewSelector       equ (0x0006 << 3) + SA_TIG + SA_RPL0

; end of [section .gdt]

TopOfStack16 equ 0x7c00   ;定义常量，16位模式下的栈顶初始值

;定义一个32位模式的数据段
[section .dat]
[bits 32]
DATA32_SEGMENT:
	DTOS    db "D.T.OS!", 0  ;以0结尾的字符串 "D.T.OS!"
	DTOS_OFFSET equ DTOS - $$ ;字符串"D.T.OS!" 在数据段的偏移地址

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
	
	;32位保护模式栈段初始化
	mov esi, STACK32_SEGMENT
	mov edi, STACK32_DESC
	call InitDescItem
	
	;初始化函数代码段
	mov esi, FUNCTION_SEGMENT
	mov edi, FUNCTION_DESC
	call InitDescItem
	
	;初始化一致性代码段
	mov esi, NEW_SEGMENT
	mov edi, NEW_DESC
	call InitDescItem
	
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
	;jmp dword Code32Selector : 0
	
	;高特权级跳转到低特权级步骤
	;跳到第特权级选择子Code32Selector对应的代码段处执行,即CODE32_SEGMENT代码段处
	push Stack32Selector  	;目标栈段选择子
	push TopOfStack32		;目标栈段栈顶指针位置
	push Code32Selector		;目标代码段选择子
	push 0					;目标代码段偏移地址
	
	retf					;跳转指令，高特权级跳到低特权级 (0 -> 3)  

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
	
	
;定义32位代码段
[section .s32]	
[bits 32]
CODE32_SEGMENT:  
    mov ax, VideoSelector    ;加载显示段
	mov gs, ax
	
	mov ax, Stack32Selector ;设置栈空间(32位模式下有打印函数调用)
	mov ss, ax
	
	mov eax, TopOfStack32
	mov esp, eax  ;设置32位保护模式的栈顶
	
	;设置参数并调用打印函数
	mov ax, Data32Selector ;数据段选择子
	mov ds, ax
	mov ebp, DTOS_OFFSET  ;字符在数据段的偏移地址
	mov bx, 0x0c 	;打印属性黑底红字
	mov dh, 12 ;打印位置 12行33列
	mov dl, 33
	
	call FunctionSelector : PrintString ;调用选择子FunctionSelector对应代码段，偏移地址为PrintString处的函数(打印函数)

	jmp NewSelector : 0   ;跳转到一致性代码段(从非一致代码段跳转到一致性代码段, CPL >= DPL,必须是地特权级向高特权级跳转)

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限

;定义32位栈段,专用于保护模式
[section .gs]
[bits 32]
STACK32_SEGMENT:
	times 1024 * 4 db 0 ;定义一个4K的空间
	
Stack32SegLen equ $ - STACK32_SEGMENT ;栈长度
TopOfStack32 equ Stack32SegLen - 1  ;栈顶位置

;定义一个一致性代码段,描述符特权级定义为0
[section .new]
[bits 32]
NEW_SEGMENT:
	
	;设置参数并调用打印函数
	mov ax, Data32Selector ;数据段选择子
	mov ds, ax
	mov ebp, DTOS_OFFSET  ;字符在数据段的偏移地址
	mov bx, 0x0c 	;打印属性黑底红字
	mov dh, 13 ;打印位置 12行33列
	mov dl, 33
	
	;从非一致代码段跳转到此处一致性代码段，但当前特权级保持不变，依旧是非一致性代码段的特权级(地特权级)，所以在此处可以直接调用低特权级的打印代码段函数
	call FunctionSelector : PrintString ;调用选择子FunctionSelector对应代码段，偏移地址为PrintString处的函数(打印函数)
	jmp $
	
NewSegLen equ $ - NEW_SEGMENT


;定义一个32位代码函数段，用于存放共有函数
[section .fun]
[bits 32]
FUNCTION_SEGMENT:

;定义32位模式下的打印函数
;ds:ebp -> 字符串地址
;bx -> 打印属性
;dx -> 打印位置 dh(行), dl(列)
PrintStringFun:	
	push ebp
	push eax
	push edi
	push dx
	push cx
		
printfun:
	mov cl, [ds:ebp] ;一个个加载字符串内容
	cmp cl, 0
	je endfun
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
	
	jmp printfun
		
endfun:
	pop cx
	pop dx
	pop edi
	pop eax
	pop ebp
	
	retf
	
PrintString equ PrintStringFun - $$	 ;打印函数在代码段偏移地址

FunctionSegLen equ $ - FUNCTION_SEGMENT   

  