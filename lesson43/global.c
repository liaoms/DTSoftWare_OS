  #include "global.h"
  
  
  GdtInfo gGdtInfo = {0};
  IdtInfo gIdtInfo = {0};
  void (* const RunTask)(volatile Task* pt) = NULL;
  void (* const LoadTask)(volatile Task* pt) = NULL;