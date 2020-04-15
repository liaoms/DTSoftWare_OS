#ifndef __SCREEN_H__
#define __SCREEN_H__

#define SCREEN_WIDTH 	80
#define SCREEN_HEIGHT 	25

#include "type.h"

typedef enum
{
	SCREEN_GRAY = 0X07,
	SCREEN_BLUE = 0X09,
	SCREEN_GREEN = 0X0A,
	SCREEN_RED = 0X0C,
	SCREEN_YELLOW = 0X0E,
	SCREEN_WHITE = 0X0F
	
}PrintColor;

void ClearScreen();
int SetPrintPos(byte w, byte h);
void SetPrintColor(PrintColor c);
int PrintChar(char c);
int PrintString(const char* s);
int PrintIntDec(int n);
int PrintHex(uint n);

#endif