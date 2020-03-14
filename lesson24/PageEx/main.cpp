#include <QCoreApplication>
#include <iostream>
#include <QList>
#include <ctime>
#include <QQueue>

using namespace  std;

#define PAGE_DIR_NUM (0xF + 1)  //页目录数大小
#define PAGE_SUB_NUM (0xF +1)	//子页表大小
#define PAGE_UNM (PAGE_DIR_NUM * PAGE_SUB_NUM )   //一个任务的页面数
#define FRAME_NUM (0x04)      //系统的页框数
#define FP_NONE  -1


//一个页框结构
struct FrameItem
{
    int pid;    //使用该页框的任务ID
    int pnum;   //该页框保存的页表序号
    int tickId;    //记录页框访问次数

    FrameItem()
    {
        pid = FP_NONE;
        pnum = FP_NONE;
        tickId = 0;
    }
};

//页表类
class PageTable
{
	//指针数组，元素为指向子页表的地址
    int* m_pt[PAGE_DIR_NUM]; //页表采用二级页目录表示  保存到额内容模拟计算机的物理页号，即页框号

public:
    PageTable()
    {
        for(int i=0; i<PAGE_DIR_NUM; i++)  //任务页目录初始化
        {
            m_pt[i] = NULL;
        }
    }

    int& operator [](int i)
    {
        if( (i >= 0) && (i < length()) )
        {
			int dir = ((i & 0xF0) >> 4);
			int sub = (i & 0x0F);
			
			if(m_pt[dir] == NULL)
			{
				//页目录对应的子页表没有，则申请一个页目录下的子页表,节省空间
				m_pt[dir] = new int(PAGE_SUB_NUM);
				
				for(int j=0; j<PAGE_SUB_NUM; j++)
				{
					m_pt[dir][j] = FP_NONE;
				}
			}
			
			
            return m_pt[dir][sub];
        }
        else
        {
            QCoreApplication::exit(-1);
            return m_pt[0][0] ; //消除编译警告
        }
    }

    int length()
    {
        return PAGE_UNM;
    }
	
	~PageTable()
	{
		for(int i=0; i<PAGE_DIR_NUM; i++)
		{
			delete[] m_pt[i];
		}
	}
};

//任务结构
class PCB
{
    int m_pid; //当前任务id
    PageTable m_pageTable;  //当前任务页表

    int* m_pageSerial;     //随机数组指针，模拟任务执行时要访问的页面
    int m_pageSerialCount;  //任务要访问的页面个数
    int m_next; //m_pageSerial[m_next] 为下次要访问的页号

public:
    PCB(int pid)
    {
        m_pid = pid;
        m_pageSerialCount = qrand() % 5 + 5;   //任务执行过程中要访问的页的个数

        m_pageSerial = new int(m_pageSerialCount);

        for(int i=0; i<m_pageSerialCount; i++)
        {
            m_pageSerial[i] = qrand() % 5;  //每次访问的页号
        }

        m_next = 0;
    }

    int getPid()
    {
        return m_pid;
    }

    PageTable& getPageTable()
    {
        return m_pageTable;
    }

    int getNextPage()  //获取下一次要访问的页表号
    {
        int ret = m_next++;

        if(ret < m_pageSerialCount)
        {
            ret = m_pageSerial[ret];
        }
        else
        {
            ret = FP_NONE;
        }
        return ret;
    }

    bool running()
    {
        return (m_next < m_pageSerialCount);
    }

    //打印任务访问的页面
    void PrintPageSerial()
    {
        QString s = "";
        for(int i=0; i<m_pageSerialCount; i++)
        {
            s += QString::number(m_pageSerial[i]) + " ";
        }

        cout << ("Task" + QString::number(m_pid) + ":" + s).toStdString() << endl;
    }

    ~PCB()
    {
        delete[] m_pageSerial;
    }
};

FrameItem FrameTable[FRAME_NUM];  //页框表

QList<PCB*> TaskTable;  //任务表

QQueue<int> FrameQueue; //保存被任务占用的页框的队列

void PrintLog(QString string)
{
    cout << string.toStdString() << endl;
}

void PrintPageMap(int pid, int page, int frame)
{
    QString s = "Task" + QString::number(pid) + " : ";

    s += "Page" + QString::number(page) + "==> Frame" + QString::number(frame);

    cout << s.toStdString() << endl;
}

void PrintfFatalError(QString s, int pid, int page)
{
    s += "Task" + QString::number(pid) + ": page" + QString::number(page);

    cout << s.toStdString() << endl;

    QCoreApplication::exit(-1);
}

int GetFrameItem();
int AccessPage(PCB& pcb);
int ReQuestPage(int pid, int page);
int Random();
int SwapPage();
int ClearFrameItem(PCB& pcb);   //释放页框
int ClearFrameItem(int frame);   //释放单个页框
int FIFO();
int LRU();  //LUR算法

//获取页框
int GetFrameItem()
{
    int ret = FP_NONE;

    for(int i=0; i<FRAME_NUM; i++)
    {
        if(FrameTable[i].pid == FP_NONE)  //有页框还没被任务占用，则返回这个页框
        {
            ret = i;
            break;
        }
    }

    return ret;
}

