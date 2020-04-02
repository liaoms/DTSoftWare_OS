%include "common.asm"

global _start

extern gGdtInfo
extern gIdtInfo
extern RunTask
extern InitInterrupt
extern EnableTimer
extern SendEOI
extern KMain
extern ClearScreen

[section .text]
[bits 32]
_start:
    mov ebp, 0
    
	call InitGlobal
	call ClearScreen
    call KMain
    
    jmp $
	
;将共享内存地址中的全局段描述符地址值加载到全局变量中，供C代码使用
InitGlobal:
	push ebp
	mov ebp, esp
	
	mov eax, dword [GdtEntry]
	mov [gGdtInfo], eax
	mov eax, dword [GdtSize]
	mov [gGdtInfo + 4], eax   ;全局段吗，描述符大小加载到gGdtInfo结构体偏移4地址处
	
	mov eax, dword [IdtEntry]
	mov [gIdtInfo], eax
	mov eax, dword [IdtSize]
	mov [gIdtInfo + 4], eax   ;获取共享内存中的中断描述符表地址
	
	mov eax, dword [RunTaskEntry]
	mov dword  [RunTask], eax
	
	mov eax, dword [InitInterruptEntry] ;获取共享内存地址中中断相关函数地址
	mov dword  [InitInterrupt], eax
	
	mov eax, dword [EnableTimertEntry]
	mov dword  [EnableTimer], eax
	
	mov eax, dword [SendEOIEntry]
	mov dword [SendEOI], eax
	
	leave
	ret