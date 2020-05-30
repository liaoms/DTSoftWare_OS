#ifndef __UTILITY_H__
#define __UTILITY_H__

#define AddrOff(a, i) ((void*)((uint)a + i * sizeof(*a)))

void Delay(int n);

#endif 