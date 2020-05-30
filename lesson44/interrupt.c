#include "interrupt.h"
#include "utility.h"
#include "ihandler.h"

void (* const InitInterrupt)();
void (* const EnableTimer)();
void (* const SendEOI)(uint port);

void IntModInit()
{
	SetIntHandler(AddrOff(gIdtInfo.entry, 0x20), (uint)TimerHandlerEntry);  //设置时钟中断入口函数为TimerHandlerEntry
	
	InitInterrupt();  	//初始化外部中断
	EnableTimer();		//开启时钟中断
}

//设置中断服务程序入口
int SetIntHandler(Gate* pGate, uint ifunc)
{
	int ret = 0;
	ret = (NULL != pGate);
	if(ret)
	{
		pGate->offset1 = ifunc & 0xFFFF;
		pGate->selector = GDT_CODE32_FLAT_SELECTOR;
		pGate->dcount = 0;
		pGate->attr = DA_386IGate + DA_DPL0;
		pGate->offset2 = (ifunc >> 16) & 0xFFFF;
	}
	
	
	return ret;
}

//获取中断服务程序入口
int GetIntHandler(Gate* pGate, uint *pIfunc)
{
	int ret = 0;
	
	*pIfunc = (pGate->offset1) | (pGate->offset2 << 16);
	
	
	return ret;
}