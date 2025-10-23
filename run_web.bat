@echo off
chcp 65001 >nul
echo ========================================
echo Starting Web Version (Chrome)
echo ========================================
flutter run -d chrome --web-port=8080
