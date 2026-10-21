# Beat the Bot

Offline brain-training game. Train your brain. Beat Zed.

## How to verify without running Flutter locally

1. Copy these files into your repo folder in VS Code.
2. In the VS Code terminal (PowerShell):

       git add .
       git commit -m "Add Beat the Bot foundation"
       git push

3. Open the repo on GitHub, then the Actions tab, then "Build and verify".
4. Green check = analyze, tests and a debug APK build all passed.
   Download the `debug-apk` artifact to install it on your phone.
5. The first run also uploads `android-scaffold`. Download it, put the
   `android` folder in your repo, and commit it. After that CI uses your copy.

If a step fails, open it, copy the red error text and send it to Claude.
