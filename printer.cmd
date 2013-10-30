@echo off
cls
set version=1.28
setLocal EnableDelayedExpansion
title Add Printer
rem ***************************************
rem * Variables
rem ***************************************

call :VARIABLES

rem ***************************************
rem * Prechecks
rem ***************************************

call :AdminCheck
echo [ ] Check if Scripts exist...
call :CheckVersion
call :CopyScripts
echo [+] All scripts found
call :CopyDrivers

rem ***************************************
rem * User input
rem ***************************************

set printer=%1
set emulvl=%2

if not defined printer set /p printer="[*] Printername (PS(MFG)NL|WIEN00) "

if /i "%printer:~-4%" == " PCL" (
	set emulvl=PCL
	set printer=%printer:~0,-4%
) else set emulvl=PS

title Add Printer %printer%

rem ***************************************
rem * Binary 1? = PS 0? = PCL
rem ***************************************

if /i "%emulvl%" == "PS" (
	set /a lexmap^|=0x1
	set lexmarkuni=!lexmarkuni! PS3
) else (
	set /a lexmap^|=0x0
)

if %lexmap% == 0 set lexmarkdrv=%lexmarkx86%
if %lexmap% == 1 set lexmarkdrv=%lexmarkx86ps%
if %lexmap% == 2 set lexmarkdrv=%lexmarkx64%
if %lexmap% == 3 set lexmarkdrv=%lexmarkx64ps%

rem ***************************************
rem * Get Printername
rem ***************************************

call :CheckIP
for /f "tokens=1 delims=." %%a in ("%printer%") do set printer=%%a

rem ***************************************
rem * Get location. structure: PS[NULL|MFG|PLOT|PROD][Location]00
rem ***************************************
if /I %printer:~0,2% == PS (
	       if /I %printer:~2,3% == MFG  (
		set location=%printer:~5,-2%
	) else if /I %printer:~2,4% == PLOT (
		set location=%printer:~6,-2%
	) else if /I %printer:~2,4% == PROD (
		set location=NL
	) else if /I %printer:~2,3% == KYO (
		set location=%printer:~5,-2%
	) else set location=%printer:~2,-2%
) else goto printerip

rem ***************************************
rem * Defining printerfqdn (also check for ip, nslookup sometimes provides wrong results)
rem ***************************************

set printerfqdn=%printer%.%location%.%companydomain%
:printerip
if not defined printerfqdn set printerfqdn=%printer%

rem ***************************************
rem * Check if Printer is online
rem * First check with 1 packet (very fast), then with 3 packets (slow)
rem ***************************************

echo [ ] Check if printer %printer% is online...
ping -n 1 %printerfqdn% | find "TTL">nul || ping -n 3 %printerfqdn% | find "TTL">nul || goto error3
echo [+] Printer %printer% is online

echo [ ] Check Printerdescription...
call :PrinterSNMPChecks

rem ***************************************
rem * This is the point where all information about the printer is known
rem ***************************************

rem ***************************************
rem * Delete port to ensure adding a new port causes no errors
rem ***************************************

%cscript% %prnport% -l | find "Port name %printer%">nul && %cscript% %prnport% -d -r %printer% | find "Deleted port %printer%">nul

rem ***************************************
rem * Add Standard TCP/IP Port
rem ***************************************
echo [ ] Add Standard TCP/IP Port
%cscript% %prnport% -a -o raw -r %printer% -h %printerfqdn% -me -y public | find "Created/updated port %printer%">nul || goto error4
echo [+] Port added

if defined type (echo [+] Printerdriver found) else goto error9

rem ***************************************
rem * Wait for Printer Driver
rem ***************************************

call :ExtractDrivers

rem ***************************************
rem * Add Printer with Printer Driver
rem ***************************************
echo [ ] Add Printer %printer% to Port...
rundll32 printui.dll,PrintUIEntry /if /b "%printer%" /f "%drv%" /r "%printer%" /m "%type%"
%cscript% %prnmngr% -l | findstr /i "%printer%">nul|| goto error9
echo [+] Printer %printer% successfully added
echo [ ] Call Post Installation...
call :PostInstallation
goto error0

:error0
echo [*] Done>>%logfile%
exit /b 0

:error1
echo [-] CScript not found (%cscript%)>>%logfile%
exit /b 1

:error2
echo [-] PrnPort not found (%prnport%)>>%logfile%
exit /b 2

:error3
echo [-] Printer %printer% not online or not found. (Connection timed out)>>%logfile%
exit /b 3

