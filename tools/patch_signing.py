"""Idempotent patch: make the Android release build use android/key.properties.

Run from the repo root (CI does this in the release workflow only).
Works with both android/app/build.gradle.kts (Kotlin) and build.gradle (Groovy).
If the file does not look like a standard Flutter template it exits with an
error and changes nothing, so a release can never be silently debug-signed.
"""
import os
import re
import sys

KTS = "android/app/build.gradle.kts"
GRV = "android/app/build.gradle"

if os.path.exists(KTS):
    path, kotlin = KTS, True
elif os.path.exists(GRV):
    path, kotlin = GRV, False
else:
    sys.exit("No android/app/build.gradle(.kts) found")

with open(path, encoding="utf-8") as f:
    s = f.read()

if "keystoreProperties" in s:
    print("Signing already configured in", path)
    sys.exit(0)

if kotlin:
    props = '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''
    signing = '''    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

'''
    sign_pattern = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
    sign_new = ('signingConfig = if (keystorePropertiesFile.exists()) '
                'signingConfigs.getByName("release") '
                'else signingConfigs.getByName("debug")')
else:
    props = '''def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

'''
    signing = '''    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }

'''
    sign_pattern = r'signingConfig\s*=?\s*signingConfigs\.debug'
    sign_new = ('signingConfig keystorePropertiesFile.exists() '
                '? signingConfigs.release : signingConfigs.debug')

android_m = re.search(r'^android\s*\{', s, flags=re.M)
build_types_m = re.search(r'^[ \t]*buildTypes\s*\{', s, flags=re.M)
if not android_m or not build_types_m or not re.search(sign_pattern, s):
    sys.exit(
        "Unexpected format in " + path + ". Nothing was changed. "
        "Send this file to Claude so the patch can be adjusted."
    )

# Insert back to front so earlier offsets stay valid.
s = re.sub(sign_pattern, lambda m: sign_new, s, count=1)
s = s[:build_types_m.start()] + signing + s[build_types_m.start():]
s = s[:android_m.start()] + props + s[android_m.start():]
if kotlin:
    s = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + s

with open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("Release signing configured in", path)
