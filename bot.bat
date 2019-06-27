@echo off
:loop
set /p token=<"%~dn0.token"
luvit -i bot.lua "%token%"
pause
goto loop