:error4
echo [-] Could not add Standard TCP/IP Port>>%logfile%
exit /b 4

:error5
echo [-] No Source-Servers are available>>%logfile%
exit /b 5

:error6
echo [-] Could not write to destination>>%logfile%
exit /b 6

:error7
echo [-] Could not delete port %printer%>>%logfile%
exit /b 7

:error8
echo [-] Administrator rights needed>>%logfile%
exit /b 8

:error9
echo [-] Printer driver not found>>%logfile%
exit /b 9

rem ***************************************
rem * Functions
rem ***************************************

rem ***************************************
rem * Admin check for win XP
rem ***************************************

:AdminCheck
ver>nul | findstr "Microsoft Windows XP [Version 5.1.2600]" && (mkdir %windir%\system32\test 2>nul && rmdir %windir%\system32\test) | goto error8
goto :EOF

rem ***************************************
rem * check if package exists check if newer is available and copy new if applicable
rem * Preload Scripts (7z, snmp,...) and printerdrivers
rem ***************************************
rem * avoid output with precheck of version file
rem * !! + delayedExpansion needed because of for-loop
rem ***************************************

:CheckVersion
rem ***************************************
rem * Verbose
rem ***************************************
if /i "%2" == "-V"		(erase %dest%\*.version)
if /i "%3" == "-V"		(erase %dest%\*.version)

for /f %%a in ('dir %dest%\*.version /A-D /B 2^>nul') do (
	set curver=%%a
	set curver=!curver:~0,4!
) 
if %curver% equ 0 echo [^|] Scripts and drivers not found.
goto :EOF

:CopyScripts
if not %version% == %curver% (
	echo [ ] Copy new scripts...
	erase 2>nul %dest%\7za.exe %dest%\CMDTools.7z
	xcopy>nul %source%\PrinterInstallPackage\7za.exe %dest% /Y /Q /G /K /R /Z
	xcopy>nul %source%\PrinterInstallPackage\CMDTools.7z %dest% /Y /Q /G /K /R /Z
	echo [ ] Extract scripts...
	%dest%\7za.exe>nul x -y -aoa %dest%\CMDTools.7z -o%dest%
	erase %dest%\*.version 2>nul
	echo.>%dest%\%version%.version

	rem xcopy>nul %source%\PrinterInstallPackage\*.version %dest% /Y /Q /G /K /R /Z
)
goto :EOF

:CopyDrivers
if not %version% == %curver% (
	echo [ ] Copy Drivers in Background...
	erase 2>nul %dest%\Druckertreiber.7z %dest%\Drivers.7z
	start /B "Copy Files" "xcopy">nul %source%\PrinterInstallPackage\Druckertreiber.7z %dest% /Y /Q
)
goto :EOF

:ExtractDrivers

if not exist %dest%\Drivers.7z (rename 2>nul %dest%\Druckertreiber.7z Drivers.7z) else (goto :Extract)
call :Spinner Extract Drivers
goto :ExtractDrivers

:Extract
"%dest%\7za.exe">nul x -y -aoa %dest%\Drivers.7z -o%dest%
goto :EOF

rem ***************************************
rem * Check for IP Address
rem ***************************************

:CheckIP
echo %printer% | findstr /R "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*">nul || goto :EOF
FOR /F "tokens=* delims=" %%A in ('nslookup %printer% 2^>^&1 ') do (
	echo %%A | findstr /R /C:"Name: ">nul && set printer=%%A
	echo %%A | findstr /R /C:"\*\*\*">nul && (set printerfqdn=%printer% & goto printerip)
)
rem ***************************************
rem * Name:    printername.location.companydomain
rem * printerfqdn begins at position 10
rem ***************************************
set printer=%printer:~9%
goto :EOF

:PrinterSNMPChecks
rem ***************************************
rem * Save the SNMP output (SNMPv2-MIB::sysDescr.0) to a variable: Printername (Lexmark X654,...)
rem * suppress snmpget errors
rem ***************************************
FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% SNMPv2-MIB::sysDescr.0') do SET prtdesc=%%A

rem ***************************************
rem * Check Printer by Description
rem ***************************************

echo %prtdesc%|findstr /R /C:"TOSHIBA e-STUDIO[2-4][5,8]1[1,c]">nul	&& set type=%mfgcolor%&&		set drv=%mfgdrv%
echo %prtdesc%|findstr /R /C:"TOSHIBA e-STUDIO350">nul			&& set type=%mfgbw%&&			set drv=%mfgdrv%
echo %prtdesc%|findstr /R /C:"Lexmark">nul				&& set type=%lexmarkuni%&&		set drv=%lexmarkdrv%

