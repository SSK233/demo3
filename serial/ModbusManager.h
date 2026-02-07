#ifndef MODBUSMANAGER_H
#define MODBUSMANAGER_H

#include <QObject>
#include <QModbusRtuSerialMaster>
#include <QModbusDataUnit>
#include <QTimer>

/**
 * @brief 电压读取相关常量定义
 * @details 定义读取电压数据的Modbus配置
 */
constexpr int VOLTAGE_SLAVE_ADDRESS = 3;//从站地址3
constexpr int VOLTAGE_REGISTER_ADDRESS = 0;//寄存器地址0

/**
 * @brief 电流读取相关常量定义
 * @details 定义读取电流数据的Modbus配置
 */
constexpr int CURRENT_SLAVE_ADDRESS = 3;//从站地址3
constexpr int CURRENT_REGISTER_ADDRESS = 1;//寄存器地址1

/**
 * @brief 功率读取相关常量定义
 * @details 定义读取功率数据的Modbus配置
 */
constexpr int POWER_SLAVE_ADDRESS = 3;//从站地址3
constexpr int POWER_REGISTER_ADDRESS = 3;//寄存器地址3

class ModbusManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double voltage READ voltage NOTIFY voltageChanged)
    Q_PROPERTY(double current READ current NOTIFY currentChanged)
    Q_PROPERTY(double power READ power NOTIFY powerChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit ModbusManager(QObject *parent = nullptr);
    ~ModbusManager();

    double voltage() const { return m_voltage; }
    double current() const { return m_current; }
    double power() const { return m_power; }
    bool connected() const { return m_connected; }

    Q_INVOKABLE bool connectToPort(const QString &portName, int baudRate = 9600);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE void startReading(int intervalMs = 1000);
    Q_INVOKABLE void stopReading();

signals:
    void voltageChanged();
    void currentChanged();
    void powerChanged();
    void connectedChanged();
    void errorOccurred(const QString &error);

private slots:
    void onStateChanged(QModbusDevice::State state);
    void onErrorOccurred(QModbusDevice::Error error);
    void readAllRegisters();
    void onReadReady();

private:
    QModbusRtuSerialMaster *m_modbusMaster;
    QTimer *m_readTimer;
    double m_voltage;
    double m_current;
    double m_power;
    bool m_connected;
    int m_pendingReads;

    void readHoldingRegister(int slaveAddress, int registerAddress);
};

#endif
