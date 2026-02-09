#include "DataRecorder.h"
#include <QDebug>
#include <QStandardPaths>
#include <QDir>

DataRecorder::DataRecorder(QObject *parent)
    : QObject(parent)
    , m_timer(nullptr)
    , m_recording(false)
    , m_interval(3)
    , m_lastVoltage(0.0)
    , m_lastCurrent(0.0)
    , m_lastPower(0.0)
{
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &DataRecorder::onTimerTimeout);
}

DataRecorder::~DataRecorder()
{
    if (m_timer) {
        m_timer->stop();
    }
}

void DataRecorder::setInterval(int seconds)
{
    if (m_interval != seconds && seconds > 0) {
        m_interval = seconds;
        emit intervalChanged();
        if (m_recording && m_timer) {
            m_timer->setInterval(m_interval * 1000);
        }
    }
}

void DataRecorder::startRecording()
{
    if (m_recording) {
        return;
    }
    
    m_recording = true;
    m_timer->setInterval(m_interval * 1000);
    m_timer->start();
    
    qDebug() << "开始记录数据，间隔:" << m_interval << "秒";
    emit recordingChanged();
}

void DataRecorder::stopRecording()
{
    if (!m_recording) {
        return;
    }
    
    m_recording = false;
    m_timer->stop();
    
    qDebug() << "停止记录数据，共记录" << m_records.size() << "条";
    emit recordingChanged();
}

void DataRecorder::addData(double voltage, double current, double power)
{
    m_lastVoltage = voltage;
    m_lastCurrent = current;
    m_lastPower = power;
}

void DataRecorder::onTimerTimeout()
{
    DataRecord record;
    record.timestamp = QDateTime::currentDateTime();
    record.voltage = m_lastVoltage;
    record.current = m_lastCurrent;
    record.power = m_lastPower;
    
    m_records.append(record);
    
    QString timeStr = record.timestamp.toString("yyyy-MM-dd HH:mm:ss");
    qDebug() << QString("记录数据 [%1] 电压: %2 V, 电流: %3 A, 功率: %4 kW")
                    .arg(timeStr)
                    .arg(record.voltage, 0, 'f', 2)
                    .arg(record.current, 0, 'f', 2)
                    .arg(record.power, 0, 'f', 3);
    
    emit dataAdded(timeStr, record.voltage, record.current, record.power);
    emit recordCountChanged();
}

void DataRecorder::exportToExcel(const QString &filePath)
{
    QString actualPath = filePath;
    if (actualPath.isEmpty()) {
        QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        QString fileName = QString("数据报表_%1.csv")
                               .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
        actualPath = QDir(desktopPath).filePath(fileName);
    }
    
    QFile file(actualPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "无法打开文件:" << actualPath;
        emit exportFinished(false, actualPath);
        return;
    }
    
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    
    QByteArray bom = "\xEF\xBB\xBF";
    file.write(bom);
    
    out << "时间,电压(V),电流(A),功率(kW)\n";
    
    for (const DataRecord &record : m_records) {
        out << "'" << record.timestamp.toString("yyyy-MM-dd HH:mm:ss") << ","
            << QString::number(record.voltage, 'f', 2) << ","
            << QString::number(record.current, 'f', 2) << ","
            << QString::number(record.power, 'f', 3) << "\n";
    }
    
    file.close();
    
    qDebug() << "数据已导出到:" << actualPath;
    qDebug() << "共导出" << m_records.size() << "条记录";
    emit exportFinished(true, actualPath);
}

void DataRecorder::clearData()
{
    m_records.clear();
    qDebug() << "已清除所有记录数据";
    emit recordCountChanged();
}

int DataRecorder::recordCount() const
{
    return m_records.size();
}
