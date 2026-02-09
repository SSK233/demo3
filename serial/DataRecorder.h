#ifndef DATARECORDER_H
#define DATARECORDER_H

#include <QObject>
#include <QTimer>
#include <QDateTime>
#include <QVector>
#include <QFile>
#include <QTextStream>

struct DataRecord {
    QDateTime timestamp;
    double voltage;
    double current;
    double power;
};

class DataRecorder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordCountChanged)

public:
    explicit DataRecorder(QObject *parent = nullptr);
    ~DataRecorder();

    bool recording() const { return m_recording; }
    int interval() const { return m_interval; }
    void setInterval(int seconds);

    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE void exportToExcel(const QString &filePath);
    Q_INVOKABLE void addData(double voltage, double current, double power);
    Q_INVOKABLE void clearData();
    Q_INVOKABLE int recordCount() const;

signals:
    void recordingChanged();
    void intervalChanged();
    void recordCountChanged();
    void dataAdded(const QString &timestamp, double voltage, double current, double power);
    void exportFinished(bool success, const QString &filePath);

private slots:
    void onTimerTimeout();

private:
    QTimer *m_timer;
    QVector<DataRecord> m_records;
    bool m_recording;
    int m_interval;
    double m_lastVoltage;
    double m_lastCurrent;
    double m_lastPower;
};

#endif
