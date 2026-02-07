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

/**
 * @brief 电压写入相关常量定义
 * @details 定义写入电压数据的Modbus配置
 */
constexpr int WRITE_VOLTAGE_SLAVE_ADDRESS = 1;//从站地址
constexpr int WRITE_VOLTAGE_REGISTER_ADDRESS = 50;//寄存器地址

/**
 * @brief 电流写入相关常量定义
 * @details 定义写入电流数据的Modbus配置
 */
constexpr int WRITE_CURRENT_SLAVE_ADDRESS = 1;//从站地址1
constexpr int WRITE_CURRENT_REGISTER_ADDRESS = 51;//寄存器地址51

/**
 * @brief 风机控制相关常量定义
 * @details 定义风机控制的Modbus配置
 */
constexpr int FAN_SLAVE_ADDRESS = 1;//从站地址1
constexpr int FAN_REGISTER_ADDRESS = 1;//寄存器地址1

/**
 * @brief 风机状态读取相关常量定义
 * @details 定义读取风机状态的Modbus配置
 */
constexpr int FAN_STATE_SLAVE_ADDRESS = 1;//从站地址1
constexpr int FAN_STATE_REGISTER_ADDRESS = 2;//寄存器地址2

/**
 * @brief 高温报警状态读取相关常量定义
 * @details 定义读取高温报警状态的Modbus配置
 */
constexpr int HIGH_TEMP_SLAVE_ADDRESS = 1;//从站地址1
constexpr int HIGH_TEMP_REGISTER_ADDRESS = 3;//寄存器地址3

/**
 * @brief 卸载控制相关常量定义
 * @details 定义卸载控制的Modbus配置
 */
constexpr int UNLOAD_SLAVE_ADDRESS = 1;//从站地址1
constexpr int UNLOAD_REGISTER_ADDRESS = 35;//寄存器地址35

class ModbusManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double voltage READ voltage NOTIFY voltageChanged)
    Q_PROPERTY(double current READ current NOTIFY currentChanged)
    Q_PROPERTY(double power READ power NOTIFY powerChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int fanState READ fanState NOTIFY fanStateChanged)
    Q_PROPERTY(int highTempState READ highTempState NOTIFY highTempStateChanged)
    Q_PROPERTY(bool hasFanStateData READ hasFanStateData NOTIFY hasFanStateDataChanged)
    Q_PROPERTY(bool hasHighTempData READ hasHighTempData NOTIFY hasHighTempDataChanged)

public:
    explicit ModbusManager(QObject *parent = nullptr);
    ~ModbusManager();

    double voltage() const { return m_voltage; }
    double current() const { return m_current; }
    double power() const { return m_power; }
    bool connected() const { return m_connected; }
    int fanState() const { return m_fanState; }
    int highTempState() const { return m_highTempState; }
    bool hasFanStateData() const { return m_hasFanStateData; }
    bool hasHighTempData() const { return m_hasHighTempData; }

    Q_INVOKABLE bool connectToPort(const QString &portName, int baudRate = 9600, int parity = 0);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE void startReading(int intervalMs = 1000);
    Q_INVOKABLE void stopReading();
    Q_INVOKABLE void writeVoltage(double value);
    Q_INVOKABLE void writeCurrent(double value);
    Q_INVOKABLE void writeFanState(bool state);
    Q_INVOKABLE void writeVoltageAndCurrent(double voltage, double current);
    Q_INVOKABLE void writeUnload();
    Q_INVOKABLE void writeHoldingRegister(int slaveAddress, int registerAddress, double value);

signals:
    void voltageChanged();
    void currentChanged();
    void powerChanged();
    void connectedChanged();
    void fanStateChanged();
    void highTempStateChanged();
    void hasFanStateDataChanged();
    void hasHighTempDataChanged();
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
    int m_fanState;
    int m_highTempState;
    bool m_hasFanStateData;
    bool m_hasHighTempData;
    int m_pendingReads;

    void readHoldingRegister(int slaveAddress, int registerAddress);
};

#endif
