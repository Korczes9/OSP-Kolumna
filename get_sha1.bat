@echo off
echo =====================================================
echo    POBIERANIE SHA-1 FINGERPRINT DLA GOOGLE MAPS
echo =====================================================
echo.

cd /d "%~dp0android"

echo Pobieranie SHA-1 dla DEBUG keystore (testowanie)...
echo.
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr "SHA1:"

echo.
echo =====================================================
echo SKOPIUJ POWYZSZA WARTOSC SHA1 (bez "SHA1: ")
echo I WKLEJ W GOOGLE CLOUD CONSOLE
echo =====================================================
echo.
echo Przykad:
echo   SHA1: 12:34:56:AB:CD:EF:...
echo   ^
echo   Skopiuj tylko: 12:34:56:AB:CD:EF:...
echo.
pause
