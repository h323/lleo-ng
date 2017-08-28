rem del $$$$$$$$.bsy
del lleo_dip.exe
tasm /z/ml/m lleo_dip.asm
if exist lleo_dip.obj wlink @dos4gw.lnk
del lleo_dip.obj
if exist lleo_dip.exe lleo_dip.exe
rem c lucky.bsy novo.rtm
