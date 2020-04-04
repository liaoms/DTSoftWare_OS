#include "kernel.h"
#include "screen.h"
#include "global.h"

void (* const InitInterrupt)() = NULL;
void (* const EnableTimer)() = NULL;
void (* const SendEOI)(uint port) = NULL;

Task* gCTaskAddr = NULL;    //定义一个全局任务结构体指针，供加载内核的Kernel.asm使用

//保存进程的结构体信息
Task p = {0};

void Delay(int n)
{
    while( n > 0 )
    {
        int i = 0;
        int j = 0;
        
        for(i=0; i<1000; i++)
        {
            for(j=0; j<1000; j++)
            {
                asm volatile ("nop\n");
            }
        }
        
        n--;
    }
}

//进程入口函数
void TaskA()
{
    int i = 0;
    
    SetPrintPos(0, 12);
    
    PrintString("Task A: ");
    
    while(1)
    {
        SetPrintPos(8, 12);
        PrintChar('A' + i);
        i = (i + 1) % 26;
        Delay(1);
    }
}

void TimerHandlerEntry();

//中断服务程序
void TimerHandler()
{
	static int i = 0;
	
	i = (i+1) % 10;
	
	if(0 == i)
	{
		static int j = 0;
		
		SetPrintPos(0, 13);
		PrintString("TimerHandler: ");
		SetPrintPos(14, 13);
		PrintIntDec(j++);
		PrintChar('\n');	
	}
	
	SendEOI(MASTER_EOI_PORT);   //时钟中断需要手工结束中断控制字
	
	//asm volatile("leave\n""iret\n");  //中断程序需要以iret结尾
}

void KMain()
{	
	uint base 	= 0;
	uint limit 	= 0;
	uint attr 	= 0;
	uint temp = 0;
	
	int i = 0;
	
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
	
	//设置进程结构体参数
	p.rv.cs = LDT_CODE32_SELECTOR;   	//指向LDT的代码段描述符
    p.rv.gs = LDT_VIDEO_SELECTOR;		//显存
    p.rv.ds = LDT_DATA32_SELECTOR;		//数据段
    p.rv.es = LDT_DATA32_SELECTOR;
    p.rv.fs = LDT_DATA32_SELECTOR;
    p.rv.ss = LDT_DATA32_SELECTOR;
    
    p.rv.esp = (uint)p.stack + sizeof(p.stack);   //进程使用的栈段
    p.rv.eip = (uint)TaskA;		//进程入口地址
    p.rv.eflags = 0x3202;		//标志，允许IO访问，允许中断
    
    p.tss.ss0 = GDT_DATA32_FLAT_SELECTOR;   //设置tss结构体，
    p.tss.esp0 = (uint)&p.rv + sizeof(p.rv);     //使用任务结构体的RegValue成员作为内核初始的内核栈，设置任务的esp0指向任务结构的寄存器结构体，以便进入中断后，寄存器上下文存入任务对应的结构体处，便于恢复上下文执行
    p.tss.iomb = sizeof(p.tss);
    
    SetDescValue(p.ldt + LDT_VIDEO_INDEX,  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3); 	//注册局部任务段ldt显存段描述符
    SetDescValue(p.ldt + LDT_CODE32_INDEX, 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);		//注册局部任务段ldt代码段描述符
    SetDescValue(p.ldt + LDT_DATA32_INDEX, 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);		//注册局部任务段ldt数据段描述符
    
    p.ldtSelector = GDT_TASK_LDT_SELECTOR;
    p.tssSelector = GDT_TASK_TSS_SELECTOR;
    
    SetDescValue(&gGdtInfo.entry[GDT_TASK_LDT_INDEX], (uint)&p.ldt, sizeof(p.ldt)-1, DA_LDT + DA_DPL0);  	//全局段中注册任务的ldt
    SetDescValue(&gGdtInfo.entry[GDT_TASK_TSS_INDEX], (uint)&p.tss, sizeof(p.tss)-1, DA_386TSS + DA_DPL0); 	//全局段中注册任务的tss
	
	SetIntHandler(gIdtInfo.entry + 0x20, (uint)TimerHandlerEntry);  //设置时钟中断入口函数为TimerHandlerEntry
	
	InitInterrupt();  	//初始化外部中断
	EnableTimer();		//开启时钟中断
    
    gCTaskAddr = &p;
	
    RunTask(gCTaskAddr);   //执行进程，执行时刽调用内核函数RunTask，将参数P传入，寄存器设置为该任务TaskA的信息，从而进入任务入口TaskA执行
	
}
