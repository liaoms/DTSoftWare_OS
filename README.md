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
	3、获取指定文件名的根目录项
	4、获取指定文件名内容
	
# 2020-01-21
	突破512字节限制
	1、编写打印函数打印字符串
	2、读取指定扇区的内容
	3、增加内存比较函数
	4、增加根目录目标文件查找函数
	5、增加内存拷贝函数
	6、增加FAT表项读取函数

# 2020-02-21
	主引导程序控制权的转移
	主引导程序执行完成后，跳转到其他文件函数执行，最终将控制权交出去

# 2020-02-23
	实模式到保护模式
	1、实模式切换到保护模式执行
	2、定义显示段并在屏幕上打印一个字符
	3、定义打印函数打印字符串、优化代码

# 2020-02-24
	从保护模式返回实模式
	1、上节优化:定义32位保护模式下的栈段，该模式下的函数调用需要的栈都是这个栈
	2、从保护模式返回实模式(先在保护模式下打印黑底红字的"D.T.OS!"，再返回实模式打印黑底白字的"D.T.OS!")
	
# 2020-02-29
	第十四课、局部段描述符表的使用
	1、新增加一个局部段，内部定义一个任务A，定义自己的数据段、代码段、栈段，并且从全局段跳到局部段中的代码段执行(多任务的基本思想)
	
# 2020-03-03
	第十六课、保护模式中的特权级之门描述符
	1、将14课的打印函数封装成公共函数，并在全局代码段与局部代码段调用该打印函数
	2、增加调用门，对公共函数使用调用门方式调用

# 2020-03-08
	第十七课、保护模式中的特权级之高特权级代码段跳转到第特权级代码段
	第十八课、深入理解特权级(内核雏形)，(高特权级的内核初始化后，跳转到地特权级低的应用程序taskA，应用程序通过调用门调用内核打印函数)
	
# 2020-03-09
	第十九课、深入理解特权级之数据段访问规则(CPL <= DPL)&&(RPL <= DPL)
			  非一致性代码段只能平级跳转规则(CPL = DPL,如 CODE32_DESC 跳转到FUNCTION_DESC，特权级必须相等)
			  非一致性代码段跳到一致性代码段,需要满足CPL(非一致性代码段) >= DPL(一致性代码段，即非一致性代码段特权级要低于一致性代码段特权级)，
			  跳转到一致性代码段后，当前特权级依旧保持非一致性代码段的特权级，可以直接调用非一致性代码段的函数
			  
# 2020-03-14
	第二十四课、实战页式内存管理
		1、模拟多任务执行，任务页映射系统页框，及系统页框的置换操作
		2、任务结束后，释放占用的页框
		3、FIFO 页交换算法实现(队列实现，先入页框的任务页，先移出页框)
		4、LRU 页交换算法实现(页交换时，页框使用数最少的先移除)
		5、任务页表采用二级页表表示方式(分页目录与子页表)
		
# 2020-03-15
	第二十七课、x86系统上的内存分页
		1、循环累加功能验证(loop指令)
		2、stosb/stosw/stosd 指令验证，拷贝数据到指定内存位置
		3、对x86系统进行内存分页
		
# 2020-03-15
	第二十八课、x86分页机制
		1、对两个页表进行分页，并切换页表
		2、保护模式下使用平坦内存模型，使得可直接操作物理内存地址，(例子为将数据段字符串拷贝到指定的物理地址处)
		3、数据准备，往两个物理地址写字符串，以便后续同一个虚拟地址使用不用页表时映射到不同物理地址，得到不同的字符串
		4、增加页映射函数，同一虚拟内存，映射到不同的页表，映射的物理地址不同
		5、斜街上一节，切换不同页表后，打印同一个虚拟地址处的内容，得到不同的字符串
	
	
	
	