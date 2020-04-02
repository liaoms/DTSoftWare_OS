  #include "global.h"
  
  
  GdtInfo gGdtInfo = {0};
  IdtInfo gIdtInfo = {0};
  void (* const RunTask)(Task* pt) = NULL;