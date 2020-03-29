
jmp short _start  ;三个字节预制,jmp一个、start一个，nop占空符一个
nop

header:	;FAT12系统文件0扇区主引导区结构
    BS_OEMName     db "D.T.Soft"
    BPB_BytsPerSec dw 512
    BPB_SecPerClus db 1
    BPB_RsvdSecCnt dw 1
    BPB_NumFATs    db 2
    BPB_RootEntCnt dw 224
    BPB_TotSec16   dw 2880
    BPB_Media      db 0xF0
    BPB_FATSz16    dw 9
    BPB_SecPerTrk  dw 18
    BPB_NumHeads   dw 2
    BPB_HiddSec    dd 0
    BPB_TotSec32   dd 0
    BS_DrvNum      db 0
    BS_Reserved1   db 0
    BS_BootSig     db 0x29
    BS_VolID       dd 0
    BS_VolLab      db "D.T.OS-0.01"
    BS_FileSysType db "FAT12   "
	
const:
	RootEntryOffset equ 19	;根目录从19扇区开始
	RootEntryLength	equ 14	;连续读取14个扇区
	SPInitValue		equ BaseOfStack - EntryItemLength
	EntryItem		equ SPInitValue
	EntryItemLength	equ 32
	FatEntryOffset	equ 1
	FatEntryLength	equ 9

_start:
	jmp BLMain
	

;
; return :
;	dx -> (dx != 0) : succeed : failed
;
;
LoadTarget:
	mov ax, RootEntryOffset ;读取的扇区为19号扇区,将19扇区号赋值到ax寄存器(读取扇区函数中除法用到)
	mov cx, RootEntryLength	;读取14个扇区
	mov bx, Buffer	;设置读取后存放内存位置,保存到Buffer标签内存处
	
	call ReadSector	;读取扇区
	
	mov si, Target
	mov cx, TarLen
	mov dx, 0
	
	call FindEntry
	
	cmp dx, 0
	jz finish	
	
	mov si, bx		
	mov di, EntryItem
	mov cx, EntryItemLength
	
	call MemCpy		;内存拷贝
	
	mov ax, FatEntryLength
	mov cx, [BPB_BytsPerSec]
	mul cx
	mov bx, BaseOfTarget
	sub bx, ax
	
	mov ax, FatEntryOffset
	mov cx, FatEntryLength
	
	call ReadSector
	
	mov dx, [EntryItem + 0x1A] ;获取第一个扇区的位置
	mov si, BaseOfTarget / 0x10
	mov es, si
	mov si, 0	;目标地址处
	
	
;ax ->保存逻辑扇区号
;cx ->保存读取扇区数
; es:bx ->保存读取的内容
loading:
	mov ax, dx
	add ax, 31
	mov cx, 1
	push dx
	push bx
	mov bx, si
	call ReadSector
	pop bx
	pop cx
	call FatVec
	cmp dx, 0xFF7
	jnb finish
	add si, 512	;移到下一个扇区
	cmp si, 0
	jnz continue
	mov si, es
	add si, 0x1000
	mov es, si
	mov si, 0
continue:
	
	jmp loading

finish:	
	ret
	
;	-> FAT表项读取函数
;cx	-> FAT表下标
;bx	-> FAT表地址
; return
;	dx -> fat[index]
FatVec:
	push cx
	mov ax, cx
	shr	ax, 1
	
	mov cx, 3
	mul cx
	mov cx, ax	;fat表下标/2 * 3 的结果存入cx
	
	pop ax
	
	and ax, 1	;fat表下标/2的余数是否为0(判断奇数偶数)
	jz even		;偶数跳转到even
	jmp odd		;奇数跳转到odd
	
even:	;FatVec[j] = ( (Fat[i+1] & 0x0F) << 8 ) | Fat[i];
	mov dx, cx
	add dx, 1
	add dx, bx
	mov bp, dx
	mov dl, byte [bp]
	and dl, 0x0F
	shl dx, 8
	add cx, bx
	mov bp, cx
	or dl, byte [bp]
	jmp return
odd:	;FatVec[j+1] = (Fat[i+2] << 4) | ((Fat[i+1] >> 4) & 0x0F)
	mov dx, cx
	add dx, 2
	add dx, bx
	mov bp, dx
	mov dl, byte [bp]
	mov dh, 0
	shl dx, 4
	add cx, 1
	add cx, bx
	mov bp, cx
	mov cl, byte [bp]
	shr cl, 4
	and cl, 0x0F
	mov ch, 0
	or dx, cx
	
