"""Idempotent patch of the generated AndroidManifest.xml for AdMob.

Run from the repo root. Safe to run on every CI build.
Replace ADMOB_APP_ID with your real AdMob app ID before publishing.
"""
import os
import sys

# Release builds pass the real ID in the ADMOB_APP_ID environment variable.
# Without it, Google's TEST app ID is used (safe for development).
ADMOB_APP_ID = os.environ.get("ADMOB_APP_ID") or "ca-app-pub-3940256099942544~3347511713"
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

# Friendly app name on the phone's home screen.
s = s.replace('android:label="beat_the_bot"', 'android:label="Beat the Bot"')

# Daily reminders (flutter_local_notifications).
for perm in ("android.permission.POST_NOTIFICATIONS",
             "android.permission.RECEIVE_BOOT_COMPLETED"):
    if perm not in s:
        s = s.replace(
            "<application",
            '<uses-permission android:name="' + perm + '"/>\n    <application',
            1,
        )

if "ScheduledNotificationReceiver" not in s:
    receivers = """    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
        </intent-filter>
    </receiver>
"""
    s = s.replace("</application>", receivers + "    </application>", 1)

if meta_key not in s:
    sys.exit("Could not patch AndroidManifest.xml")

with open(PATH, "w", encoding="utf-8") as f:
    f.write(s)
print("AndroidManifest.xml patched")
