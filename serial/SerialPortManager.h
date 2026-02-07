#ifndef SERIALPORTMANAGER_H
#define SERIALPORTMANAGER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QStringList>
#include <QVariantList>

class SerialPortManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString currentPort READ currentPort NOTIFY currentPortChanged)

public:
    explicit SerialPortManager(QObject *parent = nullptr);
    ~SerialPortManager();

    QStringList availablePorts() const;
    bool isConnected() const;
    QString currentPort() const;

    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE bool openPort(const QString &portName, int baudRate = 9600);
    Q_INVOKABLE void closePort();
    Q_INVOKABLE bool sendData(const QString &data);
    Q_INVOKABLE QString readData();

signals:
    void availablePortsChanged();
    void isConnectedChanged();
    void currentPortChanged();
    void dataReceived(const QString &data);
    void errorOccurred(const QString &error);

private slots:
    void onReadyRead();
    void onErrorOccurred(QSerialPort::SerialPortError error);

private:
    QSerialPort *m_serialPort;
    QStringList m_availablePorts;
    bool m_isConnected;
    QString m_currentPort;
    QByteArray m_readBuffer;

    void updateAvailablePorts();
};

#endif