return:
	ret
	
;	-> 内存拷贝函数
;ds:si	-> 拷贝源地址
;es:di	-> 拷贝目标地址
;cx		-> 拷贝长度
MemCpy:
	
	cmp si, di	;比较si,di大小
	ja btoe		; si > di,跳转到btoe(从头拷贝到尾)
	
	add si, cx	;si <= di, si和di位置移到内存尾部
	add di, cx
	dec si		;指向尾部最后一个有效字节
	dec di
	jmp etob
	
btoe:	;将si一个个字节拷贝到di(从前到后)
	cmp cx, 0
	jz done
	mov al, [si]
	mov byte [di], al
	inc si	;地址自增
	inc di
	dec cx
	jmp btoe
	
etob:	;将si一个个字节拷贝到di(从后到前)
	cmp cx, 0
	jz done
	mov al, [si]
	mov byte [di], al
	dec si	;地址自减
	dec di
	dec cx
	jmp etob
	
done:
	
	ret
	
;	查找根目录目标文件函数
;es:bx 	-> 根目录便宜地址
;ds:si 	-> 查找的目标字符串
;cx		-> 目标字符串长度
;return:
;		(dx != 0) ? exit : noexit
;		exit -> bx 寄存器为根目录目标文件的地址
FindEntry:
	push cx
	
	mov dx, [BPB_RootEntCnt]	;循环查找次数(根目录文件数)
	mov bp, SP
	
find:
	cmp dx, 0	;dx为0，说明根目录文件数都遍历完,没找到
	jz noexist
	mov di, bx	;赋值一个根目录地址
	mov cx, [bp]
	push si
	call MemCmp		;根目录比较
	pop si
	cmp cx, 0
	jz exist
	add bx, 32		;根目录地址偏移32字节
	dec dx			;根目录文件数减1
	jmp find 		;循环找
	
exist:
noexist:
	pop cx
	
	ret
	
	
;ds:si 	-> 保存比较源串
;es:di 	-> 保存比较目标串
;cx		-> 比较长度
;return:
;	(cx == 0) ? equal : noequal	
MemCmp:	;内存比较函数

	
compare:
	cmp cx, 0	;判断cx是否为0
	jz equal	;为0说明比较结果相等，跳转到equal标签处
	mov al, [si]	;将源si位置的一个字节存入al
	cmp al, byte [di]	;与目标di位置1个字节比较
	jz goon	;相等跳转goon标签处，变量递增/减
	jmp noequal	;不相等直接跳到noequal处

goon:
	inc si	;si递增1个字节
	inc di	;di递增1个字节
	dec cx	;cx递减1(剩余待比较字符串)
	jmp compare	;跳转到compare继续执行
equal:
noequal:

	ret
	

; es:bp --> string address
; cx    --> string length
Print:
	mov dx, 0		;打印位置置前
    mov ax, 0x1301	;设置关键寄存器
    mov bx, 0x0007
    int 0x10		;触发中断
    ret				;函数结尾标志
	
; no parameter
ResetFloppy:	;重置软驱函数
	push ax
	mov ah, 0x00
	mov dl, [BS_DrvNum]	;设置逻辑扇区号(驱动器号)
	int 0x13
	pop ax
	ret 
	
;ax ->保存逻辑扇区号
;cx ->保存读取扇区数
; es:bx ->保存读取的内容
ReadSector:	;读取软驱数据函数

	call ResetFloppy
	
	push bx
	push cx
	
	mov bl, [BPB_SecPerTrk]	;柱面扇区数赋值到bl寄存器
	div bl 		;做除法， (被除数默认存在ax寄存器)逻辑扇区号 / 柱面扇区数
	mov cl, ah	;获取余数(余数放在ah)
	add cl, 1	;获取扇区号(存入cl),余数+1为起始扇区号(存入cl)
	mov ch, al	;获取商(商放在al)
	shr ch, 1	;商右移一位，得到柱面号(存入ch)
	mov dh, al	
	and dh, 1	;商&1得到磁头号，存入dh
	mov dl, [BS_DrvNum]	;设置逻辑扇区号(驱动器号)

	pop ax
	pop bx
	
	mov ah, 0x02	;固定格式

read:	
	int 0x13	;触发软盘读取数据中断
	jc read		;读错时重读
	
	ret