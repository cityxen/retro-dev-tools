@echo off
echo Starting KickAss>CON
set cfg="%CD%\KickAss_AutoGen.cfg"
echo Using CONFIG [ %cfg% ]
java -jar %~dp0..\dev-tools\commodore64\KickAssembler\KickAss.jar -cfgfile %cfg% %1 %2 %3 %4
 