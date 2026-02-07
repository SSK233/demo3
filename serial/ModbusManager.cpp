#include "ModbusManager.h"
#include <QDebug>
#include <QVariant>
#include <QSerialPort>

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
    m_modbusMaster = new QModbusRtuSerialMaster(this);
    
    connect(m_modbusMaster, &QModbusClient::stateChanged,
            this, &ModbusManager::onStateChanged);
    connect(m_modbusMaster, &QModbusClient::errorOccurred,
            this, &ModbusManager::onErrorOccurred);
    
    m_readTimer = new QTimer(this);
    m_readTimer->setInterval(1000);
    connect(m_readTimer, &QTimer::timeout, this, &ModbusManager::readAllRegisters);
}

ModbusManager::~ModbusManager()
{
    if (m_modbusMaster) {
        m_modbusMaster->disconnectDevice();
    }
}

bool ModbusManager::connectToPort(const QString &portName, int baudRate, int parity)
{
    if (m_connected) {
        disconnectPort();
    }
    
    QSerialPort::Parity parityValue = QSerialPort::NoParity;
    if (parity == 1) {
        parityValue = QSerialPort::OddParity;
    } else if (parity == 2) {
        parityValue = QSerialPort::EvenParity;
    }
    
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialPortNameParameter, QVariant::fromValue(portName));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, QVariant::fromValue(baudRate));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, QVariant::fromValue(QSerialPort::Data8));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialParityParameter, QVariant::fromValue(parityValue));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, QVariant::fromValue(QSerialPort::OneStop));
    
    m_modbusMaster->setTimeout(1000);
    m_modbusMaster->setNumberOfRetries(3);
    
    m_modbusMaster->connectDevice();
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

void ModbusManager::disconnectPort()
{
    stopReading();
    if (m_modbusMaster) {
        m_modbusMaster->disconnectDevice();
    }
    m_connected = false;
    emit connectedChanged();
}

void ModbusManager::startReading(int intervalMs)
{
    if (m_readTimer) {
        m_readTimer->setInterval(intervalMs);
        m_readTimer->start();
        qDebug() << "Started reading Modbus registers every" << intervalMs << "ms";
    }
}

void ModbusManager::stopReading()
{
    if (m_readTimer) {
        m_readTimer->stop();
    }
}

void ModbusManager::onStateChanged(QModbusDevice::State state)
{
    bool newConnected = (state == QModbusDevice::ConnectedState);
    if (m_connected != newConnected) {
        m_connected = newConnected;
        emit connectedChanged();
        qDebug() << "Modbus state changed:" << (newConnected ? "connected" : "disconnected");
    }
}

void ModbusManager::onErrorOccurred(QModbusDevice::Error error)
{
    if (error != QModbusDevice::NoError) {
        emit errorOccurred(m_modbusMaster->errorString());
        qDebug() << "Modbus error:" << m_modbusMaster->errorString();
    }
}

void ModbusManager::readAllRegisters()
{
    if (!m_connected || !m_modbusMaster) {
        return;
    }
    
    m_pendingReads = 5;
    
    readHoldingRegister(VOLTAGE_SLAVE_ADDRESS, VOLTAGE_REGISTER_ADDRESS);
    readHoldingRegister(CURRENT_SLAVE_ADDRESS, CURRENT_REGISTER_ADDRESS);
    readHoldingRegister(POWER_SLAVE_ADDRESS, POWER_REGISTER_ADDRESS);
    readHoldingRegister(FAN_STATE_SLAVE_ADDRESS, FAN_STATE_REGISTER_ADDRESS);
    readHoldingRegister(HIGH_TEMP_SLAVE_ADDRESS, HIGH_TEMP_REGISTER_ADDRESS);
}