rem ***************************************
rem * If none of the usual Printers (by Names) was found, check per Type
rem ***************************************

if not defined type FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% SNMPv2-SMI::mib-2.43.5.1.1.16.1') do SET prtdesc=%%A

echo %prtdesc%|findstr /R /C:"LP 30[2,3][8,3]_LP 40[2,3][8,3]">nul	&& set type=%prtkyo%&&			set drv=%prtdrv%
echo %prtdesc%|findstr /R /C:"CLP 3416_CLP 4416">nul			&& set type=CLP 3316_CLP 4316 (KPDL)&&	set drv=%ta%

rem if not defined type FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% 1.3.6.1.2.1.43.5.1.1.17.1') do SET prtdesc=%%A
rem echo %prtdesc%|findstr /R /C:"FS-3920DN">nul			&& set type=Kyocera FS-3920DN
if not defined type FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% 1.3.6.1.2.1.1.1.0') do SET prtdesc=%%A
echo %prtdesc%|findstr /R /C:"KYOCERA MITA Printing System">nul		&& set type=Kyocera Classic Universaldriver PCL6 (A4)&&			set drv=%kyo%
echo %prtdesc%|findstr /R /C:"Intermec EasyCoder PD41">nul		&& set type=%PD41%&&		set drv=%intermec%
echo %prtdesc%|findstr /R /C:"Intermec EasyCoder PD42">nul		&& set type=%PD42%&&		set drv=%intermec%

if not defined type FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% 1.3.6.1.2.1.25.3.2.1.3.1') do SET prtdesc=%%A
echo %prtdesc%|findstr /R /C:"Officejet Pro K8600">nul		&& set type=%hpojprok8600%

goto :EOF

:VARIABLES
rem ***************************************
rem * Logfile, Company settings
rem ***************************************

set curver=0
set logfile=%temp%\printerinstall.%version%.log
set companydomain=SYSSTEM.AT

rem ***************************************
rem * Primary Destinations and Sources
rem ***************************************

set primarysource=\\fs.sysstem.at\software
set secondarysource=\\fs2.sysstem.at\software

set primarydest=%temp%
set secondarydest=C:\temp

rem ***************************************
rem * Set Destinations and Sources Logic
rem ***************************************

if exist "%primarysource%" (
	set source=%primarysource%
) else if exist "%secondarysource%" (
	set source=%secondarysource%
) else goto error5

if exist "%primarydest%" (
	set dest=%primarydest%
) else if exist "%secondarydest%" (
	set dest=%secondarydest%
) else goto error6

rem ***************************************
rem * Set script paths
rem ***************************************

set cscript=%dest%\CMDTools\Cscript\cscript.exe
set prnport=%dest%\CMDTools\Printing_Admin_Scripts\prnport.vbs
set prnmngr=%dest%\CMDTools\Printing_Admin_Scripts\prnmngr.vbs
set mibsdir=%dest%\CMDTools\snmp\mibs\mibs
set snmpget=%dest%\CMDTools\snmp\snmpget.exe 2^^^>nul -M %mibsdir% -L e

rem ***************************************
rem * Driverfiles
rem ***************************************

set lexmarkx64=%dest%\Druckertreiber\Lexmark_Universal_v2_W64\Drivers\Print\GDI\LMUD1O40.inf
set lexmarkx86=%dest%\Druckertreiber\Lexmark_Universal_v2_W32\Drivers\Print\GDI\LMUD1O40.inf
set lexmarkx64ps=%dest%\Druckertreiber\Lexmark_Universal_v2_W64_PS\LMUD1N40.inf
set lexmarkx86ps=%dest%\Druckertreiber\Lexmark_Universal_v2_W32_PS\LMUD1N40.inf
set mfgdrv=%dest%\Druckertreiber\Windows 7\Toshiba eStudio 350 3511\estudio.inf
set prtdrv=%dest%\Druckertreiber\Windows 7\Kyocera FS-3900DN PCL5\driver\OEMSETUP.inf
set sharp=%dest%\Druckertreiber\Windows 7\Sharp MX 3501\sn0emdeu.inf
set ta=%dest%\Druckertreiber\Windows 7\TA CLP 4416\KPDLminiDriverViW7s8_cCD_cLP_20110622\German\OEMSETUP.inf
set kyo=%dest%\Druckertreiber\KyoceraClassicUniversalPCL6_v1.10\OEMSETUP.inf
set intermec=%dest%\Druckertreiber\Intermec\InterDriver7\Intermec.inf

