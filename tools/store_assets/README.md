# Картинки для магазинов

Скриншоты снимаются из настоящего приложения (веб-версия), в Chrome с размером экрана
телефона 960×540 при масштабе 2× → 1920×1080 (16:9). Запись нот делается «живым» нажатием
клавиш; после записи приложение сохраняет PDF, ноты читаются из него и сверяются с ожидаемыми —
при расхождении запись повторяется.

```powershell
cd tools\store_assets; npm install
flutter build web --release
node serve.js ..\..\build\web 8766          # в отдельном окне
node shots.js "<папка>\screenshots_ru" 0 2 all   # 0=ru, 1=uz, 2=en; 2 = масштаб; all = все сцены
node make_icon.js ..\..\assets\icon\app_icon.png "<папка>\icons\icon_512.png"
node make_feature.js "<папка>\screenshots_ru" "<папка>\icons\icon_512.png" "<папка>\graphics\feature_1024x500_ru.jpg" ru
```

Требуется Google Chrome по пути `C:\Program Files\Google\Chrome\Application\chrome.exe`.
Размеры подогнаны под требования Google Play и RuStore (см. docs/PUBLISHING.md).
