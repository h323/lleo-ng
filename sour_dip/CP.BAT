if exist lleo_dip.exe del lleo_dip.exe
tasm /z/ml/m lleo_dip.asm
rem if exist lleo_dip.obj wcc386 -i=%WATCOM%\h -fpi lleo_dip
if exist lleo_dip.obj wlink @pmodew.lnk system pmodew file lleo_dip
if exist lleo_dip.obj del lleo_dip.obj
if exist lleo_dip.exe lleo_dip.exe
rem c sysoeff.bsy lleo2.rtm
