# Keep rules for release builds (R8 code shrinking).
#
# Google's ads library brings in AndroidX WorkManager, which starts when the
# app launches. WorkManager creates its Room database by reflection, and R8
# removes the constructor it needs, so the app crashed on launch.

# Room: keep the no-argument constructor of every generated database class.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# WorkManager: keep workers and input mergers that are created by reflection.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.InputMerger { public <init>(); }
