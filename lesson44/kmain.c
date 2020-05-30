#include "screen.h"
#include "task.h"
#include "interrupt.h"

void KMain()
{	
	
	//打印全局段描述表信息
	
	PrintString("Gdt Entry:");
	PrintHex((int)gGdtInfo.entry);
	PrintChar('\n');
	PrintString("Gdt size:");
	PrintIntDec((int)gGdtInfo.size);
	PrintChar('\n');
	
	PrintString("Idt Entry:");
	PrintHex((int)gIdtInfo.entry);
	PrintChar('\n');
	PrintString("Idt size:");
	PrintIntDec((int)gIdtInfo.size);
	PrintChar('\n');
	
	PrintString("RunTask: ");
    PrintHex((uint)RunTask);
    PrintChar('\n');

    IntModInit();   //初始化中断
	
	TaskModInit();	//初始化任务
	
	LuanchTask();	//启动任务
    	
}
