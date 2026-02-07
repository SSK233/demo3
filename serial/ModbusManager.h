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

/**
 * @brief Modbus管理器类
 * @details 负责Modbus RTU串行通信的管理，包括设备连接、数据读取和写入
 */
class ModbusManager : public QObject
{
    Q_OBJECT
    /**
     * @brief 电压值属性
     * @details 存储当前读取的电压值，单位为伏特(V)
     */
    Q_PROPERTY(double voltage READ voltage NOTIFY voltageChanged)
    
    /**
     * @brief 电流值属性
     * @details 存储当前读取的电流值，单位为安培(A)
     */
    Q_PROPERTY(double current READ current NOTIFY currentChanged)
    
    /**
     * @brief 功率值属性
     * @details 存储当前读取的功率值，单位为千瓦(kW)
     */
    Q_PROPERTY(double power READ power NOTIFY powerChanged)
    
    /**
     * @brief 连接状态属性
     * @details 存储当前Modbus设备的连接状态
     */
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    
    /**
     * @brief 风机状态属性
     * @details 存储当前风机的状态
     */
    Q_PROPERTY(int fanState READ fanState NOTIFY fanStateChanged)
    
    /**
     * @brief 高温报警状态属性
     * @details 存储当前高温报警的状态
     */
    Q_PROPERTY(int highTempState READ highTempState NOTIFY highTempStateChanged)
    
    /**
     * @brief 风机状态数据有效性属性
     * @details 标识是否已获取有效的风机状态数据
     */
    Q_PROPERTY(bool hasFanStateData READ hasFanStateData NOTIFY hasFanStateDataChanged)
    
