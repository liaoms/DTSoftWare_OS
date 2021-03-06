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

//获取指定文件名的根目录项
RootEntry FindRootEntry(Fat12Header& rf, QString p, QString fn)
{
    RootEntry ret = {{0}};

    for(int i=0; i<rf.BPB_RootEntCnt; i++)
    {
        RootEntry re = FindRootEntry(rf, p, i);

        if( re.DIR_Name[0] != '\0' )
        {
            int d = fn.lastIndexOf(".");
            QString name = QString(re.DIR_Name).trimmed();

            if( d >= 0 )
            {
                QString n = fn.mid(0, d);
                QString p = fn.mid(d + 1);

                if( name.startsWith(n) && name.endsWith(p) )
                {
                    ret = re;
                    break;
                }
            }
            else
            {
                if( fn == name )
                {
                    ret = re;
                    break;
                }
            }
        }
    }
    return ret;
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

//获取FAT表
QVector<ushort> ReadFat(Fat12Header& rf, QString p)
{
    QFile file(p);
    int size = rf.BPB_BytsPerSec * 9; //FAT表占用的大小(9个扇区字节)
    uchar* fat = new uchar[size];
    QVector<ushort> ret(size * 2 / 3, 0xFFFF); //每个FAT表项占用1.5字节，FAT表个数为: 占用内存 / 1.5

    if( file.open(QIODevice::ReadOnly) )
    {
        QDataStream in(&file);

        file.seek(rf.BPB_BytsPerSec * 1); //定位到第一个扇区(FAT表起始扇区)

        in.readRawData(reinterpret_cast<char*>(fat), size); //读取FAT表内容

        //分配规划FAT表
        for(int i=0, j=0; i<size; i+=3, j+=2)
        {
            ret[j] = static_cast<ushort>((fat[i+1] & 0x0F) << 8) | fat[i];
            ret[j+1] = static_cast<ushort>(fat[i+2] << 4) | ((fat[i+1] >> 4) & 0x0F);
        }
    }

    file.close();

    delete[] fat;

    return ret;
}

//获取文件内容
QByteArray ReadFileContent(Fat12Header& rf, QString p, QString fn)
{
    QByteArray ret;
    RootEntry re = FindRootEntry(rf, p, fn); //读取设定文件名的根目录文件项

    if( re.DIR_Name[0] != '\0' )
    {
        QVector<ushort> vec = ReadFat(rf, p); //获取FAT表
        QFile file(p);

        if( file.open(QIODevice::ReadOnly) )
        {
            char buf[512] = {0};
            QDataStream in(&file);
            int count = 0;

            ret.resize(re.DIR_FileSize);

            //遍历所有簇获取文件内容
            for(int i=0, j=re.DIR_FstClus; j<0xFF7; i+=512, j=vec[j])
            {
                //定位到文件数据扇区(33区)，数据区起始地址对应编号为2，所以要-2
                file.seek(rf.BPB_BytsPerSec * (33 + j - 2));

                in.readRawData(buf, sizeof(buf));

                for(uint k=0; k<sizeof(buf); k++)
                {
                    if( count < ret.size() )
                    {
                        ret[i+k] = buf[k];
                        count++;
                    }
                }
            }
        }
        file.close();
    }
    return ret;
}

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    QString strImg = "E:\\DTSoftWare\\Code\\Fat12Test\\data.img";

    Fat12Header f12;

    //读取并打印data.img主引导程序(第0扇区)的关键信息
    PrintHeader(f12, strImg);

    qDebug() << "*****************";
    //PrintRootEntry(f12, strImg);
    RootEntry re = FindRootEntry(f12, strImg, "LOADER.BIN");
    if( re.DIR_Name[0] != '\0' )
    {
        qDebug() << "DIR_Name: " << hex << re.DIR_Name;
        qDebug() << "DIR_Attr: " << hex << re.DIR_Attr;
        qDebug() << "DIR_WrtDate: " << hex << re.DIR_WrtDate;
        qDebug() << "DIR_WrtTime: " << hex << re.DIR_WrtTime;
        qDebug() << "DIR_FstClus: " << hex << re.DIR_FstClus;
        qDebug() << "DIR_FileSize: " << hex << re.DIR_FileSize;
    }
	qDebug() << endl;

    qDebug() << "Print File Content:";

    QString content = QString(ReadFileContent(f12, strImg, "TEST.TXT"));

    qDebug() << content;

    return a.exec();
}
