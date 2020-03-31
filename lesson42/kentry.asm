%include "common.asm"

global _start

extern gGdtInfo
extern RunTask
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
	
	mov eax, dword [RunTaskEntry]
	mov dword  [RunTask], eax
	
	leave
	ret