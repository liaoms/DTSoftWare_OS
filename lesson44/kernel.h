#ifndef __KERNEL_H__
#define __KERNEL_H__

#include "type.h"
#include "const.h"

typedef struct
{
	ushort limitl;
	ushort base1;
	byte   base2;
	byte   attr1;
	byte   attr2_limit2;
	byte   base3;
}Descriptor;

typedef struct 
{
	Descriptor* const entry;
	const int size;
} GdtInfo;

typedef struct 
{
	ushort offset1;    //门结构的偏移地址1
	ushort selector;   //门结构的选择子
	byte dcount;	   //参数
	byte attr;         //属性
	ushort offset2;    //偏移地址2
} Gate;

typedef struct
{
	Gate* const entry;
	const int size;
}IdtInfo;

extern GdtInfo gGdtInfo;
extern IdtInfo gIdtInfo;

int SetDescValue(Descriptor* pDesc, uint base, uint limit, ushort attr);
int GetDescValue(Descriptor* pDesc, uint* pBase, uint* pLimit, ushort* pAttr);

#endif 