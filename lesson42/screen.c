#include "screen.h"
#include "kernel.h"

static int gPosW = 0;
static int gPosH = 0;
static char gColor = SCREEN_WHITE;

void ClearScreen()
{
	int w = 0;
	int h = 0;
	SetPrintPos(0, 0);
	
	for(h=0; h<SCREEN_HEIGHT; h++)
	{
		for(w=0; w<SCREEN_WIDTH; w++)
		{
			PrintChar(' ');
		}		
	}
	SetPrintPos(0, 0);
}

int SetPrintPos(byte w, byte h)
{
	int ret = 0;
	ret = (w <= SCREEN_WIDTH) && (h <= SCREEN_HEIGHT);
	if( ret )
	{
		//光标位置
		unsigned short bx = SCREEN_WIDTH * h + w;
		
		gPosW = w;
		gPosH = h;		
		
		//挪动光标位置
		asm volatile(
            "movw %0,      %%bx\n"
            "movw $0x03D4, %%dx\n"
            "movb $0x0E,   %%al\n"
            "outb %%al,    %%dx\n"
            "movw $0x03D5, %%dx\n"
            "movb %%bh,    %%al\n"
            "outb %%al,    %%dx\n"
            "movw $0x03D4, %%dx\n"
            "movb $0x0F,   %%al\n"
            "outb %%al,    %%dx\n"
            "movw $0x03D5, %%dx\n"
            "movb %%bl,    %%al\n"
            "outb %%al,    %%dx\n"
            :
            : "r"(bx)
            : "ax", "bx", "dx"
        );
	}
	
	return ret;
}

void SetPrintColor(PrintColor c)
{
	gColor = c;
}

int PrintChar(char c)
{
	int ret = 0;
	if( ('\n' == c) || ('\r' == c) )
	{
		SetPrintPos(0, gPosH + 1);
	}
	else
	{
		byte pw = gPosW;
		byte ph = gPosH;
		if( (pw <= SCREEN_WIDTH) && (ph <= SCREEN_HEIGHT))
		{
			int edi = (ph * SCREEN_WIDTH + pw) * 2;  //打印位置
			char ah = gColor;	//打印颜色
			char al = c;		//打印字符
			
			asm volatile (
				"movl %0, %%edi\n"   
				"movb %1, %%ah\n"
				"movb %2, %%al\n"
				"movw %%ax, %%gs:(%%edi)"   //赋值到显存
 				"\n"
				:
				: "r"(edi), "r"(ah), "r"(al)
				: "ax", "edi"			
			);
			
			pw ++;
			ret = 1;
			if(pw == SCREEN_WIDTH)
			{
				pw = 0;
				ph = ph + 1;			
			}
		}
		
		
		SetPrintPos(pw, ph);
	}
	return ret;
}

int PrintString(const char* s)
{
	int ret = 0;
	
	if(s != NULL)
	{
		while(*s)
		{
			ret += PrintChar(*s++);
		}
	}	
	else
	{
		ret = -1;
	}
	return ret;
	
}

int PrintIntDec(int n)
{
	int ret = 0;
	if( n < 0)
	{
		PrintChar('-');
		n = -n;
		
		ret += PrintIntDec(n);
	}
	else
	{
		if(n < 10)
		{
			ret += PrintChar('0' + n);
		}
		else
		{
			ret += PrintIntDec(n / 10);
			ret += PrintIntDec(n % 10);
		}
	}
	return ret;
}

int PrintHex(uint n)
{
	char hex[11] = {'0', 'x', 0};
	int i = 0;
	
	for(i=9; i>=2; i--)
	{
		int p = n & 0xF;
		
		if(p < 10)
		{
			hex[i] = ('0' + p);
		}
		else
		{
			hex[i] = ('A' + p - 10);
		}
		n = n >> 4;
	}
	PrintString(hex);
}