rem ***************************************
rem * Name of Drivers
rem ***************************************

set mfgbw=TOSHIBA e-STUDIO BW PS3
set mfgcolor=TOSHIBA e-STUDIO COLOR PS3
set lexmarkuni=Lexmark Universal v2
set prtkyo=Kyocera FS-3900DN
set prtsharp=SHARP MX-3501N PCL6
set pd41=EasyCoder PD41 (300 dpi) - IPL
set pd42=EasyCoder PD42 (300 dpi) - IPL
set hpojprok8600=HP Officejet Pro K8600 Series

rem ***************************************
rem * set Lexmark Driver for x64 or x86
rem * Better than Processor Architecture, because CPU could be x64 and Windows x86
rem ***************************************
rem * Binary ?10 = x64 ?00 = x86
rem ***************************************

set lexmap=0

if defined ProgramFiles(x86) (
	set /a lexmap^|=0x2
	set lexct=%dest%\CMDTools\LexmarkConfigUtil\x64\ConfigUtil.exe
) else (
	set /a lexmap^|=0x0
	set lexct=%dest%\CMDTools\LexmarkConfigUtil\x86\ConfigUtil.exe
)
goto :EOF

rem ***************************************
rem * PostInstalltion
rem ***************************************
:PostInstallation

rem ***************************************
rem * Sysstem AT Settings (BW Print)
rem ***************************************
%lexct%>nul push /dcf %dest%\CMDTools\LexmarkConfigUtil\SYSSTEM.ldc /po %printer%
rem * set all Printers to B/W
rem for /f "tokens=3" %%a in ('%cscript% %prnmngr% -l ^| find "Printer name"') do (
rem 	%lexct%>nul push /dcf %dest%\CMDTools\LexmarkConfigUtil\SYSSTEM.ldc /po %%a
rem )
goto :EOF

rem ***************************************
rem * Spinner
rem ***************************************
:Spinner
set backline=
<nul (set/p z=[\] %*)
<nul (set/p z=%backline%)
ping>nul localhost -n 1
<nul (set/p z=[^|] %*)
<nul (set/p z=%backline%)
ping>nul localhost -n 1
<nul (set/p z=[/] %*)
<nul (set/p z=%backline%)
ping>nul localhost -n 1
<nul (set/p z=[-] %*)
<nul (set/p z=%backline%)
ping>nul localhost -n 1
goto :EOF

rem ***************************************
rem * Depricated printerchecks
rem ***************************************

rem echo [ ] Check for Printername...
rem ***************************************
rem * PSMFGWIEN13 does not have SNMP
rem ***************************************
rem echo %printer%|findstr /R /C:"PSMFGWIEN13" /I >nul 			&& set type=%prtsharp%&&	set drv=%sharp%

rem too unspecific

rem ***************************************
rem * Check Printer by Serialnumber (obsolete. Maybe after fail check)
rem ***************************************

rem if not defined type FOR /F "tokens=1 delims=" %%A in ('%snmpget% -v1 -cpublic %printerfqdn% 1.3.6.1.2.1.43.5.1.1.17.1') do SET prtsn=%%A

rem echo %prtsn% | findstr /R /C:"STRING: \"AT........\"">nul	&& set type=%prtkyo%&&		set drv=%prtdrv%
rem echo %prtsn% | findstr /R /C:"STRING: \"C........\"">nul	&& set type=%mfgcolor%&&	set drv=%mfgdrv%
rem echo %prtsn% | findstr /R /C:"STRING: \"F........\"">nul	&& set type=%mfgbw%&&		set drv=%mfgdrv%
rem echo %prtsn% | findstr /R /C:"STRING: \".......-91-.\"">nul	&& set type=%mfglexx654de%
rem echo %prtsn% | findstr /R /C:"STRING: \".......-84-.\"">nul	&& set type=%mfglexx544ps%

rem ***************************************
rem * Delete precached driverfiles
rem ***************************************

rem if exist %temp%\{*-*-*-*-*} (
rem 	for /f "tokens=*" %%a in ('dir %temp%\{*-*-*-*-*} /B /AD') do (rmdir %temp%\%%a)
rem )

rem ***************************************
rem * If there hasn't been a type found by SNMP, user has to choose manually
rem ***************************************
rem if not defined type echo [*] Printerdriver not found. Please choose manually.