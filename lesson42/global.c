  #include "global.h"
  
  
  GdtInfo gGdtInfo = {0};
  void (* const RunTask)(Task* pt) = NULL;