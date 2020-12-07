when not compiles(switch("d","testDefine")): #Fixes bug with vscode extension for nim support
  import system/nimscript
--gc:orc
--exceptions:goto
switch("path", "$projectDir/../src")