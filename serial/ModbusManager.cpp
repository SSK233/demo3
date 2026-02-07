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

bool ModbusManager::connectToPort(const QString &portName, int baudRate)
{
    if (m_connected) {
        disconnectPort();
    }
    
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialPortNameParameter, QVariant::fromValue(portName));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, QVariant::fromValue(baudRate));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, QVariant::fromValue(QSerialPort::Data8));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialParityParameter, QVariant::fromValue(QSerialPort::NoParity));
    m_modbusMaster->setConnectionParameter(QModbusDevice::SerialStopBitsParameter, QVariant::fromValue(QSerialPort::OneStop));
    
    m_modbusMaster->setTimeout(1000);
    m_modbusMaster->setNumberOfRetries(3);
    
    m_modbusMaster->connectDevice();
    qDebug() << "Modbus connecting to port:" << portName;
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
    
    m_pendingReads = 3;
    
    readHoldingRegister(VOLTAGE_SLAVE_ADDRESS, VOLTAGE_REGISTER_ADDRESS);
    readHoldingRegister(CURRENT_SLAVE_ADDRESS, CURRENT_REGISTER_ADDRESS);
    readHoldingRegister(POWER_SLAVE_ADDRESS, POWER_REGISTER_ADDRESS);
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
                qDebug() << "Voltage read:" << m_voltage << "V";
            } else if (slaveAddress == CURRENT_SLAVE_ADDRESS && registerAddress == CURRENT_REGISTER_ADDRESS) {
                m_current = rawValue * 0.1;
                emit currentChanged();
                qDebug() << "Current read:" << m_current << "A";
            } else if (slaveAddress == POWER_SLAVE_ADDRESS && registerAddress == POWER_REGISTER_ADDRESS) {
                m_power = rawValue * 0.01;
                emit powerChanged();
                qDebug() << "Power read:" << m_power << "kW";
            }
        }
    } else {
        qDebug() << "Modbus reply error:" << reply->errorString();
    }
    
    reply->deleteLater();
}