//访问任务页面
int AccessPage(PCB& pcb)
{
    int pid = pcb.getPid();
    PageTable& pageTable = pcb.getPageTable();  //获取任务的页表
    int page = pcb.getNextPage();

    if(page != FP_NONE)
    {
        PrintLog("Access Task" + QString::number(pid));
        if(pageTable[page] != FP_NONE)   //下次要访问的页表已经加载在页框中，直接使用
        {
            PrintLog("Find target page in page table.");
            PrintPageMap(pid, page, pageTable[page]);
        }
        else
        {
            PrintLog("Target page is NOT Found, need to request page ...");  //要访问的页表不在页框中，需要请求页框得到一个页表
            pageTable[page] = ReQuestPage(pid, page);  //获取一个页框，映射到任务的页表里

            if(pageTable[page] != FP_NONE)
            {
                PrintPageMap(pid,page, pageTable[page]);
            }
            else
            {
                PrintfFatalError("Can Not request page from disk...",pid, page);
            }
        }

    }
    else
    {
        PrintLog("Task" + QString::number(pid) + "is finished");
    }
    return 0;

}

 //页请求
int ReQuestPage(int pid, int page)
{
    int frame = GetFrameItem();  //从页框请求一个页

    if(frame != FP_NONE)   //页框还有空余的页，直接返回使用
    {
        PrintLog("Get a frame to hold page content: Frame" + QString::number(frame));
    }
    else   //页框页已经使用完，需要置换页
    {
         PrintLog("No Free frame to allocate, need to swap page out.");

         frame = SwapPage();  //置换页
         if(frame != FP_NONE)
         {
            PrintLog("Succeed to Swap lazy page out");
         }
         else
         {
            PrintfFatalError("Fail to swap page out...",pid, FP_NONE);
         }
    }

    PrintLog("Load content from disk to frame" + QString::number(frame));
    FrameTable[frame].pid = pid;
    FrameTable[frame].pnum = frame;
    FrameTable[frame].tickId = 0xFF;    //请求到一个页框，给访问次数赋值255

    FrameQueue.enqueue(frame);  //请求到一个页框，便入队列
    return frame;

}


int Random()
{
    int obj = qrand() % FRAME_NUM;  //随机决定一个页框里要置换出去的页

    ClearFrameItem(obj);    //释放随机获取的页框

    return obj;
}
//页交换
int SwapPage()
{
    //return Random();
    //return FIFO();
    return LRU();
}



//释放任务
int ClearFrameItem(PCB& pcb)
{
    int pid = pcb.getPid();

    for(int i=0; i<FRAME_NUM; i++)
    {
        if(FrameTable[i].pid == pid) //释放目标任务占用的页框
        {
            FrameTable[i].pnum = FP_NONE;
            FrameTable[i].pid = FP_NONE;
        }
    }
    return 0;
}

int ClearFrameItem(int frame)   //释放单个页框
{
    PrintLog("Random select a frame to swap page content out: frame" + QString::number(frame));
    PrintLog("Write the selected page content back to disk");

    FrameTable[frame].pid = FP_NONE;   //对应页复位
    FrameTable[frame].pnum = FP_NONE;

    for(int i=0, f=0; !f && i<TaskTable.count(); i++)  //将任务中使用到该被置换出去的页框，对应的页清空
    {
        PageTable& pt = TaskTable[i]->getPageTable();
        for(int j=0; j<pt.length(); j++)
        {
            if(pt[j] == frame)
            {
                pt[j] = FP_NONE;
                f = 1;
                break;
            }
        }
    }
}

int FIFO()
{
    int frame = FrameQueue.dequeue();  //FIFO页面交换算法，交换队列头的页框

    ClearFrameItem(frame);  //释放队列头的页框

    return frame;
}

int LRU()
{
    int tickCmp = FrameTable[0].tickId;
    int ret =0;
    QString s = "";
    for(int i=0; i<FRAME_NUM; i++) //获取访问次数最少的页框
    {
        if( tickCmp > FrameTable[i].tickId )
        {
            tickCmp = FrameTable[i].tickId;
            ret = i;
        }

        s += "Frame" + QString::number(i) + " tickId = " + QString::number(FrameTable[i].tickId) + " : ";
    }
    PrintLog("Frame tickId List is : " + s);

    ClearFrameItem(ret); //清除访问次数最少的页框

    return ret;
}

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    qsrand(time(NULL));
    int index = 0;

    //创建两个任务
    TaskTable.append(new PCB(1));
	TaskTable.append(new PCB(2));

    PrintLog("Task Page Serial:");

    for(int i=0; i<TaskTable.count(); i++)
    {
        TaskTable[i]->PrintPageSerial();
    }

    while(true)
    {
        for(int i=0; i<FRAME_NUM; i++) //模拟系统中断，每次中断，tickId计数减一
        {
            FrameTable[i].tickId--;
        }

        if(TaskTable.count() > 0)
        {
            if(TaskTable[index]->running())  //两个任务执行过程，回车观察页的使用及置换情况
            {
                AccessPage(*TaskTable[index]);
            }
            else //对应任务已经结束，释放页框及任务空间
            {
                PCB* pcb = TaskTable[index];

                PrintLog("Task" + QString::number(pcb->getPid()) + " is Finished");

                TaskTable.removeAt(index);  //任务表中移除该任务
                ClearFrameItem(*pcb);  //回收业务占用的内框

                delete pcb; //释放业务占用的内存
            }
        }


        if(TaskTable.count() > 0)
        {
            index = (index + 1) % TaskTable.count();
        }

        cin.get();
    }


    return a.exec();
}
