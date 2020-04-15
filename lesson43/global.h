 #ifndef __GLOBAL_H__
 #define __GLOBAL_H__
 
 #include "kernel.h"
 #include "const.h"
 
 extern GdtInfo gGdtInfo;
 extern IdtInfo gIdtInfo;
 extern void (* const RunTask)(volatile Task* pt);
 extern void (* const LoadTask)(volatile Task* pt);
 
 
 #endif