#ifndef __INTERRUPT_H__
#define __INTERRUPT_H__

#include "kernel.h"

extern void (* const EnableTimer)();
extern void (* const SendEOI)(uint port);

void IntModInit();
int SetIntHandler(Gate* pGate, uint ifunc);
int GetIntHandler(Gate* pGate, uint *pIfunc);

#endif