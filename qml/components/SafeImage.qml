import QtQuick 1.0

Image {
    id: root
    
    // Свойство для хранения "реального" URL, который мы хотим загрузить
    property string targetSource: ""
    property int retryCount: 0
    property int maxRetries: 3
    
    source: targetSource
    
    // Используем таймер для задержки повторного запроса
    Timer {
        id: retryTimer
        interval: 2000 // 2 секунды перед повтором
        repeat: false
        onTriggered: {
            // "Передергиваем" source, чтобы QML снова полез в сеть
            root.source = "";
            root.source = root.targetSource;
        }
    }
    
    onStatusChanged: {
        if (status === Image.Error) {
            if (retryCount < maxRetries) {
                retryCount++;
                console.log("[SafeImage] Ошибка загрузки, попытка " + retryCount + "...");
                retryTimer.start();
            } else {
                console.log("[SafeImage] Исчерпаны все попытки загрузки.");
            }
        } else if (status === Image.Ready) {
            retryCount = 0; // Сбрасываем счетчик при успехе
        }
    }
}