@echo off
cls
rem ***************************************
rem * Primary Destinations and Sources
rem ***************************************

set primarysource=\\%fs%\temp
set secondarysource=\\fs.sysstem.at\software

rem ***************************************
rem * Set Destinations and Sources Logic
rem ***************************************

if exist "%primarysource%" (
	set source=%primarysource%
) else if exist "%secondarysource%" (
	set source=%secondarysource%
) else goto error1

set cscript=%source%\Printerinstallpackage\CMDTools\Cscript\cscript.exe
set prnmngr=%source%\Printerinstallpackage\CMDTools\Printing_Admin_Scripts\prnmngr.vbs

if defined ProgramFiles(x86) (
	set lexct=%source%\Printerinstallpackage\CMDTools\LexmarkConfigUtil\x64\ConfigUtil.exe
) else (
	set lexct=%source%\Printerinstallpackage\CMDTools\LexmarkConfigUtil\x86\ConfigUtil.exe
)


rem * set all Printers to B/W
for /f "tokens=3" %%a in ('%cscript% %prnmngr% -l ^| find "Printer name"') do (
	%lexct%>nul push /dcf %source%\Printerinstallpackage\CMDTools\LexmarkConfigUtil\sysstem.ldc /po %%a
)
goto error0

:error0
echo Successful!
pause>nul
exit

:error1
echo Can't find source!
pause>nul
exit