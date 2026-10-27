param([switch]$QA)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
 $config=Get-Content tools/android.json -Raw | ConvertFrom-Json
 $build=Join-Path $root $(if($QA){'web-client/android/package-qa-015'}else{'web-client/android/package-015'})
 $sdk=$config.sdk
 $javabin=Join-Path $config.java 'bin'
 $env:JAVA_HOME=$config.java
 $package=if($QA){'org.thaney.ambatopia.qa'}else{'org.thaney.growtopiareconstruction'}
 $label=if($QA){'Ambatopia Web QA'}else{'Ambatopia'}
 $apk=Join-Path $root ('build/android/'+$(if($QA){'Ambatopia-web-0.15-QA.apk'}else{'Ambatopia-web-0.15.apk'}))
 New-Item -ItemType Directory -Force "$build/res/drawable","$build/assets","$build/classes","$build/dex" | Out-Null
 Copy-Item -LiteralPath assets/ambatopia/app-icon.png -Destination "$build/res/drawable/app_icon.png" -Force
 & node scripts/package-web-assets.mjs "$build/assets"
 if($LASTEXITCODE -ne 0){throw 'Packaged asset integrity failed'}
 $manifest=@"
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="$package" android:versionCode="15" android:versionName="0.15.0-web-engine"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="35"/><uses-permission android:name="android.permission.INTERNET"/><uses-feature android:name="android.hardware.touchscreen" android:required="false"/><application android:label="$label" android:icon="@drawable/app_icon" android:allowBackup="false" android:usesCleartextTraffic="false" android:hardwareAccelerated="true" android:debuggable="$($QA.IsPresent.ToString().ToLower())" android:theme="@android:style/Theme.Material.Light.NoActionBar"><activity android:name="org.thaney.ambatopia.MainActivity" android:exported="true" android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize|uiMode" android:screenOrientation="sensorLandscape"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity></application></manifest>
"@
 [IO.File]::WriteAllText("$build/AndroidManifest.xml",$manifest)
 & "$javabin/javac.exe" -encoding UTF-8 -source 8 -target 8 -classpath "$sdk/platforms/android-35/android.jar" -d "$build/classes" web-client/android/MainActivity.java
 if($LASTEXITCODE -ne 0){throw 'Android Java compilation failed'}
 $classes=@(Get-ChildItem "$build/classes" -Recurse -Filter '*.class' | ForEach-Object {$_.FullName})
 & "$sdk/build-tools/35.0.1/d8.bat" --lib "$sdk/platforms/android-35/android.jar" --min-api 24 --output "$build/dex" @classes
 if($LASTEXITCODE -ne 0){throw 'Android dex conversion failed'}
 & "$sdk/build-tools/35.0.1/aapt.exe" package -f -M "$build/AndroidManifest.xml" -S "$build/res" -A "$build/assets" -I "$sdk/platforms/android-35/android.jar" -F "$build/unsigned.apk"
 if($LASTEXITCODE -ne 0){throw 'Android asset packaging failed'}
 Copy-Item -LiteralPath "$build/dex/classes.dex" -Destination "$build/classes.dex" -Force
 Push-Location $build
 try { & "$sdk/build-tools/35.0.1/aapt.exe" add unsigned.apk classes.dex; if($LASTEXITCODE -ne 0){throw 'Dex packaging failed'} } finally { Pop-Location }
 & "$sdk/build-tools/35.0.1/zipalign.exe" -f 4 "$build/unsigned.apk" "$build/aligned.apk"
 & "$sdk/build-tools/35.0.1/apksigner.bat" sign --ks tools/profile/Godot/keystores/debug.keystore --ks-pass pass:android --key-pass pass:android --out $apk "$build/aligned.apk"
 if($LASTEXITCODE -ne 0){throw 'APK signing failed'}
 & "$sdk/build-tools/35.0.1/apksigner.bat" verify $apk
 if($LASTEXITCODE -ne 0){throw 'APK signature verification failed'}
 Write-Output "Built $apk"
} finally { Pop-Location }
