"""Idempotent patch: make the release build use android/app/proguard-rules.pro.

Run from the repo root (CI does this in the release workflow only).
Works with build.gradle.kts (Kotlin) and build.gradle (Groovy). If the file
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

if not os.path.exists("android/app/proguard-rules.pro"):
    sys.exit("android/app/proguard-rules.pro is missing")

with open(path, encoding="utf-8") as f:
    s = f.read()

if "proguard-rules.pro" in s:
    print("ProGuard rules already configured in", path)
    sys.exit(0)

line = (
    'proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
    if kotlin
    else "proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'"
)

bt = re.search(r"^[ \t]*buildTypes\s*\{", s, flags=re.M)
if not bt:
    sys.exit("Unexpected format in " + path + ". Nothing was changed.")
rel = re.search(r"^([ \t]*)release\s*\{[ \t]*\n", s[bt.end():], flags=re.M)
if not rel:
    sys.exit("Unexpected format in " + path + ". Nothing was changed.")

insert_at = bt.end() + rel.end()
indent = rel.group(1) + "    "
s = s[:insert_at] + indent + line + "\n" + s[insert_at:]

with open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("ProGuard rules configured in", path)
