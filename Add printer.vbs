'***************************************
'* Version 1.03
'***************************************

printername=InputBox("Please enter Printername","Add a Printer","PSMFGxx00")

with createobject("Wscript.Shell")
  nReturnErrorLevel = .run("\\fs.sysstem.at\Software\CMDTools\printer.cmd "&printername, 1, True)
end with

if nReturnErrorLevel = 0 then wsh.echo "Printer added"
if nReturnErrorLevel = 1 then wsh.echo "CScript not found"
if nReturnErrorLevel = 2 then wsh.echo "PrnPort not found"
if nReturnErrorLevel = 3 then wsh.echo "Printer "&printername&" not online or not found. (Connection timed out)"
if nReturnErrorLevel = 4 then wsh.echo "Could not add Standard TCP/IP Port"
if nReturnErrorLevel = 5 then wsh.echo "No Source-Servers are available"
if nReturnErrorLevel = 6 then wsh.echo "Could not write to destination"
if nReturnErrorLevel = 7 then wsh.echo "Could not delete old port"
if nReturnErrorLevel = 8 then wsh.echo "Administrator rights needed"
if nReturnErrorLevel = 9 then wsh.echo "Printer driver not found"
if nReturnErrorLevel > 9 then wsh.echo "Unexpected Error (Exit >9)"