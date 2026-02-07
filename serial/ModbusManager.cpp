// 包含必要的头文件
#include "ModbusManager.h"
#include <QDebug>
#include <QVariant>
#include <QSerialPort>

/**
 * @brief ModbusManager构造函数
 * @param parent 父对象
 * @details 初始化Modbus管理器，创建Modbus RTU串行主机和读取定时器
 */
ModbusManager::ModbusManager(QObject *parent)
    : QObject(parent)
    , m_modbusMaster(nullptr)
    , m_readTimer(nullptr)
    , m_voltage(0.0)
    , m_current(0.0)
    , m_power(0.0)
    , m_connected(false)
    , m_fanState(0)
    , m_highTempState(0)
    , m_hasFanStateData(false)
    , m_hasHighTempData(false)
    , m_pendingReads(0)
{
    // 创建Modbus RTU串行主机
    m_modbusMaster = new QModbusRtuSerialMaster(this);
    
    // 连接状态变化信号
    connect(m_modbusMaster, &QModbusClient::stateChanged,
            this, &ModbusManager::onStateChanged);
    // 连接错误发生信号
    connect(m_modbusMaster, &QModbusClient::errorOccurred,
            this, &ModbusManager::onErrorOccurred);
    
    // 创建读取定时器
    m_readTimer = new QTimer(this);
    m_readTimer->setInterval(1000); // 默认读取间隔为1000毫秒
    // 连接定时器超时信号到读取所有寄存器的槽函数
    connect(m_readTimer, &QTimer::timeout, this, &ModbusManager::readAllRegisters);
}

/**
 * @brief ModbusManager析构函数
 * @details 断开Modbus设备连接，释放资源
 */
ModbusManager::~ModbusManager()
{
    if (m_modbusMaster) {
        m_modbusMaster->disconnectDevice();
    }
}

/**
 * @brief 连接到Modbus设备
 * @param portName 串口名称
 * @param baudRate 波特率
 * @param parity 校验位（0：无校验，1：奇校验，2：偶校验）
 * @return 连接是否成功
 * @details 配置并连接到Modbus RTU设备
 */
bool ModbusManager::connectToPort(const QString &portName, int baudRate, int parity)
{
    // 如果已经连接，先断开
    if (m_connected) {
        disconnectPort();
    }
    
    // 配置校验位
    QSerialPort::Parity parityValue = QSerialPort::NoParity;
    if (parity == 1) {
        parityValue = QSerialPort::OddParity;
    } else if (parity == 2) {
        parityValue = QSerialPort::EvenParity;
    }
    
    // 设置连接参数
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialPortNameParameter, QVariant::fromValue(portName));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, QVariant::fromValue(baudRate));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, QVariant::fromValue(QSerialPort::Data8));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialParityParameter, QVariant::fromValue(parityValue));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, QVariant::fromValue(QSerialPort::OneStop));
    
    // 设置超时和重试次数
    m_modbusMaster->setTimeout(1000);
    m_modbusMaster->setNumberOfRetries(3);
    
    // 连接设备
    m_modbusMaster->connectDevice();
    
    // 输出连接参数
    QString parityStr = (parity == 0) ? "无校验" : (parity == 1) ? "奇校验" : "偶校验";
    qDebug() << "========================================";
    qDebug() << "Modbus 连接参数:";
    qDebug() << "  串口号:" << portName;
    qDebug() << "  波特率:" << baudRate;
    qDebug() << "  校验位:" << parityStr;
    qDebug() << "  数据位: 8";
    qDebug() << "  停止位: 1";
    qDebug() << "========================================";
    return true;
}

/**
 * @brief 断开与Modbus设备的连接
 * @details 停止读取并断开设备连接
 */
void ModbusManager::disconnectPort()
{
    // 停止读取
    stopReading();
    // 断开设备连接
    if (m_modbusMaster) {
        m_modbusMaster->disconnectDevice();
    }
    // 更新连接状态
    m_connected = false;
    emit connectedChanged();
}

/**
 * @brief 开始定时读取数据
 * @param intervalMs 读取间隔，单位为毫秒
 * @details 启动定时器，定时读取Modbus寄存器
 */
void ModbusManager::startReading(int intervalMs)
{
    if (m_readTimer) {
        // 设置读取间隔
        m_readTimer->setInterval(intervalMs);
        // 启动定时器
        m_readTimer->start();
        qDebug() << "Started reading Modbus registers every" << intervalMs << "ms";
    }
}

