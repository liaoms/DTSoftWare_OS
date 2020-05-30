#ifndef __IHANDLER_H__
#define __IHANDLER_H__

#define DecHandler(name) 	void name##Entry(); \
							void name()

DecHandler(TimerHandler);


#endif 