#include "ihandler.h"
#include "interrupt.h"

//中断服务程序
void TimerHandler()
{
	static int i = 0;
	
	i = (i+1) % 5;
	
	if(0 == i)
	{
		Schedule();	
	}
	
	SendEOI(MASTER_EOI_PORT);   //时钟中断需要手工结束中断控制字
}