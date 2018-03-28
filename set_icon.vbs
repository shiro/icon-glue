Set Shell = CreateObject("WScript.Shell")

Set link = Shell.CreateShortcut(WScript.Arguments(0))
link.IconLocation = WScript.Arguments(1)
link.Save
