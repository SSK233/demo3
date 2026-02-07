import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

/**
 * @file HomePage.qml
 * @brief 主页组件 - 设备控制面板
 *
 * 主要功能模块：
 * - 串口通信管理（端口选择、开关控制）
 * - 风机控制
 * - 电气参数显示（电压、电流、功率）
 * - 电流值设置（二进制位选择 + 滑块调节）
 */
Page {
    id: window

    /** @brief 动画窗口别名，用于页面切换动画 */
    property alias animatedWindow: animationWrapper

    /** @brief 当前选中的串口索引，-1表示未选中 */
    property int selectedSerialPortIndex: -1

    /**
     * @brief 串口管理器
     * 负责串口通信的底层操作，包括端口刷新、打开、关闭等
     */
    SerialPortManager {
        id: serialPortManager

        /** 可用串口列表变化时更新下拉框数据 */
        onAvailablePortsChanged: {
            updateSerialPortModel()
        }

        /** 串口错误处理回调 */
        onErrorOccurred: {
            console.log("串口错误:", error)
        }
    }

    /**
     * @brief Modbus管理器
     * 负责Modbus RTU通信，读取电压、电流、功率数据
     */
    property bool dataUpdatePending: false

    Timer {
        id: dataUpdateTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (modbusManager.voltage > 0 || modbusManager.current > 0 || modbusManager.power > 0) {
                waveformDataManager.addDataPoint(modbusManager.voltage, modbusManager.current, modbusManager.power)
            }
            window.dataUpdatePending = false
        }
    }

    ModbusManager {
        id: modbusManager

        onVoltageChanged: {
            if (!window.dataUpdatePending) {
                window.dataUpdatePending = true
                dataUpdateTimer.start()
            }
        }

        onErrorOccurred: {
            console.log("Modbus错误:", error)
        }
    }

    /**
     * @brief 更新串口下拉框数据模型
     * 将串口管理器返回的端口列表转换为下拉框可用的格式
     */
    function updateSerialPortModel() {
        var ports = serialPortManager.availablePorts
        var newModel = []
        for (var i = 0; i < ports.length; i++) {
            newModel.push({ text: ports[i] })
        }
        serialPortDropdown.model = newModel
    }

    /** @brief 页面背景 - 透明色，允许底层背景显示 */
    background: Rectangle {
        color: "transparent"
    }

    // ========================================================================
    // 串口控制区域
    // ========================================================================

    /**
     * @brief 刷新串口按钮
     * 点击后刷新可用串口列表
     */
    EButton {
        id: refreshSerialButton
        text: "刷新串口"
        iconCharacter: "\uf021"           // Font Awesome 刷新图标
        iconRotateOnClick: true            // 点击时图标旋转
        size: "s"                          // 小号尺寸
        containerColor: theme.secondaryColor // 背景颜色（自适应深色模式）
        textColor: theme.textColor         // 文字颜色（自适应深色模式）
        iconColor: theme.textColor         // 图标颜色（自适应深色模式）
        shadowEnabled: true                // 启用阴影效果
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16                // 与边缘之间的间距
        onClicked: {
            serialPortManager.refreshPorts()
        }
    }

    /**
     * @brief 串口选择下拉框
     * 显示可用串口列表，供用户选择
     * 串口打开时自动禁用
     */
    EDropdown {
        id: serialPortDropdown
        title: "选择串口"                   // 默认提示文字
        width: 140                          // 宽度
        headerHeight: 40                    // 头部高度（与按钮一致）
        radius: 20                          // 圆角半径
        containerColor: theme.secondaryColor // 背景颜色
        textColor: theme.textColor          // 文字颜色
        shadowEnabled: true                 // 启用阴影效果
        enabled: !serialPortSwitch.checked  // 串口打开时禁用选择
        anchors.top: refreshSerialButton.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onSelectionChanged: {
            selectedSerialPortIndex = index
        }
    }

    /**
     * @brief 串口开关
     * 控制串口的连接/断开状态
     */
    ESwitchButton {
        id: serialPortSwitch
        z: -1                               // 确保下拉框展开时不会被遮挡
        text: "串口开关"
        size: "s"                          // 小号尺寸
        containerColor: theme.secondaryColor // 背景颜色
        textColor: theme.textColor          // 文字颜色
        thumbColor: "#FFFFFF"               // 滑块颜色（白色）
        trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"  // 轨道未选中颜色
        trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"    // 轨道选中颜色（绿色）
        shadowEnabled: true                 // 启用阴影效果
        anchors.top: serialPortDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: {
            if (checked) {
                if (selectedSerialPortIndex >= 0 && serialPortDropdown.model[selectedSerialPortIndex]) {
                    var portName = serialPortDropdown.model[selectedSerialPortIndex].text
                    var success = modbusManager.connectToPort(portName)
                    if (success) {
                        modbusManager.startReading(1000)
                    } else {
                        serialPortSwitch.checked = false
                    }
                } else {
                    serialPortSwitch.checked = false
                }
            } else {
                modbusManager.stopReading()
                modbusManager.disconnectPort()
            }
        }
    }

    /**
     * @brief 风机开关
     * 控制设备风机的运行状态
     */
    ESwitchButton {
        id: fanSwitch
        z: -1   
        text: "风机开关"
        size: "s"                          // 小号尺寸
        containerColor: theme.secondaryColor // 背景颜色
        textColor: theme.textColor          // 文字颜色
        thumbColor: "#FFFFFF"               // 滑块颜色（白色）
        trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"  // 轨道未选中颜色
        trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"    // 轨道选中颜色（绿色）
        shadowEnabled: true                 // 启用阴影效果
        anchors.top: serialPortSwitch.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: {
            console.log("风机开关状态:", checked ? "开启" : "关闭")
        }
    }

    // ========================================================================
    // 电气参数显示区域
    // ========================================================================

    /**
     * @brief 电气参数卡片
     * 显示电压、电流、功率三个电气参数
     */
    EHoverCard {
        id: electricCard
        z: -1   
        width: 120                              // 卡片宽度
        height: 250                             // 卡片高度
        anchors.bottom: parent.bottom           // 底部对齐
        anchors.bottomMargin: 16                // 底部边距
        anchors.right: parent.right             // 右侧对齐
        anchors.rightMargin: 16                 // 右边距

        // === 内容布局：垂直排列三个参数 ===
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            /** 电压显示区域 */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    text: "电压"
                    color: theme.textColor
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: modbusManager.voltage.toFixed(1) + " V"
                    color: theme.textColor
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            /** 分隔线 */
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.textColor
                opacity: 0.3
            }

            /** 电流显示区域 */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    text: "电流"
                    color: theme.textColor
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: modbusManager.current.toFixed(1) + " A"
                    color: theme.textColor
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }

            /** 分隔线 */
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.textColor
                opacity: 0.3
            }

            /** 功率显示区域 */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    text: "功率"
                    color: theme.textColor
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: modbusManager.power.toFixed(2) + " kW"
                    color: theme.textColor
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ========================================================================
    // 电流值设置区域
    // ========================================================================

    /** @brief 当前选中的位掩码值（用于按钮组合选择） */
    property int selectedValue: 0

    /** @brief 按钮节流锁，防止快速连续点击 */
    property bool throttleBlocked: false

    /**
     * @brief 根据位掩码获取按钮背景色
     * @param bitMask 位掩码值
     * @return 如果当前值包含该位，返回高亮色；否则返回普通色
     */
    function getButtonColor(bitMask) {
        return (selectedValue & bitMask) ? theme.focusColor : theme.secondaryColor
    }

    /**
     * @brief 按钮节流定时器
     * 200ms内只响应第一次点击，防止重复触发
     */
    Timer {
        id: buttonThrottleTimer
        interval: 200
        repeat: false
        onTriggered: {
            throttleBlocked = false
        }
    }

    /**
     * @brief 节流点击处理函数
     * @param bitMask 要切换的位掩码
     * 在200ms内，只有第一次点击会生效，后续点击被忽略
     * 使用异或运算切换对应位的状态
     */
    function throttledButtonClick(bitMask) {
        if (throttleBlocked) {
            return
        }
        throttleBlocked = true
        selectedValue ^= bitMask
        buttonThrottleTimer.start()
    }

    /**
     * @brief 位值按钮行
     * 用于二进制位选择（1, 2, 4, 8, 16, 32, 64）
     * 每个按钮代表一个二进制位，点击切换该位的状态
     */
    Row {
        id: valueButtonsRow
        spacing: 12
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -80
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -90

        /** 位0按钮 - 值为1 */
        EButton {
            id: btn1
            text: "1"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(1)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(1)
        }

        /** 位1按钮 - 值为2 */
        EButton {
            id: btn2
            text: "2"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(2)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(2)
        }

        /** 位2按钮 - 值为4 */
        EButton {
            id: btn4
            text: "4"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(4)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(4)
        }

        /** 位3按钮 - 值为8 */
        EButton {
            id: btn8
            text: "8"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(8)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(8)
        }

        /** 位4按钮 - 值为16 */
        EButton {
            id: btn16
            text: "16"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(16)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(16)
        }

        /** 位5按钮 - 值为32 */
        EButton {
            id: btn32
            text: "32"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(32)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(32)
        }

        /** 位6按钮 - 值为64 */
        EButton {
            id: btn64
            text: "64"
            size: "m"
            width: 48
            height: 48
            radius: 24
            containerColor: getButtonColor(64)
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: throttledButtonClick(64)
        }
    }

    /**
     * @brief 中央滑块组件
     * 用于精确设置电流值，范围0-127
     */
    ESlider {
        id: centralSlider
        text: "输入电流I/A "
        width: 450
        minimumValue: 0
        maximumValue: 127
        decimals: 0
        stepSize: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -80
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30
        onUserValueChanged: {
            console.log("Slider value changed:", value)
        }
    }

    /**
     * @brief 载入按钮
     * 将滑块当前值应用到设备
     */
    EButton {
        id: loadButton
        text: "载入"
        iconCharacter: "\uf019"
        size: "s"
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        iconColor: theme.textColor
        shadowEnabled: true
        anchors.top: centralSlider.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -140
        onClicked: {
            console.log("载入电流值:", centralSlider.value)
        }
    }

    /**
     * @brief 卸载按钮
     * 清除/重置电流设置
     */
    EButton {
        id: unloadButton
        text: "卸载"
        iconCharacter: "\uf1f8"
        size: "s"
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        iconColor: theme.textColor
        shadowEnabled: true
        anchors.top: centralSlider.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -20
        onClicked: {
            console.log("卸载电流值")
        }
    }

    /** @brief 动画窗口包装器 - 用于页面切换动画效果 */
    EAnimatedWindow {
        id: animationWrapper
    }
}
