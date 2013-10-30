'***************************************
'* Version 1.02
'***************************************

printername=InputBox("Please enter Printername","Remove a Printer","PSMFGxx00")

with createobject("Wscript.Shell")
  nReturnErrorLevel = .run("\\fs.sysstem.at\Software\CMDTools\removeprinter.cmd "&printername, 1, True)
end with