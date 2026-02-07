#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "serial/SerialPortManager.h"
#include "serial/ModbusManager.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/new/prefix1/fonts/icon.ico"));

    qmlRegisterType<SerialPortManager>("EvolveUI", 1, 0, "SerialPortManager");
    qmlRegisterType<ModbusManager>("EvolveUI", 1, 0, "ModbusManager");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [](){ QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("EvolveUI", "Main");
    return app.exec();
}
