// 导入必要的QML模块
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

// 波形显示页面组件
Page {
    id: root

    // 动画窗口属性别名，用于外部访问
    property alias animatedWindow: animationWrapper

    // 页面背景设置为透明
    background: Rectangle {
        color: "transparent"
    }

    // 滚动视图，用于容纳波形图表
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 8  // 边距设置
        clip: true  // 启用裁剪，防止内容溢出
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn  // 始终显示垂直滚动条
        ScrollBar.vertical.width: 12  // 滚动条宽度

        // 可 flick 的内容区域
        Flickable {
            id: flickable
            width: scrollView.width - scrollView.ScrollBar.vertical.width
            height: contentHeight
            // 计算内容高度，确保所有图表都能显示
            contentHeight: column.children.length > 0 ? column.children[0].height + column.children[1].height + column.children[2].height + column.children[3].height + 32 : 600

            // 垂直布局容器
            Column {
                id: column
                width: parent.width
                spacing: 8  // 子项间距

                // 按钮行布局
                RowLayout {
                    width: parent.width
                    height: 60
                    spacing: 16

                    // 左侧空白占位
                    Item {
                        width: 10
                        height: 10
                    }

                    // 清除数据按钮
                    EButton {
                        id: clearButton
                        text: "清除数据"
                        iconCharacter: "\uf1f8"  // 垃圾桶图标
                        size: "s"  // 按钮大小
                        containerColor: theme.secondaryColor  // 容器颜色
                        textColor: theme.textColor  // 文本颜色
                        iconColor: theme.textColor  // 图标颜色
                        shadowEnabled: true  // 启用阴影
                        onClicked: {
                            waveformDataManager.clearData()  // 调用数据管理器的清除数据方法
                        }
                    }

                    // 右侧填充空白，使按钮靠左对齐
                    Item {
                        Layout.fillWidth: true
                    }
                }

                // 电压波形图表
                EAreaChart {
                    id: voltageChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "电压波形"
                    subtitle: "实时电压变化 (V)"
                    dataSeries: waveformDataManager.voltageChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                }

                // 电流波形图表
                EAreaChart {
                    id: currentChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "电流波形"
                    subtitle: "实时电流变化 (A)"
                    dataSeries: waveformDataManager.currentChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                }

                // 功率波形图表
                EAreaChart {
                    id: powerChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "功率波形"
                    subtitle: "实时功率变化 (kW)"
                    dataSeries: waveformDataManager.powerChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                    startFromFirstValue: true  // 从第一个值开始绘制
                }
            }
        }
    }

    // 动画窗口包装器
    EAnimatedWindow {
        id: animationWrapper
    }

    // 数据更新连接
    Connections {
        target: waveformDataManager  // 目标数据源
        function onDataUpdated() {
            // 当数据更新时，刷新三个图表的数据
            voltageChart.dataSeries = waveformDataManager.voltageChartData
            currentChart.dataSeries = waveformDataManager.currentChartData
            powerChart.dataSeries = waveformDataManager.powerChartData
        }
    }
}
