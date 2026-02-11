import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
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
     * @brief 风机开关
     * 控制设备风机的运行状态
     */
    ESwitchButton {
        id: fanSwitch
        text: "风机开关"
        size: "s"
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        thumbColor: "#FFFFFF"
        trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"
        trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"
        shadowEnabled: true
        anchors.top: serialPortSwitch.bottom
        anchors.topMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: function(checked) {
            modbusManager.writeFanState(checked)
            console.log("风机开关状态:", checked ? "开启(1)" : "关闭(0)")
        }
    }

    /**
     * @brief 风机状态指示灯
     * 显示风机的实际开关状态（读取从站1寄存器2）
     */
    ECard {
        id: fanStatusIndicator
        width: 140
        height: 40
        cardColor: theme.secondaryColor
        radius: 20
        padding: 10
        shadowEnabled: true
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: fanSwitch.left
        anchors.rightMargin: 24

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: !modbusManager.hasFanStateData ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.fanState === 1 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336"))
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: !modbusManager.hasFanStateData ? "风机状态：未就绪" : (modbusManager.fanState === 1 ? "风机状态：运行" : "风机状态：停止")
                color: theme.textColor
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
    
    /**
     * @brief 高温报警状态指示灯
     * 显示设备高温报警状态（读取从站1寄存器3）
     */
    ECard {
        id: highTempIndicator
        width: 160
        height: 40
        cardColor: theme.secondaryColor
        radius: 20
        padding: 10
        shadowEnabled: true
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: fanStatusIndicator.left
        anchors.rightMargin: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: !modbusManager.hasHighTempData ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.highTempState === 0 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336"))
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: !modbusManager.hasHighTempData ? "温度状态： 未就绪" : (modbusManager.highTempState === 0 ? "温度状态：   正常" : "温度状态：高温报警")
                color: theme.textColor
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    /**
     * @brief 数字时钟卡片
     * 使用网络天气，图标随天气自动切换
     */
    EClockCard {
        useNetworkWeather: true
        weatherApiKey: "SLKpiXphkV7ch3vZp"
        weatherLocation: "ip"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
    }

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
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 16
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
        z: 3
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
        onSelectionChanged: function(index) {
            selectedSerialPortIndex = index
        }
    }

    /**
     * @brief 波特率选择下拉框
     * 显示常用波特率列表，供用户选择
     */
    EDropdown {
        id: baudRateDropdown
        z: 2
        title: "波特率"
        width: 140
        headerHeight: 40
        radius: 20
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        shadowEnabled: true
        enabled: !serialPortSwitch.checked
        anchors.top: serialPortDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        model: [
            { text: "1200" },
            { text: "2400" },
            { text: "4800" },
            { text: "9600" },
            { text: "19200" },
            { text: "38400" },
            { text: "57600" },
            { text: "115200" }
        ]
        Component.onCompleted: {
            selectedIndex = 3
        }
    }

    /**
     * @brief 奇偶校验位选择下拉框
     * 显示校验方式列表，供用户选择
     */
    EDropdown {
        id: parityDropdown
        z: 1
        title: "校验位"
        width: 140
        headerHeight: 40
        radius: 20
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        shadowEnabled: true
        enabled: !serialPortSwitch.checked
        anchors.top: baudRateDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        model: [
            { text: "无校验" },
            { text: "奇校验" },
            { text: "偶校验" }
        ]
        Component.onCompleted: {
            selectedIndex = 0
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
        anchors.top: parityDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: function(checked) {
            if (checked) {
                if (selectedSerialPortIndex >= 0 && serialPortDropdown.model[selectedSerialPortIndex]) {
                    var portName = serialPortDropdown.model[selectedSerialPortIndex].text
                    var baudRate = parseInt(baudRateDropdown.model[baudRateDropdown.selectedIndex].text)
                    var parity = parityDropdown.selectedIndex
                    var success = modbusManager.connectToPort(portName, baudRate, parity)
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



    // ========================================================================
    // 电气参数显示区域
    // ========================================================================

    /**
     * @brief 三相电气参数卡片
     * 显示A、B、C三相的电压、电流、功率
     */
    EHoverCard {
        id: electricCard
        z: -1
        width: 360                              // 卡片宽度
        height: 180                             // 卡片高度
        anchors.bottom: parent.bottom           // 底部对齐
        anchors.bottomMargin: 16                // 底部边距
        anchors.right: parent.right             // 右侧对齐
        anchors.rightMargin: 16                 // 右边距

        // === 内容布局：网格排列三相数据 ===
        GridLayout {
            anchors.fill: parent
            anchors.margins: 12
            columns: 6
            rowSpacing: 8
            columnSpacing: 8

            Text {
                text: ""
                Layout.preferredWidth: 40
            }

            Text {
                text: "A相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "B相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "C相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电压"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "220.0 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "221.5 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "219.8 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电流"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "10.5 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "10.2 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "10.8 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "功率"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "2.31 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "2.26 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "2.37 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }
        }
    }

    /**
     * @brief 电压输入区域
     * 包含标签和输入框
     */
    Column {
        id: voltageColumn
        spacing: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -178            //调整左右移动的位置，减号后面的数字增加则向左移动
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30

        Text {
            text: "输入电压/V"
            color: theme.textColor
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }

        EInput {
            id: voltageInput
            placeholderText: ""
            width: 120
            height: 50
            radius: 25
            onTextChanged: {
                var text = voltageInput.text
                var filtered = ""
                var dotFound = false
                var decimalCount = 0
                for (var i = 0; i < text.length; i++) {
                    var ch = text.charAt(i)
                    if (ch >= '0' && ch <= '9') {
                        if (!dotFound || decimalCount < 1) {
                            filtered += ch
                            if (dotFound) decimalCount++
                        }
                    } else if (ch === '.' && !dotFound) {
                        filtered += ch
                        dotFound = true
                    }
                }
                if (filtered !== text) {
                    voltageInput.text = filtered
                }
                var voltageValue = parseFloat(filtered)
                if (!isNaN(voltageValue)) {
                    if (voltageValue > 1000) {
                        voltageInput.text = "1000.0"
                        voltageValue = 1000
                    }
                    var currentValue = parseFloat(currentInput.text)
                    if (!isNaN(currentValue) && currentValue > 0) {
                        var power = voltageValue * currentValue
                        if (power > 30000) {
                            var maxVoltage = Math.floor(30000 / currentValue * 10) / 10
                            voltageInput.text = maxVoltage.toFixed(1)
                            powerWarningDialog.open()
                        }
                    }
                }
            }
        }
    }

    /**
     * @brief 电流输入区域
     * 包含标签和输入框
     */
    Column {
        id: currentColumn
        spacing: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: 20           //调整左右移动的位置，数字增加则向右移动
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30

        Text {
            text: "输入电流/A"
            color: theme.textColor
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }

        EInput {
            id: currentInput
            placeholderText: ""
            width: 120
            height: 50
            radius: 25
            onTextChanged: {
                var text = currentInput.text
                var filtered = ""
                var dotFound = false
                var decimalCount = 0
                for (var i = 0; i < text.length; i++) {
                    var ch = text.charAt(i)
                    if (ch >= '0' && ch <= '9') {
                        if (!dotFound || decimalCount < 1) {
                            filtered += ch
                            if (dotFound) decimalCount++
                        }
                    } else if (ch === '.' && !dotFound) {
                        filtered += ch
                        dotFound = true
                    }
                }
                if (filtered !== text) {
                    currentInput.text = filtered
                }
                var currentValue = parseFloat(filtered)
                if (!isNaN(currentValue)) {
                    if (currentValue > 300) {
                        currentInput.text = "300.0"
                        currentValue = 300
                    }
                    var voltageValue = parseFloat(voltageInput.text)
                    if (!isNaN(voltageValue) && voltageValue > 0) {
                        var power = voltageValue * currentValue
                        if (power > 30000) {
                            var maxCurrent = Math.floor(30000 / voltageValue * 10) / 10
                            currentInput.text = maxCurrent.toFixed(1)
                            powerWarningDialog.open()
                        }
                    }
                }
            }
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
        anchors.top: voltageColumn.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -140         //调整左右移动的位置，减号后面的数字增加则向左移动
        onClicked: {
            voltageInput.focus = false
            currentInput.focus = false
            
            var voltageValue = parseFloat(voltageInput.text)
            var currentValue = parseFloat(currentInput.text)
            if (!isNaN(voltageValue) && !isNaN(currentValue)) {
                loadConfirmDialog.message = "确定要载入以下数值？\n电压: " + voltageValue + " V\n电流: " + currentValue + " A"
                loadConfirmDialog.open()
            } else {
                console.log("请输入有效的电压和电流值")
            }
        }
    }

    /** @brief 载入确认对话框 */
    EAlertDialog {
        id: loadConfirmDialog
        title: "确认载入"
        message: ""
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            var voltageValue = parseFloat(voltageInput.text)
            var currentValue = parseFloat(currentInput.text)
            modbusManager.writeVoltageAndCurrent(voltageValue, currentValue)
            console.log("载入: 电压 -> 寄存器50, 电流 -> 寄存器51 (单次发送)")
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
        anchors.top: voltageColumn.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -20            //调整左右移动的位置，减号后面的数字增加则向左移动
        onClicked: {
            unloadConfirmDialog.open()
        }
    }

    /** @brief 卸载确认对话框 */
    EAlertDialog {
        id: unloadConfirmDialog
        title: "确认卸载"
        message: "确定要执行卸载操作吗？"
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            modbusManager.writeUnload()
            console.log("卸载: 从站1寄存器35写1")
        }
    }

    /** @brief 功率超限警告对话框 */
    EAlertDialog {
        id: powerWarningDialog
        title: "警告"
        message: "输入的电压 × 电流不能超过 30000W（30KW），已自动调整数值。"
        confirmText: "确定"
        cancelText: ""
    }

    /** @brief 动画窗口包装器 - 用于页面切换动画效果 */
    EAnimatedWindow {
        id: animationWrapper
    }
}
