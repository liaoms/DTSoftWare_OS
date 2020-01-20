#include <QtCore/QCoreApplication>
#include <QFile>
#include <QDataStream>
#include <QDebug>

#pragma pack(push)
#pragma pack(1)

struct Fat12Header
{
    char BS_OEMName[8];
    ushort BPB_BytsPerSec; //每扇区字节数，默认512字节
    uchar BPB_SecPerClus;   //每簇扇区数
    ushort BPB_RsvdSecCnt;
    uchar BPB_NumFATs;
    ushort BPB_RootEntCnt;  //最大跟目录文件数
    ushort BPB_TotSec16;
    uchar BPB_Media;
    ushort BPB_FATSz16;
    ushort BPB_SecPerTrk;
    ushort BPB_NumHeads;
    uint BPB_HiddSec;
    uint BPB_TotSec32;
    uchar BS_DrvNum;
    uchar BS_Reserved1;
    uchar BS_BootSig;
    uint BS_VolID;
    char BS_VolLab[11];
    char BS_FileSysType[8];
};

struct RootEntry
{
    char DIR_Name[11];
    uchar DIR_Attr;
    uchar reserve[10];
    ushort DIR_WrtTime;
    ushort DIR_WrtDate;
    ushort DIR_FstClus;
    uint DIR_FileSize;
};

#pragma pack(pop)

void PrintHeader(Fat12Header& rf, QString p)
{
    QFile file(p);

    if( file.open(QIODevice::ReadOnly) )
    {
        QDataStream in(&file);

        file.seek(3); //第0扇区偏移3个字节，跳过开始的3个字节跳转指令

        in.readRawData(reinterpret_cast<char*>(&rf), sizeof(rf));

        rf.BS_OEMName[7] = 0;
        rf.BS_VolLab[10] = 0;
        rf.BS_FileSysType[7] = 0;

        qDebug() << "BS_OEMName: " << rf.BS_OEMName;
        qDebug() << "BPB_BytsPerSec: " << hex << rf.BPB_BytsPerSec;
        qDebug() << "BPB_SecPerClus: " << hex << rf.BPB_SecPerClus;
        qDebug() << "BPB_RsvdSecCnt: " << hex << rf.BPB_RsvdSecCnt;
        qDebug() << "BPB_NumFATs: " << hex << rf.BPB_NumFATs;
        qDebug() << "BPB_RootEntCnt: " << hex << rf.BPB_RootEntCnt;
        qDebug() << "BPB_TotSec16: " << hex << rf.BPB_TotSec16;
        qDebug() << "BPB_Media: " << hex << rf.BPB_Media;
        qDebug() << "BPB_FATSz16: " << hex << rf.BPB_FATSz16;
        qDebug() << "BPB_SecPerTrk: " << hex << rf.BPB_SecPerTrk;
        qDebug() << "BPB_NumHeads: " << hex << rf.BPB_NumHeads;
        qDebug() << "BPB_HiddSec: " << hex << rf.BPB_HiddSec;
        qDebug() << "BPB_TotSec32: " << hex << rf.BPB_TotSec32;
        qDebug() << "BS_DrvNum: " << hex << rf.BS_DrvNum;
        qDebug() << "BS_Reserved1: " << hex << rf.BS_Reserved1;
        qDebug() << "BS_BootSig: " << hex << rf.BS_BootSig;
        qDebug() << "BS_VolID: " << hex << rf.BS_VolID;
        qDebug() << "BS_VolLab: " << rf.BS_VolLab;
        qDebug() << "BS_FileSysType: " << rf.BS_FileSysType;

        file.seek(510); //定位到第510个字节

        uchar b510 = 0;
        uchar b511 = 0;

        //读取第510、511字节位置处内容，即结束标志
        in.readRawData(reinterpret_cast<char*>(&b510), sizeof(b510));
        in.readRawData(reinterpret_cast<char*>(&b511), sizeof(b511));

        qDebug() << "Byte 510: " << hex << b510;
        qDebug() << "Byte 511: " << hex << b511;
    }

    file.close();
}

//获取一个根目录项
RootEntry FindRootEntry(Fat12Header& rf, QString p, int i)
{
    RootEntry ret = {{0}};

    QFile file(p);

    //BPB_RootEntCnt为最大根目录文件数
    if( file.open(QIODevice::ReadOnly) && (0 <= i) && (i < rf.BPB_RootEntCnt) )
    {
        QDataStream in(&file);

        //定位到19扇区的各个根目录项开始处
        file.seek(19 * rf.BPB_BytsPerSec + i * sizeof(RootEntry));
        //每次只读一个根目录项
        in.readRawData(reinterpret_cast<char*>(&ret), sizeof(ret));
    }

    file.close();

    return ret; //返回读取到的根目录项
}

//打印根目录项
void PrintRootEntry(Fat12Header& rf, QString p)
{
    //依次遍历每个根目录项并获取打印
    for(int i=0; i<rf.BPB_RootEntCnt; i++)
    {
        RootEntry re = FindRootEntry(rf, p, i);
        if( re.DIR_Name[0] != '\0' )
        {
            qDebug() << i << ":";
            qDebug() << "DIR_Name: " << hex << re.DIR_Name;
            qDebug() << "DIR_Attr: " << hex << re.DIR_Attr;
            qDebug() << "DIR_WrtDate: " << hex << re.DIR_WrtDate;
            qDebug() << "DIR_WrtTime: " << hex << re.DIR_WrtTime;
            qDebug() << "DIR_FstClus: " << hex << re.DIR_FstClus;
            qDebug() << "DIR_FileSize: " << hex << re.DIR_FileSize;
        }
    }
}

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    QString strImg = "E:\\DTSoftWare\\Code\\Fat12Test\\data.img";

    Fat12Header f12;

    //读取并打印data.img主引导程序(第0扇区)的关键信息
    PrintHeader(f12, strImg);

    qDebug() << "*****************";
    //读取根目录项信息
    PrintRootEntry(f12, strImg);

    return a.exec();
}
