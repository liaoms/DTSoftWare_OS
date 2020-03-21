%include "inc.asm"


PageDirBase0	equ 0x200000   	;定义页目录基地址
PageTblBase0	equ 0x201000	;定义子页表基地址
PageDirBase1	equ 0x300000   	;定义页目录基地址
PageTblBase1	equ 0x301000	;定义子页表基地址

ObjectAddrX		equ 0x401000	;目标虚地址    (最终目标为，在不同页表下，该虚地址映射到如下两个不同的物理地址处)
TargetAddrY		equ 0x501000	;目标物理地址
TargetAddrZ		equ 0x601000	;目标物理地址

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
PAGE_DIR_DESC0 		:	Descriptor    PageDirBase0,           	4095,             	DA_DRW + DA_32   ;页目录基地址描述符,页目录占4K(总共有1024个页目录，每个页目录占4字节)字节，即最大偏移地址为4095
PAGE_TBL_DESC0 		:   Descriptor    PageTblBase0,           	1023,             	DA_DRW + DA_32 + DA_LIMIT_4K	;有1024个子页表，每个页表占4K字节(每个子页表有1024页表项，每个页表项占4字节)，所以设定最大偏移地址为1023，偏移单位为4K(DA_LIMIT_4K),			
PAGE_DIR_DESC1 		:   Descriptor    PageDirBase1,           	4095,             	DA_DRW + DA_32   ;页目录基地址描述符,页目录占4K(总共有1024个页目录，每个页目录占4字节)字节，即最大偏移地址为4095
PAGE_TBL_DESC1 		:   Descriptor    PageTblBase1,           	1023,             	DA_DRW + DA_32 + DA_LIMIT_4K	;有1024个子页表，每个页表占4K字节(每个子页表有1024页表项，每个页表项占4字节)，所以设定最大偏移地址为1023，偏移单位为4K(DA_LIMIT_4K),
FLAT_MODE_RW_DESC 	:   Descriptor        0,           	      0xFFFFF,              DA_DRW + DA_32 + DA_LIMIT_4K	;平坦内存模型(实现保护模式下指哪写哪)，32位X86最大访问内存为4G，所以设定基地址为0，最大偏移地址为0xFFFFF，偏移单位为4K(DA_LIMIT_4K)，总共地址为4G

; GDT end

GdtLen  equ $ - GDT_ENTRY	;全局段的长度 

GdtPtr:	;全局段描述符地址
        dw GdtLen - 1
        dd 0
		
; GDT Selector(定义选择子)

Code32Selector    		equ (0x0001 << 3) + SA_TIG + SA_RPL0  ;第一个代码段的选择子下标为1 (0x001),
VideoSelector     		equ (0x0002 << 3) + SA_TIG + SA_RPL0  ;显示段的选择子下标为2 (0x002)
Data32Selector    		equ (0x0003 << 3) + SA_TIG + SA_RPL0  ;数据段的选择子下标为3 (0x003)
Stack32Selector   		equ (0x0004 << 3) + SA_TIG + SA_RPL0  ;32为保护模式下栈段的选择子下标为4 (0x004)
PageDirSelector0   		equ (0x0005 << 3) + SA_TIG + SA_RPL0  ;页目录选择子
PageTblSelector0   		equ (0x0006 << 3) + SA_TIG + SA_RPL0  ;子页表选择子
PageDirSelector1   		equ (0x0007 << 3) + SA_TIG + SA_RPL0  ;页目录选择子
PageTblSelector1   		equ (0x0008 << 3) + SA_TIG + SA_RPL0  ;子页表选择子
FlatModeRWSelector  	equ (0x0009 << 3) + SA_TIG + SA_RPL0  ;平坦内存模型选择子

; end of [section .gdt]

TopOfStack16 equ 0x7c00   ;定义常量，16位模式下的栈顶初始值

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



