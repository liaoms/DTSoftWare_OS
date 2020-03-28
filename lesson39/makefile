
.PHONY : all clean rebuild

RM := rm -fr

ASM_SRC := entry.asm
C_SRC 	:= main.c
TARGET	:= app.out
	
ASM_OBJ	:= entry.o
C_OBJ	:= main.o
	
all : $(TARGET) $(ASM_OBJ) $(C_OBJ)
	
	@echo "Biuld Success ==> app.out"

$(TARGET) : $(ASM_OBJ) $(C_OBJ)
	ld -s $^ -o $@

#编译汇编需要编译成elf文件格式，以便与C函数相互嵌套
$(ASM_OBJ) : $(ASM_SRC)
	nasm -f elf $^ -o $@

$(C_OBJ) : $(C_SRC)
	gcc -c $^ -o $@

clean :
	$(RM) $(TARGET) $(ASM_OBJ) $(C_OBJ)

rebuild :
	@$(MAKE) clean
	@$(MAKE) all
	