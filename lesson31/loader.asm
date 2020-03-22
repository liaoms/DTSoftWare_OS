%include "inc.asm"

org 0x9000	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

jmp ENTRY_SEGMENT	;跳转执行

[section .gdt]	;定义一个源码级别的代码段
; GDT definition
;
;                                 		段基址   			    段界限              段属性
GDT_ENTRY    		:   Descriptor        0,    			      0,                   0        	;全局段入口(0占位)
CODE32_DESC  		:   Descriptor        0,    			Code32SegLen -1,       	DA_C + DA_32		;定义第一个32位代码段描述符,
VIDEO_DESC   		:   Descriptor     0xB8000, 			    0x07FFF,           	DA_DRWA + DA_32	;定义一个显示段范围0xB8000~0xBFFFF，段界限为偏移地址的最大值(0xBFFFF-0xB8000)属性为 已访问的可读写数据段 + 保护模式下32位段
DATA32_DESC  		:   Descriptor        0,    			Data32SegLen - 1,      	DA_DRW + DA_32	;定义数据段描述符   
STACK32_DESC 		:   Descriptor        0,    			TopOfStack32,          	DA_DRW + DA_32	;定义32为保护模式下栈段描述符(栈空间)
SYSDATE32_DESC      :   Descriptor        0,    			SysDate32SegLen - 1,    DA_DR + DA_32	;定义32为保护模式下只读数据段 
; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度 

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0
		
; GDT Selector(定义选择子)m

Code32Selector    		equ (0x0001 << 3) + SA_TIG + SA_RPL0  ;第一个代码段的选择子下标为1 (0x001),
VideoSelector     		equ (0x0002 << 3) + SA_TIG + SA_RPL0  ;显示段的选择子下标为2 (0x002)
Data32Selector    		equ (0x0003 << 3) + SA_TIG + SA_RPL0  ;数据段的选择子下标为3 (0x003)
Stack32Selector   		equ (0x0004 << 3) + SA_TIG + SA_RPL0  ;32为保护模式下栈段的选择子下标为4 (0x004)
SysDate32Selector   	equ (0x0005 << 3) + SA_TIG + SA_RPL0  ;定义32为保护模式下只读数据段 的选择子
; end of [section .gdt]

TopOfStack16 equ 0x7c00   ;定义常量，16位模式下的栈顶初始值

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
	
	HELLO    db "HELLO WORD!", 0  ;以0结尾的字符串 "D.T.OS!"
	HELLO_LEN equ $ - HELLO		;当前地址 - 字符串起始地址 
	HELLO_OFFSET equ HELLO - $$ ;字符串"D.T.OS!" 在数据段的偏移地址(字符串起始地址 - 段起始地址)

Data32SegLen equ $ - DATA32_SEGMENT  ;数据段长度


[section .sysdat]
[bits 32]
SYSDATE32_SEGMENT:
	MEM_SIZE 		times 4 db 0   			;定义4字节内存，用于保存物理内存容量
	MEM_SIZE_OFFSET equ MEM_SIZE - $$
	
	MEM_ADRS_NUM 	times 4 db 0   			;定义4字节内存，用于保存查到的ADRS结构的数量
	MEM_ADRS_NUM_OFFSET equ MEM_ADRS_NUM - $$
	
	MEM_ADRS 		times 64 * 20 db 0		;定义64个ADRS结构体，每个结构体占20个字节
	MEM_ADRS_OFFSET equ MEM_ADRS - $$

SysDate32SegLen equ $ - SYSDATE32_SEGMENT


;实模式的代码段定义
[section .s16]
[bits 16]	;16位模式
ENTRY_SEGMENT:
    mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16
	
	;获取物理内存大小
	;call GetMemSize   ;打断点，查看内存 MEM_SIZE 处的大小(单位为字节)，即为物理内存大小，此处大小为0x2000000 / 1024 / 1024 = 32M,与bochsrc里的内存配置大小一致
	call InitSysMenBuf ;打断点，查看MEM_ADRS_NUM、MEM_ADRS内存的地址值，MEM_ADRS每次查看1个ADRS结构体(20字节),地址查看方式为找到函数的入口地址，再在函数中找该两个变量的地址
	
	cmp eax, 0  ;判断内存获取结果
	
	jnz CODE16_MEM_ERR  ;不为0，出错则跳转
	
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
	
	;32位保护模式只读数据段初始化
	mov esi, SYSDATE32_SEGMENT
	mov edi, SYSDATE32_DESC
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
	jmp dword Code32Selector : 0
	
CODE16_MEM_ERR:
	
	mov bp, MEM_ERR_MSG
	mov cx, MEM_ERR_MSG_LEN
	call Print
	jmp $

;实模式下的打印函数
;es:bp -> 要打印的字符串
;cx  -> 字符串长度
Print:
	mov dx, 0
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10
	ret
	
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
	
