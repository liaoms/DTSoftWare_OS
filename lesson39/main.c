
extern print(char*, int);   //引用汇编文件的函数名
extern char vstr[];
extern int vlen;


int fun_c()
{
	char* str = "every thing will be ok\n";
	print(vstr, vlen);   //调用汇编函数的打印函数打印
	return 0;
}


