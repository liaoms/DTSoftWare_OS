%include "common.asm"

global _start
global TimerHandlerEntry

extern TimerHandler

extern gCTaskAddr
extern gGdtInfo
extern gIdtInfo
extern RunTask
extern LoadTask
extern InitInterrupt
extern EnableTimer
extern SendEOI
extern KMain
extern ClearScreen

;定义宏，0表示该宏的使用不需要参数
%macro BeginISR 0
	sub esp, 4	;进入中断后，ss、esp、eflags、cs、ip已经保存到如上结构体位置处，esp此时指向预留raddr位置，需要减4跳过该位置
	pushad		;保存通用寄存器值
	
	push ds     ;保存特殊功能寄存器值
	push es
	push fs
	push gs     ;此时任务上下文寄存器值已经保存完毕
	
	mov dx, ss  ;设置中断中使用的数据段、堆栈段
	mov ds, dx
	mov es, dx
		
	mov esp, BaseOfLoader   ;避免保存的上下文寄存器值被破坏，需要将一个其他地址赋值给esp，供中断函数执行后内核栈的使用
%endmacro
	
%macro EndISR 0
	mov esp, [gCTaskAddr]  ;中断结束，将esp指向任务结构体开始处，准备恢复上下文
	
	pop gs    ;恢复段寄存器
	pop fs
	pop es
	pop ds
	
	popad		;恢复通用寄存器
	
	add esp, 4   ;跳过预留位置raddr

	iret  		;使用iret时，自动将ss、esp、eflags、cs、ip恢复
%endmacro

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
	
	mov eax, dword [LoadTaskEntry]
	mov dword [LoadTask], eax
	
	leave
	ret
	
	

;typedef struct {
;    uint gs;
;    uint fs;
;    uint es;
;    uint ds;
;    uint edi;
;    uint esi;
;    uint ebp;
;    uint kesp;
;    uint ebx;
;    uint edx;
;    uint ecx;
;    uint eax;
;    uint raddr;
;    uint eip;
;    uint cs;
;    uint eflags;
;    uint esp;
;    uint ss;
;} RegValue;
;
; 时钟中断程序入口
;
TimerHandlerEntry:
	
BeginISR
	call TimerHandler   ;调用中断业务函数
EndISR
	
	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	