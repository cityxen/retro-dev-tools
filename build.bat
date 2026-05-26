robocopy /MIR E:\dev\cityxen\Commodore64_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\commodore64\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd C64/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd C64/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\Commodore128_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\commodore128\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd C128/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd C128/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\Commodore16_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\commodore16\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd C16/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd C16/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\CommodoreVIC20_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\vic20\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd VIC20/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd VIC20/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\Commmodore_PET_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\pet\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd PET/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd PET/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\AppleIIe_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\appleiie\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd AppleIIe/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd AppleIIe/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)

robocopy /MIR E:\dev\cityxen\Atari_8Bit_Programming\include\ E:\dev\cityxen\retro-dev-tools\include\atari8bit\ /NDL >nul 2>&1

if %ERRORLEVEL% EQU 0 (
    echo ---- MIRROR'd Atari8Bit/include to retro-dev-tools GOOD! RC[%ERRORLEVEL%]
) else (
    echo ---- MIRROR'd Atari8Bit/include to retro-dev-tools BAD! RC[%ERRORLEVEL%]
)