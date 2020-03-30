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
	const Descriptor* entry;
	const int size;
} GdtInfo;


typedef struct {
    uint gs;
    uint fs;
    uint es;
    uint ds;
    uint edi;
    uint esi;
    uint ebp;
    uint kesp;
    uint ebx;
    uint edx;
    uint ecx;
    uint eax;
    uint raddr;
    uint eip;
    uint cs;
    uint eflags;
    uint esp;
    uint ss;
} RegValue;

typedef struct
{
    uint   previous;
    uint   esp0;
    uint   ss0;
    uint   unused[22];
    ushort reserved;
    ushort iomb;
} TSS;

typedef struct
{
    RegValue   rv;
    Descriptor ldt[3];
    TSS        tss;
    ushort     ldtSelector;
    ushort     tssSelector;
    uint       id;
    char       name[8]; 
    byte       stack[512];
} Task;

int SetDescValue(Descriptor* pDesc, uint base, uint limit, ushort attr);
int GetDescValue(Descriptor* pDesc, uint* pBase, uint* pLimit, ushort* pAttr);

#endif 