/**
 * @brief 停止定时读取数据
 * @details 停止读取定时器
 */
void ModbusManager::stopReading()
{
    if (m_readTimer) {
        m_readTimer->stop();
    }
}

/**
 * @brief 设备状态变化槽函数
 * @param state 新的设备状态
 * @details 处理Modbus设备状态变化，更新连接状态
 */
void ModbusManager::onStateChanged(QModbusDevice::State state)
{
    bool newConnected = (state == QModbusDevice::ConnectedState);
    if (m_connected != newConnected) {
        m_connected = newConnected;
        emit connectedChanged();
        qDebug() << "Modbus state changed:" << (newConnected ? "connected" : "disconnected");
    }
}

/**
 * @brief 错误发生槽函数
 * @param error 错误类型
 * @details 处理Modbus设备错误，发送错误信号
 */
void ModbusManager::onErrorOccurred(QModbusDevice::Error error)
{
    if (error != QModbusDevice::NoError) {
        emit errorOccurred(m_modbusMaster->errorString());
        qDebug() << "Modbus error:" << m_modbusMaster->errorString();
    }
}

/**
 * @brief 读取所有寄存器槽函数
 * @details 读取所有需要的Modbus寄存器值
 */
void ModbusManager::readAllRegisters()
{
    // 检查连接状态
    if (!m_connected || !m_modbusMaster) {
        return;
    }
    
    // 设置待处理的读取请求数量
    m_pendingReads = 5;
    
    // 读取各个寄存器
    readHoldingRegister(VOLTAGE_SLAVE_ADDRESS, VOLTAGE_REGISTER_ADDRESS);
    readHoldingRegister(CURRENT_SLAVE_ADDRESS, CURRENT_REGISTER_ADDRESS);
    readHoldingRegister(POWER_SLAVE_ADDRESS, POWER_REGISTER_ADDRESS);
    readHoldingRegister(FAN_STATE_SLAVE_ADDRESS, FAN_STATE_REGISTER_ADDRESS);
    readHoldingRegister(HIGH_TEMP_SLAVE_ADDRESS, HIGH_TEMP_REGISTER_ADDRESS);
}

/**
 * @brief 读取保持寄存器
 * @param slaveAddress 从站地址
 * @param registerAddress 寄存器地址
 * @details 发送Modbus读取请求，读取指定的保持寄存器
 */
void ModbusManager::readHoldingRegister(int slaveAddress, int registerAddress)
{
    // 检查连接状态
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        return;
    }
    
    // 创建读取单元
    QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, registerAddress, 1);
    
    // 发送读取请求
    if (auto *reply = m_modbusMaster->sendReadRequest(readUnit, slaveAddress)) {
        if (!reply->isFinished()) {
            // 连接读取完成信号
            connect(reply, &QModbusReply::finished, this, &ModbusManager::onReadReady);
        } else {
            // 读取已完成，删除回复
            delete reply;
        }
    } else {
        // 发送请求失败
        qDebug() << "Modbus read error:" << m_modbusMaster->errorString();
    }
}

/**
 * @brief 读取完成槽函数
 * @details 处理Modbus读取回复，更新相应的数据
 */
void ModbusManager::onReadReady()
{
    // 获取发送者（回复对象）
    auto reply = qobject_cast<QModbusReply *>(sender());
    if (!reply) {
        return;
    }
    
    // 处理回复
    if (reply->error() == QModbusDevice::NoError) {
        // 获取回复数据
        const QModbusDataUnit unit = reply->result();
        int slaveAddress = reply->serverAddress();
        int registerAddress = unit.startAddress();
        
        // 检查是否有数据
        if (unit.valueCount() > 0) {
            // 获取原始值
            quint16 rawValue = unit.value(0);
            
            // 根据从站地址和寄存器地址更新相应的数据
            if (slaveAddress == VOLTAGE_SLAVE_ADDRESS && registerAddress == VOLTAGE_REGISTER_ADDRESS) {
                // 更新电压值（原始值乘以0.1）
                m_voltage = rawValue * 0.1;
                emit voltageChanged();
            } else if (slaveAddress == CURRENT_SLAVE_ADDRESS && registerAddress == CURRENT_REGISTER_ADDRESS) {
                // 更新电流值（原始值乘以0.1）
                m_current = rawValue * 0.1;
                emit currentChanged();
            } else if (slaveAddress == POWER_SLAVE_ADDRESS && registerAddress == POWER_REGISTER_ADDRESS) {
                // 更新功率值（原始值乘以0.01）
                m_power = rawValue * 0.01;
                emit powerChanged();
            } else if (slaveAddress == FAN_STATE_SLAVE_ADDRESS && registerAddress == FAN_STATE_REGISTER_ADDRESS) {
                // 更新风机状态
                m_fanState = rawValue;
                if (!m_hasFanStateData) {
                    m_hasFanStateData = true;
                    emit hasFanStateDataChanged();
                }
                emit fanStateChanged();
            } else if (slaveAddress == HIGH_TEMP_SLAVE_ADDRESS && registerAddress == HIGH_TEMP_REGISTER_ADDRESS) {
                // 更新高温报警状态
                m_highTempState = rawValue;
                if (!m_hasHighTempData) {
                    m_hasHighTempData = true;
                    emit hasHighTempDataChanged();
                }
                emit highTempStateChanged();
            }
        }
    } else {
        // 读取错误
        qDebug() << "Modbus reply error:" << reply->errorString();
    }
    
    // 删除回复对象
    reply->deleteLater();
}

