
global _start
global vstr   ;对外接口，供C文件使用
global vlen
global print

extern fun_c   ;应用C文件里的函数名

[section .data]
	vstr db "hello", 0x0A
	vlen dd $ - vstr

[section .text]
_start:
	mov ebp, 0

	call fun_c  ;调用C文件的函数
	
	call exit

print:
	push ebp	;函数调用的固定格式
	mov ebp, esp
	
	mov edx, [ebp + 12]  ;获取第一个参数
	mov ecx, [ebp + 8]   ;获取第二个参数(参数从右向左压入栈)
	mov ebx, 1
	mov eax, 4   ;system_write   0x80中断下4号打印系统调用
	int 0x80
	
	pop ebp
	ret
	
exit:
	mov ebx, 0
	mov eax, 1   ;system_wait
	int 0x80