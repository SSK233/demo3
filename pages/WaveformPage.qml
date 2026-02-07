import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    id: root

    property alias animatedWindow: animationWrapper

    background: Rectangle {
        color: "transparent"
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn
        ScrollBar.vertical.width: 12

        Flickable {
            id: flickable
            width: scrollView.width - scrollView.ScrollBar.vertical.width
            height: contentHeight
            contentHeight: column.children.length > 0 ? column.children[0].height + column.children[1].height + column.children[2].height + column.children[3].height + 32 : 600

            Column {
                id: column
                width: parent.width
                spacing: 8

                RowLayout {
                    width: parent.width
                    height: 60
                    spacing: 16

                    Item {
                        width: 10
                        height: 10
                    }

                    EButton {
                        id: clearButton
                        text: "清除数据"
                        iconCharacter: "\uf1f8"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            waveformDataManager.clearData()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                EAreaChart {
                    id: voltageChart
                    width: parent.width - 10
                    height: 280
                    title: "电压波形"
                    subtitle: "实时电压变化 (V)"
                    dataSeries: waveformDataManager.voltageChartData
                    lineStyle: EAreaChart.LineStyle.Smooth
                    topPadding: 50
                    chartPadding: 10
                    titleFontSize: 14
                    subtitleFontSize: 10
                }

                EAreaChart {
                    id: currentChart
                    width: parent.width - 10
                    height: 280
                    title: "电流波形"
                    subtitle: "实时电流变化 (A)"
                    dataSeries: waveformDataManager.currentChartData
                    lineStyle: EAreaChart.LineStyle.Smooth
                    topPadding: 50
                    chartPadding: 10
                    titleFontSize: 14
                    subtitleFontSize: 10
                }

                EAreaChart {
                    id: powerChart
                    width: parent.width - 10
                    height: 280
                    title: "功率波形"
                    subtitle: "实时功率变化 (kW)"
                    dataSeries: waveformDataManager.powerChartData
                    lineStyle: EAreaChart.LineStyle.Smooth
                    topPadding: 50
                    chartPadding: 10
                    titleFontSize: 14
                    subtitleFontSize: 10
                    startFromFirstValue: true
                }
            }
        }
    }

    EAnimatedWindow {
        id: animationWrapper
    }

    Connections {
        target: waveformDataManager
        function onDataUpdated() {
            voltageChart.dataSeries = waveformDataManager.voltageChartData
            currentChart.dataSeries = waveformDataManager.currentChartData
            powerChart.dataSeries = waveformDataManager.powerChartData
        }
    }
}
