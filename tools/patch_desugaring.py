"""Idempotent patch: turn on core library desugaring for the Android app.

The notifications plugin needs it. Run from the repo root. Works with
android/app/build.gradle.kts (Kotlin) and build.gradle (Groovy). If the file
does not look like a standard Flutter template it exits with an error and
changes nothing.
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

if "coreLibraryDesugaring" in s or "CoreLibraryDesugaringEnabled" in s:
    print("Desugaring already configured in", path)
    sys.exit(0)

flag = ("isCoreLibraryDesugaringEnabled = true" if kotlin
        else "coreLibraryDesugaringEnabled true")
dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
       if kotlin
       else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'")

co = re.search(r"^([ \t]*)compileOptions\s*\{[ \t]*\n", s, flags=re.M)
if co:
    s = s[:co.end()] + co.group(1) + "    " + flag + "\n" + s[co.end():]
else:
    android = re.search(r"^android\s*\{[ \t]*\n", s, flags=re.M)
    if not android:
        sys.exit("Unexpected format in " + path + ". Nothing was changed.")
    block = "    compileOptions {\n        " + flag + "\n    }\n\n"
    s = s[:android.end()] + block + s[android.end():]

deps = re.search(r"^dependencies\s*\{[ \t]*\n", s, flags=re.M)
if deps:
    s = s[:deps.end()] + "    " + dep + "\n" + s[deps.end():]
else:
    s = s.rstrip("\n") + "\n\ndependencies {\n    " + dep + "\n}\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("Desugaring configured in", path)
