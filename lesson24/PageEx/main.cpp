#include <QCoreApplication>
#include <iostream>
#include <QList>
#include <ctime>

using namespace  std;

#define PAGE_UNM (0xFF + 1)   //一个任务的页面数
#define FRAME_NUM (0x04)      //系统的页框数
#define FP_NONE  -1


//一个页框结构
struct FrameItem
{
    int pid;    //使用该页框的任务ID
    int pnum;   //该页框保存的页表序号

    FrameItem()
    {
        pid = FP_NONE;
        pnum = FP_NONE;
    }
};

//页表类
class PageTable
{
    int m_pt[PAGE_UNM]; //一个任务有有256个页表  m_pt下标模拟应用程序的逻辑页号，保存到额内容模拟计算机的物理页号，即页框号

public:
    PageTable()
    {
        for(int i=0; i<PAGE_UNM; i++)  //任务页表初始化
        {
            m_pt[i] = FP_NONE;
        }
    }

    int& operator [](int i)
    {
        if( (i >= 0) && (i < length()) )
        {
            return m_pt[i];
        }
        else
        {
            QCoreApplication::exit(-1);
            return m_pt[0] ; //消除编译警告
        }
    }

    int length()
    {
        return PAGE_UNM;
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

    return frame;

}


int Random()
{
    int obj = qrand() % FRAME_NUM;  //随机决定一个页框里要置换出去的页

    PrintLog("Random select a frame to swap page content out: frame" + QString::number(obj));
    PrintLog("Write the selected page content back to disk");

    FrameTable[obj].pid = FP_NONE;   //对应页复位
    FrameTable[obj].pnum = FP_NONE;

    for(int i=0, f=0; !f && i<TaskTable.count(); i++)  //将任务中使用到该被置换出去的页框，对应的页清空
    {
        PageTable& pt = TaskTable[i]->getPageTable();
        for(int j=0; j<pt.length(); j++)
        {
            if(pt[j] == obj)
            {
                pt[j] = FP_NONE;
                f = 1;
                break;
            }
        }
    }

    return obj;
}
//页交换
int SwapPage()
{
    return Random();
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