;实模式的代码段定义
[section .s16]
[bits 16]	;16位模式
ENTRY_SEGMENT:
    mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16

	;初始化32位的代码段的段基地址
	;mov eax, 0	;eax寄存器为ax寄存器的延伸，有32位
	;mov ax, cs
	;shl eax, 4
	;add eax, CODE32_SEGMENT
	;mov word [CODE32_DESC + 2], ax	;初始化代码段低32位的31-16位的段基地址(位置为增加2字处)
	;shr eax, 16
	;mov byte [CODE32_DESC + 4], al	;初始化代码段高32位的7-0位的段基地址(位置为增加4字节处)
	;mov byte [CODE32_DESC + 7], ah	;初始化代码段高32位的31-14位的段基地址(位置为增加7字节处)
	
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
	
	call PrintString  ;调用被代码段内的打印函数PrintString
	
	mov ax,FlatModeRWSelector ;使用平坦内存模型
	mov es, ax
	
	mov esi, DTOS_OFFSET  ;数据源为数据段偏移地址为 DTOS_OFFSET处的字符串[ds:esi]
	mov edi, TargetAddrY  ;目的地址为实际物理地址0x501000 [es:edi]
	mov ecx, DTOS_LEN
	
	call MemCpy32	;开始拷贝, 拷贝完成后可使用内存查看命令 x /8bx ds:esi  x /8bx 0x501000 分别查看ds:处8字节内容与 物理地址0x501000物理地址处8字节内容，结果一致，说明实现了保护模式下操作具体物理地址 
	
	mov esi, HELLO_OFFSET  ;数据源为数据段偏移地址为 HELLO_OFFSET处的字符串[ds:esi]
	mov edi, TargetAddrZ  ;目的地址为实际物理地址0x601000 [es:edi]
	mov ecx, HELLO_LEN
	
	call MemCpy32	;开始拷贝, 拷贝完成后可使用内存查看命令 x /8bx ds:esi  x /8bx 0x601000 分别查看ds:处8字节内容与 物理地址0x601000物理地址处8字节内容，结果一致，说明实现了保护模式下操作具体物理地址 

	
	;初始化第一个页表
	;mov eax, PageDirSelector0
	;mov ebx, PageTblSelector0
	;mov ecx, PageTblBase0
	;call InitPageTable
	
	;初始化第二个页表
	;mov eax, PageDirSelector1
	;mov ebx, PageTblSelector1
	;mov ecx, PageTblBase1
	;
	;call InitPageTable
	
	;切换第一个页表
	;mov eax, PageDirBase0
	;call SwitchPageTable
	
	;切换第二个页表
	;mov eax, PageDirBase1
	;call SwitchPageTable
	
	;call SetupPage	;页初始化	
	
	jmp $   ;断点可以打到此处，执行到此处，可以查看内存中数据段的值:  x /4bx ds:0    (表示以16进制查看4字节内容，查看地址为ds:0  即数据段偏移地址为0的地方)

;	-> 32位保护模式内存拷贝函数
;es ->平坦内存模型对应的选择子
;ds:esi	-> 拷贝源地址
;es:edi	-> 拷贝目标地址
;ecx		-> 拷贝长度
MemCpy32:
	
	push esi
	push edi
	push ecx
	push ax
	
	cmp esi, edi	;比较esi,edi大小
	ja btoe		; si > di,跳转到btoe(从头拷贝到尾)
	
	add esi, ecx	;si <= di, si和di位置移到内存尾部
	add edi, ecx
	dec esi		;指向尾部最后一个有效字节
	dec edi
	jmp etob
	
btoe:	;将si一个个字节拷贝到di(从前到后)
	cmp ecx, 0
	jz done
	mov al, [ds:esi]   
	mov byte [es:edi], al
	inc esi	;地址自增
	inc edi
	dec ecx
	jmp btoe
	
etob:	;将si一个个字节拷贝到di(从后到前)
	cmp ecx, 0
	jz done
	mov al, [ds:esi]
	mov byte [es:edi], al
	dec esi	;地址自减
	dec edi
	dec ecx
	jmp etob
	
done:
	pop ax
	pop ecx
	pop edi
	pop esi
	
	ret


;页初始化函数
; eax -> 页目录选择子
; ebx -> 页表选择子
; ecx -> 页表基地址
InitPageTable:
	
	push es
	push eax	;[esp + 12]
	push ebx	;[esp + 8]
	push ecx	;[esp + 4]
	push edi   	;[esp]
	
	
	;页目录初始化
	mov ax, [esp + 12]  ;页目录选择子
	mov es, ax
	mov ecx, 1024   ;循环1024次，总共有1024个页目录(即可以指向1024个子页表)
	mov edi, 0   ; 初始化的目的地址为[es:edi]
	mov eax, [esp + 4] ;页表基地址
	or eax, PG_P | PG_USU | PG_RWW ; PG_P(页存在属性为) | PG_USU(用户级) | PG_RWW(读/写/执行属性)
	
	cld ;edi 递增(32位系统按4字节)
	
stdir:
	stosd	;4字节方式复制
	add eax, 4096	;初始化的页目录的值，每次递增4096  (PageTblBase + 4096*i)  i=0~1023
	loop stdir
	
	;子页表初始化
	mov ax, [esp + 8]  ;页表选择子
	mov es, ax
	mov ecx, 1024 * 1024  ;子页表初始化为一个个子页表内的页表项初始化(1024个子页表，每个子页表1024个页表项，故循环1024*1024次初始化)
	mov edi, 0	;初始化地址[es:edi]
	
	mov eax, PG_P | PG_USU | PG_RWW ; 0(初始化初值0开始) | PG_P(页存在属性为) | PG_USU(用户级) | PG_RWW(读/写/执行属性)
	cld
	
sttbl:
	stosd
	add eax, 4096 ;页表项值每次递增4096
	loop sttbl
		
	pop edi
	pop ecx
	pop ebx
	pop eax
	pop es
	
	ret
	
;页表切换函数
;eax -> 页目录基地址
SwitchPageTable:

	push eax ;[esp]
	
	;暂时关闭页切换(cr0寄存区最高位置0)
	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax
	
	;开启硬件分页机制
	mov eax, [esp]  ;将cr3指向也目录地址
	mov cr3, eax
	
	mov eax, cr0 	;将cr0最高位置1
	or eax, 0x80000000
	mov cr0, eax

	pop eax
	
	ret
	
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







  