org 0x9000	;新增loader程序，供启动程序跳转到此处执行，起始地址为0x9000

begin:
	mov si, msg
	
;内容为打印字符串
print:
	mov al, [si]
	add si, 1
	cmp al, 0x00
	je end
	mov ah, 0x0E
	mov bx, 0x0F
	int 0x10
	jmp print

end:
	hlt
	jmp end
	
msg:
	db 0x0a, 0x0a
	db "Hello, D.T.OS!!!"
	db 0x0a, 0x0a
	db 0x00