void ModbusManager::readHoldingRegister(int slaveAddress, int registerAddress)
{
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        return;
    }
    
    QModbusDataUnit readUnit(QModbusDataUnit::HoldingRegisters, registerAddress, 1);
    
    if (auto *reply = m_modbusMaster->sendReadRequest(readUnit, slaveAddress)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, &ModbusManager::onReadReady);
        } else {
            delete reply;
        }
    } else {
        qDebug() << "Modbus read error:" << m_modbusMaster->errorString();
    }
}

void ModbusManager::onReadReady()
{
    auto reply = qobject_cast<QModbusReply *>(sender());
    if (!reply) {
        return;
    }
    
    if (reply->error() == QModbusDevice::NoError) {
        const QModbusDataUnit unit = reply->result();
        int slaveAddress = reply->serverAddress();
        int registerAddress = unit.startAddress();
        
        if (unit.valueCount() > 0) {
            quint16 rawValue = unit.value(0);
            
            if (slaveAddress == VOLTAGE_SLAVE_ADDRESS && registerAddress == VOLTAGE_REGISTER_ADDRESS) {
                m_voltage = rawValue * 0.1;
                emit voltageChanged();
            } else if (slaveAddress == CURRENT_SLAVE_ADDRESS && registerAddress == CURRENT_REGISTER_ADDRESS) {
                m_current = rawValue * 0.1;
                emit currentChanged();
            } else if (slaveAddress == POWER_SLAVE_ADDRESS && registerAddress == POWER_REGISTER_ADDRESS) {
                m_power = rawValue * 0.01;
                emit powerChanged();
            } else if (slaveAddress == FAN_STATE_SLAVE_ADDRESS && registerAddress == FAN_STATE_REGISTER_ADDRESS) {
                m_fanState = rawValue;
                if (!m_hasFanStateData) {
                    m_hasFanStateData = true;
                    emit hasFanStateDataChanged();
                }
                emit fanStateChanged();
            } else if (slaveAddress == HIGH_TEMP_SLAVE_ADDRESS && registerAddress == HIGH_TEMP_REGISTER_ADDRESS) {
                m_highTempState = rawValue;
                if (!m_hasHighTempData) {
                    m_hasHighTempData = true;
                    emit hasHighTempDataChanged();
                }
                emit highTempStateChanged();
            }
        }
    } else {
        qDebug() << "Modbus reply error:" << reply->errorString();
    }
    
    reply->deleteLater();
}

void ModbusManager::writeHoldingRegister(int slaveAddress, int registerAddress, double value)
{
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write";
        return;
    }
    
    quint16 rawValue = static_cast<quint16>(qRound(value));
    
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, registerAddress, 1);
    writeUnit.setValue(0, rawValue);
    
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, slaveAddress)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, [this, reply, slaveAddress, registerAddress, value]() {
                if (reply->error() == QModbusDevice::NoError) {
                    qDebug() << "Write successful - Slave:" << slaveAddress 
                             << "Register:" << registerAddress 
                             << "Value:" << value;
                } else {
                    qDebug() << "Write error:" << reply->errorString();
                }
                reply->deleteLater();
            });
        } else {
            delete reply;
        }
    } else {
        qDebug() << "Modbus write request error:" << m_modbusMaster->errorString();
    }
}

void ModbusManager::writeVoltage(double value)
{
    writeHoldingRegister(WRITE_VOLTAGE_SLAVE_ADDRESS, WRITE_VOLTAGE_REGISTER_ADDRESS, value);
}

void ModbusManager::writeCurrent(double value)
{
    writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS, WRITE_CURRENT_REGISTER_ADDRESS, value);
}

void ModbusManager::writeFanState(bool state)
{
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write fan state";
        return;
    }
    
    quint16 rawValue = state ? 1 : 0;
    
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, FAN_REGISTER_ADDRESS, 1);
    writeUnit.setValue(0, rawValue);
    
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, FAN_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, [this, reply, state]() {
                if (reply->error() == QModbusDevice::NoError) {
                    qDebug() << "Fan state write successful - State:" << (state ? "ON(1)" : "OFF(0)");
                } else {
                    qDebug() << "Fan state write error:" << reply->errorString();
                }
                reply->deleteLater();
            });
        } else {
            delete reply;
        }
    } else {
        qDebug() << "Fan state write request error:" << m_modbusMaster->errorString();
    }
}

