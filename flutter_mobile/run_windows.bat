@echo off
:: Configure Pub Cache path using DOS 8.3 short name (no spaces)
set "PUB_CACHE=C:\Users\CHANDR~1\AppData\Local\Pub\Cache"

:: Prepend the Flutter SDK path using short name to PATH
set "PATH=C:\Users\CHANDR~1\DOCUME~1\develop\FLUTTE~1.6-S\flutter\bin;%PATH%"

:: Run Flutter natively on Windows
flutter run -d windows
