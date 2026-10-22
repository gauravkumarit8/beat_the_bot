"""Idempotent patch of the generated AndroidManifest.xml for AdMob.

Run from the repo root. Safe to run on every CI build.
Replace ADMOB_APP_ID with your real AdMob app ID before publishing.
"""
import sys

ADMOB_APP_ID = "ca-app-pub-3940256099942544~3347511713"  # Google TEST app ID
PATH = "android/app/src/main/AndroidManifest.xml"

with open(PATH, encoding="utf-8") as f:
    s = f.read()

meta_key = "com.google.android.gms.ads.APPLICATION_ID"
if meta_key in s:
    # Keep the app ID in sync with the constant above.
    import re
    s = re.sub(
        r'(android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+android:value=")[^"]*(")',
        r"\g<1>" + ADMOB_APP_ID + r"\g<2>",
        s,
    )
else:
    s = s.replace(
        "</application>",
        '    <meta-data android:name="' + meta_key + '" android:value="'
        + ADMOB_APP_ID + '"/>\n    </application>',
        1,
    )

if "android.permission.INTERNET" not in s:
    s = s.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )

if meta_key not in s:
    sys.exit("Could not patch AndroidManifest.xml")

with open(PATH, "w", encoding="utf-8") as f:
    f.write(s)
print("AndroidManifest.xml patched")