void ModbusManager::writeVoltageAndCurrent(double voltage, double current)
{
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write";
        return;
    }
    
    quint16 voltageRaw = static_cast<quint16>(qRound(voltage));
    quint16 currentRaw = static_cast<quint16>(qRound(current));
    
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, WRITE_VOLTAGE_REGISTER_ADDRESS, 2);
    writeUnit.setValue(0, voltageRaw);
    writeUnit.setValue(1, currentRaw);
    
    qDebug() << "========================================";
    qDebug() << "发送写入请求:";
    qDebug() << "  从站地址:" << WRITE_VOLTAGE_SLAVE_ADDRESS;
    qDebug() << "  起始寄存器:" << WRITE_VOLTAGE_REGISTER_ADDRESS;
    qDebug() << "  寄存器数量: 2";
    qDebug() << "  电压值(原始):" << voltageRaw << "(" << voltage << "V)";
    qDebug() << "  电流值(原始):" << currentRaw << "(" << current << "A)";
    qDebug() << "========================================";
    
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, WRITE_VOLTAGE_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, [this, reply, voltage, current]() {
                qDebug() << "========================================";
                qDebug() << "收到PLC响应:";
                if (reply->error() == QModbusDevice::NoError) {
                    const QModbusDataUnit result = reply->result();
                    qDebug() << "  状态: 写入成功";
                    qDebug() << "  从站地址:" << reply->serverAddress();
                    qDebug() << "  功能码:" << static_cast<int>(result.registerType());
                    qDebug() << "  起始地址:" << result.startAddress();
                    qDebug() << "  写入寄存器数:" << result.valueCount();
                    qDebug() << "  写入数据: 电压=" << voltage << "V, 电流=" << current << "A";
                } else {
                    qDebug() << "  状态: 写入失败";
                    qDebug() << "  错误码:" << static_cast<int>(reply->error());
                    qDebug() << "  错误信息:" << reply->errorString();
                }
                qDebug() << "========================================";
                reply->deleteLater();
            });
        } else {
            delete reply;
        }
    } else {
        qDebug() << "发送请求失败:" << m_modbusMaster->errorString();
    }
}

void ModbusManager::writeUnload()
{
    if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
        qDebug() << "Modbus not connected, cannot write unload";
        return;
    }
    
    QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, UNLOAD_REGISTER_ADDRESS, 1);
    writeUnit.setValue(0, 1);
    
    qDebug() << "========================================";
    qDebug() << "发送卸载请求:";
    qDebug() << "  从站地址:" << UNLOAD_SLAVE_ADDRESS;
    qDebug() << "  寄存器地址:" << UNLOAD_REGISTER_ADDRESS;
    qDebug() << "  写入值: 1";
    qDebug() << "========================================";
    
    if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, UNLOAD_SLAVE_ADDRESS)) {
        if (!reply->isFinished()) {
            connect(reply, &QModbusReply::finished, this, [this, reply]() {
                qDebug() << "========================================";
                qDebug() << "收到PLC响应(卸载):";
                if (reply->error() == QModbusDevice::NoError) {
                    const QModbusDataUnit result = reply->result();
                    qDebug() << "  状态: 写入成功";
                    qDebug() << "  从站地址:" << reply->serverAddress();
                    qDebug() << "  寄存器地址:" << result.startAddress();
                    qDebug() << "  写入值: 1";
                } else {
                    qDebug() << "  状态: 写入失败";
                    qDebug() << "  错误码:" << static_cast<int>(reply->error());
                    qDebug() << "  错误信息:" << reply->errorString();
                }
                qDebug() << "========================================";
                reply->deleteLater();
            });
        } else {
            delete reply;
        }
    } else {
        qDebug() << "发送卸载请求失败:" << m_modbusMaster->errorString();
    }
}
