import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    id: window

    background: Rectangle {
        color: "transparent"
    }

    property var homePage
    property var modbusManager: homePage ? homePage.modbusManager : null
    property bool stepRunActive: homePage ? homePage.stepRunActive : false
    property int maxSteps: 10
    property int currentStepIndex: -1
    property bool isRunning: false
    property int remainingTime: 0
    property int totalElapsedTime: 0

    ListModel {
        id: stepModel
        ListElement {
            stepName: "第1步"
            powerA: 0
            powerB: 0
            powerC: 0
            duration: 1
        }
    }

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

    function removeStep(index) {
        if (stepModel.count > 1 && index >= 0 && index < stepModel.count) {
            stepModel.remove(index)
            for (var i = 0; i < stepModel.count; i++) {
                stepModel.set(i, { stepName: "第" + (i + 1) + "步" })
            }
        }
    }

    Timer {
        id: runTimer
        interval: 1000
        repeat: true
        running: isRunning
        onTriggered: {
            if (remainingTime > 0) {
                remainingTime--
                totalElapsedTime++
            } else {
                if (currentStepIndex < stepModel.count - 1) {
                    currentStepIndex++
                    startStep(currentStepIndex)
                } else {
                    stopRun()
                }
            }
        }
    }

    function startStep(index) {
        if (index >= 0 && index < stepModel.count) {
            var step = stepModel.get(index)
            remainingTime = step.duration
            if (modbusManager) {
                modbusManager.writePower(step.powerA, step.powerB, step.powerC)
            }
            console.log("分步运行 - " + step.stepName + ": A=" + step.powerA + "kW, B=" + step.powerB + "kW, C=" + step.powerC + "kW, 时长=" + step.duration + "s")
        }
    }

    function startRun() {
        if (stepModel.count === 0) return

        if (homePage) {
            homePage.stepRunActive = true
        }
        isRunning = true
        currentStepIndex = 0
        totalElapsedTime = 0
        startStep(0)
        runTimer.running = true
    }

    function stopRun() {
        isRunning = false
        currentStepIndex = -1
        remainingTime = 0
        runTimer.running = false
        if (homePage) {
            homePage.stepRunActive = false
        }
        if (modbusManager) {
            modbusManager.writeUnload()
        }
        console.log("分步运行停止")
    }

    function onExitPage() {
        if (isRunning) {
            stopRun()
        }
        stepRunActive = false
    }

    Component.onDestruction: {
        onExitPage()
    }

    Rectangle {
        id: leftPanel
        width: 420
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 16
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 32

            Text {
                text: "分步运行配置"
                color: theme.textColor
                font.pixelSize: 20
                font.bold: true
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    width: leftPanel.width - 32

                    Repeater {
                        model: stepModel
                        delegate: ECard {
                            width: (leftPanel.width - 32 - 12) / 2
                            height: 210
                            padding: 12

                            property int stepIndex: index

                            ColumnLayout {
                                spacing: 8

                                RowLayout {
                                    Text {
                                        text: stepName
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "删除"
                                        size: "xs"
                                        containerColor: theme.isDark ? "#EF5350" : "#F44336"
                                        textColor: "white"
                                        visible: stepModel.count > 1 && !isRunning
                                        onClicked: removeStep(stepIndex)
                                    }
                                }

                                ColumnLayout {
                                    spacing: 10

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
                                            enabled: !isRunning
                                            text: model.powerA
                                            onTextChanged: {
                                                var value = parseFloat(text)
                                                if (!isNaN(value)) {
                                                    stepModel.set(stepIndex, { powerA: value })
                                                }
                                            }
                                        }
                                    }

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

        RowLayout {
            Layout.topMargin: 20
            width: leftPanel.width - 32

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
                visible: stepModel.count < maxSteps
                enabled: !isRunning
                onClicked: addStep()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

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

            RowLayout {
                spacing: 16

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

            EHoverCard {
                height: 80
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 20

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

            Text {
                text: "实时电气参数"
                color: theme.textColor
                font.pixelSize: 16
                font.bold: true
            }

            EHoverCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

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
