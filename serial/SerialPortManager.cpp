#include "SerialPortManager.h"
#include <QDebug>

/**
 * @brief 构造函数
 * @param parent 父对象指针
 *
 * 初始化串口管理器，设置默认参数，并连接信号槽
 */
SerialPortManager::SerialPortManager(QObject *parent)
    : QObject(parent)
    , m_serialPort(new QSerialPort(this))
    , m_isConnected(false)
{
    updateAvailablePorts();

    connect(m_serialPort, &QSerialPort::readyRead, this, &SerialPortManager::onReadyRead);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &SerialPortManager::onErrorOccurred);
}

/**
 * @brief 析构函数
 *
 * 关闭已打开的串口连接
 */
SerialPortManager::~SerialPortManager()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }
}

/**
 * @brief 获取可用串口列表
 * @return 可用串口名称列表
 */
QStringList SerialPortManager::availablePorts() const
{
    return m_availablePorts;
}

/**
 * @brief 获取串口连接状态
 * @return true表示已连接，false表示未连接
 */
bool SerialPortManager::isConnected() const
{
    return m_isConnected;
}

/**
 * @brief 获取当前串口名称
 * @return 当前连接的串口名称
 */
QString SerialPortManager::currentPort() const
{
    return m_currentPort;
}

/**
 * @brief 刷新可用串口列表
 *
 * 更新可用串口列表并发送信号通知
 */
void SerialPortManager::refreshPorts()
{
    updateAvailablePorts();
    emit availablePortsChanged();
}

/**
 * @brief 打开指定串口
 * @param portName 串口名称
 * @param baudRate 波特率（默认9600）
 * @return true表示打开成功，false表示打开失败
 *
 * 配置串口参数：8位数据位、无校验、1位停止位、无流控制
 */
bool SerialPortManager::openPort(const QString &portName, int baudRate)
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudRate);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serialPort->open(QIODevice::ReadWrite)) {
        m_isConnected = true;
        m_currentPort = portName;
        emit isConnectedChanged();
        emit currentPortChanged();
        return true;
    } else {
        emit errorOccurred(m_serialPort->errorString());
        return false;
    }
}

/**
 * @brief 关闭当前串口
 *
 * 关闭串口并重置连接状态和当前端口信息
 */
void SerialPortManager::closePort()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        m_isConnected = false;
        m_currentPort.clear();
        emit isConnectedChanged();
        emit currentPortChanged();
    }
}

/**
 * @brief 向串口发送数据
 * @param data 要发送的数据（UTF-8编码的字符串）
 * @return true表示发送成功，false表示发送失败
 */
bool SerialPortManager::sendData(const QString &data)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("串口未打开");
        return false;
    }

    QByteArray byteArray = data.toUtf8();
    qint64 bytesWritten = m_serialPort->write(byteArray);
    return bytesWritten != -1;
}

/**
 * @brief 读取串口接收缓冲区数据
 * @return 读取到的数据（UTF-8编码的字符串）
 *
 * 读取后清空缓冲区
 */
QString SerialPortManager::readData()
{
    QString data = QString::fromUtf8(m_readBuffer);
    m_readBuffer.clear();
    return data;
}

/**
 * @brief 串口数据可读时的槽函数
 *
 * 读取所有可用数据，追加到缓冲区，并发送数据接收信号
 */
void SerialPortManager::onReadyRead()
{
    QByteArray data = m_serialPort->readAll();
    m_readBuffer.append(data);
    emit dataReceived(QString::fromUtf8(data));
}

/**
 * @brief 串口错误发生时的槽函数
 * @param error 错误类型
 *
 * 发送错误信息信号
 */
void SerialPortManager::onErrorOccurred(QSerialPort::SerialPortError error)
{
    if (error != QSerialPort::NoError) {
        emit errorOccurred(m_serialPort->errorString());
    }
}

/**
 * @brief 更新可用串口列表
 *
 * 遍历系统所有可用串口并存储到列表中
 */
void SerialPortManager::updateAvailablePorts()
{
    m_availablePorts.clear();
    const auto ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        m_availablePorts.append(port.portName());
    }
}