    /**
     * @brief 高温报警状态数据有效性属性
     * @details 标识是否已获取有效的高温报警状态数据
     */
    Q_PROPERTY(bool hasHighTempData READ hasHighTempData NOTIFY hasHighTempDataChanged)

public:
    /**
     * @brief 构造函数
     * @param parent 父对象
     */
    explicit ModbusManager(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~ModbusManager();

    /**
     * @brief 获取电压值
     * @return 当前电压值
     */
    double voltage() const { return m_voltage; }
    
    /**
     * @brief 获取电流值
     * @return 当前电流值
     */
    double current() const { return m_current; }
    
    /**
     * @brief 获取功率值
     * @return 当前功率值
     */
    double power() const { return m_power; }
    
    /**
     * @brief 获取连接状态
     * @return 当前连接状态
     */
    bool connected() const { return m_connected; }
    
    /**
     * @brief 获取风机状态
     * @return 当前风机状态
     */
    int fanState() const { return m_fanState; }
    
    /**
     * @brief 获取高温报警状态
     * @return 当前高温报警状态
     */
    int highTempState() const { return m_highTempState; }
    
    /**
     * @brief 获取风机状态数据有效性
     * @return 是否有有效的风机状态数据
     */
    bool hasFanStateData() const { return m_hasFanStateData; }
    
    /**
     * @brief 获取高温报警状态数据有效性
     * @return 是否有有效的高温报警状态数据
     */
    bool hasHighTempData() const { return m_hasHighTempData; }

    /**
     * @brief 连接到Modbus设备
     * @param portName 串口名称
     * @param baudRate 波特率，默认为9600
     * @param parity 校验位，默认为0（无校验）
     * @return 连接是否成功
     */
    Q_INVOKABLE bool connectToPort(const QString &portName, int baudRate = 9600, int parity = 0);
    
    /**
     * @brief 断开与Modbus设备的连接
     */
    Q_INVOKABLE void disconnectPort();
    
    /**
     * @brief 开始定时读取数据
     * @param intervalMs 读取间隔，单位为毫秒，默认为1000ms
     */
    Q_INVOKABLE void startReading(int intervalMs = 1000);
    
    /**
     * @brief 停止定时读取数据
     */
    Q_INVOKABLE void stopReading();
    
    /**
     * @brief 写入电压值
     * @param value 要写入的电压值
     */
    Q_INVOKABLE void writeVoltage(double value);
    
    /**
     * @brief 写入电流值
     * @param value 要写入的电流值
     */
    Q_INVOKABLE void writeCurrent(double value);
    
    /**
     * @brief 写入风机状态
     * @param state 风机状态，true为开启，false为关闭
     */
    Q_INVOKABLE void writeFanState(bool state);
    
    /**
     * @brief 同时写入电压和电流值
     * @param voltage 要写入的电压值
     * @param current 要写入的电流值
     */
    Q_INVOKABLE void writeVoltageAndCurrent(double voltage, double current);
    
    /**
     * @brief 写入卸载控制命令
     */
    Q_INVOKABLE void writeUnload();
    
    /**
     * @brief 写入保持寄存器
     * @param slaveAddress 从站地址
     * @param registerAddress 寄存器地址
     * @param value 要写入的值
     */
    Q_INVOKABLE void writeHoldingRegister(int slaveAddress, int registerAddress, double value);

signals:
    /**
     * @brief 电压值变化信号
     * @details 当电压值发生变化时触发
     */
    void voltageChanged();
    
    /**
     * @brief 电流值变化信号
     * @details 当电流值发生变化时触发
     */
    void currentChanged();
    
    /**
     * @brief 功率值变化信号
     * @details 当功率值发生变化时触发
     */
    void powerChanged();
    
    /**
     * @brief 连接状态变化信号
     * @details 当连接状态发生变化时触发
     */
    void connectedChanged();
    
    /**
     * @brief 风机状态变化信号
     * @details 当风机状态发生变化时触发
     */
    void fanStateChanged();
    
    /**
     * @brief 高温报警状态变化信号
     * @details 当高温报警状态发生变化时触发
     */
    void highTempStateChanged();
    
    /**
     * @brief 风机状态数据有效性变化信号
     * @details 当风机状态数据有效性发生变化时触发
     */
    void hasFanStateDataChanged();
    
    /**
     * @brief 高温报警状态数据有效性变化信号
     * @details 当高温报警状态数据有效性发生变化时触发
     */
    void hasHighTempDataChanged();
    
    /**
     * @brief 错误发生信号
     * @details 当Modbus通信发生错误时触发
     * @param error 错误信息
     */
    void errorOccurred(const QString &error);

private slots:
    /**
     * @brief 设备状态变化槽函数
     * @details 当Modbus设备状态发生变化时调用
     * @param state 新的设备状态
     */
    void onStateChanged(QModbusDevice::State state);
    
    /**
     * @brief 错误发生槽函数
     * @details 当Modbus设备发生错误时调用
     * @param error 错误类型
     */
    void onErrorOccurred(QModbusDevice::Error error);
    
    /**
     * @brief 读取所有寄存器槽函数
     * @details 定时读取所有需要的寄存器值
     */
    void readAllRegisters();
    
    /**
     * @brief 读取完成槽函数
     * @details 当寄存器读取完成时调用
     */
    void onReadReady();

private:
    /**
     * @brief Modbus RTU串行主机
     */
    QModbusRtuSerialMaster *m_modbusMaster;
    
    /**
     * @brief 读取定时器
     * @details 用于定时触发数据读取
     */
    QTimer *m_readTimer;
    
    /**
     * @brief 电压值
     */
    double m_voltage;
    
    /**
     * @brief 电流值
     */
    double m_current;
    
    /**
     * @brief 功率值
     */
    double m_power;
    
    /**
     * @brief 连接状态
     */
    bool m_connected;
    
    /**
     * @brief 风机状态
     */
    int m_fanState;
    
    /**
     * @brief 高温报警状态
     */
    int m_highTempState;
    
    /**
     * @brief 风机状态数据有效性
     */
    bool m_hasFanStateData;
    
    /**
     * @brief 高温报警状态数据有效性
     */
    bool m_hasHighTempData;
    
    /**
     * @brief 待处理的读取请求数量
     */
    int m_pendingReads;

    /**
     * @brief 读取保持寄存器
     * @param slaveAddress 从站地址
     * @param registerAddress 寄存器地址
     */
    void readHoldingRegister(int slaveAddress, int registerAddress);
};

#endif