/**
 * @brief 写入保持寄存器
 * @param slaveAddress 从站地址
 * @param registerAddress 寄存器地址
 * @param value 要写入的值
 * @details 发送Modbus写入请求，写入指定的保持寄存器
 */
void ModbusManager::writeHoldingRegister(int slaveAddress, int registerAddress, double value)
{
    // 检查连接状态
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write";
        return;
    }
    
    // 将值转换为16位无符号整数
    quint16 rawValue = static_cast<quint16>(qRound(value));
    
    // 创建写入单元
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, registerAddress, 1);
    writeUnit.setValue(0, rawValue);
    
    // 发送写入请求
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, slaveAddress)) {
        if (!reply->isFinished()) {
            // 连接写入完成信号
            connect(reply, &QModbusReply::finished, this, [this, reply, slaveAddress, registerAddress, value]() {
                if (reply->error() == QModbusDevice::NoError) {
                    // 写入成功
                    qDebug() << "Write successful - Slave:" << slaveAddress 
                             << "Register:" << registerAddress 
                             << "Value:" << value;
                } else {
                    // 写入失败
                    qDebug() << "Write error:" << reply->errorString();
                }
                reply->deleteLater();
            });
        } else {
            // 写入已完成，删除回复
            delete reply;
        }
    } else {
        // 发送请求失败
        qDebug() << "Modbus write request error:" << m_modbusMaster->errorString();
    }
}

/**
 * @brief 写入电压值
 * @param value 要写入的电压值
 * @details 写入电压值到指定的寄存器
 */
void ModbusManager::writeVoltage(double value)
{
    writeHoldingRegister(WRITE_VOLTAGE_SLAVE_ADDRESS, WRITE_VOLTAGE_REGISTER_ADDRESS, value);
}

/**
 * @brief 写入电流值
 * @param value 要写入的电流值
 * @details 写入电流值到指定的寄存器
 */
void ModbusManager::writeCurrent(double value)
{
    writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS, WRITE_CURRENT_REGISTER_ADDRESS, value);
}

/**
 * @brief 写入风机状态
 * @param state 风机状态，true为开启，false为关闭
 * @details 写入风机状态到指定的寄存器
 */
void ModbusManager::writeFanState(bool state)
{
    // 检查连接状态
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write fan state";
        return;
    }
    
    // 将状态转换为16位无符号整数（1为开启，0为关闭）
    quint16 rawValue = state ? 1 : 0;
    
    // 创建写入单元
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, FAN_REGISTER_ADDRESS, 1);
    writeUnit.setValue(0, rawValue);
    
    // 发送写入请求
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, FAN_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            // 连接写入完成信号
            connect(reply, &QModbusReply::finished, this, [this, reply, state]() {
                if (reply->error() == QModbusDevice::NoError) {
                    // 写入成功
                    qDebug() << "Fan state write successful - State:" << (state ? "ON(1)" : "OFF(0)");
                } else {
                    // 写入失败
                    qDebug() << "Fan state write error:" << reply->errorString();
                }
                reply->deleteLater();
            });
        } else {
            // 写入已完成，删除回复
            delete reply;
        }
    } else {
        // 发送请求失败
        qDebug() << "Fan state write request error:" << m_modbusMaster->errorString();
    }
}

/**
 * @brief 同时写入电压和电流值
 * @param voltage 要写入的电压值
 * @param current 要写入的电流值
 * @details 同时写入电压和电流值到指定的寄存器
 */