;通过BIOS中断(int 0x15)基础功能(eax = 0xE801获取)，获取物理内存容量
GetMemSize:
	push eax
	push ebx
	push ecx
	push edx
	
	mov dword [MEM_SIZE], 0   ;保存地址清零
	
	xor eax, eax   ;eax及eax的最低位 CF 位清零
	mov eax, 0xE801 ;设置特殊寄存器值，为了触发中断后获取物理内存值
	int 0x15	;触发中断，获取物理内存，值保存待eax，ebx中(同时也保存在ecx，edx中，取一份即可)
	
	jc geterr   ;eax的最低位 CF 为1时，出错，跳转到 geterr处
	
	shl eax, 10   ;eax保存单位为1K, 乘以1024后得到字节数
	
	shl ebx, 6    ;ebx保存单位为64k， 值乘以64 ，再 乘以 1024，得到字节数
	shl ebx, 10
	
	mov dword [MEM_SIZE], eax	;将获取的内存值保存到目的内存处
	add dword [MEM_SIZE], ebx
	
	;(历史原因，存在内存黑洞,是的获取的内存容量比实际的少1M)
	mov ecx, 1	;补上1M的内存
	shl ecx, 20  ;转化为字节
	add dword [MEM_SIZE], ecx   ;累加到内存地址里
	 
	jmp getOK
	
geterr:
	mov dword [MEM_SIZE], 0  

getOK:
 	
	pop edx
	pop ecx
	pop ebx
	pop eax
	
	ret
	
;通过BIOS中断(int 0x15)高级功能(eax = 0xE820获取)，ADRS结构体获取物理内存容量
; return 
; eax -> 0 succeed    1  failed
InitSysMenBuf:
	push edi
	push ebx
	push ecx
	push edx
	
	call GetMemSize   ;先通过基础版方式获取内存，值保存在MEM_SIZE内存处
	
	mov edi, MEM_ADRS   ;结构体赋值到edi寄存器
	mov ebx, 0	;ebx 寄存器必须设置为0

doLoop:
	mov eax, 0xE820     ;特殊设置
	mov edx, 0x534D4150 ;特殊设置
	mov ecx, 20			;表示ADRS结构体大小(为20字节)
	
	int 0x15   ;触发中断， 将一个ADRS结构体内容存到edi所指向的MEM_ADRS地址中
	
	jc memerr   ;判断CF位是否为1，为1表示出错，跳转到memerr
	
	;ADRS结构体中type值为1表示内存可用，2表示不可用，3表示预留(视为可用)
	cmp dword [edi + 16], 1   ;比较获取到当前的type值是否为1
	jne next
	
	mov eax, dword [edi]     ;计算type为1的内存值   32位机ADRS计算内存只用到(BaseAddrLow(偏移地址0字节处) + LengthLow(偏移地址8字节处))
	add eax, dword [edi + 8]
	
	cmp dword [MEM_SIZE], eax	
	jnb next   ;if(MEM_SIZE > eax) -> jmp next
	
	mov dword [MEM_SIZE], eax   ;else MEM_SIZE = eax  ,最终MEM_SIZE 保存的是type=1下，的最大可用物理内存值
	
next:
	
	add edi, 20   ;正常提取一个ADRS结构体后，edi往后偏移20字节，准备保存下次循环提取的ADRS结构体(一个ADRS占用20字节)
	inc dword [MEM_ADRS_NUM]   ;ADRS结构体计数自增1
	
	cmp ebx, 0   ;判断 ebx 是否为0
	jne doLoop  ;不为0则继续循环， 为零则循环结束，接着往下走
	
	mov eax, 0   ;设置成功返回值
	jmp memok
	
memerr:
	mov eax, 1   ;设置失败返回值
	mov dword [MEM_SIZE], 0
	mov dword [MEM_ADRS_NUM], 0
	mov dword [MEM_ADRS], 0

memok:	
	pop edx
	pop ecx
	pop ebx
	pop edi


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
	mov ax, Data32Selector ;设置数据段
	mov ds, ax
	
	;打印函数
	mov ebp, DTOS_OFFSET  ;
	mov bx, 0x0c 	;打印属性黑底红字
	mov dh, 12 ;打印位置 12行33列
	mov dl, 33
	
	call PrintString 
	
	
	jmp $   
	
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

Code32SegLen    equ $ - CODE32_SEGMENT    ;定义32位代码段段界限

;定义32位栈段,专用于保护模式
[section .gs]
[bits 32]
STACK32_SEGMENT:
	times 1024 * 4 db 0 ;定义一个4K的空间
	
Stack32SegLen equ $ - STACK32_SEGMENT ;栈长度
TopOfStack32 equ Stack32SegLen - 1  ;栈顶位置







  
