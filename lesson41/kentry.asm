
global _start

extern KMain
extern ClearScreen

[section .text]
[bits 32]
_start:
    mov ebp, 0
    
	call ClearScreen
    call KMain
    
    jmp $