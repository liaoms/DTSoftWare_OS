# DTSoftWare_OS
从零打造一个操作系统内核

# 2020-01-19
	第一个主引导程序启动
	1、编译汇编代码
		nasm boot.asm -o boot.bin
	2、创建a.img软盘
		bximage (参数依次选择fd 、 1.44 、 a.img)
	3、讲主引导程序写入a.imgruanpan
		dd if=boot.bin of=a.img bs=512 count=1 conv=notrunc
		if：输入文件
		of：输出到
		bs：每个单元的大小(单位字节)
		count：写入的单元个数
		conv：写入模式(notrunc为无换行间隔)
	4、创建新的虚拟机DTOS，并将启动软盘设置为a.img
	5、启动新的虚拟机DTOS即可
	
	调试环境搭建
	1、软件及配置已经配置好，将bochsrc文件放到要调试的.bin的目录下即可
	2、命令行直接输入bochs启动调试软件，使用方式与gdb类似

# 2020-01-20
	主引导程序扩展
	1、使用Fat12文件系统对软盘data.img格式化，并往data.img写入两个文件 loader.bin、test.txt，同时读取data.img中Fat12文件系统的主引导区基本信息
	2、获取根目录文件项