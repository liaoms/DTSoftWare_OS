#include "task.h"
#include "utility.h"

void (* const RunTask)(volatile Task* pt) = NULL;
void (* const LoadTask)(volatile Task* pt) = NULL;

volatile Task* gCTaskAddr = NULL;    //定义一个全局任务结构体指针，供加载内核的Kernel.asm使用

//保存进程的结构体信息
Task p = {0};
Task t = {0};
TSS gTSS = {0};

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

//进程入口函数
void TaskB()
{
    int i = 0;
    
    SetPrintPos(0, 13);
    
    PrintString("Task B: ");
    
    while(1)
    {
        SetPrintPos(8, 13);
        PrintChar('0' + i);
        i = (i + 1) % 10;
        Delay(1);
    }
}

static void TaskInit(Task* pt, void* Entry)
{
	//设置进程结构体参数
	pt->rv.cs = LDT_CODE32_SELECTOR;   	//指向LDT的代码段描述符
    pt->rv.gs = LDT_VIDEO_SELECTOR;		//显存
    pt->rv.ds = LDT_DATA32_SELECTOR;		//数据段
    pt->rv.es = LDT_DATA32_SELECTOR;
    pt->rv.fs = LDT_DATA32_SELECTOR;
    pt->rv.ss = LDT_DATA32_SELECTOR;
    
    pt->rv.esp = (uint)pt->stack + sizeof(pt->stack);   //进程使用的栈段
    pt->rv.eip = (uint)Entry;		//进程入口地址
    pt->rv.eflags = 0x3202;		//标志，允许IO访问，允许中断
    
    gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;   //设置tss结构体，
    gTSS.esp0 = (uint)&pt->rv + sizeof(pt->rv);     //使用任务结构体的RegValue成员作为内核初始的内核栈，设置任务的esp0指向任务结构的寄存器结构体，以便进入中断后，寄存器上下文存入任务对应的结构体处，便于恢复上下文执行
    gTSS.iomb = sizeof(TSS);
    
    SetDescValue( AddrOff(pt->ldt, LDT_VIDEO_INDEX),  0xB8000, 0x07FFF, DA_DRWA + DA_32 + DA_DPL3); 	//注册局部任务段ldt显存段描述符
    SetDescValue( AddrOff(pt->ldt, LDT_CODE32_INDEX), 0x00,    0xFFFFF, DA_C + DA_32 + DA_DPL3);		//注册局部任务段ldt代码段描述符
    SetDescValue( AddrOff(pt->ldt, LDT_DATA32_INDEX), 0x00,    0xFFFFF, DA_DRW + DA_32 + DA_DPL3);		//注册局部任务段ldt数据段描述符
    
    pt->ldtSelector = GDT_TASK_LDT_SELECTOR;
    pt->tssSelector = GDT_TASK_TSS_SELECTOR;
    
    SetDescValue( AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&pt->ldt, sizeof(pt->ldt)-1, DA_LDT + DA_DPL0);  	//全局段中注册任务的ldt
    SetDescValue( AddrOff(gGdtInfo.entry, GDT_TASK_TSS_INDEX), (uint)&gTSS, sizeof(gTSS)-1, DA_386TSS + DA_DPL0); 	//全局段中注册任务的tss
}

void TaskModInit() 	//任务初始化
{
	TaskInit(&t, TaskB);
	TaskInit(&p, TaskA);
}

void LuanchTask()		//任务启动   
{
	gCTaskAddr = &p;
    RunTask(gCTaskAddr);   //执行进程，执行时刽调用内核函数RunTask，将参数P传入，寄存器设置为该任务TaskA的信息，从而进入任务入口TaskA执行
}


void Schedule()  //任务调度
{
	gCTaskAddr = (gCTaskAddr == &p) ? &t : &p;
	
	gTSS.ss0 = GDT_DATA32_FLAT_SELECTOR;   //设置tss结构体，
    gTSS.esp0 = (uint)&gCTaskAddr->rv.gs + sizeof(RegValue); 
	
	SetDescValue( AddrOff(gGdtInfo.entry, GDT_TASK_LDT_INDEX), (uint)&gCTaskAddr->ldt, sizeof(gCTaskAddr->ldt)-1, DA_LDT + DA_DPL0);  	//全局段中注册任务的ldt

	LoadTask(gCTaskAddr);
}
