@echo off
"%~dp0php\php.exe" -c "%~dp0php\php.ini" "%~dp0src\get.php" %*
exit /b