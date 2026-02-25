import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    id: window

    background: Rectangle {
        color: "transparent"
    }

    // === 属性定义 ===

    // 引用首页对象，用于访问首页的属性和方法
    property var homePage

    // Modbus管理器，用于向设备发送功率设置命令
    property var modbusManager: homePage ? homePage.modbusManager : null

    // 分步运行模式状态，与首页功率设置互斥
    property bool stepRunActive: homePage ? homePage.stepRunActive : false

    // 最大步骤数量限制
    property int maxSteps: 10

    // 当前正在执行的步骤索引，-1表示未运行
    property int currentStepIndex: -1

    // 是否正在执行分步运行
    property bool isRunning: false

    // 当前步骤剩余时间（秒）
    property int remainingTime: 0

    // 累计已运行时间（秒）
    property int totalElapsedTime: 0

    // === 数据模型 ===

    // 步骤列表模型，存储每个步骤的配置信息
    ListModel {
        id: stepModel
        // 默认包含一个步骤
        ListElement {
            stepName: "第1步"      // 步骤名称
            powerA: 0              // A相功率(kW)
            powerB: 0              // B相功率(kW)
            powerC: 0              // C相功率(kW)
            duration: 1            // 运行时间(秒)
        }
    }

    // === 步骤管理函数 ===

    // 添加新步骤
    function addStep() {
        if (stepModel.count < maxSteps) {
            stepModel.append({
                stepName: "第" + (stepModel.count + 1) + "步",
                powerA: 0,
                powerB: 0,
                powerC: 0,
                duration: 1
            })
        }
    }

    // 删除指定索引的步骤
    function removeStep(index) {
        if (stepModel.count > 1 && index >= 0 && index < stepModel.count) {
            stepModel.remove(index)
            // 更新剩余步骤的名称
            for (var i = 0; i < stepModel.count; i++) {
                stepModel.set(i, { stepName: "第" + (i + 1) + "步" })
            }
        }
    }

    // === 运行控制 ===

    // 定时器，用于定时更新剩余时间和切换步骤
    Timer {
        id: runTimer
        interval: 1000          // 定时周期1秒
        repeat: true            // 重复执行
        running: isRunning      // 与运行状态同步
        onTriggered: {
            // 如果还有剩余时间
            if (remainingTime > 0) {
                remainingTime--      // 剩余时间减1
                totalElapsedTime++    // 累计时间加1
            } else {
                // 当前步骤时间已到，切换到下一个步骤
                if (currentStepIndex < stepModel.count - 1) {
                    currentStepIndex++
                    startStep(currentStepIndex)
                } else {
                    // 所有步骤执行完毕，停止运行
                    stopRun()
                }
            }
        }
    }

    // 开始执行指定索引的步骤
    function startStep(index) {
        if (index >= 0 && index < stepModel.count) {
            var step = stepModel.get(index)
            remainingTime = step.duration    // 设置当前步骤的剩余时间
            // 向设备写入功率设置
            if (modbusManager) {
                modbusManager.writePower(step.powerA, step.powerB, step.powerC)
            }
            console.log("分步运行 - " + step.stepName + ": A=" + step.powerA + "kW, B=" + step.powerB + "kW, C=" + step.powerC + "kW, 时长=" + step.duration + "s")
        }
    }

    // 开始分步运行
    function startRun() {
        if (stepModel.count === 0) return

        // 设置首页的分步运行模式状态，禁用首页的功率控制
        if (homePage) {
            homePage.stepRunActive = true
        }
        // 更新运行状态
        isRunning = true
        currentStepIndex = 0
        totalElapsedTime = 0
        // 开始执行第一个步骤
        startStep(0)
        // 启动定时器
        runTimer.running = true
    }

    // 停止分步运行
    function stopRun() {
        isRunning = false
        currentStepIndex = -1
        remainingTime = 0
        // 停止定时器
        runTimer.running = false
        // 取消首页的分步运行模式状态
        if (homePage) {
            homePage.stepRunActive = false
        }
        // 发送卸载命令
        if (modbusManager) {
            modbusManager.writeUnload()
        }
        console.log("分步运行停止")
    }

    // 退出页面时的清理操作
    function onExitPage() {
        if (isRunning) {
            stopRun()
        }
        stepRunActive = false
    }

    // 页面销毁时自动调用清理函数
    Component.onDestruction: {
        onExitPage()
    }

    // === 界面布局 ===

    // 左侧面板 - 步骤配置区域
    Rectangle {
        id: leftPanel
        width: 420
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.topMargin: 24
        anchors.bottomMargin: 8
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 32

            // 标题
            Text {
                text: "分步运行配置"
                color: theme.textColor
                font.pixelSize: 20
                font.bold: true
                Layout.topMargin: 8
            }

            // 步骤卡片滚动区域
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 步骤卡片网格布局（2列）
                GridLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 16
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    width: leftPanel.width - 48

                    // 步骤列表 Repeater
                    Repeater {
                        model: stepModel
                        delegate: ECard {
                            // 卡片宽度 = (面板宽度 - 边距 - 列间距) / 2
                            width: (leftPanel.width - 48 - 12) / 2
                            height: 210
                            padding: 12

                            // 当前步骤在模型中的索引
                            property int stepIndex: index

                            ColumnLayout {
                                spacing: 8

                                // 步骤名称行
                                RowLayout {
                                    Text {
                                        text: stepName
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    // 删除按钮
                                    EButton {
                                        text: "删除"
                                        size: "xs"
                                        containerColor: theme.isDark ? "#EF5350" : "#F44336"
                                        textColor: "white"
                                        visible: stepModel.count > 1 && !isRunning   // 运行时隐藏
                                        onClicked: removeStep(stepIndex)
                                    }
                                }

                                // 参数输入区域（纵向排列）
                                ColumnLayout {
                                    spacing: 10

                                    // A相功率输入行
                                    RowLayout {
                                        Text {
                                            text: "A相功率/KW"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning    // 运行时禁用输入
                                            text: model.powerA
                                            onTextChanged: {
                                                var value = parseFloat(text)
                                                if (!isNaN(value)) {
                                                    stepModel.set(stepIndex, { powerA: value })
                                                }
                                            }
                                        }
                                    }

                                    // B相功率输入行
                                    RowLayout {
                                        Text {
                                            text: "B相功率/KW"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning
                                            text: model.powerB
                                            onTextChanged: {
                                                var value = parseFloat(text)
                                                if (!isNaN(value)) {
                                                    stepModel.set(stepIndex, { powerB: value })
                                                }
                                            }
                                        }
                                    }

                                    // C相功率输入行
                                    RowLayout {
                                        Text {
                                            text: "C相功率/KW"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning
                                            text: model.powerC
                                            onTextChanged: {
                                                var value = parseFloat(text)
                                                if (!isNaN(value)) {
                                                    stepModel.set(stepIndex, { powerC: value })
                                                }
                                            }
                                        }
                                    }

                                    // 运行时间输入行
                                    RowLayout {
                                        Text {
                                            text: "运行时间/秒"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning
                                            text: model.duration
                                            onTextChanged: {
                                                var value = parseInt(text)
                                                if (!isNaN(value) && value > 0) {
                                                    stepModel.set(stepIndex, { duration: value })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 添加步骤按钮（居中显示）
        RowLayout {
            Layout.topMargin: 32
            width: leftPanel.width - 48

            Item {
                Layout.fillWidth: true
            }

            EButton {
                text: "添加步骤"
                size: "s"
                containerColor: theme.secondaryColor
                textColor: theme.textColor
                iconCharacter: "\uf067"
                iconColor: theme.textColor
                visible: stepModel.count < maxSteps      // 未达到最大数量时显示
                enabled: !isRunning                     // 运行时禁用
                Layout.leftMargin: 100
                onClicked: addStep()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // 右侧面板 - 运行控制和状态显示
    Rectangle {
        id: rightPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftPanel.right
        anchors.right: parent.right
        anchors.margins: 16
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            // 开始/停止按钮行
            RowLayout {
                spacing: 16

                // 开始运行按钮
                EButton {
                    id: startButton
                    text: "开始运行"
                    size: "m"
                    containerColor: theme.isDark ? "#66BB6A" : "#4CAF50"
                    textColor: "white"
                    iconCharacter: "\uf04b"
                    iconColor: "white"
                    enabled: !isRunning
                    onClicked: startRun()
                }

                // 停止按钮
                EButton {
                    id: stopButton
                    text: "停止"
                    size: "m"
                    containerColor: theme.isDark ? "#EF5350" : "#F44336"
                    textColor: "white"
                    iconCharacter: "\uf04d"
                    iconColor: "white"
                    enabled: isRunning
                    onClicked: {
                        stopRun()
                    }
                }
            }

            // 运行状态卡片
            EHoverCard {
                height: 80
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 20

                        // 当前步骤显示
                        ColumnLayout {
                            Text {
                                text: "当前步骤"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: isRunning ? (currentStepIndex >= 0 ? stepModel.get(currentStepIndex).stepName : "已完成") : "未运行"
                                color: isRunning ? (theme.isDark ? "#66BB6A" : "#4CAF50") : theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        // 剩余时间显示
                        ColumnLayout {
                            Text {
                                text: "剩余时间"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: isRunning ? remainingTime + " 秒" : "--"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        // 累计时间显示
                        ColumnLayout {
                            Text {
                                text: "累计时间"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: totalElapsedTime + " 秒"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // 实时电气参数标题
            Text {
                text: "实时电气参数"
                color: theme.textColor
                font.pixelSize: 16
                font.bold: true
            }

            // 电气参数显示卡片
            EHoverCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    columns: 6
                    rowSpacing: 8
                    columnSpacing: 8

                    // 表头 - A/B/C相
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

                    // 电压行
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
                        text: "220.0 V"
                        color: theme.textColor
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 80
                    }

                    // 电流行
                    Text {
                        text: "电流"
                        color: theme.textColor
                        font.pixelSize: 12
                        Layout.preferredWidth: 40
                    }

                    Text {
                        text: "10.0 A"
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
                        text: "10.0 A"
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
                        text: "10.0 A"
                        color: theme.textColor
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 80
                    }

                    // 功率行
                    Text {
                        text: "功率"
                        color: theme.textColor
                        font.pixelSize: 12
                        Layout.preferredWidth: 40
                    }

                    Text {
                        text: "2.20 kW"
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
                        text: "2.20 kW"
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
                        text: "2.20 kW"
                        color: theme.textColor
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 80
                    }
                }
            }
        }
    }
}