void ModbusManager::writeVoltageAndCurrent(double voltage, double current)
{
    // 检查连接状态
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write";
        return;
    }
    
    // 将值转换为16位无符号整数
    quint16 voltageRaw = static_cast<quint16>(qRound(voltage));
    quint16 currentRaw = static_cast<quint16>(qRound(current));
    
    // 创建写入单元（写入2个寄存器）
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, WRITE_VOLTAGE_REGISTER_ADDRESS, 2);
    writeUnit.setValue(0, voltageRaw);
    writeUnit.setValue(1, currentRaw);
    
    // 输出写入请求信息
    qDebug() << "========================================";
    qDebug() << "发送写入请求:";
    qDebug() << "  从站地址:" << WRITE_VOLTAGE_SLAVE_ADDRESS;
    qDebug() << "  起始寄存器:" << WRITE_VOLTAGE_REGISTER_ADDRESS;
    qDebug() << "  寄存器数量: 2";
    qDebug() << "  电压值(原始):" << voltageRaw << "(" << voltage << "V)";
    qDebug() << "  电流值(原始):" << currentRaw << "(" << current << "A)";
    qDebug() << "========================================";
    
    // 发送写入请求
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, WRITE_VOLTAGE_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            // 连接写入完成信号
            connect(reply, &QModbusReply::finished, this, [this, reply, voltage, current]() {
                qDebug() << "========================================";
                qDebug() << "收到PLC响应:";
                if (reply->error() == QModbusDevice::NoError) {
                    // 写入成功
                    const QModbusDataUnit result = reply->result();
                    qDebug() << "  状态: 写入成功";
                    qDebug() << "  从站地址:" << reply->serverAddress();
                    qDebug() << "  功能码:" << static_cast<int>(result.registerType());
                    qDebug() << "  起始地址:" << result.startAddress();
                    qDebug() << "  写入寄存器数:" << result.valueCount();
                    qDebug() << "  写入数据: 电压=" << voltage << "V, 电流=" << current << "A";
                } else {
                    // 写入失败
                    qDebug() << "  状态: 写入失败";
                    qDebug() << "  错误码:" << static_cast<int>(reply->error());
                    qDebug() << "  错误信息:" << reply->errorString();
                }
                qDebug() << "========================================";
                reply->deleteLater();
            });
        } else {
            // 写入已完成，删除回复
            delete reply;
        }
    } else {
        // 发送请求失败
        qDebug() << "发送请求失败:" << m_modbusMaster->errorString();
    }
}

/**
 * @brief 写入卸载控制命令
 * @details 写入卸载控制命令到指定的寄存器
 */
void ModbusManager::writeUnload()
{
    // 检查连接状态
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write unload";
        return;
    }
    
    // 创建写入单元
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, UNLOAD_REGISTER_ADDRESS, 1);
    writeUnit.setValue(0, 1); // 写入值为1
    
    // 输出卸载请求信息
    qDebug() << "========================================";
    qDebug() << "发送卸载请求:";
    qDebug() << "  从站地址:" << UNLOAD_SLAVE_ADDRESS;
    qDebug() << "  寄存器地址:" << UNLOAD_REGISTER_ADDRESS;
    qDebug() << "  写入值: 1";
    qDebug() << "========================================";
    
    // 发送写入请求
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, UNLOAD_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            // 连接写入完成信号
            connect(reply, &QModbusReply::finished, this, [this, reply]() {
                qDebug() << "========================================";
                qDebug() << "收到PLC响应(卸载):";
                if (reply->error() == QModbusDevice::NoError) {
                    // 写入成功
                    const QModbusDataUnit result = reply->result();
                    qDebug() << "  状态: 写入成功";
                    qDebug() << "  从站地址:" << reply->serverAddress();
                    qDebug() << "  寄存器地址:" << result.startAddress();
                    qDebug() << "  写入值: 1";
                } else {
                    // 写入失败
                    qDebug() << "  状态: 写入失败";
                    qDebug() << "  错误码:" << static_cast<int>(reply->error());
                    qDebug() << "  错误信息:" << reply->errorString();
                }
                qDebug() << "========================================";
                reply->deleteLater();
            });
        } else {
            // 写入已完成，删除回复
            delete reply;
        }
    } else {
        // 发送请求失败
        qDebug() << "发送卸载请求失败:" << m_modbusMaster->errorString();
    }
}
