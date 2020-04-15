#include "kernel.h"

int SetDescValue(Descriptor* pDesc, uint base, uint limit, ushort attr)
{
	int ret = 0;
	
	ret = (NULL != pDesc);
	
	if(ret)
	{
		pDesc->limitl 		= limit & 0xFFFF;
		pDesc->base1		= base & 0xFFFF;
		pDesc->base2 		= (base >> 16) & 0xFF;
		pDesc->attr1 		= attr & 0xFF;
		pDesc->attr2_limit2 = ((attr >> 8) & 0xF0) | ((limit >> 16) & 0xF);
		pDesc->base3 		= (attr >> 24) & 0xFF;
	}
	
	return ret;
}

int GetDescValue(Descriptor* pDesc, uint* pBase, uint* pLimit, ushort* pAttr)
{
	int ret = 0;
	
	ret = pDesc && pBase && pAttr && pLimit;
	
	if(ret)
	{
		*pBase = (pDesc->base3 << 24) | (pDesc->base2 << 16) | (pDesc->base1);
		*pLimit = ((pDesc->attr2_limit2 & 0xF) << 16) | pDesc->limitl;
		*pAttr = ((pDesc->attr2_limit2 & 0xF0) << 8) | pDesc->attr1;
	}
	
	return ret;
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