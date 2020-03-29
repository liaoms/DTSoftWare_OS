#include "kernel.h"
#include "screen.h"

void KMain()
{
	SetPrintPos(SCREEN_WIDTH/2, SCREEN_HEIGHT/2);
	int n = PrintString("LMS\n");
	PrintHex(n);
	PrintChar('\n');
	n = PrintIntDec(-123456);
	PrintChar('\n');
	PrintIntDec(n);
	
	//PrintChar('L');
}
