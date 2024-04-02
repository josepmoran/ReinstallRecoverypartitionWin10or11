@echo off
REM those are the variables in this code : WindowsSelection, OSPartition, RecoveryPartition, isgtp, VarId, DiskPRecovery
:Begin
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
for /f "tokens=3" %%a in ('wmic os get Caption') do ( set WindowsSelection=%%a )
if %WindowsSelection%==11 (set WindowsVersion=SW_DVD9_Win_Pro_11
goto :DetectUsbRoot)
if %WindowsSelection%==10 (set WindowsVersion=SW_DVD9_Win_Pro_10
goto :DetectUsbRoot)
echo Error in detect the windows version
pause
goto :End
:DetectUsbRoot
REM This is to detect the USB Root
if exist A:/image/%WindowsVersion%.iso (set UsbRoot=A
goto :MainProgram)
if exist B:/image/%WindowsVersion%.iso (set UsbRoot=B
goto :MainProgram)
if exist D:/image/%WindowsVersion%.iso (set UsbRoot=D
goto :MainProgram)
if exist E:/image/%WindowsVersion%.iso (set UsbRoot=E
goto :MainProgram)
if exist F:/image/%WindowsVersion%.iso (set UsbRoot=F
goto :MainProgram)
echo Something goes wrong with the usb root, please try again 
goto :End
:MainProgram 
REM ------------------Get the OSpartition Primary --------------
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
(
ECHO list disk
ECHO select disk 0
ECHO list partition
) > %~dp0temp.scr
SET /A OSPartition
SET /A RecoveryPartition
For /F "usebackq tokens=2,3,4,5,6,7" %%P IN (`diskpart /s %~dp0temp.scr ^| findstr /r "Partition.[0-9]"`) DO (    
    If /i "%%S" EQU "KB" (
        REM Skip drives sized in KiloBytes
    ) Else If /i "%%S" EQU "MB" (
        REM Skip drives sized in MegaBytes
    ) Else (
        REM GB/TB
        If /i "%%S" EQU "GB" Set /A intSize=%%R * 1
        If /i "%%S" EQU "TB" Set /A intSize=%%R * 1024    
	   If /i "%%Q" EQU "Primary" (Set /A OSPartition=%%P	   	  
            Call :s_Work_Partition %%P )     
    )
)
ENDLOCAL
ECHO something goes wrong with Taking the OSPartition
pause
Goto :End
:s_Work_Partition
echo This is the primary partition in number %OSPartition%
set /a "RecoveryPartition=OSPartition+1"
echo This will be the partition of the recovery %RecoveryPartition%
REM ----------------------------End of the OSpartition Prymary---
REM ----------------------------Search for the GTP on diskpart-----------
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
(
ECHO list disk
) > %~dp0IsGTPScript.txt
SET /A isgtp = 0
For /F "usebackq tokens=2,3,4,5,6,7,8,9" %%P IN (`diskpart /s %~dp0IsGTPScript.txt ^| findstr /r "Disk 0"`) DO (    
      if /i "%%P" EQU "0" ( if /i "%%V" EQU "*" (SET /A isgtp = 1) else (SET /A isgtp = 0 )) 
)
REM ----------------------------End of Search for the GTP on diskpart--------
REM --------------if selection of ID depends of flag isgtp-------
if %isgtp%==1 (SET VarId="de94bba4-06d1-4d40-a16a-bfd50179d6ac" ) else ( SET VarId=27 )
REM --------------Create scrippart1.txt----------
(
ECHO list disk
ECHO select disk 0
ECHO list part
ECHO select part %OSPartition%
ECHO shrink desired=8192
ECHO create partition primary
ECHO format quick fs=ntfs label="Recovery"
ECHO set id = %VarId%
ECHO assign letter=R
ECHO exit
) > %~dp0scriptpart1.txt
REM -----------End of creation of scripart1.txt-----------
REM -----------Begin of scipart1.txt--------
diskpart /s %UsbRoot%:/scriptpart1.txt
reagentc /disable
mkdir C:\dism
REM ------Mount the Image-----
start %UsbRoot%:\image\%WindowsVersion%.iso
timeout 5
REM Searching  the root of the mount image
set ImageRoot=Z
if exist D:\sources\install.wim (set ImageRoot=D
goto :MountImage)
if exist E:\sources\install.wim (set ImageRoot=E
goto :MountImage)
if exist F:\sources\install.wim (set ImageRoot=F
goto :MountImage)
if exist G:\sources\install.wim (set ImageRoot=G
goto :MountImage)
echo Something goes wrong with the Image root, please try again 
goto :End
:MountImage
DISM /Mount-image /imagefile:%ImageRoot%:\sources\install.wim /Index:1 /MountDir:C:\dism /readonly /optimize
robocopy /MIR /XJ C:\dism\Windows\System32\Recovery\ C:\Windows\System32\Recovery
dism /unmount-image /mountdir:C:\dism /discard
mkdir R:\Recovery\WindowsRE
xcopy /h C:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE
reagentc /setreimage /path R:\Recovery\WindowsRE /target C:\Windows
reagentc /enable
reagentc /info
REM -----------------------------------------------------------
REM ----------------------------Search for the disk part of recovery-----------
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
(
ECHO select disk 0
ECHO list part
) > %~dp0DiskpartRecoveryscript.txt
For /F "usebackq tokens=2,3,4,5,6,7,8,9" %%P IN (`diskpart /s %~dp0DiskpartRecoveryscript.txt ^| findstr /r "Partition.[0-9]"`) DO (    
        if /i "%%Q" EQU "Recovery" ( if /i "%%S" EQU "GB" (if /i "%%R" EQU "8" ( set /A DiskPRecovery = %%P ) ) ))
REM --------------END of Search of the disk part of recovery---------------
REM -----------Creating scriptpart2----
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
(
ECHO list disk
ECHO select disk 0
ECHO list part
ECHO select part %DiskPRecovery%
ECHO remove letter=R
ECHO exit
) > %~dp0scriptpart2.txt
ENDLOCAL
REM --------Finish the scriptpart2-------
REM --------Execute diskpart scriptpart2-------
diskpart /s %UsbRoot%:/scriptpart2.txt
REM --------------Dismount the Image---------
PowerShell Dismount-DiskImage -DevicePath \\.\%ImageRoot%:
echo Finishing working with %WindowsVersion%
echo -----------------------------------------------------------------------------------------------------------------------
echo -------------------------------------Script complete thank you for your patience---------------------------------------
:End
pause
exit