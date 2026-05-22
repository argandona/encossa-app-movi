@echo off
echo Iniciando Control Almacen...
start "" http://localhost:8080
python -m http.server 8080 --directory "%~dp0build\web"
