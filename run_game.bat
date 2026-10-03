@echo off
rem Запуск игры из исходников двойным кликом, без экспорта в exe.
rem Godot не в PATH: путь задан здесь, на обоих ПК он одинаковый.
rem Если Godot переедет - поменять GODOT_DIR.
chcp 65001 >nul
setlocal
set "GODOT_DIR=C:\Godot_v4.7.1-stable_mono_win64"
set "GODOT=%GODOT_DIR%\Godot_v4.7.1-stable_win64.exe"
set "GODOT_CONSOLE=%GODOT_DIR%\Godot_v4.7.1-stable_win64_console.exe"

if not exist "%GODOT%" (
    echo Не найден Godot: %GODOT%
    echo Поправь GODOT_DIR в %~nx0
    pause
    exit /b 1
)

cd /d "%~dp0"

rem Импорт ресурсов: игра читает модели и текстуры только из импорта (.godot/imported).
rem На свежем клоне его нет, после git pull он устаревает - без этого шага игра не
rem запустится или покажет старые модели. Если ничего не менялось, это ~4 секунды.
echo Обновляю импорт ресурсов...
"%GODOT_CONSOLE%" --headless --path . --import >nul 2>&1
if errorlevel 1 (
    echo Импорт завершился с ошибкой, подробности: "%GODOT_CONSOLE%" --headless --path . --import
    pause
)

start "" "%GODOT%" --path .
