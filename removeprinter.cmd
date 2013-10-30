@echo off
rem ***************************************
rem * Version 1.00
rem ***************************************

title Remove Printer

set printer=%1
if not defined printer set /p printer="[*] Printername (PS<location>) "
title Remove Printer %printer%

rundll32 printui.dll,PrintUIEntry /dl /n "%printer%"