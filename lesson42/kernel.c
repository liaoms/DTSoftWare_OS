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