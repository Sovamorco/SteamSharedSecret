@echo off
setlocal EnableDelayedExpansion

echo. && echo [ Pulling APK from device ] && echo.

rmdir /s /q temp > nul 2> nul

mkdir temp > nul 2>nul

adb shell pm list packages |^
for /F "tokens=2 delims=: " %%a in ('findstr /l /c:steam.community') do ^
@for /F "tokens=2 delims=: " %%a in ('adb shell pm path %%a') do ^
@adb pull %%a temp\steam.apk

echo. && echo [ Disassembling APK ] && echo.

call apktool -f -o temp\steam d temp\steam.apk

echo. && echo [ Checking app version ] && echo.

for /F "tokens=*" %%a in (temp\steam\AndroidManifest.xml) do (
	echo."%%a" | findstr /c:"android:allowBackup" > nul
	if not errorlevel 1 (
		echo."%%a" | findstr /c:true > nul
		if not errorlevel 1 (
			echo. && echo Steam app already patched, skipping patch... && echo.
			goto :patched
		)
	)
)


echo. && echo. && echo Make sure Steam Guard Mobile Authenticator is DISABLED or you will be locked out of your Steam account!
echo Unskippable 25 second wait to make sure you read above notice (IT IS IMPORTANT!)
timeout /t 25 /nobreak
echo Press any key when ready to continue or Ctrl+C to exit
pause > nul

echo. && echo [ Patching AndroidManifest.xml ] && echo.

:: Mainly for testing or failed attempts
del temp\steam\AndroidManifest.xml.tmp 2>nul

for /F "tokens=*" %%a in (temp\steam\AndroidManifest.xml) do (
	set "result=%%a"
	echo."%%a" | findstr /c:"android:allowBackup" > nul
	if not errorlevel 1 (
		set "result=!result:false=true!"
	)
	echo !result! >> temp\steam\AndroidManifest.xml.tmp
)

move /Y temp\steam\AndroidManifest.xml.tmp temp\steam\AndroidManifest.xml

echo. && echo [ Rebuilding APK ] && echo.

call apktool b temp\steam

echo. && echo [ Generating signing key ] && echo.

set "random-string=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "storepass="
for /L %%i in (1,1,32) do call :add

jdk\bin\keytool -genkeypair -noprompt ^
    -keyalg RSA ^
    -keysize 2048 ^
    -validity 10000 ^
    -storepass "%storepass%" ^
    -keypass "%storepass%" ^
    -keystore temp\key.keystore ^
    -alias alias ^
    -dname "CN=example.com, OU=dont, O=use, L=this, S=in, C=production"

echo. && echo [ Signing APK ] && echo.

jdk\bin\jarsigner ^
    -sigalg SHA1withRSA ^
    -digestalg SHA1 ^
    -keystore temp\key.keystore ^
    -storepass "%storepass%" ^
    -keypass "%storepass%" ^
    temp\steam\dist\steam.apk ^
    alias > nul

echo. && echo [ Uninstalling Steam App ] && echo.

adb uninstall com.valvesoftware.android.steam.community

echo. && echo [ Installing patched APK ] && echo.

adb install temp\steam\dist\steam.apk
adb shell monkey -p com.valvesoftware.android.steam.community 1

echo. && echo Sign in to Steam and ENABLE Steam Guard Mobile Authenticator, then press any key to continue && echo.
timeout /t 5 /nobreak > nul
pause > nul

:patched

echo. && echo Extracting data. Please confirm "back up my data" on device. DO NOT set a password. && echo.

adb backup -f temp\backup.ab com.valvesoftware.android.steam.community > nul

jdk\bin\java -jar abe.jar unpack temp\backup.ab temp\backup.tar > nul 2> nul

7z\7za.exe x -otemp temp\backup.tar > nul

mkdir %UserProfile%\Documents\SteamAuth > nul 2> nul
del %UserProfile%\Documents\SteamAuth\secrets.txt > nul 2> nul

for /r %%i in (temp\apps\com.valvesoftware.android.steam.community\f\*) do (
	@for /F "tokens=4,16 delims=,:" %%a in ('type %%i') do (
		echo %%~b %%~a >> %UserProfile%\Documents\SteamAuth\secrets.txt
	)
)

rmdir /s /q temp

echo. && echo. && pause

exit /B %ERRORLEVEL%%

:add
	set /a x=%random% %% 62
	set storepass=%storepass%!random-string:~%x%,1!
	exit /B 0
