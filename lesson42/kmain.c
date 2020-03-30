#include "kernel.h"
#include "screen.h"
#include "global.h"

void KMain()
{	
	uint base 	= 0;
	uint limit 	= 0;
	uint attr 	= 0;
	
	int i = 0;
	
	//打印全局段描述表信息
	
	PrintString("Gdt Entry:");
	PrintHex((int)gGdtInfo.entry);
	PrintChar('\n');
	
	for(i=0; i<gGdtInfo.size; i++)
	{
		GetDescValue(gGdtInfo.entry + i, &base, &limit, &attr);
	
		PrintHex(base);
		PrintString("    ");
		
		PrintHex(limit);
		PrintString("    ");
		
		PrintHex(attr);
		PrintChar('\n');
	}
	
}
