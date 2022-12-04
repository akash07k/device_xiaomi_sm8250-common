#!/usr/bin/env bash

DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# Remove the following intermediate buildinfo.prop file to trigger
# gen_from_buildinfo_sh rule in build/core/sysprop.mk. This will populate
# system/build.prop file with fresh infos when making "dirty" build.
rm -vf out/target/product/munch/obj/PACKAGING/system_build_prop_intermediates/buildinfo.prop

# ************************************
# Apply the patch for MIUI camera
# ************************************
echo 'Patching frameworks/base'
patch_name='Multiple reverts for MIUI camera'
patch_dir=frameworks/base
cur_commit="$(git -C $patch_dir show -s --format=%s)" || exit $?

# Remove old commit
if [ "$cur_commit" = "$patch_name" ]; then
    git -C $patch_dir reset --hard HEAD^ || exit $?
fi

# Apply and commit patch
git -C $patch_dir apply --verbose < <(cat <<'EOL'
From b6bf8df1662145446794bd168654792db08aea8a Mon Sep 17 00:00:00 2001
From: spkal01 <kalligeross@gmail.com>
Date: Mon, 24 Oct 2022 15:13:59 +0300
Subject: [PATCH] [SQUASH] Multiple reverts for miuicamera

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 core/java/android/hardware/Camera.java        | 48 +------------------
 .../hardware/camera2/CameraManager.java       | 30 +-----------
 core/jni/android_hardware_Camera.cpp          |  2 +-
 3 files changed, 4 insertions(+), 76 deletions(-)

diff --git a/core/java/android/hardware/Camera.java b/core/java/android/hardware/Camera.java
index efc92d3992df..f04479deeef3 100644
--- a/core/java/android/hardware/Camera.java
+++ b/core/java/android/hardware/Camera.java
@@ -46,7 +46,6 @@ import android.os.Message;
 import android.os.Process;
 import android.os.RemoteException;
 import android.os.ServiceManager;
-import android.os.SystemProperties;
 import android.renderscript.Allocation;
 import android.renderscript.Element;
 import android.renderscript.RSIllegalArgumentException;
@@ -64,7 +63,6 @@ import com.android.internal.app.IAppOpsService;
 import java.io.IOException;
 import java.lang.ref.WeakReference;
 import java.util.ArrayList;
-import java.util.Arrays;
 import java.util.LinkedHashMap;
 import java.util.List;
 
@@ -282,31 +280,6 @@ public class Camera {
      */
     private static final int CAMERA_FACE_DETECTION_SW = 1;
 
-    /**
-     * @hide
-     */
-    public static boolean shouldExposeAuxCamera() {
-        /**
-         * Force to expose only two cameras
-         * if the package name does not falls in this bucket
-         */
-        String packageName = ActivityThread.currentOpPackageName();
-        List<String> packageList = new ArrayList<>(Arrays.asList(
-                SystemProperties.get("vendor.camera.aux.packagelist", ",").split(",")));
-        List<String> packageExcludelist = new ArrayList<>(Arrays.asList(
-                SystemProperties.get("vendor.camera.aux.packageexcludelist", ",").split(",")));
-
-        // Append packages from lineage-sdk resources
-        Resources res = ActivityThread.currentApplication().getResources();
-        packageList.addAll(Arrays.asList(res.getStringArray(
-                org.lineageos.platform.internal.R.array.config_cameraAuxPackageAllowList)));
-        packageExcludelist.addAll(Arrays.asList(res.getStringArray(
-                org.lineageos.platform.internal.R.array.config_cameraAuxPackageExcludeList)));
-
-        return (packageList.isEmpty() || packageList.contains(packageName)) &&
-                !packageExcludelist.contains(packageName);
-    }
-
     /**
      * Returns the number of physical cameras available on this device.
      * The return value of this method might change dynamically if the device
@@ -322,20 +295,7 @@ public class Camera {
      * @return total number of accessible camera devices, or 0 if there are no
      *   cameras or an error was encountered enumerating them.
      */
-    public static int getNumberOfCameras() {
-        int numberOfCameras = _getNumberOfCameras();
-        if (!shouldExposeAuxCamera() && numberOfCameras > 2) {
-            numberOfCameras = 2;
-        }
-        return numberOfCameras;
-    }
-
-    /**
-     * Returns the number of physical cameras available on this device.
-     *
-     * @hide
-     */
-    public native static int _getNumberOfCameras();
+    public native static int getNumberOfCameras();
 
     /**
      * Returns the information about a particular camera.
@@ -346,9 +306,6 @@ public class Camera {
      *    low-level failure).
      */
     public static void getCameraInfo(int cameraId, CameraInfo cameraInfo) {
-        if (cameraId >= getNumberOfCameras()) {
-            throw new RuntimeException("Unknown camera ID");
-        }
         _getCameraInfo(cameraId, cameraInfo);
         IBinder b = ServiceManager.getService(Context.AUDIO_SERVICE);
         IAudioService audioService = IAudioService.Stub.asInterface(b);
@@ -564,9 +521,6 @@ public class Camera {
 
     /** used by Camera#open, Camera#open(int) */
     Camera(int cameraId) {
-        if (cameraId >= getNumberOfCameras()) {
-            throw new RuntimeException("Unknown camera ID");
-        }
         int err = cameraInit(cameraId);
         if (checkInitErrors(err)) {
             if (err == -EACCES) {
diff --git a/core/java/android/hardware/camera2/CameraManager.java b/core/java/android/hardware/camera2/CameraManager.java
index 18b8e367ddc7..400356810088 100644
--- a/core/java/android/hardware/camera2/CameraManager.java
+++ b/core/java/android/hardware/camera2/CameraManager.java
@@ -27,7 +27,6 @@ import android.app.ActivityThread;
 import android.content.Context;
 import android.content.pm.PackageManager;
 import android.graphics.Point;
-import android.hardware.Camera;
 import android.hardware.CameraStatus;
 import android.hardware.ICameraService;
 import android.hardware.ICameraServiceListener;
@@ -1651,10 +1650,8 @@ public final class CameraManager {
 
         private String[] extractCameraIdListLocked() {
             String[] cameraIds = null;
-            boolean exposeAuxCamera = Camera.shouldExposeAuxCamera();
-            int size = exposeAuxCamera ? mDeviceStatus.size() : 2;
             int idCount = 0;
-            for (int i = 0; i < size; i++) {
+            for (int i = 0; i < mDeviceStatus.size(); i++) {
                 int status = mDeviceStatus.valueAt(i);
                 if (status == ICameraServiceListener.STATUS_NOT_PRESENT
                         || status == ICameraServiceListener.STATUS_ENUMERATING) continue;
@@ -1662,7 +1659,7 @@ public final class CameraManager {
             }
             cameraIds = new String[idCount];
             idCount = 0;
-            for (int i = 0; i < size; i++) {
+            for (int i = 0; i < mDeviceStatus.size(); i++) {
                 int status = mDeviceStatus.valueAt(i);
                 if (status == ICameraServiceListener.STATUS_NOT_PRESENT
                         || status == ICameraServiceListener.STATUS_ENUMERATING) continue;
@@ -1927,14 +1924,6 @@ public final class CameraManager {
                     throw new IllegalArgumentException("cameraId was null");
                 }
 
-                /* Force to expose only two cameras
-                 * if the package name does not falls in this bucket
-                 */
-                boolean exposeAuxCamera = Camera.shouldExposeAuxCamera();
-                if (exposeAuxCamera == false && (Integer.parseInt(cameraId) >= 2)) {
-                    throw new IllegalArgumentException("invalid cameraId");
-                }
-
                 ICameraService cameraService = getCameraService();
                 if (cameraService == null) {
                     throw new CameraAccessException(CameraAccessException.CAMERA_DISCONNECTED,
@@ -2202,11 +2191,6 @@ public final class CameraManager {
         }
 
         private void onStatusChangedLocked(int status, String id) {
-            if (!Camera.shouldExposeAuxCamera() && Integer.parseInt(id) >= 2) {
-                Log.w(TAG, "[soar.cts] ignore the status update of camera: " + id);
-                return;
-            }
-
             if (DEBUG) {
                 Log.v(TAG,
                         String.format("Camera id %s has status changed to 0x%x", id, status));
@@ -2338,16 +2322,6 @@ public final class CameraManager {
                         String.format("Camera id %s has torch status changed to 0x%x", id, status));
             }
 
-            /* Force to ignore the aux or composite camera torch status update
-             * if the package name does not falls in this bucket
-             */
-            boolean exposeAuxCamera = Camera.shouldExposeAuxCamera();
-            if (exposeAuxCamera == false && Integer.parseInt(id) >= 2) {
-                Log.w(TAG, "ignore the torch status update of camera: " + id);
-                return;
-            }
-
-
             if (!validTorchStatus(status)) {
                 Log.e(TAG, String.format("Ignoring invalid device %s torch status 0x%x", id,
                                 status));
diff --git a/core/jni/android_hardware_Camera.cpp b/core/jni/android_hardware_Camera.cpp
index 3325f62bba01..ca02cd74372a 100644
--- a/core/jni/android_hardware_Camera.cpp
+++ b/core/jni/android_hardware_Camera.cpp
@@ -1166,7 +1166,7 @@ static void android_hardware_Camera_sendVendorCommand(JNIEnv *env, jobject thiz,
 //-------------------------------------------------
 
 static const JNINativeMethod camMethods[] = {
-  { "_getNumberOfCameras",
+  { "getNumberOfCameras",
     "()I",
     (void *)android_hardware_Camera_getNumberOfCameras },
   { "_getCameraInfo",
-- 
2.38.1.windows.1

EOL
) &&
git -C $patch_dir commit --no-gpg-sign -am "$patch_name"
