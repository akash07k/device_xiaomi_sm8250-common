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
From 6c9f57bd25b0c2fa34acb141513d995907c2ef0c Mon Sep 17 00:00:00 2001
From: spkal01 <kalligeross@gmail.com>
Date: Mon, 24 Oct 2022 15:13:59 +0300
Subject: [PATCH] [SQUASH] Multiple reverts for miuicamera

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 core/java/android/hardware/Camera.java        | 50 +------------------
 .../hardware/camera2/CameraManager.java       | 30 +----------
 core/jni/android_hardware_Camera.cpp          |  2 +-
 3 files changed, 4 insertions(+), 78 deletions(-)

diff --git a/core/java/android/hardware/Camera.java b/core/java/android/hardware/Camera.java
index 2595aeb313df..f04479deeef3 100644
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
 
@@ -282,33 +280,6 @@ public class Camera {
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
-    	if (packageName == null)
-    	    return true;
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
@@ -324,20 +295,7 @@ public class Camera {
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
@@ -348,9 +306,6 @@ public class Camera {
      *    low-level failure).
      */
     public static void getCameraInfo(int cameraId, CameraInfo cameraInfo) {
-        if (cameraId >= getNumberOfCameras()) {
-            throw new RuntimeException("Unknown camera ID");
-        }
         _getCameraInfo(cameraId, cameraInfo);
         IBinder b = ServiceManager.getService(Context.AUDIO_SERVICE);
         IAudioService audioService = IAudioService.Stub.asInterface(b);
@@ -566,9 +521,6 @@ public class Camera {
 
     /** used by Camera#open, Camera#open(int) */
     Camera(int cameraId) {
-        if (cameraId >= getNumberOfCameras()) {
-            throw new RuntimeException("Unknown camera ID");
-        }
         int err = cameraInit(cameraId);
         if (checkInitErrors(err)) {
             if (err == -EACCES) {
diff --git a/core/java/android/hardware/camera2/CameraManager.java b/core/java/android/hardware/camera2/CameraManager.java
index 9458960d13de..f8170731b2e5 100644
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
@@ -1678,10 +1677,8 @@ public final class CameraManager {
 
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
@@ -1689,7 +1686,7 @@ public final class CameraManager {
             }
             cameraIds = new String[idCount];
             idCount = 0;
-            for (int i = 0; i < size; i++) {
+            for (int i = 0; i < mDeviceStatus.size(); i++) {
                 int status = mDeviceStatus.valueAt(i);
                 if (status == ICameraServiceListener.STATUS_NOT_PRESENT
                         || status == ICameraServiceListener.STATUS_ENUMERATING) continue;
@@ -1954,14 +1951,6 @@ public final class CameraManager {
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
@@ -2229,11 +2218,6 @@ public final class CameraManager {
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
@@ -2365,16 +2349,6 @@ public final class CameraManager {
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

git -C $patch_dir apply --verbose < <(cat <<'EOL'
From 3139485245297454afce839f796572abc89b2767 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Sat, 22 Oct 2022 23:54:23 +0000
Subject: [PATCH] DNM Revert "Camera: Add support for readout timestamp"

This reverts commit 91e7522cb28d2b1e2e12adc8726db8190d711f2e.

Temporary revert. No devices support this as of yet.

Signed-off-by: Pranav Vashi <neobuddy89@gmail.com>
---
 .../camera2/CameraCaptureSession.java         | 36 -------------------
 .../camera2/CameraCharacteristics.java        | 34 ------------------
 .../hardware/camera2/CameraMetadata.java      | 22 ------------
 .../impl/CameraCaptureSessionImpl.java        | 15 --------
 .../camera2/impl/CameraDeviceImpl.java        | 24 +++----------
 .../camera2/impl/CaptureCallback.java         |  7 ----
 .../camera2/impl/CaptureResultExtras.java     | 23 +-----------
 .../camera2/params/OutputConfiguration.java   | 25 ++-----------
 8 files changed, 7 insertions(+), 179 deletions(-)

diff --git a/core/java/android/hardware/camera2/CameraCaptureSession.java b/core/java/android/hardware/camera2/CameraCaptureSession.java
index 5b1973ad2dd4..691690c09e0e 100644
--- a/core/java/android/hardware/camera2/CameraCaptureSession.java
+++ b/core/java/android/hardware/camera2/CameraCaptureSession.java
@@ -1233,42 +1233,6 @@ public abstract class CameraCaptureSession implements AutoCloseable {
             // default empty implementation
         }
 
-        /**
-         * This method is called when the camera device has started reading out the output
-         * image for the request, at the beginning of the sensor image readout.
-         *
-         * <p>For a capture request, this callback is invoked right after
-         * {@link #onCaptureStarted}. Unlike {@link #onCaptureStarted}, instead of passing
-         * a timestamp of start of exposure, this callback passes a timestamp of start of
-         * camera data readout. This is useful because for a camera running at fixed frame
-         * rate, the start of readout is at fixed interval, which is not necessarily true for
-         * the start of exposure, particularly when autoexposure is changing exposure duration
-         * between frames.</p>
-         *
-         * <p>This timestamp may not match {@link CaptureResult#SENSOR_TIMESTAMP the result
-         * timestamp field}. It will, however, match the timestamp of buffers sent to the
-         * output surfaces with {@link OutputConfiguration#TIMESTAMP_BASE_READOUT_SENSOR}
-         * timestamp base.</p>
-         *
-         * <p>This callback will be called only if {@link
-         * CameraCharacteristics#SENSOR_READOUT_TIMESTAMP} is
-         * {@link CameraMetadata#SENSOR_READOUT_TIMESTAMP_HARDWARE}, and it's called
-         * right after {@link #onCaptureStarted}.</p>
-         *
-         * @param session the session returned by {@link CameraDevice#createCaptureSession}
-         * @param request the request for the readout that just began
-         * @param timestamp the timestamp at start of readout for a regular request, or
-         *                  the timestamp at the input image's start of readout for a
-         *                  reprocess request, in nanoseconds.
-         * @param frameNumber the frame number for this capture
-         *
-         * @hide
-         */
-        public void onReadoutStarted(@NonNull CameraCaptureSession session,
-                @NonNull CaptureRequest request, long timestamp, long frameNumber) {
-            // default empty implementation
-        }
-
         /**
          * This method is called when some results from an image capture are
          * available.
diff --git a/core/java/android/hardware/camera2/CameraCharacteristics.java b/core/java/android/hardware/camera2/CameraCharacteristics.java
index 861a8502c44d..c32ad724bb37 100644
--- a/core/java/android/hardware/camera2/CameraCharacteristics.java
+++ b/core/java/android/hardware/camera2/CameraCharacteristics.java
@@ -4418,40 +4418,6 @@ public final class CameraCharacteristics extends CameraMetadata<CameraCharacteri
     public static final Key<android.graphics.Rect[]> SENSOR_OPTICAL_BLACK_REGIONS =
             new Key<android.graphics.Rect[]>("android.sensor.opticalBlackRegions", android.graphics.Rect[].class);
 
-    /**
-     * <p>Whether or not the camera device supports readout timestamp and
-     * onReadoutStarted callback.</p>
-     * <p>If this tag is HARDWARE, the camera device calls onReadoutStarted in addition to the
-     * onCaptureStarted callback for each capture. The timestamp passed into the callback
-     * is the start of camera image readout rather than the start of the exposure. In
-     * addition, the application can configure an
-     * {@link android.hardware.camera2.params.OutputConfiguration } with
-     * TIMESTAMP_BASE_READOUT_SENSOR timestamp base, in which case, the timestamp of the
-     * output surface matches the timestamp from the corresponding onReadoutStarted callback.</p>
-     * <p>The readout timestamp is beneficial for video recording, because the encoder favors
-     * uniform timestamps, and the readout timestamps better reflect the cadence camera sensors
-     * output data.</p>
-     * <p>If this tag is HARDWARE, the camera device produces the start-of-exposure and
-     * start-of-readout together. As a result, the onReadoutStarted is called right after
-     * onCaptureStarted. The difference in start-of-readout and start-of-exposure is the sensor
-     * exposure time, plus certain constant offset. The offset is usually due to camera sensor
-     * level crop, and it remains constant for a given camera sensor mode.</p>
-     * <p><b>Possible values:</b></p>
-     * <ul>
-     *   <li>{@link #SENSOR_READOUT_TIMESTAMP_NOT_SUPPORTED NOT_SUPPORTED}</li>
-     *   <li>{@link #SENSOR_READOUT_TIMESTAMP_HARDWARE HARDWARE}</li>
-     * </ul>
-     *
-     * <p>This key is available on all devices.</p>
-     * @see #SENSOR_READOUT_TIMESTAMP_NOT_SUPPORTED
-     * @see #SENSOR_READOUT_TIMESTAMP_HARDWARE
-     * @hide
-     */
-    @PublicKey
-    @NonNull
-    public static final Key<Integer> SENSOR_READOUT_TIMESTAMP =
-            new Key<Integer>("android.sensor.readoutTimestamp", int.class);
-
     /**
      * <p>List of lens shading modes for {@link CaptureRequest#SHADING_MODE android.shading.mode} that are supported by this camera device.</p>
      * <p>This list contains lens shading modes that can be set for the camera device.
diff --git a/core/java/android/hardware/camera2/CameraMetadata.java b/core/java/android/hardware/camera2/CameraMetadata.java
index c67a560b5885..eb8c73aced39 100644
--- a/core/java/android/hardware/camera2/CameraMetadata.java
+++ b/core/java/android/hardware/camera2/CameraMetadata.java
@@ -1657,28 +1657,6 @@ public abstract class CameraMetadata<TKey> {
      */
     public static final int SENSOR_REFERENCE_ILLUMINANT1_ISO_STUDIO_TUNGSTEN = 24;
 
-    //
-    // Enumeration values for CameraCharacteristics#SENSOR_READOUT_TIMESTAMP
-    //
-
-    /**
-     * <p>This camera device doesn't support readout timestamp and onReadoutStarted
-     * callback.</p>
-     * @see CameraCharacteristics#SENSOR_READOUT_TIMESTAMP
-     * @hide
-     */
-    public static final int SENSOR_READOUT_TIMESTAMP_NOT_SUPPORTED = 0;
-
-    /**
-     * <p>This camera device supports the onReadoutStarted callback as well as outputting
-     * readout timestamp for streams with TIMESTAMP_BASE_READOUT_SENSOR timestamp base. The
-     * readout timestamp is generated by the camera hardware and it has the same accuracy
-     * and timing characteristics of the start-of-exposure time.</p>
-     * @see CameraCharacteristics#SENSOR_READOUT_TIMESTAMP
-     * @hide
-     */
-    public static final int SENSOR_READOUT_TIMESTAMP_HARDWARE = 1;
-
     //
     // Enumeration values for CameraCharacteristics#LED_AVAILABLE_LEDS
     //
diff --git a/core/java/android/hardware/camera2/impl/CameraCaptureSessionImpl.java b/core/java/android/hardware/camera2/impl/CameraCaptureSessionImpl.java
index 1c6ca081e677..c5bb3e2ec80c 100644
--- a/core/java/android/hardware/camera2/impl/CameraCaptureSessionImpl.java
+++ b/core/java/android/hardware/camera2/impl/CameraCaptureSessionImpl.java
@@ -671,21 +671,6 @@ public class CameraCaptureSessionImpl extends CameraCaptureSession
                 }
             }
 
-            @Override
-            public void onReadoutStarted(CameraDevice camera,
-                    CaptureRequest request, long timestamp, long frameNumber) {
-                if ((callback != null) && (executor != null)) {
-                    final long ident = Binder.clearCallingIdentity();
-                    try {
-                        executor.execute(() -> callback.onReadoutStarted(
-                                    CameraCaptureSessionImpl.this, request, timestamp,
-                                    frameNumber));
-                    } finally {
-                        Binder.restoreCallingIdentity(ident);
-                    }
-                }
-            }
-
             @Override
             public void onCapturePartial(CameraDevice camera,
                     CaptureRequest request, android.hardware.camera2.CaptureResult result) {
diff --git a/core/java/android/hardware/camera2/impl/CameraDeviceImpl.java b/core/java/android/hardware/camera2/impl/CameraDeviceImpl.java
index 80a55acbd236..578ab5564994 100644
--- a/core/java/android/hardware/camera2/impl/CameraDeviceImpl.java
+++ b/core/java/android/hardware/camera2/impl/CameraDeviceImpl.java
@@ -2075,16 +2075,12 @@ public class CameraDeviceImpl extends CameraDevice
                     resultExtras.getLastCompletedReprocessFrameNumber();
             final long lastCompletedZslFrameNumber =
                     resultExtras.getLastCompletedZslFrameNumber();
-            final boolean hasReadoutTimestamp = resultExtras.hasReadoutTimestamp();
-            final long readoutTimestamp = resultExtras.getReadoutTimestamp();
 
             if (DEBUG) {
                 Log.d(TAG, "Capture started for id " + requestId + " frame number " + frameNumber
                         + ": completedRegularFrameNumber " + lastCompletedRegularFrameNumber
                         + ", completedReprocessFrameNUmber " + lastCompletedReprocessFrameNumber
-                        + ", completedZslFrameNumber " + lastCompletedZslFrameNumber
-                        + ", hasReadoutTimestamp " + hasReadoutTimestamp
-                        + (hasReadoutTimestamp ? ", readoutTimestamp " + readoutTimestamp : "")) ;
+                        + ", completedZslFrameNumber " + lastCompletedZslFrameNumber);
             }
             final CaptureCallbackHolder holder;
 
@@ -2136,26 +2132,14 @@ public class CameraDeviceImpl extends CameraDevice
                                                 CameraDeviceImpl.this,
                                                 holder.getRequest(i),
                                                 timestamp - (subsequenceId - i) *
-                                                NANO_PER_SECOND / fpsRange.getUpper(),
+                                                NANO_PER_SECOND/fpsRange.getUpper(),
                                                 frameNumber - (subsequenceId - i));
-                                            if (hasReadoutTimestamp) {
-                                                holder.getCallback().onReadoutStarted(
-                                                    CameraDeviceImpl.this,
-                                                    holder.getRequest(i),
-                                                    readoutTimestamp - (subsequenceId - i) *
-                                                    NANO_PER_SECOND / fpsRange.getUpper(),
-                                                    frameNumber - (subsequenceId - i));
-                                            }
                                         }
                                     } else {
                                         holder.getCallback().onCaptureStarted(
-                                            CameraDeviceImpl.this, request,
+                                            CameraDeviceImpl.this,
+                                            holder.getRequest(resultExtras.getSubsequenceId()),
                                             timestamp, frameNumber);
-                                        if (hasReadoutTimestamp) {
-                                            holder.getCallback().onReadoutStarted(
-                                                CameraDeviceImpl.this, request,
-                                                readoutTimestamp, frameNumber);
-                                        }
                                     }
                                 }
                             }
diff --git a/core/java/android/hardware/camera2/impl/CaptureCallback.java b/core/java/android/hardware/camera2/impl/CaptureCallback.java
index b064e6a1f975..6defe63b1766 100644
--- a/core/java/android/hardware/camera2/impl/CaptureCallback.java
+++ b/core/java/android/hardware/camera2/impl/CaptureCallback.java
@@ -65,13 +65,6 @@ public abstract class CaptureCallback {
     public abstract void onCaptureStarted(CameraDevice camera,
             CaptureRequest request, long timestamp, long frameNumber);
 
-    /**
-     * This method is called when the camera device has started reading out the output
-     * image for the request, at the beginning of the sensor image readout.
-     */
-    public abstract void onReadoutStarted(CameraDevice camera,
-            CaptureRequest request, long timestamp, long frameNumber);
-
     /**
      * This method is called when some results from an image capture are
      * available.
diff --git a/core/java/android/hardware/camera2/impl/CaptureResultExtras.java b/core/java/android/hardware/camera2/impl/CaptureResultExtras.java
index 8bf94986a490..5d9da73fd5c0 100644
--- a/core/java/android/hardware/camera2/impl/CaptureResultExtras.java
+++ b/core/java/android/hardware/camera2/impl/CaptureResultExtras.java
@@ -33,8 +33,6 @@ public class CaptureResultExtras implements Parcelable {
     private long lastCompletedRegularFrameNumber;
     private long lastCompletedReprocessFrameNumber;
     private long lastCompletedZslFrameNumber;
-    private boolean hasReadoutTimestamp;
-    private long readoutTimestamp;
 
     public static final @android.annotation.NonNull Parcelable.Creator<CaptureResultExtras> CREATOR =
             new Parcelable.Creator<CaptureResultExtras>() {
@@ -58,8 +56,7 @@ public class CaptureResultExtras implements Parcelable {
                                int partialResultCount, int errorStreamId,
                                String errorPhysicalCameraId, long lastCompletedRegularFrameNumber,
                                long lastCompletedReprocessFrameNumber,
-                               long lastCompletedZslFrameNumber, boolean hasReadoutTimestamp,
-                               long readoutTimestamp) {
+                               long lastCompletedZslFrameNumber) {
         this.requestId = requestId;
         this.subsequenceId = subsequenceId;
         this.afTriggerId = afTriggerId;
@@ -71,8 +68,6 @@ public class CaptureResultExtras implements Parcelable {
         this.lastCompletedRegularFrameNumber = lastCompletedRegularFrameNumber;
         this.lastCompletedReprocessFrameNumber = lastCompletedReprocessFrameNumber;
         this.lastCompletedZslFrameNumber = lastCompletedZslFrameNumber;
-        this.hasReadoutTimestamp = hasReadoutTimestamp;
-        this.readoutTimestamp = readoutTimestamp;
     }
 
     @Override
@@ -98,10 +93,6 @@ public class CaptureResultExtras implements Parcelable {
         dest.writeLong(lastCompletedRegularFrameNumber);
         dest.writeLong(lastCompletedReprocessFrameNumber);
         dest.writeLong(lastCompletedZslFrameNumber);
-        dest.writeBoolean(hasReadoutTimestamp);
-        if (hasReadoutTimestamp) {
-            dest.writeLong(readoutTimestamp);
-        }
     }
 
     public void readFromParcel(Parcel in) {
@@ -119,10 +110,6 @@ public class CaptureResultExtras implements Parcelable {
         lastCompletedRegularFrameNumber = in.readLong();
         lastCompletedReprocessFrameNumber = in.readLong();
         lastCompletedZslFrameNumber = in.readLong();
-        hasReadoutTimestamp = in.readBoolean();
-        if (hasReadoutTimestamp) {
-            readoutTimestamp = in.readLong();
-        }
     }
 
     public String getErrorPhysicalCameraId() {
@@ -168,12 +155,4 @@ public class CaptureResultExtras implements Parcelable {
     public long getLastCompletedZslFrameNumber() {
         return lastCompletedZslFrameNumber;
     }
-
-    public boolean hasReadoutTimestamp() {
-        return hasReadoutTimestamp;
-    }
-
-    public long getReadoutTimestamp() {
-        return readoutTimestamp;
-    }
 }
diff --git a/core/java/android/hardware/camera2/params/OutputConfiguration.java b/core/java/android/hardware/camera2/params/OutputConfiguration.java
index 90e92dbe2ab0..bd92846c8a39 100644
--- a/core/java/android/hardware/camera2/params/OutputConfiguration.java
+++ b/core/java/android/hardware/camera2/params/OutputConfiguration.java
@@ -247,26 +247,6 @@ public final class OutputConfiguration implements Parcelable {
      */
     public static final int TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED = 4;
 
-    /**
-     * Timestamp is the start of readout in the same time domain as TIMESTAMP_BASE_SENSOR.
-     *
-     * <p>The start of the camera sensor readout after exposure. For a rolling shutter camera
-     * sensor, the timestamp is typically equal to the start of exposure time +
-     * exposure time + certain fixed offset. The fixed offset could be due to camera sensor
-     * level crop. The benefit of using readout time is that when camera runs in a fixed
-     * frame rate, the timestamp intervals between frames are constant.</p>
-     *
-     * <p>This timestamp is in the same time domain as in TIMESTAMP_BASE_SENSOR, with the exception
-     * that one is start of exposure, and the other is start of readout.</p>
-     *
-     * <p>This timestamp base is supported only if {@link
-     * CameraCharacteristics#SENSOR_READOUT_TIMESTAMP} is
-     * {@link CameraMetadata#SENSOR_READOUT_TIMESTAMP_HARDWARE}.</p>
-     *
-     * @hide
-     */
-    public static final int TIMESTAMP_BASE_READOUT_SENSOR = 5;
-
     /** @hide */
     @Retention(RetentionPolicy.SOURCE)
     @IntDef(prefix = {"TIMESTAMP_BASE_"}, value =
@@ -274,8 +254,7 @@ public final class OutputConfiguration implements Parcelable {
          TIMESTAMP_BASE_SENSOR,
          TIMESTAMP_BASE_MONOTONIC,
          TIMESTAMP_BASE_REALTIME,
-         TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED,
-         TIMESTAMP_BASE_READOUT_SENSOR})
+         TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED})
     public @interface TimestampBase {};
 
     /** @hide */
@@ -997,7 +976,7 @@ public final class OutputConfiguration implements Parcelable {
     public void setTimestampBase(@TimestampBase int timestampBase) {
         // Verify that the value is in range
         if (timestampBase < TIMESTAMP_BASE_DEFAULT ||
-                timestampBase > TIMESTAMP_BASE_READOUT_SENSOR) {
+                timestampBase > TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED) {
             throw new IllegalArgumentException("Not a valid timestamp base value " +
                     timestampBase);
         }
-- 
2.38.1.windows.1

EOL
) &&
git -C $patch_dir commit --no-gpg-sign -am "$patch_name"

# ************************************
# Apply the patch for MIUI camera
# ************************************
echo 'Patching frameworks/av'
patch_name='Multiple commits for MIUI camera'
patch_dir=frameworks/av
cur_commit="$(git -C $patch_dir show -s --format=%s)" || exit $?

# Remove old commit
if [ "$cur_commit" = "$patch_name" ]; then
    git -C $patch_dir reset --hard HEAD^ || exit $?
fi

# Apply and commit patch
git -C $patch_dir apply --verbose < <(cat <<'EOL'
From 32916b3d5240d4e3cd1d94dfbfd1f3fb5521c263 Mon Sep 17 00:00:00 2001
From: Adithya R <gh0strider.2k18.reborn@gmail.com>
Date: Fri, 1 Jan 2021 03:07:52 +0530
Subject: [PATCH 01/11] libcameraservice: Add support for miui camera mode

 * devices like ginkgo and some xiaomi sdm660 use miui camera mode in camera
   hal to activate certain functions in camera hal, these are enabled when
   vendor.camera.miui.apk is set to 1 based on sys.camera.miui.apk value

 * if this prop is set by default gcam crashes, so we must do it dynamically

 * xiaomi does this in stock libcameraservice but unfortunately we don't
   have stock android 12 to use prebuilt lib

Change-Id: I8d9ee4e650f3e2196546570c183c9d169b8aa335
Signed-off-by: Joey Huab <joey@evolution-x.org>
Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 services/camera/libcameraservice/CameraService.cpp | 11 +++++++++++
 1 file changed, 11 insertions(+)

diff --git a/services/camera/libcameraservice/CameraService.cpp b/services/camera/libcameraservice/CameraService.cpp
index 2388b7966b..cb2ade9f43 100644
--- a/services/camera/libcameraservice/CameraService.cpp
+++ b/services/camera/libcameraservice/CameraService.cpp
@@ -35,6 +35,7 @@
 
 #include <android-base/macros.h>
 #include <android-base/parseint.h>
+#include <android-base/properties.h>
 #include <android-base/stringprintf.h>
 #include <binder/ActivityManager.h>
 #include <binder/AppOpsManager.h>
@@ -85,6 +86,7 @@ namespace {
 namespace android {
 
 using base::StringPrintf;
+using base::SetProperty;
 using binder::Status;
 using namespace camera3;
 using frameworks::cameraservice::service::V2_0::implementation::HidlCameraService;
@@ -3490,6 +3492,15 @@ status_t CameraService::BasicClient::startCameraOps() {
 
     mOpsActive = true;
 
+    // Configure miui camera mode
+    if (strcmp(String8(mClientPackageName).string(), "com.android.camera") == 0) {
+        SetProperty("sys.camera.miui.apk", "1");
+        ALOGI("Enabling miui camera mode");
+    } else {
+        SetProperty("sys.camera.miui.apk", "0");
+        ALOGI("Disabling miui camera mode");
+    }
+
     // Transition device availability listeners from PRESENT -> NOT_AVAILABLE
     sCameraService->updateStatus(StatusInternal::NOT_AVAILABLE, mCameraIdStr);
 
-- 
2.38.1.windows.1


From 397e470912de872510faa91b5cf8b1cc1f3b8eff Mon Sep 17 00:00:00 2001
From: Adithya R <gh0strider.2k18.reborn@gmail.com>
Date: Tue, 3 Aug 2021 20:27:06 +0530
Subject: [PATCH 02/11] HACK: libcameraservice: Make system cameras available
 to all camera apps

 * big brained realmeme decided to move aux cams to "system-only cameras"
   utilizing the new permission introduced in android 11, thereby breaking
   aux cams in 3rd party camera apps like gcam

 * lets avoid this and make system camera accessible to all camera apps;
   legacy apps still wont break because of the aux cams check in fwb

Test: manual, aux cameras accessible by gcam on realme X3
Change-Id: I5db53ffe91a8c28972f1c58bd228cb0f79d7183a
Signed-off-by: Adithya R <gh0strider.2k18.reborn@gmail.com>
Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 services/camera/libcameraservice/CameraService.cpp | 5 ++---
 1 file changed, 2 insertions(+), 3 deletions(-)

diff --git a/services/camera/libcameraservice/CameraService.cpp b/services/camera/libcameraservice/CameraService.cpp
index cb2ade9f43..e047005dd6 100644
--- a/services/camera/libcameraservice/CameraService.cpp
+++ b/services/camera/libcameraservice/CameraService.cpp
@@ -642,9 +642,8 @@ void CameraService::onTorchStatusChangedLocked(const String8& cameraId,
 
 static bool hasPermissionsForSystemCamera(int callingPid, int callingUid,
         bool logPermissionFailure = false) {
-    return checkPermission(sSystemCameraPermission, callingPid, callingUid,
-            logPermissionFailure) &&
-            checkPermission(sCameraPermission, callingPid, callingUid);
+    return checkPermission(sCameraPermission, callingPid, callingUid,
+            logPermissionFailure);
 }
 
 Status CameraService::getNumberOfCameras(int32_t type, int32_t* numCameras) {
-- 
2.38.1.windows.1


From 1551bca2263dd415f30b11068b79d19724fb85ee Mon Sep 17 00:00:00 2001
From: Adithya R <gh0strider.2k18.reborn@gmail.com>
Date: Tue, 5 May 2020 13:33:12 +0530
Subject: [PATCH 03/11] libcameraservice: HAX for depth sensor on ginkgo [2/2]

 * miui camera uses logical id 61 as depth sensor on portrait mode
   but oss libcam maps it to physical id 2 which is wrong, our physical
   id of depth sensor is 20 so we must hack it this way

[ghostrider-reborn 2021-10-26]
 * updated for android 12

[akemiyxl 2022-09-04]
 * Forward to android 13 (googlag move to HidlCamera3Device.cpp)

Change-Id: I57388d0e00fc21b99427e0c0b1ff9a39926b2243
Signed-off-by: Adithya R <gh0strider.2k18.reborn@gmail.com>
Signed-off-by: akemiyxl <akemiyxl.github@gmail.com>
Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/hidl/HidlCamera3Device.cpp         | 18 +++++++++++++++---
 1 file changed, 15 insertions(+), 3 deletions(-)

diff --git a/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp b/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
index 9557692d78..8b1870adca 100644
--- a/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
+++ b/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
@@ -29,6 +29,9 @@
 #define CLOGE(fmt, ...) ALOGE("Camera %s: %s: " fmt, mId.string(), __FUNCTION__, \
             ##__VA_ARGS__)
 
+#define CLOGW(fmt, ...) ALOGW("Camera %s: %s: " fmt, mId.string(), __FUNCTION__, \
+ ##__VA_ARGS__)
+
 // Convenience macros for transitioning to the error state
 #define SET_ERR(fmt, ...) setErrorState(   \
     "%s: " fmt, __FUNCTION__,              \
@@ -177,11 +180,20 @@ status_t HidlCamera3Device::initialize(sp<CameraProviderManager> manager,
             // Do not override characteristics for physical cameras
             res = manager->getCameraCharacteristics(
                     physicalId, /*overrideForPerfClass*/false, &mPhysicalDeviceInfoMap[physicalId]);
+            // HACK for ginkgo - check camera id 20 for depth sensor
             if (res != OK) {
-                SET_ERR_L("Could not retrieve camera %s characteristics: %s (%d)",
+                CLOGW("Could not retrieve camera %s characteristics: %s (%d)",
                         physicalId.c_str(), strerror(-res), res);
-                session->close();
-                return res;
+                physicalId = std::to_string(20); // TODO: Maybe make this a soong config?
+                CLOGW("Trying physical camera %s if available", physicalId.c_str());
+                res = manager->getCameraCharacteristics(
+                        physicalId, false, &mPhysicalDeviceInfoMap[physicalId]);
+                if (res != OK) {
+                    SET_ERR_L("Could not retrieve camera %s characteristics: %s (%d)",
+                            physicalId.c_str(), strerror(-res), res);
+                    session->close();
+                    return res;
+                }
             }
 
             bool usePrecorrectArray =
-- 
2.38.1.windows.1


From 8508fb1408601d64afcdf0eb303659cfa22d1ab0 Mon Sep 17 00:00:00 2001
From: jhenrique09 <jhenrique09.mcz@hotmail.com>
Date: Tue, 24 Mar 2020 16:36:07 -0300
Subject: [PATCH 04/11] [2/2] av: Remove restrictions for system audio record

* Give freedom to screen recorder apps

Change-Id: I726bde4f44bba6fc8cd771ae90c8864b26cdd919
Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../libaaudio/src/utility/AAudioUtilities.cpp |  6 ++--
 .../managerdefinitions/src/AudioPolicyMix.cpp | 36 ++-----------------
 2 files changed, 5 insertions(+), 37 deletions(-)

diff --git a/media/libaaudio/src/utility/AAudioUtilities.cpp b/media/libaaudio/src/utility/AAudioUtilities.cpp
index 872faca58b..849d8b612f 100644
--- a/media/libaaudio/src/utility/AAudioUtilities.cpp
+++ b/media/libaaudio/src/utility/AAudioUtilities.cpp
@@ -239,7 +239,7 @@ audio_flags_mask_t AAudioConvert_allowCapturePolicyToAudioFlagsMask(
         aaudio_spatialization_behavior_t spatializationBehavior,
         bool isContentSpatialized) {
     audio_flags_mask_t flagsMask = AUDIO_FLAG_NONE;
-    switch (policy) {
+    /*switch (policy) {
         case AAUDIO_UNSPECIFIED:
         case AAUDIO_ALLOW_CAPTURE_BY_ALL:
             // flagsMask is not modified
@@ -254,7 +254,7 @@ audio_flags_mask_t AAudioConvert_allowCapturePolicyToAudioFlagsMask(
         default:
             ALOGE("%s() 0x%08X unrecognized capture policy", __func__, policy);
             // flagsMask is not modified
-    }
+    }*/
 
     switch (spatializationBehavior) {
         case AAUDIO_UNSPECIFIED:
@@ -274,7 +274,7 @@ audio_flags_mask_t AAudioConvert_allowCapturePolicyToAudioFlagsMask(
         flagsMask = static_cast<audio_flags_mask_t>(flagsMask | AUDIO_FLAG_CONTENT_SPATIALIZED);
     }
 
-    return flagsMask;
+    return AUDIO_FLAG_NONE;
 }
 
 audio_flags_mask_t AAudioConvert_privacySensitiveToAudioFlagsMask(
diff --git a/services/audiopolicy/common/managerdefinitions/src/AudioPolicyMix.cpp b/services/audiopolicy/common/managerdefinitions/src/AudioPolicyMix.cpp
index e142bef750..cf2e8e9238 100644
--- a/services/audiopolicy/common/managerdefinitions/src/AudioPolicyMix.cpp
+++ b/services/audiopolicy/common/managerdefinitions/src/AudioPolicyMix.cpp
@@ -205,40 +205,8 @@ AudioPolicyMixCollection::MixMatchStatus AudioPolicyMixCollection::mixMatch(
         const AudioMix* mix, size_t mixIndex, const audio_attributes_t& attributes,
         const audio_config_base_t& config, uid_t uid) {
 
-    if (mix->mMixType == MIX_TYPE_PLAYERS) {
-        // Loopback render mixes are created from a public API and thus restricted
-        // to non sensible audio that have not opted out.
-        if (is_mix_loopback_render(mix->mRouteFlags)) {
-            if (!(attributes.usage == AUDIO_USAGE_UNKNOWN ||
-                  attributes.usage == AUDIO_USAGE_MEDIA ||
-                  attributes.usage == AUDIO_USAGE_GAME ||
-                  attributes.usage == AUDIO_USAGE_VOICE_COMMUNICATION)) {
-                return MixMatchStatus::NO_MATCH;
-            }
-            auto hasFlag = [](auto flags, auto flag) { return (flags & flag) == flag; };
-            if (hasFlag(attributes.flags, AUDIO_FLAG_NO_SYSTEM_CAPTURE)) {
-                return MixMatchStatus::NO_MATCH;
-            }
-
-            if (attributes.usage == AUDIO_USAGE_VOICE_COMMUNICATION) {
-                if (!mix->mVoiceCommunicationCaptureAllowed) {
-                    return MixMatchStatus::NO_MATCH;
-                }
-            } else if (!mix->mAllowPrivilegedMediaPlaybackCapture &&
-                hasFlag(attributes.flags, AUDIO_FLAG_NO_MEDIA_PROJECTION)) {
-                return MixMatchStatus::NO_MATCH;
-            }
-        }
-
-        // Permit match only if requested format and mix format are PCM and can be format
-        // adapted by the mixer, or are the same (compressed) format.
-        if (!is_mix_loopback(mix->mRouteFlags) &&
-            !((audio_is_linear_pcm(config.format) && audio_is_linear_pcm(mix->mFormat.format)) ||
-              (config.format == mix->mFormat.format)) &&
-              config.format != AUDIO_CONFIG_BASE_INITIALIZER.format) {
-            return MixMatchStatus::NO_MATCH;
-        }
-
+    if (mix->mMixType == MIX_TYPE_PLAYERS &&
+               (config.format != mix->mFormat.format || true)) {
         int userId = (int) multiuser_get_user_id(uid);
 
         // TODO if adding more player rules (currently only 2), make rule handling "generic"
-- 
2.38.1.windows.1


From 9daf71b8fb8e95f32c27707cc0a4c5cc6acf64fd Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 13:07:02 +0000
Subject: [PATCH 05/11] Revert "Camera: Reduce latency for dejittering"

This reverts commit 35bd3553b06468c8d77adecca498ff0a0d194d41.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/Camera3OutputStream.cpp                | 14 ++++----------
 .../libcameraservice/device3/Camera3OutputStream.h |  2 +-
 .../device3/PreviewFrameSpacer.cpp                 |  2 +-
 .../libcameraservice/device3/PreviewFrameSpacer.h  |  2 +-
 4 files changed, 7 insertions(+), 13 deletions(-)

diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index efb04df076..b7ff1f0fa9 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -1406,24 +1406,18 @@ void Camera3OutputStream::returnPrefetchedBuffersLocked() {
 }
 
 nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
-    nsecs_t currentTime = systemTime();
-    if (!mFixedFps) {
-        mLastCaptureTime = t;
-        mLastPresentTime = currentTime;
-        return t;
-    }
-
     ParcelableVsyncEventData parcelableVsyncEventData;
     auto res = mDisplayEventReceiver.getLatestVsyncEventData(&parcelableVsyncEventData);
     if (res != OK) {
         ALOGE("%s: Stream %d: Error getting latest vsync event data: %s (%d)",
                 __FUNCTION__, mId, strerror(-res), res);
         mLastCaptureTime = t;
-        mLastPresentTime = currentTime;
+        mLastPresentTime = t;
         return t;
     }
 
     const VsyncEventData& vsyncEventData = parcelableVsyncEventData.vsync;
+    nsecs_t currentTime = systemTime();
     nsecs_t minPresentT = mLastPresentTime + vsyncEventData.frameInterval / 2;
 
     // Find the best presentation time without worrying about previous frame's
@@ -1528,8 +1522,8 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
         }
     }
 
-    if (expectedPresentT == mLastPresentTime && expectedPresentT <
-            vsyncEventData.frameTimelines[maxTimelines-1].expectedPresentationTime) {
+    if (expectedPresentT == mLastPresentTime && expectedPresentT <=
+            vsyncEventData.frameTimelines[maxTimelines].expectedPresentationTime) {
         // Couldn't find a reasonable presentation time. Using last frame's
         // presentation time would cause a frame drop. The best option now
         // is to use the next VSync as long as the last presentation time
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index db988a0114..741bca2fa7 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -432,7 +432,7 @@ class Camera3OutputStream :
     static constexpr nsecs_t kSpacingResetIntervalNs = 50000000LL; // 50 millisecond
     static constexpr nsecs_t kTimelineThresholdNs = 1000000LL; // 1 millisecond
     static constexpr float kMaxIntervalRatioDeviation = 0.05f;
-    static constexpr int kMaxTimelines = 2;
+    static constexpr int kMaxTimelines = 3;
     nsecs_t syncTimestampToDisplayLocked(nsecs_t t);
 
     // Re-space frames by delaying queueBuffer so that frame delivery has
diff --git a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
index b3cb17857f..67f42b45e3 100644
--- a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
+++ b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
@@ -68,7 +68,7 @@ bool PreviewFrameSpacer::threadLoop() {
         return true;
     }
 
-    // Cache the frame to match readout time interval, for up to kMaxFrameWaitTime
+    // Cache the frame to match readout time interval, for up to 33ms
     nsecs_t expectedQueueTime = mLastCameraPresentTime + readoutInterval;
     nsecs_t frameWaitTime = std::min(kMaxFrameWaitTime, expectedQueueTime - currentTime);
     if (frameWaitTime > 0 && mPendingBuffers.size() < 2) {
diff --git a/services/camera/libcameraservice/device3/PreviewFrameSpacer.h b/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
index cb9690cf63..e165768b97 100644
--- a/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
+++ b/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
@@ -85,7 +85,7 @@ class PreviewFrameSpacer : public Thread {
     nsecs_t mLastCameraPresentTime = 0;
     static constexpr nsecs_t kWaitDuration = 5000000LL; // 50ms
     static constexpr nsecs_t kFrameIntervalThreshold = 80000000LL; // 80ms
-    static constexpr nsecs_t kMaxFrameWaitTime = 10000000LL; // 10ms
+    static constexpr nsecs_t kMaxFrameWaitTime = 33333333LL; // 33ms
 };
 
 }; //namespace camera3
-- 
2.38.1.windows.1


From 734ff300983ad52348eabec89f2c51e9d781294b Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 13:07:06 +0000
Subject: [PATCH 06/11] Revert "Camera: Avoid dequeue too many buffers from
 buffer queue"

This reverts commit c235270ed552cbbe1df31cf3862f913872fab38a.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/Camera3IOStreamBase.cpp           | 14 +-----
 .../device3/Camera3IOStreamBase.h             | 10 ----
 .../device3/Camera3OutputStream.cpp           | 21 +-------
 .../device3/Camera3OutputStream.h             |  1 -
 .../device3/Camera3Stream.cpp                 | 50 +++++--------------
 .../libcameraservice/device3/Camera3Stream.h  |  7 +--
 .../device3/PreviewFrameSpacer.cpp            |  1 -
 7 files changed, 17 insertions(+), 87 deletions(-)

diff --git a/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp b/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
index f594f84f70..add1483bf8 100644
--- a/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
+++ b/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
@@ -41,10 +41,8 @@ Camera3IOStreamBase::Camera3IOStreamBase(int id, camera_stream_type_t type,
                 physicalCameraId, sensorPixelModesUsed, setId, isMultiResolution,
                 dynamicRangeProfile, streamUseCase, deviceTimeBaseIsRealtime, timestampBase),
         mTotalBufferCount(0),
-        mMaxCachedBufferCount(0),
         mHandoutTotalBufferCount(0),
         mHandoutOutputBufferCount(0),
-        mCachedOutputBufferCount(0),
         mFrameCount(0),
         mLastTimestamp(0) {
 
@@ -97,8 +95,8 @@ void Camera3IOStreamBase::dump(int fd, const Vector<String16> &args) const {
     lines.appendFormat("      Timestamp base: %d\n", getTimestampBase());
     lines.appendFormat("      Frames produced: %d, last timestamp: %" PRId64 " ns\n",
             mFrameCount, mLastTimestamp);
-    lines.appendFormat("      Total buffers: %zu, currently dequeued: %zu, currently cached: %zu\n",
-            mTotalBufferCount, mHandoutTotalBufferCount, mCachedOutputBufferCount);
+    lines.appendFormat("      Total buffers: %zu, currently dequeued: %zu\n",
+            mTotalBufferCount, mHandoutTotalBufferCount);
     write(fd, lines.string(), lines.size());
 
     Camera3Stream::dump(fd, args);
@@ -137,14 +135,6 @@ size_t Camera3IOStreamBase::getHandoutInputBufferCountLocked() {
     return (mHandoutTotalBufferCount - mHandoutOutputBufferCount);
 }
 
-size_t Camera3IOStreamBase::getCachedOutputBufferCountLocked() const {
-    return mCachedOutputBufferCount;
-}
-
-size_t Camera3IOStreamBase::getMaxCachedOutputBuffersLocked() const {
-    return mMaxCachedBufferCount;
-}
-
 status_t Camera3IOStreamBase::disconnectLocked() {
     switch (mState) {
         case STATE_IN_RECONFIG:
diff --git a/services/camera/libcameraservice/device3/Camera3IOStreamBase.h b/services/camera/libcameraservice/device3/Camera3IOStreamBase.h
index ca1f238de2..f389d53b16 100644
--- a/services/camera/libcameraservice/device3/Camera3IOStreamBase.h
+++ b/services/camera/libcameraservice/device3/Camera3IOStreamBase.h
@@ -56,18 +56,11 @@ class Camera3IOStreamBase :
     int              getMaxTotalBuffers() const { return mTotalBufferCount; }
   protected:
     size_t            mTotalBufferCount;
-    // The maximum number of cached buffers allowed for this stream
-    size_t            mMaxCachedBufferCount;
-
     // sum of input and output buffers that are currently acquired by HAL
     size_t            mHandoutTotalBufferCount;
     // number of output buffers that are currently acquired by HAL. This will be
     // Redundant when camera3 streams are no longer bidirectional streams.
     size_t            mHandoutOutputBufferCount;
-    // number of cached output buffers that are currently queued in the camera
-    // server but not yet queued to the buffer queue.
-    size_t            mCachedOutputBufferCount;
-
     uint32_t          mFrameCount;
     // Last received output buffer's timestamp
     nsecs_t           mLastTimestamp;
@@ -104,9 +97,6 @@ class Camera3IOStreamBase :
 
     virtual size_t   getHandoutInputBufferCountLocked();
 
-    virtual size_t   getCachedOutputBufferCountLocked() const;
-    virtual size_t   getMaxCachedOutputBuffersLocked() const;
-
     virtual status_t getEndpointUsage(uint64_t *usage) const = 0;
 
     status_t getBufferPreconditionCheckLocked() const;
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index b7ff1f0fa9..379a571137 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -419,7 +419,6 @@ status_t Camera3OutputStream::returnBufferCheckedLocked(
     mLock.unlock();
 
     ANativeWindowBuffer *anwBuffer = container_of(buffer.buffer, ANativeWindowBuffer, handle);
-    bool bufferDeferred = false;
     /**
      * Return buffer back to ANativeWindow
      */
@@ -479,7 +478,6 @@ status_t Camera3OutputStream::returnBufferCheckedLocked(
                         __FUNCTION__, mId, strerror(-res), res);
                 return res;
             }
-            bufferDeferred = true;
         } else {
             nsecs_t presentTime = mSyncToDisplay ?
                     syncTimestampToDisplayLocked(captureTime) : captureTime;
@@ -503,10 +501,6 @@ status_t Camera3OutputStream::returnBufferCheckedLocked(
     }
     mLock.lock();
 
-    if (bufferDeferred) {
-        mCachedOutputBufferCount++;
-    }
-
     // Once a valid buffer has been returned to the queue, can no longer
     // dequeue all buffers for preallocation.
     if (buffer.status != CAMERA_BUFFER_STATUS_ERROR) {
@@ -698,15 +692,10 @@ status_t Camera3OutputStream::configureConsumerQueueLocked(bool allowPreviewResp
                 !isVideoStream());
         if (forceChoreographer || defaultToChoreographer) {
             mSyncToDisplay = true;
-            // For choreographer synced stream, extra buffers aren't kept by
-            // camera service. So no need to update mMaxCachedBufferCount.
             mTotalBufferCount += kDisplaySyncExtraBuffer;
         } else if (defaultToSpacer) {
             mPreviewFrameSpacer = new PreviewFrameSpacer(this, mConsumer);
-            // For preview frame spacer, the extra buffer is kept by camera
-            // service. So update mMaxCachedBufferCount.
-            mMaxCachedBufferCount = 1;
-            mTotalBufferCount += mMaxCachedBufferCount;
+            mTotalBufferCount ++;
             res = mPreviewFrameSpacer->run(String8::format("PreviewSpacer-%d", mId).string());
             if (res != OK) {
                 ALOGE("%s: Unable to start preview spacer", __FUNCTION__);
@@ -975,14 +964,6 @@ bool Camera3OutputStream::shouldLogError(status_t res, StreamState state) {
     return true;
 }
 
-void Camera3OutputStream::onCachedBufferQueued() {
-    Mutex::Autolock l(mLock);
-    mCachedOutputBufferCount--;
-    // Signal whoever is waiting for the buffer to be returned to the buffer
-    // queue.
-    mOutputBufferReturnedSignal.signal();
-}
-
 status_t Camera3OutputStream::disconnectLocked() {
     status_t res;
 
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index 741bca2fa7..1b4739cf50 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -259,7 +259,6 @@ class Camera3OutputStream :
 
     void setImageDumpMask(int mask) { mImageDumpMask = mask; }
     bool shouldLogError(status_t res);
-    void onCachedBufferQueued();
 
   protected:
     Camera3OutputStream(int id, camera_stream_type_t type,
diff --git a/services/camera/libcameraservice/device3/Camera3Stream.cpp b/services/camera/libcameraservice/device3/Camera3Stream.cpp
index 88be9ff137..7ad6649754 100644
--- a/services/camera/libcameraservice/device3/Camera3Stream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3Stream.cpp
@@ -665,19 +665,11 @@ status_t Camera3Stream::getBuffer(camera_stream_buffer *buffer,
         }
     }
 
-    // Wait for new buffer returned back if we are running into the limit. There
-    // are 2 limits:
-    // 1. The number of HAL buffers is greater than max_buffers
-    // 2. The number of HAL buffers + cached buffers is greater than max_buffers
-    //    + maxCachedBuffers
+    // Wait for new buffer returned back if we are running into the limit.
     size_t numOutstandingBuffers = getHandoutOutputBufferCountLocked();
-    size_t numCachedBuffers = getCachedOutputBufferCountLocked();
-    size_t maxNumCachedBuffers = getMaxCachedOutputBuffersLocked();
-    while (numOutstandingBuffers == camera_stream::max_buffers ||
-            numOutstandingBuffers + numCachedBuffers ==
-            camera_stream::max_buffers + maxNumCachedBuffers) {
-        ALOGV("%s: Already dequeued max output buffers (%d(+%zu)), wait for next returned one.",
-                        __FUNCTION__, camera_stream::max_buffers, maxNumCachedBuffers);
+    if (numOutstandingBuffers == camera_stream::max_buffers) {
+        ALOGV("%s: Already dequeued max output buffers (%d), wait for next returned one.",
+                        __FUNCTION__, camera_stream::max_buffers);
         nsecs_t waitStart = systemTime(SYSTEM_TIME_MONOTONIC);
         if (waitBufferTimeout < kWaitForBufferDuration) {
             waitBufferTimeout = kWaitForBufferDuration;
@@ -695,16 +687,12 @@ status_t Camera3Stream::getBuffer(camera_stream_buffer *buffer,
         }
 
         size_t updatedNumOutstandingBuffers = getHandoutOutputBufferCountLocked();
-        size_t updatedNumCachedBuffers = getCachedOutputBufferCountLocked();
-        if (updatedNumOutstandingBuffers >= numOutstandingBuffers &&
-                updatedNumCachedBuffers == numCachedBuffers) {
-            ALOGE("%s: outstanding buffer count goes from %zu to %zu, "
+        if (updatedNumOutstandingBuffers >= numOutstandingBuffers) {
+            ALOGE("%s: outsanding buffer count goes from %zu to %zu, "
                     "getBuffer(s) call must not run in parallel!", __FUNCTION__,
                     numOutstandingBuffers, updatedNumOutstandingBuffers);
             return INVALID_OPERATION;
         }
-        numOutstandingBuffers = updatedNumOutstandingBuffers;
-        numCachedBuffers = updatedNumCachedBuffers;
     }
 
     res = getBufferLocked(buffer, surface_ids);
@@ -1069,20 +1057,11 @@ status_t Camera3Stream::getBuffers(std::vector<OutstandingBuffer>* buffers,
     }
 
     size_t numOutstandingBuffers = getHandoutOutputBufferCountLocked();
-    size_t numCachedBuffers = getCachedOutputBufferCountLocked();
-    size_t maxNumCachedBuffers = getMaxCachedOutputBuffersLocked();
-    // Wait for new buffer returned back if we are running into the limit. There
-    // are 2 limits:
-    // 1. The number of HAL buffers is greater than max_buffers
-    // 2. The number of HAL buffers + cached buffers is greater than max_buffers
-    //    + maxCachedBuffers
-    while (numOutstandingBuffers + numBuffersRequested > camera_stream::max_buffers ||
-            numOutstandingBuffers + numCachedBuffers + numBuffersRequested >
-            camera_stream::max_buffers + maxNumCachedBuffers) {
-        ALOGV("%s: Already dequeued %zu(+%zu) output buffers and requesting %zu "
-                "(max is %d(+%zu)), waiting.", __FUNCTION__, numOutstandingBuffers,
-                numCachedBuffers, numBuffersRequested, camera_stream::max_buffers,
-                maxNumCachedBuffers);
+    // Wait for new buffer returned back if we are running into the limit.
+    while (numOutstandingBuffers + numBuffersRequested > camera_stream::max_buffers) {
+        ALOGV("%s: Already dequeued %zu output buffers and requesting %zu (max is %d), waiting.",
+                __FUNCTION__, numOutstandingBuffers, numBuffersRequested,
+                camera_stream::max_buffers);
         nsecs_t waitStart = systemTime(SYSTEM_TIME_MONOTONIC);
         if (waitBufferTimeout < kWaitForBufferDuration) {
             waitBufferTimeout = kWaitForBufferDuration;
@@ -1099,16 +1078,13 @@ status_t Camera3Stream::getBuffers(std::vector<OutstandingBuffer>* buffers,
             return res;
         }
         size_t updatedNumOutstandingBuffers = getHandoutOutputBufferCountLocked();
-        size_t updatedNumCachedBuffers = getCachedOutputBufferCountLocked();
-        if (updatedNumOutstandingBuffers >= numOutstandingBuffers &&
-                updatedNumCachedBuffers == numCachedBuffers) {
-            ALOGE("%s: outstanding buffer count goes from %zu to %zu, "
+        if (updatedNumOutstandingBuffers >= numOutstandingBuffers) {
+            ALOGE("%s: outsanding buffer count goes from %zu to %zu, "
                     "getBuffer(s) call must not run in parallel!", __FUNCTION__,
                     numOutstandingBuffers, updatedNumOutstandingBuffers);
             return INVALID_OPERATION;
         }
         numOutstandingBuffers = updatedNumOutstandingBuffers;
-        numCachedBuffers = updatedNumCachedBuffers;
     }
 
     res = getBuffersLocked(buffers);
diff --git a/services/camera/libcameraservice/device3/Camera3Stream.h b/services/camera/libcameraservice/device3/Camera3Stream.h
index 214618a172..d429e6caa8 100644
--- a/services/camera/libcameraservice/device3/Camera3Stream.h
+++ b/services/camera/libcameraservice/device3/Camera3Stream.h
@@ -558,10 +558,6 @@ class Camera3Stream :
     // Get handout input buffer count.
     virtual size_t   getHandoutInputBufferCountLocked() = 0;
 
-    // Get cached output buffer count.
-    virtual size_t   getCachedOutputBufferCountLocked() const = 0;
-    virtual size_t   getMaxCachedOutputBuffersLocked() const = 0;
-
     // Get the usage flags for the other endpoint, or return
     // INVALID_OPERATION if they cannot be obtained.
     virtual status_t getEndpointUsage(uint64_t *usage) const = 0;
@@ -580,8 +576,6 @@ class Camera3Stream :
 
     uint64_t mUsage;
 
-    Condition mOutputBufferReturnedSignal;
-
   private:
     // Previously configured stream properties (post HAL override)
     uint64_t mOldUsage;
@@ -589,6 +583,7 @@ class Camera3Stream :
     int mOldFormat;
     android_dataspace mOldDataSpace;
 
+    Condition mOutputBufferReturnedSignal;
     Condition mInputBufferReturnedSignal;
     static const nsecs_t kWaitForBufferDuration = 3000000000LL; // 3000 ms
 
diff --git a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
index 67f42b45e3..0439501733 100644
--- a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
+++ b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
@@ -122,7 +122,6 @@ void PreviewFrameSpacer::queueBufferToClientLocked(
         }
     }
 
-    parent->onCachedBufferQueued();
     mLastCameraPresentTime = currentTime;
     mLastCameraReadoutTime = bufferHolder.readoutTimestamp;
 }
-- 
2.38.1.windows.1


From cb155ec7fe17bd2311d47b6d7db32c2a33182737 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 13:07:12 +0000
Subject: [PATCH 07/11] Revert "Camera: Avoid latency accumulation when syncing
 preview to vsync"

This reverts commit 696e4da718391c11b5742369dfa12d4a65900520.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/Camera3Device.cpp                 |  40 +++----
 .../libcameraservice/device3/Camera3Device.h  |  14 +--
 .../device3/Camera3FakeStream.h               |   2 +-
 .../device3/Camera3OfflineSession.h           |   3 -
 .../device3/Camera3OutputStream.cpp           | 112 +++---------------
 .../device3/Camera3OutputStream.h             |   6 +-
 .../device3/Camera3OutputStreamInterface.h    |   5 +-
 .../device3/Camera3OutputUtils.cpp            |   6 +-
 .../device3/Camera3OutputUtils.h              |   1 -
 .../device3/InFlightRequest.h                 |   7 +-
 .../device3/aidl/AidlCamera3Device.cpp        |   6 +-
 .../aidl/AidlCamera3OfflineSession.cpp        |   6 +-
 .../device3/hidl/HidlCamera3Device.cpp        |   6 +-
 .../hidl/HidlCamera3OfflineSession.cpp        |   9 +-
 14 files changed, 56 insertions(+), 167 deletions(-)

diff --git a/services/camera/libcameraservice/device3/Camera3Device.cpp b/services/camera/libcameraservice/device3/Camera3Device.cpp
index 7542197170..67f2a32ac7 100644
--- a/services/camera/libcameraservice/device3/Camera3Device.cpp
+++ b/services/camera/libcameraservice/device3/Camera3Device.cpp
@@ -2679,7 +2679,7 @@ void Camera3Device::setErrorStateLockedV(const char *fmt, va_list args) {
 status_t Camera3Device::registerInFlight(uint32_t frameNumber,
         int32_t numBuffers, CaptureResultExtras resultExtras, bool hasInput,
         bool hasAppCallback, nsecs_t minExpectedDuration, nsecs_t maxExpectedDuration,
-        bool isFixedFps, const std::set<std::set<String8>>& physicalCameraIds,
+        const std::set<std::set<String8>>& physicalCameraIds,
         bool isStillCapture, bool isZslCapture, bool rotateAndCropAuto,
         const std::set<std::string>& cameraIdsWithZoom,
         const SurfaceMap& outputSurfaces, nsecs_t requestTimeNs) {
@@ -2688,7 +2688,7 @@ status_t Camera3Device::registerInFlight(uint32_t frameNumber,
 
     ssize_t res;
     res = mInFlightMap.add(frameNumber, InFlightRequest(numBuffers, resultExtras, hasInput,
-            hasAppCallback, minExpectedDuration, maxExpectedDuration, isFixedFps, physicalCameraIds,
+            hasAppCallback, minExpectedDuration, maxExpectedDuration, physicalCameraIds,
             isStillCapture, isZslCapture, rotateAndCropAuto, cameraIdsWithZoom, requestTimeNs,
             outputSurfaces));
     if (res < 0) return res;
@@ -3254,18 +3254,16 @@ bool Camera3Device::RequestThread::sendRequestsBatch() {
     return true;
 }
 
-Camera3Device::RequestThread::ExpectedDurationInfo
-        Camera3Device::RequestThread::calculateExpectedDurationRange(
-                const camera_metadata_t *request) {
-    ExpectedDurationInfo expectedDurationInfo = {
+std::pair<nsecs_t, nsecs_t> Camera3Device::RequestThread::calculateExpectedDurationRange(
+        const camera_metadata_t *request) {
+    std::pair<nsecs_t, nsecs_t> expectedRange(
             InFlightRequest::kDefaultMinExpectedDuration,
-            InFlightRequest::kDefaultMaxExpectedDuration,
-            /*isFixedFps*/false};
+            InFlightRequest::kDefaultMaxExpectedDuration);
     camera_metadata_ro_entry_t e = camera_metadata_ro_entry_t();
     find_camera_metadata_ro_entry(request,
             ANDROID_CONTROL_AE_MODE,
             &e);
-    if (e.count == 0) return expectedDurationInfo;
+    if (e.count == 0) return expectedRange;
 
     switch (e.data.u8[0]) {
         case ANDROID_CONTROL_AE_MODE_OFF:
@@ -3273,32 +3271,29 @@ Camera3Device::RequestThread::ExpectedDurationInfo
                     ANDROID_SENSOR_EXPOSURE_TIME,
                     &e);
             if (e.count > 0) {
-                expectedDurationInfo.minDuration = e.data.i64[0];
-                expectedDurationInfo.maxDuration = expectedDurationInfo.minDuration;
+                expectedRange.first = e.data.i64[0];
+                expectedRange.second = expectedRange.first;
             }
             find_camera_metadata_ro_entry(request,
                     ANDROID_SENSOR_FRAME_DURATION,
                     &e);
             if (e.count > 0) {
-                expectedDurationInfo.minDuration =
-                        std::max(e.data.i64[0], expectedDurationInfo.minDuration);
-                expectedDurationInfo.maxDuration = expectedDurationInfo.minDuration;
+                expectedRange.first = std::max(e.data.i64[0], expectedRange.first);
+                expectedRange.second = expectedRange.first;
             }
-            expectedDurationInfo.isFixedFps = false;
             break;
         default:
             find_camera_metadata_ro_entry(request,
                     ANDROID_CONTROL_AE_TARGET_FPS_RANGE,
                     &e);
             if (e.count > 1) {
-                expectedDurationInfo.minDuration = 1e9 / e.data.i32[1];
-                expectedDurationInfo.maxDuration = 1e9 / e.data.i32[0];
+                expectedRange.first = 1e9 / e.data.i32[1];
+                expectedRange.second = 1e9 / e.data.i32[0];
             }
-            expectedDurationInfo.isFixedFps = (e.data.i32[1] == e.data.i32[0]);
             break;
     }
 
-    return expectedDurationInfo;
+    return expectedRange;
 }
 
 bool Camera3Device::RequestThread::skipHFRTargetFPSUpdate(int32_t tag,
@@ -3913,14 +3908,13 @@ status_t Camera3Device::RequestThread::prepareHalRequests() {
                 isZslCapture = true;
             }
         }
-        auto expectedDurationInfo = calculateExpectedDurationRange(settings);
+        auto expectedDurationRange = calculateExpectedDurationRange(settings);
         res = parent->registerInFlight(halRequest->frame_number,
                 totalNumBuffers, captureRequest->mResultExtras,
                 /*hasInput*/halRequest->input_buffer != NULL,
                 hasCallback,
-                expectedDurationInfo.minDuration,
-                expectedDurationInfo.maxDuration,
-                expectedDurationInfo.isFixedFps,
+                /*min*/expectedDurationRange.first,
+                /*max*/expectedDurationRange.second,
                 requestedPhysicalCameras, isStillCapture, isZslCapture,
                 captureRequest->mRotateAndCropAuto, mPrevCameraIdsWithZoom,
                 (mUseHalBufManager) ? uniqueSurfaceIdMap :
diff --git a/services/camera/libcameraservice/device3/Camera3Device.h b/services/camera/libcameraservice/device3/Camera3Device.h
index bcb76954d0..3c5cb78f6c 100644
--- a/services/camera/libcameraservice/device3/Camera3Device.h
+++ b/services/camera/libcameraservice/device3/Camera3Device.h
@@ -967,13 +967,8 @@ class Camera3Device :
         // send request in mNextRequests to HAL in a batch. Return true = sucssess
         bool sendRequestsBatch();
 
-        // Calculate the expected (minimum, maximum, isFixedFps) duration info for a request
-        struct ExpectedDurationInfo {
-            nsecs_t minDuration;
-            nsecs_t maxDuration;
-            bool isFixedFps;
-        };
-        ExpectedDurationInfo calculateExpectedDurationRange(
+        // Calculate the expected (minimum, maximum) duration range for a request
+        std::pair<nsecs_t, nsecs_t> calculateExpectedDurationRange(
                 const camera_metadata_t *request);
 
         // Check and update latest session parameters based on the current request settings.
@@ -1092,7 +1087,7 @@ class Camera3Device :
     status_t registerInFlight(uint32_t frameNumber,
             int32_t numBuffers, CaptureResultExtras resultExtras, bool hasInput,
             bool callback, nsecs_t minExpectedDuration, nsecs_t maxExpectedDuration,
-            bool isFixedFps, const std::set<std::set<String8>>& physicalCameraIds,
+            const std::set<std::set<String8>>& physicalCameraIds,
             bool isStillCapture, bool isZslCapture, bool rotateAndCropAuto,
             const std::set<std::string>& cameraIdsWithZoom, const SurfaceMap& outputSurfaces,
             nsecs_t requestTimeNs);
@@ -1344,9 +1339,6 @@ class Camera3Device :
 
     // The current minimum expected frame duration based on AE_TARGET_FPS_RANGE
     nsecs_t mMinExpectedDuration = 0;
-    // Whether the camera device runs at fixed frame rate based on AE_MODE and
-    // AE_TARGET_FPS_RANGE
-    bool mIsFixedFps = false;
 
     // Injection camera related methods.
     class Camera3DeviceInjectionMethods : public virtual RefBase {
diff --git a/services/camera/libcameraservice/device3/Camera3FakeStream.h b/services/camera/libcameraservice/device3/Camera3FakeStream.h
index a93d1da759..8cecabd861 100644
--- a/services/camera/libcameraservice/device3/Camera3FakeStream.h
+++ b/services/camera/libcameraservice/device3/Camera3FakeStream.h
@@ -100,7 +100,7 @@ class Camera3FakeStream :
 
     virtual status_t setBatchSize(size_t batchSize) override;
 
-    virtual void onMinDurationChanged(nsecs_t /*duration*/, bool /*fixedFps*/) {}
+    virtual void onMinDurationChanged(nsecs_t /*duration*/) {}
   protected:
 
     /**
diff --git a/services/camera/libcameraservice/device3/Camera3OfflineSession.h b/services/camera/libcameraservice/device3/Camera3OfflineSession.h
index 5ee6ca58a9..a7997198e1 100644
--- a/services/camera/libcameraservice/device3/Camera3OfflineSession.h
+++ b/services/camera/libcameraservice/device3/Camera3OfflineSession.h
@@ -248,9 +248,6 @@ class Camera3OfflineSession :
 
     // The current minimum expected frame duration based on AE_TARGET_FPS_RANGE
     nsecs_t mMinExpectedDuration = 0;
-    // Whether the camera device runs at fixed frame rate based on AE_MODE and
-    // AE_TARGET_FPS_RANGE
-    bool mIsFixedFps = false;
 
     // SetErrorInterface
     void setErrorState(const char *fmt, ...) override;
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index 379a571137..8371a6e712 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -1363,10 +1363,9 @@ status_t Camera3OutputStream::setBatchSize(size_t batchSize) {
     return OK;
 }
 
-void Camera3OutputStream::onMinDurationChanged(nsecs_t duration, bool fixedFps) {
+void Camera3OutputStream::onMinDurationChanged(nsecs_t duration) {
     Mutex::Autolock l(mLock);
     mMinExpectedDuration = duration;
-    mFixedFps = fixedFps;
 }
 
 void Camera3OutputStream::returnPrefetchedBuffersLocked() {
@@ -1399,21 +1398,17 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
 
     const VsyncEventData& vsyncEventData = parcelableVsyncEventData.vsync;
     nsecs_t currentTime = systemTime();
-    nsecs_t minPresentT = mLastPresentTime + vsyncEventData.frameInterval / 2;
-
-    // Find the best presentation time without worrying about previous frame's
-    // presentation time if capture interval is more than kSpacingResetIntervalNs.
-    //
-    // When frame interval is more than 50 ms apart (3 vsyncs for 60hz refresh rate),
-    // there is little risk in starting over and finding the earliest vsync to latch onto.
-    // - Update captureToPresentTime offset to be used for later frames.
-    // - Example use cases:
-    //   - when frame rate drops down to below 20 fps, or
-    //   - A new streaming session starts (stopPreview followed by
-    //   startPreview)
-    //
+
+    // Reset capture to present time offset if:
+    // - More than 1 second between frames.
+    // - The frame duration deviates from multiples of vsync frame intervals.
     nsecs_t captureInterval = t - mLastCaptureTime;
-    if (captureInterval > kSpacingResetIntervalNs) {
+    float captureToVsyncIntervalRatio = 1.0f * captureInterval / vsyncEventData.frameInterval;
+    float ratioDeviation = std::fabs(
+            captureToVsyncIntervalRatio - std::roundf(captureToVsyncIntervalRatio));
+    if (captureInterval > kSpacingResetIntervalNs ||
+            ratioDeviation >= kMaxIntervalRatioDeviation) {
+        nsecs_t minPresentT = mLastPresentTime + vsyncEventData.frameInterval / 2;
         for (size_t i = 0; i < VsyncEventData::kFrameTimelinesLength; i++) {
             const auto& timeline = vsyncEventData.frameTimelines[i];
             if (timeline.deadlineTimestamp >= currentTime &&
@@ -1435,54 +1430,21 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
     nsecs_t idealPresentT = t + mCaptureToPresentOffset;
     nsecs_t expectedPresentT = mLastPresentTime;
     nsecs_t minDiff = INT64_MAX;
-
-    // In fixed FPS case, when frame durations are close to multiples of display refresh
-    // rate, derive minimum intervals between presentation times based on minimal
+    // Derive minimum intervals between presentation times based on minimal
     // expected duration. The minimum number of Vsyncs is:
     // - 0 if minFrameDuration in (0, 1.5] * vSyncInterval,
     // - 1 if minFrameDuration in (1.5, 2.5] * vSyncInterval,
     // - and so on.
-    //
-    // This spaces out the displaying of the frames so that the frame
-    // presentations are roughly in sync with frame captures.
     int minVsyncs = (mMinExpectedDuration - vsyncEventData.frameInterval / 2) /
             vsyncEventData.frameInterval;
     if (minVsyncs < 0) minVsyncs = 0;
     nsecs_t minInterval = minVsyncs * vsyncEventData.frameInterval;
-
-    // In fixed FPS case, if the frame duration deviates from multiples of
-    // display refresh rate, find the closest Vsync without requiring a minimum
-    // number of Vsync.
-    //
-    // Example: (24fps camera, 60hz refresh):
-    //   capture readout:  |  t1  |  t1  | .. |  t1  | .. |  t1  | .. |  t1  |
-    //   display VSYNC:      | t2 | t2 | ... | t2 | ... | t2 | ... | t2 |
-    //   |  : 1 frame
-    //   t1 : 41.67ms
-    //   t2 : 16.67ms
-    //   t1/t2 = 2.5
-    //
-    //   24fps is a commonly used video frame rate. Because the capture
-    //   interval is 2.5 times of display refresh interval, the minVsyncs
-    //   calculation will directly fall at the boundary condition. In this case,
-    //   we should fall back to the basic logic of finding closest vsync
-    //   timestamp without worrying about minVsyncs.
-    float captureToVsyncIntervalRatio = 1.0f * mMinExpectedDuration / vsyncEventData.frameInterval;
-    float ratioDeviation = std::fabs(
-            captureToVsyncIntervalRatio - std::roundf(captureToVsyncIntervalRatio));
-    bool captureDeviateFromVsync = ratioDeviation >= kMaxIntervalRatioDeviation;
-    bool cameraDisplayInSync = (mFixedFps && !captureDeviateFromVsync);
-
     // Find best timestamp in the vsync timelines:
-    // - Only use at most kMaxTimelines timelines to avoid long latency
-    // - closest to the ideal presentation time,
+    // - Only use at most 3 timelines to avoid long latency
+    // - closest to the ideal present time,
     // - deadline timestamp is greater than the current time, and
-    // - For fixed FPS, if the capture interval doesn't deviate too much from refresh interval,
-    //   the candidate presentation time is at least minInterval in the future compared to last
-    //   presentation time.
-    // - For variable FPS, or if the capture interval deviates from refresh
-    //   interval for more than 5%, find a presentation time closest to the
-    //   (lastPresentationTime + captureToPresentOffset) instead.
+    // - the candidate present time is at least minInterval in the future
+    //   compared to last present time.
     int maxTimelines = std::min(kMaxTimelines, (int)VsyncEventData::kFrameTimelinesLength);
     float biasForShortDelay = 1.0f;
     for (int i = 0; i < maxTimelines; i ++) {
@@ -1495,50 +1457,12 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
         }
         if (std::abs(vsyncTime.expectedPresentationTime - idealPresentT) < minDiff &&
                 vsyncTime.deadlineTimestamp >= currentTime &&
-                ((!cameraDisplayInSync && vsyncTime.expectedPresentationTime > minPresentT) ||
-                 (cameraDisplayInSync && vsyncTime.expectedPresentationTime >
-                mLastPresentTime + minInterval + biasForShortDelay * kTimelineThresholdNs))) {
+                vsyncTime.expectedPresentationTime >
+                mLastPresentTime + minInterval + biasForShortDelay * kTimelineThresholdNs) {
             expectedPresentT = vsyncTime.expectedPresentationTime;
             minDiff = std::abs(vsyncTime.expectedPresentationTime - idealPresentT);
         }
     }
-
-    if (expectedPresentT == mLastPresentTime && expectedPresentT <=
-            vsyncEventData.frameTimelines[maxTimelines].expectedPresentationTime) {
-        // Couldn't find a reasonable presentation time. Using last frame's
-        // presentation time would cause a frame drop. The best option now
-        // is to use the next VSync as long as the last presentation time
-        // doesn't already has the maximum latency, in which case dropping the
-        // buffer is more desired than increasing latency.
-        //
-        // Example: (60fps camera, 59.9hz refresh):
-        //   capture readout:  | t1 | t1 | .. | t1 | .. | t1 | .. | t1 |
-        //                      \    \    \     \    \    \    \     \   \
-        //   queue to BQ:       |    |    |     |    |    |    |      |    |
-        //                      \    \    \     \    \     \    \      \    \
-        //   display VSYNC:      | t2 | t2 | ... | t2 | ... | t2 | ... | t2 |
-        //
-        //   |: 1 frame
-        //   t1 : 16.67ms
-        //   t2 : 16.69ms
-        //
-        // It takes 833 frames for capture readout count and display VSYNC count to be off
-        // by 1.
-        //  - At frames [0, 832], presentationTime is set to timeline[0]
-        //  - At frames [833, 833*2-1], presentationTime is set to timeline[1]
-        //  - At frames [833*2, 833*3-1] presentationTime is set to timeline[2]
-        //  - At frame 833*3, no presentation time is found because we only
-        //    search for timeline[0..2].
-        //  - Drop one buffer is better than further extend the presentation
-        //    time.
-        //
-        // However, if frame 833*2 arrives 16.67ms early (right after frame
-        // 833*2-1), no presentation time can be found because
-        // getLatestVsyncEventData is called early. In that case, it's better to
-        // set presentation time by offseting last presentation time.
-        expectedPresentT += vsyncEventData.frameInterval;
-    }
-
     mLastCaptureTime = t;
     mLastPresentTime = expectedPresentT;
 
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index 1b4739cf50..3587af4349 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -247,10 +247,9 @@ class Camera3OutputStream :
     virtual status_t setBatchSize(size_t batchSize = 1) override;
 
     /**
-     * Notify the stream on change of min frame durations or variable/fixed
-     * frame rate.
+     * Notify the stream on change of min frame durations.
      */
-    virtual void onMinDurationChanged(nsecs_t duration, bool fixedFps) override;
+    virtual void onMinDurationChanged(nsecs_t duration) override;
 
     /**
      * Apply ZSL related consumer usage quirk.
@@ -420,7 +419,6 @@ class Camera3OutputStream :
 
     // Re-space frames by overriding timestamp to align with display Vsync.
     // Default is on for SurfaceView bound streams.
-    bool    mFixedFps = false;
     nsecs_t mMinExpectedDuration = 0;
     bool mSyncToDisplay = false;
     DisplayEventReceiver mDisplayEventReceiver;
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStreamInterface.h b/services/camera/libcameraservice/device3/Camera3OutputStreamInterface.h
index dbc6fe1514..a6d4b96c7f 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStreamInterface.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStreamInterface.h
@@ -110,13 +110,12 @@ class Camera3OutputStreamInterface : public virtual Camera3StreamInterface {
     virtual status_t setBatchSize(size_t batchSize = 1) = 0;
 
     /**
-     * Notify the output stream that the minimum frame duration has changed, or
-     * frame rate has switched between variable and fixed.
+     * Notify the output stream that the minimum frame duration has changed.
      *
      * The minimum frame duration is calculated based on the upper bound of
      * AE_TARGET_FPS_RANGE in the capture request.
      */
-    virtual void onMinDurationChanged(nsecs_t duration, bool fixedFps) = 0;
+    virtual void onMinDurationChanged(nsecs_t duration) = 0;
 };
 
 // Helper class to organize a synchronized mapping of stream IDs to stream instances
diff --git a/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp b/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
index e16982b3ff..f4e3fad468 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
@@ -858,14 +858,12 @@ void notifyShutter(CaptureOutputStates& states, const camera_shutter_msg_t &msg)
                 r.resultExtras.hasReadoutTimestamp = true;
                 r.resultExtras.readoutTimestamp = msg.readout_timestamp;
             }
-            if (r.minExpectedDuration != states.minFrameDuration ||
-                    r.isFixedFps != states.isFixedFps) {
+            if (r.minExpectedDuration != states.minFrameDuration) {
                 for (size_t i = 0; i < states.outputStreams.size(); i++) {
                     auto outputStream = states.outputStreams[i];
-                    outputStream->onMinDurationChanged(r.minExpectedDuration, r.isFixedFps);
+                    outputStream->onMinDurationChanged(r.minExpectedDuration);
                 }
                 states.minFrameDuration = r.minExpectedDuration;
-                states.isFixedFps = r.isFixedFps;
             }
             if (r.hasCallback) {
                 ALOGVV("Camera %s: %s: Shutter fired for frame %d (id %d) at %" PRId64,
diff --git a/services/camera/libcameraservice/device3/Camera3OutputUtils.h b/services/camera/libcameraservice/device3/Camera3OutputUtils.h
index 8c71c2b64b..d6107c28e4 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputUtils.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputUtils.h
@@ -106,7 +106,6 @@ namespace camera3 {
         BufferRecordsInterface& bufferRecordsIntf;
         bool legacyClient;
         nsecs_t& minFrameDuration;
-        bool& isFixedFps;
     };
 
     void processCaptureResult(CaptureOutputStates& states, const camera_capture_result *result);
diff --git a/services/camera/libcameraservice/device3/InFlightRequest.h b/services/camera/libcameraservice/device3/InFlightRequest.h
index 444445bed9..fa0049510f 100644
--- a/services/camera/libcameraservice/device3/InFlightRequest.h
+++ b/services/camera/libcameraservice/device3/InFlightRequest.h
@@ -152,9 +152,6 @@ struct InFlightRequest {
     // For auto-exposure modes, equal to 1/(lower end of target FPS range)
     nsecs_t maxExpectedDuration;
 
-    // Whether the FPS range is fixed, aka, minFps == maxFps
-    bool isFixedFps;
-
     // Whether the result metadata for this request is to be skipped. The
     // result metadata should be skipped in the case of
     // REQUEST/RESULT error.
@@ -208,7 +205,6 @@ struct InFlightRequest {
             hasCallback(true),
             minExpectedDuration(kDefaultMinExpectedDuration),
             maxExpectedDuration(kDefaultMaxExpectedDuration),
-            isFixedFps(false),
             skipResultMetadata(false),
             errorBufStrategy(ERROR_BUF_CACHE),
             stillCapture(false),
@@ -219,7 +215,7 @@ struct InFlightRequest {
     }
 
     InFlightRequest(int numBuffers, CaptureResultExtras extras, bool hasInput,
-            bool hasAppCallback, nsecs_t minDuration, nsecs_t maxDuration, bool fixedFps,
+            bool hasAppCallback, nsecs_t minDuration, nsecs_t maxDuration,
             const std::set<std::set<String8>>& physicalCameraIdSet, bool isStillCapture,
             bool isZslCapture, bool rotateAndCropAuto, const std::set<std::string>& idsWithZoom,
             nsecs_t requestNs, const SurfaceMap& outSurfaces = SurfaceMap{}) :
@@ -233,7 +229,6 @@ struct InFlightRequest {
             hasCallback(hasAppCallback),
             minExpectedDuration(minDuration),
             maxExpectedDuration(maxDuration),
-            isFixedFps(fixedFps),
             skipResultMetadata(false),
             errorBufStrategy(ERROR_BUF_CACHE),
             physicalCameraIds(physicalCameraIdSet),
diff --git a/services/camera/libcameraservice/device3/aidl/AidlCamera3Device.cpp b/services/camera/libcameraservice/device3/aidl/AidlCamera3Device.cpp
index ec28d317b4..c5d81df14a 100644
--- a/services/camera/libcameraservice/device3/aidl/AidlCamera3Device.cpp
+++ b/services/camera/libcameraservice/device3/aidl/AidlCamera3Device.cpp
@@ -372,8 +372,7 @@ status_t AidlCamera3Device::initialize(sp<CameraProviderManager> manager,
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this,
-        *this, *(mInterface), mLegacyClient, mMinExpectedDuration, mIsFixedFps},
-        mResultMetadataQueue
+        *this, *(mInterface), mLegacyClient, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     for (const auto& result : results) {
@@ -414,8 +413,7 @@ status_t AidlCamera3Device::initialize(sp<CameraProviderManager> manager,
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this,
-        *this, *(mInterface), mLegacyClient, mMinExpectedDuration, mIsFixedFps},
-        mResultMetadataQueue
+        *this, *(mInterface), mLegacyClient, mMinExpectedDuration}, mResultMetadataQueue
     };
     for (const auto& msg : msgs) {
         camera3::notify(states, msg);
diff --git a/services/camera/libcameraservice/device3/aidl/AidlCamera3OfflineSession.cpp b/services/camera/libcameraservice/device3/aidl/AidlCamera3OfflineSession.cpp
index 8ff0b0725e..8d4b20f237 100644
--- a/services/camera/libcameraservice/device3/aidl/AidlCamera3OfflineSession.cpp
+++ b/services/camera/libcameraservice/device3/aidl/AidlCamera3OfflineSession.cpp
@@ -124,8 +124,7 @@ status_t AidlCamera3OfflineSession::initialize(wp<NotificationListener> listener
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this,
-        *this, mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration, mIsFixedFps},
-      mResultMetadataQueue
+        *this, mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     std::lock_guard<std::mutex> lock(mProcessCaptureResultLock);
@@ -170,8 +169,7 @@ status_t AidlCamera3OfflineSession::initialize(wp<NotificationListener> listener
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this,
-        *this, mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration, mIsFixedFps},
-      mResultMetadataQueue
+        *this, mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration}, mResultMetadataQueue
     };
     for (const auto& msg : msgs) {
         camera3::notify(states, msg);
diff --git a/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp b/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
index 8b1870adca..7431c9e4f5 100644
--- a/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
+++ b/services/camera/libcameraservice/device3/hidl/HidlCamera3Device.cpp
@@ -375,7 +375,7 @@ hardware::Return<void> HidlCamera3Device::processCaptureResult_3_4(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        *mInterface, mLegacyClient, mMinExpectedDuration, mIsFixedFps}, mResultMetadataQueue
+        *mInterface, mLegacyClient, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     //HidlCaptureOutputStates hidlStates {
@@ -437,7 +437,7 @@ hardware::Return<void> HidlCamera3Device::processCaptureResult(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        *mInterface, mLegacyClient, mMinExpectedDuration, mIsFixedFps}, mResultMetadataQueue
+        *mInterface, mLegacyClient, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     for (const auto& result : results) {
@@ -484,7 +484,7 @@ hardware::Return<void> HidlCamera3Device::notifyHelper(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        *mInterface, mLegacyClient, mMinExpectedDuration, mIsFixedFps}, mResultMetadataQueue
+        *mInterface, mLegacyClient, mMinExpectedDuration}, mResultMetadataQueue
     };
     for (const auto& msg : msgs) {
         camera3::notify(states, msg);
diff --git a/services/camera/libcameraservice/device3/hidl/HidlCamera3OfflineSession.cpp b/services/camera/libcameraservice/device3/hidl/HidlCamera3OfflineSession.cpp
index 2b4f8a1155..5c97f0eb82 100644
--- a/services/camera/libcameraservice/device3/hidl/HidlCamera3OfflineSession.cpp
+++ b/services/camera/libcameraservice/device3/hidl/HidlCamera3OfflineSession.cpp
@@ -105,8 +105,7 @@ hardware::Return<void> HidlCamera3OfflineSession::processCaptureResult_3_4(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration, mIsFixedFps},
-      mResultMetadataQueue
+        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     std::lock_guard<std::mutex> lock(mProcessCaptureResultLock);
@@ -146,8 +145,7 @@ hardware::Return<void> HidlCamera3OfflineSession::processCaptureResult(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration, mIsFixedFps},
-      mResultMetadataQueue
+        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration}, mResultMetadataQueue
     };
 
     std::lock_guard<std::mutex> lock(mProcessCaptureResultLock);
@@ -182,8 +180,7 @@ hardware::Return<void> HidlCamera3OfflineSession::notify(
         mNumPartialResults, mVendorTagId, mDeviceInfo, mPhysicalDeviceInfoMap,
         mDistortionMappers, mZoomRatioMappers, mRotateAndCropMappers,
         mTagMonitor, mInputStream, mOutputStreams, mSessionStatsBuilder, listener, *this, *this,
-        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration, mIsFixedFps},
-      mResultMetadataQueue
+        mBufferRecords, /*legacyClient*/ false, mMinExpectedDuration}, mResultMetadataQueue
     };
     for (const auto& msg : msgs) {
         camera3::notify(states, msg);
-- 
2.38.1.windows.1


From d8526580effee62aa33c096b19a66a0ef0813821 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 13:07:30 +0000
Subject: [PATCH 08/11] Revert "Camera: reset presentation timestamp more
 aggressively"

This reverts commit ed08fbe1381f2de16c6ef4247436610443c5a2ed.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/Camera3OutputStream.cpp           | 19 ++++---------------
 .../device3/Camera3OutputStream.h             |  3 +--
 2 files changed, 5 insertions(+), 17 deletions(-)

diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index 8371a6e712..7d0230469e 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -1438,27 +1438,16 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
     int minVsyncs = (mMinExpectedDuration - vsyncEventData.frameInterval / 2) /
             vsyncEventData.frameInterval;
     if (minVsyncs < 0) minVsyncs = 0;
-    nsecs_t minInterval = minVsyncs * vsyncEventData.frameInterval;
-    // Find best timestamp in the vsync timelines:
-    // - Only use at most 3 timelines to avoid long latency
+    nsecs_t minInterval = minVsyncs * vsyncEventData.frameInterval + kTimelineThresholdNs;
+    // Find best timestamp in the vsync timeline:
     // - closest to the ideal present time,
     // - deadline timestamp is greater than the current time, and
     // - the candidate present time is at least minInterval in the future
     //   compared to last present time.
-    int maxTimelines = std::min(kMaxTimelines, (int)VsyncEventData::kFrameTimelinesLength);
-    float biasForShortDelay = 1.0f;
-    for (int i = 0; i < maxTimelines; i ++) {
-        const auto& vsyncTime = vsyncEventData.frameTimelines[i];
-        if (minVsyncs > 0) {
-            // Bias towards using smaller timeline index:
-            //   i = 0:                bias = 1
-            //   i = maxTimelines-1:   bias = -1
-            biasForShortDelay = 1.0 - 2.0 * i / (maxTimelines - 1);
-        }
+    for (const auto& vsyncTime : vsyncEventData.frameTimelines) {
         if (std::abs(vsyncTime.expectedPresentationTime - idealPresentT) < minDiff &&
                 vsyncTime.deadlineTimestamp >= currentTime &&
-                vsyncTime.expectedPresentationTime >
-                mLastPresentTime + minInterval + biasForShortDelay * kTimelineThresholdNs) {
+                vsyncTime.expectedPresentationTime > mLastPresentTime + minInterval) {
             expectedPresentT = vsyncTime.expectedPresentationTime;
             minDiff = std::abs(vsyncTime.expectedPresentationTime - idealPresentT);
         }
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index 3587af4349..826f7ce468 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -426,10 +426,9 @@ class Camera3OutputStream :
     nsecs_t mLastPresentTime = 0;
     nsecs_t mCaptureToPresentOffset = 0;
     static constexpr size_t kDisplaySyncExtraBuffer = 2;
-    static constexpr nsecs_t kSpacingResetIntervalNs = 50000000LL; // 50 millisecond
+    static constexpr nsecs_t kSpacingResetIntervalNs = 1000000000LL; // 1 second
     static constexpr nsecs_t kTimelineThresholdNs = 1000000LL; // 1 millisecond
     static constexpr float kMaxIntervalRatioDeviation = 0.05f;
-    static constexpr int kMaxTimelines = 3;
     nsecs_t syncTimestampToDisplayLocked(nsecs_t t);
 
     // Re-space frames by delaying queueBuffer so that frame delivery has
-- 
2.38.1.windows.1


From fd88f0f450040437987122333565cd0beb89b776 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 13:07:37 +0000
Subject: [PATCH 09/11] Revert "Camera: Handle deviation between frame duration
 and vsync intervals"

This reverts commit 34a5e28cbcf0d9ba486d84ca00580976baa97b75.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../device3/Camera3OutputStream.cpp           | 31 +++++--------------
 .../device3/Camera3OutputStream.h             |  1 -
 2 files changed, 7 insertions(+), 25 deletions(-)

diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index 7d0230469e..6d99707cd8 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -18,7 +18,6 @@
 #define ATRACE_TAG ATRACE_TAG_CAMERA
 //#define LOG_NDEBUG 0
 
-#include <algorithm>
 #include <ctime>
 #include <fstream>
 
@@ -1399,30 +1398,14 @@ nsecs_t Camera3OutputStream::syncTimestampToDisplayLocked(nsecs_t t) {
     const VsyncEventData& vsyncEventData = parcelableVsyncEventData.vsync;
     nsecs_t currentTime = systemTime();
 
-    // Reset capture to present time offset if:
-    // - More than 1 second between frames.
-    // - The frame duration deviates from multiples of vsync frame intervals.
-    nsecs_t captureInterval = t - mLastCaptureTime;
-    float captureToVsyncIntervalRatio = 1.0f * captureInterval / vsyncEventData.frameInterval;
-    float ratioDeviation = std::fabs(
-            captureToVsyncIntervalRatio - std::roundf(captureToVsyncIntervalRatio));
-    if (captureInterval > kSpacingResetIntervalNs ||
-            ratioDeviation >= kMaxIntervalRatioDeviation) {
-        nsecs_t minPresentT = mLastPresentTime + vsyncEventData.frameInterval / 2;
+    // Reset capture to present time offset if more than 1 second
+    // between frames.
+    if (t - mLastCaptureTime > kSpacingResetIntervalNs) {
         for (size_t i = 0; i < VsyncEventData::kFrameTimelinesLength; i++) {
-            const auto& timeline = vsyncEventData.frameTimelines[i];
-            if (timeline.deadlineTimestamp >= currentTime &&
-                    timeline.expectedPresentationTime > minPresentT) {
-                nsecs_t presentT = vsyncEventData.frameTimelines[i].expectedPresentationTime;
-                mCaptureToPresentOffset = presentT - t;
-                mLastCaptureTime = t;
-                mLastPresentTime = presentT;
-
-                // Move the expected presentation time back by 1/3 of frame interval to
-                // mitigate the time drift. Due to time drift, if we directly use the
-                // expected presentation time, often times 2 expected presentation time
-                // falls into the same VSYNC interval.
-                return presentT - vsyncEventData.frameInterval/3;
+            if (vsyncEventData.frameTimelines[i].deadlineTimestamp >= currentTime) {
+                mCaptureToPresentOffset =
+                    vsyncEventData.frameTimelines[i].expectedPresentationTime - t;
+                break;
             }
         }
     }
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index 826f7ce468..4ab052b52d 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -428,7 +428,6 @@ class Camera3OutputStream :
     static constexpr size_t kDisplaySyncExtraBuffer = 2;
     static constexpr nsecs_t kSpacingResetIntervalNs = 1000000000LL; // 1 second
     static constexpr nsecs_t kTimelineThresholdNs = 1000000LL; // 1 millisecond
-    static constexpr float kMaxIntervalRatioDeviation = 0.05f;
     nsecs_t syncTimestampToDisplayLocked(nsecs_t t);
 
     // Re-space frames by delaying queueBuffer so that frame delivery has
-- 
2.38.1.windows.1


From 1bbdb0e8a5bd11731f27bb73ad2b0f10ac73af15 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Thu, 8 Dec 2022 14:26:13 +0000
Subject: [PATCH 10/11] Revert "CameraService: Updated watchdog disconnect
 timer"

This reverts commit 6dbbb0bff1d0f29e65ed3e547279770f5cc59b1b.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 .../libcameraservice/common/Camera2ClientBase.cpp    | 12 ++++--------
 .../libcameraservice/common/Camera2ClientBase.h      |  3 ---
 .../libcameraservice/device3/Camera3Device.cpp       |  2 +-
 3 files changed, 5 insertions(+), 12 deletions(-)

diff --git a/services/camera/libcameraservice/common/Camera2ClientBase.cpp b/services/camera/libcameraservice/common/Camera2ClientBase.cpp
index c8edcc7bb8..9a5e9a94d2 100644
--- a/services/camera/libcameraservice/common/Camera2ClientBase.cpp
+++ b/services/camera/libcameraservice/common/Camera2ClientBase.cpp
@@ -41,6 +41,8 @@
 
 namespace android {
 
+const static size_t kDisconnectTimeoutMs = 2500;
+
 using namespace camera2;
 
 // Interface used by CameraService
@@ -250,16 +252,10 @@ status_t Camera2ClientBase<TClientBase>::dumpDevice(
 
 template <typename TClientBase>
 binder::Status Camera2ClientBase<TClientBase>::disconnect() {
-    if (mCameraServiceWatchdog != nullptr && mDevice != nullptr) {
-        // Timer for the disconnect call should be greater than getExpectedInFlightDuration
-        // since this duration is used to error handle methods in the disconnect sequence
-        // thus allowing existing error handling methods to execute first
-        uint64_t maxExpectedDuration =
-                ns2ms(mDevice->getExpectedInFlightDuration() + kBufferTimeDisconnectNs);
-
+    if (mCameraServiceWatchdog != nullptr) {
         // Initialization from hal succeeded, time disconnect.
         return mCameraServiceWatchdog->WATCH_CUSTOM_TIMER(disconnectImpl(),
-                maxExpectedDuration / kCycleLengthMs, kCycleLengthMs);
+                kDisconnectTimeoutMs / kCycleLengthMs, kCycleLengthMs);
     }
     return disconnectImpl();
 }
diff --git a/services/camera/libcameraservice/common/Camera2ClientBase.h b/services/camera/libcameraservice/common/Camera2ClientBase.h
index e51d25d672..3af781b45d 100644
--- a/services/camera/libcameraservice/common/Camera2ClientBase.h
+++ b/services/camera/libcameraservice/common/Camera2ClientBase.h
@@ -132,9 +132,6 @@ public:
 
 protected:
 
-    // Used for watchdog timeout to monitor disconnect
-    static const nsecs_t kBufferTimeDisconnectNs = 3000000000; // 3 sec.
-
     // The PID provided in the constructor call
     pid_t mInitialClientPid;
     bool mOverrideForPerfClass = false;
diff --git a/services/camera/libcameraservice/device3/Camera3Device.cpp b/services/camera/libcameraservice/device3/Camera3Device.cpp
index 67f2a32ac7..abaac18183 100644
--- a/services/camera/libcameraservice/device3/Camera3Device.cpp
+++ b/services/camera/libcameraservice/device3/Camera3Device.cpp
@@ -1742,7 +1742,7 @@ status_t Camera3Device::flush(int64_t *frameNumber) {
     }
 
     // Calculate expected duration for flush with additional buffer time in ms for watchdog
-    uint64_t maxExpectedDuration = ns2ms(getExpectedInFlightDuration() + kBaseGetBufferWait);
+    uint64_t maxExpectedDuration = (getExpectedInFlightDuration() + kBaseGetBufferWait) / 1e6;
     status_t res = mCameraServiceWatchdog->WATCH_CUSTOM_TIMER(mRequestThread->flush(),
             maxExpectedDuration / kCycleLengthMs, kCycleLengthMs);
 
-- 
2.38.1.windows.1


From 8c75497bfca93643e8059e284877a977b5a93c91 Mon Sep 17 00:00:00 2001
From: vjspranav <pranavasri@live.in>
Date: Sat, 22 Oct 2022 21:59:45 +0000
Subject: [PATCH 11/11] [DNM] Remove the readout timestamp changes introduced
 in r11 * Also remove the other dependent changes

Revert "Camera: reset presentation timestamp more aggressively"

This reverts commit ed08fbe1381f2de16c6ef4247436610443c5a2ed.

Revert "Camera: Handle deviation between frame duration and vsync intervals"

This reverts commit 34a5e28cbcf0d9ba486d84ca00580976baa97b75.

Revert "cameraserver: Exit watchdog for disconnect call"

This reverts commit c83d7c4a24e98f714d9f2f8b68e1292356e17fec.

Revert "cameraservice: Check for watchdog initialization before timing disconnect."

This reverts commit 3f20d19b2940098995e20d682d78d78470f07558.

Revert "Camera: Initialize input stream dynamic range profile"

This reverts commit 065fb0f576532edc127abe67dd917783fae84395.

Revert "Camera: Exit PreviewStreamSpacer when disconnecting stream"

This reverts commit dc9aa82c33f10ccde2955e60df721372264b5b5a.

Revert "Camera: Narrow down cases preview spacer is used"

This reverts commit fe8a2a32c2154de30f53bae37783b67d84ec1f9a.

Revert "Camera: Add support for readout timestamp"

This reverts commit ffc4c0164df8a13f365e980d2ebcc4777f44256b.

Signed-off-by: Akash Kakkar <akash.galaxy07@gmail.com>
---
 camera/CaptureResult.cpp                      |  9 +---
 camera/include/camera/CaptureResult.h         | 15 +-----
 .../camera/camera2/OutputConfiguration.h      |  4 +-
 .../common/Camera2ClientBase.cpp              | 13 +----
 .../common/CameraProviderManager.cpp          | 21 --------
 .../common/CameraProviderManager.h            |  1 -
 .../common/aidl/AidlProviderInfo.cpp          |  5 --
 .../common/hidl/HidlProviderInfo.cpp          |  5 --
 .../device3/Camera3IOStreamBase.cpp           |  3 +-
 .../device3/Camera3OutputStream.cpp           | 48 ++++--------------
 .../device3/Camera3OutputStream.h             | 10 ----
 .../device3/Camera3OutputUtils.cpp            |  9 +---
 .../device3/InFlightRequest.h                 |  3 +-
 .../device3/PreviewFrameSpacer.cpp            | 49 ++++++++-----------
 .../device3/PreviewFrameSpacer.h              | 21 ++++----
 .../device3/aidl/AidlCamera3OutputUtils.cpp   |  1 -
 .../device3/hidl/HidlCamera3OutputUtils.cpp   |  1 -
 .../utils/SessionConfigurationUtils.cpp       |  6 +--
 .../utils/SessionConfigurationUtilsHidl.cpp   |  2 +-
 19 files changed, 52 insertions(+), 174 deletions(-)

diff --git a/camera/CaptureResult.cpp b/camera/CaptureResult.cpp
index bb880d1229..be478981a3 100644
--- a/camera/CaptureResult.cpp
+++ b/camera/CaptureResult.cpp
@@ -52,10 +52,7 @@ status_t CaptureResultExtras::readFromParcel(const android::Parcel *parcel) {
     parcel->readInt64(&lastCompletedRegularFrameNumber);
     parcel->readInt64(&lastCompletedReprocessFrameNumber);
     parcel->readInt64(&lastCompletedZslFrameNumber);
-    parcel->readBool(&hasReadoutTimestamp);
-    if (hasReadoutTimestamp) {
-        parcel->readInt64(&readoutTimestamp);
-    }
+
     return OK;
 }
 
@@ -85,10 +82,6 @@ status_t CaptureResultExtras::writeToParcel(android::Parcel *parcel) const {
     parcel->writeInt64(lastCompletedRegularFrameNumber);
     parcel->writeInt64(lastCompletedReprocessFrameNumber);
     parcel->writeInt64(lastCompletedZslFrameNumber);
-    parcel->writeBool(hasReadoutTimestamp);
-    if (hasReadoutTimestamp) {
-        parcel->writeInt64(readoutTimestamp);
-    }
 
     return OK;
 }
diff --git a/camera/include/camera/CaptureResult.h b/camera/include/camera/CaptureResult.h
index de534ab0bc..f163c1ec00 100644
--- a/camera/include/camera/CaptureResult.h
+++ b/camera/include/camera/CaptureResult.h
@@ -103,17 +103,6 @@ struct CaptureResultExtras : public android::Parcelable {
      */
     int64_t lastCompletedZslFrameNumber;
 
-    /**
-     * Whether the readoutTimestamp variable is valid and should be used.
-     */
-    bool hasReadoutTimestamp;
-
-    /**
-     * The readout timestamp of the capture. Its value is equal to the
-     * start-of-exposure timestamp plus the exposure time (and a possible fixed
-     * offset due to sensor crop).
-     */
-    int64_t readoutTimestamp;
 
     /**
      * Constructor initializes object as invalid by setting requestId to be -1.
@@ -129,9 +118,7 @@ struct CaptureResultExtras : public android::Parcelable {
           errorPhysicalCameraId(),
           lastCompletedRegularFrameNumber(-1),
           lastCompletedReprocessFrameNumber(-1),
-          lastCompletedZslFrameNumber(-1),
-          hasReadoutTimestamp(false),
-          readoutTimestamp(0) {
+          lastCompletedZslFrameNumber(-1) {
     }
 
     /**
diff --git a/camera/include/camera/camera2/OutputConfiguration.h b/camera/include/camera/camera2/OutputConfiguration.h
index b7c7f7f115..b842885a6b 100644
--- a/camera/include/camera/camera2/OutputConfiguration.h
+++ b/camera/include/camera/camera2/OutputConfiguration.h
@@ -43,9 +43,7 @@ public:
         TIMESTAMP_BASE_SENSOR = 1,
         TIMESTAMP_BASE_MONOTONIC = 2,
         TIMESTAMP_BASE_REALTIME = 3,
-        TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED = 4,
-        TIMESTAMP_BASE_READOUT_SENSOR = 5,
-        TIMESTAMP_BASE_MAX = TIMESTAMP_BASE_READOUT_SENSOR,
+        TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED = 4
     };
     enum MirrorModeType {
         MIRROR_MODE_AUTO = 0,
diff --git a/services/camera/libcameraservice/common/Camera2ClientBase.cpp b/services/camera/libcameraservice/common/Camera2ClientBase.cpp
index 9a5e9a94d2..86c99fd634 100644
--- a/services/camera/libcameraservice/common/Camera2ClientBase.cpp
+++ b/services/camera/libcameraservice/common/Camera2ClientBase.cpp
@@ -162,11 +162,6 @@ Camera2ClientBase<TClientBase>::~Camera2ClientBase() {
 
     disconnect();
 
-    if (mCameraServiceWatchdog != NULL) {
-        mCameraServiceWatchdog->requestExit();
-        mCameraServiceWatchdog.clear();
-    }
-
     ALOGI("Closed Camera %s. Client was: %s (PID %d, UID %u)",
             TClientBase::mCameraIdStr.string(),
             String8(TClientBase::mClientPackageName).string(),
@@ -252,12 +247,8 @@ status_t Camera2ClientBase<TClientBase>::dumpDevice(
 
 template <typename TClientBase>
 binder::Status Camera2ClientBase<TClientBase>::disconnect() {
-    if (mCameraServiceWatchdog != nullptr) {
-        // Initialization from hal succeeded, time disconnect.
-        return mCameraServiceWatchdog->WATCH_CUSTOM_TIMER(disconnectImpl(),
-                kDisconnectTimeoutMs / kCycleLengthMs, kCycleLengthMs);
-    }
-    return disconnectImpl();
+    return mCameraServiceWatchdog->WATCH_CUSTOM_TIMER(disconnectImpl(),
+            kDisconnectTimeoutMs / kCycleLengthMs, kCycleLengthMs);
 }
 
 template <typename TClientBase>
diff --git a/services/camera/libcameraservice/common/CameraProviderManager.cpp b/services/camera/libcameraservice/common/CameraProviderManager.cpp
index cd23250d2d..e36f761534 100644
--- a/services/camera/libcameraservice/common/CameraProviderManager.cpp
+++ b/services/camera/libcameraservice/common/CameraProviderManager.cpp
@@ -1412,27 +1412,6 @@ status_t CameraProviderManager::ProviderInfo::DeviceInfo3::addPreCorrectionActiv
     return res;
 }
 
-status_t CameraProviderManager::ProviderInfo::DeviceInfo3::addReadoutTimestampTag(
-        bool readoutTimestampSupported) {
-    status_t res = OK;
-    auto& c = mCameraCharacteristics;
-
-    auto entry = c.find(ANDROID_SENSOR_READOUT_TIMESTAMP);
-    if (entry.count != 0) {
-        ALOGE("%s: CameraCharacteristics must not contain ANDROID_SENSOR_READOUT_TIMESTAMP!",
-                __FUNCTION__);
-    }
-
-    uint8_t readoutTimestamp = ANDROID_SENSOR_READOUT_TIMESTAMP_NOT_SUPPORTED;
-    if (readoutTimestampSupported) {
-        readoutTimestamp = ANDROID_SENSOR_READOUT_TIMESTAMP_HARDWARE;
-    }
-
-    res = c.update(ANDROID_SENSOR_READOUT_TIMESTAMP, &readoutTimestamp, 1);
-
-    return res;
-}
-
 status_t CameraProviderManager::ProviderInfo::DeviceInfo3::removeAvailableKeys(
         CameraMetadata& c, const std::vector<uint32_t>& keys, uint32_t keyTag) {
     status_t res = OK;
diff --git a/services/camera/libcameraservice/common/CameraProviderManager.h b/services/camera/libcameraservice/common/CameraProviderManager.h
index d049affdad..a66598d9b2 100644
--- a/services/camera/libcameraservice/common/CameraProviderManager.h
+++ b/services/camera/libcameraservice/common/CameraProviderManager.h
@@ -663,7 +663,6 @@ private:
             status_t deriveHeicTags(bool maxResolution = false);
             status_t addRotateCropTags();
             status_t addPreCorrectionActiveArraySize();
-            status_t addReadoutTimestampTag(bool readoutTimestampSupported = true);
 
             static void getSupportedSizes(const CameraMetadata& ch, uint32_t tag,
                     android_pixel_format_t format,
diff --git a/services/camera/libcameraservice/common/aidl/AidlProviderInfo.cpp b/services/camera/libcameraservice/common/aidl/AidlProviderInfo.cpp
index ef68f281b7..81b4779eb6 100644
--- a/services/camera/libcameraservice/common/aidl/AidlProviderInfo.cpp
+++ b/services/camera/libcameraservice/common/aidl/AidlProviderInfo.cpp
@@ -532,11 +532,6 @@ AidlProviderInfo::AidlDeviceInfo3::AidlDeviceInfo3(
         ALOGE("%s: Unable to override zoomRatio related tags: %s (%d)",
                 __FUNCTION__, strerror(-res), res);
     }
-    res = addReadoutTimestampTag();
-    if (OK != res) {
-        ALOGE("%s: Unable to add sensorReadoutTimestamp tag: %s (%d)",
-                __FUNCTION__, strerror(-res), res);
-    }
 
     camera_metadata_entry flashAvailable =
             mCameraCharacteristics.find(ANDROID_FLASH_INFO_AVAILABLE);
diff --git a/services/camera/libcameraservice/common/hidl/HidlProviderInfo.cpp b/services/camera/libcameraservice/common/hidl/HidlProviderInfo.cpp
index d60565fb68..bded9aafec 100644
--- a/services/camera/libcameraservice/common/hidl/HidlProviderInfo.cpp
+++ b/services/camera/libcameraservice/common/hidl/HidlProviderInfo.cpp
@@ -655,11 +655,6 @@ HidlProviderInfo::HidlDeviceInfo3::HidlDeviceInfo3(
         ALOGE("%s: Unable to override zoomRatio related tags: %s (%d)",
                 __FUNCTION__, strerror(-res), res);
     }
-    res = addReadoutTimestampTag(/*readoutTimestampSupported*/false);
-    if (OK != res) {
-        ALOGE("%s: Unable to add sensorReadoutTimestamp tag: %s (%d)",
-                __FUNCTION__, strerror(-res), res);
-    }
 
     camera_metadata_entry flashAvailable =
             mCameraCharacteristics.find(ANDROID_FLASH_INFO_AVAILABLE);
diff --git a/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp b/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
index add1483bf8..b5d0746a71 100644
--- a/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
+++ b/services/camera/libcameraservice/device3/Camera3IOStreamBase.cpp
@@ -89,10 +89,9 @@ void Camera3IOStreamBase::dump(int fd, const Vector<String16> &args) const {
     if (strlen(camera_stream::physical_camera_id) > 0) {
         lines.appendFormat("      Physical camera id: %s\n", camera_stream::physical_camera_id);
     }
-    lines.appendFormat("      Dynamic Range Profile: 0x%" PRIx64 "\n",
+    lines.appendFormat("      Dynamic Range Profile: 0x%" PRIx64,
             camera_stream::dynamic_range_profile);
     lines.appendFormat("      Stream use case: %" PRId64 "\n", camera_stream::use_case);
-    lines.appendFormat("      Timestamp base: %d\n", getTimestampBase());
     lines.appendFormat("      Frames produced: %d, last timestamp: %" PRId64 " ns\n",
             mFrameCount, mLastTimestamp);
     lines.appendFormat("      Total buffers: %zu, currently dequeued: %zu\n",
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
index 6d99707cd8..7d55edcee2 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.cpp
@@ -66,7 +66,6 @@ Camera3OutputStream::Camera3OutputStream(int id,
         mTraceFirstBuffer(true),
         mUseBufferManager(false),
         mTimestampOffset(timestampOffset),
-        mUseReadoutTime(false),
         mConsumerUsage(0),
         mDropBuffers(false),
         mMirrorMode(mirrorMode),
@@ -100,7 +99,6 @@ Camera3OutputStream::Camera3OutputStream(int id,
         mTraceFirstBuffer(true),
         mUseBufferManager(false),
         mTimestampOffset(timestampOffset),
-        mUseReadoutTime(false),
         mConsumerUsage(0),
         mDropBuffers(false),
         mMirrorMode(mirrorMode),
@@ -141,7 +139,6 @@ Camera3OutputStream::Camera3OutputStream(int id,
         mTraceFirstBuffer(true),
         mUseBufferManager(false),
         mTimestampOffset(timestampOffset),
-        mUseReadoutTime(false),
         mConsumerUsage(consumerUsage),
         mDropBuffers(false),
         mMirrorMode(mirrorMode),
@@ -190,7 +187,6 @@ Camera3OutputStream::Camera3OutputStream(int id, camera_stream_type_t type,
         mTraceFirstBuffer(true),
         mUseBufferManager(false),
         mTimestampOffset(timestampOffset),
-        mUseReadoutTime(false),
         mConsumerUsage(consumerUsage),
         mDropBuffers(false),
         mMirrorMode(mirrorMode),
@@ -465,19 +461,17 @@ status_t Camera3OutputStream::returnBufferCheckedLocked(
             }
         }
 
-        nsecs_t captureTime = (mUseReadoutTime && readoutTimestamp != 0 ?
-                readoutTimestamp : timestamp) - mTimestampOffset;
         if (mPreviewFrameSpacer != nullptr) {
-            nsecs_t readoutTime = (readoutTimestamp != 0 ? readoutTimestamp : timestamp)
-                    - mTimestampOffset;
-            res = mPreviewFrameSpacer->queuePreviewBuffer(captureTime, readoutTime,
-                    transform, anwBuffer, anwReleaseFence);
+            res = mPreviewFrameSpacer->queuePreviewBuffer(timestamp - mTimestampOffset, transform,
+                    anwBuffer, anwReleaseFence);
             if (res != OK) {
                 ALOGE("%s: Stream %d: Error queuing buffer to preview buffer spacer: %s (%d)",
                         __FUNCTION__, mId, strerror(-res), res);
                 return res;
             }
         } else {
+            nsecs_t captureTime = (mSyncToDisplay ? readoutTimestamp : timestamp)
+                    - mTimestampOffset;
             nsecs_t presentTime = mSyncToDisplay ?
                     syncTimestampToDisplayLocked(captureTime) : captureTime;
 
@@ -684,16 +678,13 @@ status_t Camera3OutputStream::configureConsumerQueueLocked(bool allowPreviewResp
         bool forceChoreographer = (timestampBase ==
                 OutputConfiguration::TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED);
         bool defaultToChoreographer = (isDefaultTimeBase &&
-                isConsumedByHWComposer());
-        bool defaultToSpacer = (isDefaultTimeBase &&
-                isConsumedByHWTexture() &&
-                !isConsumedByCPU() &&
-                !isVideoStream());
+                isConsumedByHWComposer() &&
+                !property_get_bool("camera.disable_preview_scheduler", false));
         if (forceChoreographer || defaultToChoreographer) {
             mSyncToDisplay = true;
             mTotalBufferCount += kDisplaySyncExtraBuffer;
-        } else if (defaultToSpacer) {
-            mPreviewFrameSpacer = new PreviewFrameSpacer(this, mConsumer);
+        } else if (isConsumedByHWTexture() && !isVideoStream()) {
+            mPreviewFrameSpacer = new PreviewFrameSpacer(*this, mConsumer);
             mTotalBufferCount ++;
             res = mPreviewFrameSpacer->run(String8::format("PreviewSpacer-%d", mId).string());
             if (res != OK) {
@@ -706,16 +697,12 @@ status_t Camera3OutputStream::configureConsumerQueueLocked(bool allowPreviewResp
     mFrameCount = 0;
     mLastTimestamp = 0;
 
-    mUseReadoutTime =
-            (timestampBase == OutputConfiguration::TIMESTAMP_BASE_READOUT_SENSOR || mSyncToDisplay);
-
     if (isDeviceTimeBaseRealtime()) {
         if (isDefaultTimeBase && !isConsumedByHWComposer() && !isVideoStream()) {
             // Default time base, but not hardware composer or video encoder
             mTimestampOffset = 0;
         } else if (timestampBase == OutputConfiguration::TIMESTAMP_BASE_REALTIME ||
-                timestampBase == OutputConfiguration::TIMESTAMP_BASE_SENSOR ||
-                timestampBase == OutputConfiguration::TIMESTAMP_BASE_READOUT_SENSOR) {
+                timestampBase == OutputConfiguration::TIMESTAMP_BASE_SENSOR) {
             mTimestampOffset = 0;
         }
         // If timestampBase is CHOREOGRAPHER SYNCED or MONOTONIC, leave
@@ -725,7 +712,7 @@ status_t Camera3OutputStream::configureConsumerQueueLocked(bool allowPreviewResp
             // Reverse offset for monotonicTime -> bootTime
             mTimestampOffset = -mTimestampOffset;
         } else {
-            // If timestampBase is DEFAULT, MONOTONIC, SENSOR, READOUT_SENSOR or
+            // If timestampBase is DEFAULT, MONOTONIC, SENSOR, or
             // CHOREOGRAPHER_SYNCED, timestamp offset is 0.
             mTimestampOffset = 0;
         }
@@ -978,10 +965,6 @@ status_t Camera3OutputStream::disconnectLocked() {
 
     returnPrefetchedBuffersLocked();
 
-    if (mPreviewFrameSpacer != nullptr) {
-        mPreviewFrameSpacer->requestExit();
-    }
-
     ALOGV("%s: disconnecting stream %d from native window", __FUNCTION__, getId());
 
     res = native_window_api_disconnect(mConsumer.get(),
@@ -1275,17 +1258,6 @@ bool Camera3OutputStream::isConsumedByHWTexture() const {
     return (usage & GRALLOC_USAGE_HW_TEXTURE) != 0;
 }
 
-bool Camera3OutputStream::isConsumedByCPU() const {
-    uint64_t usage = 0;
-    status_t res = getEndpointUsage(&usage);
-    if (res != OK) {
-        ALOGE("%s: getting end point usage failed: %s (%d).", __FUNCTION__, strerror(-res), res);
-        return false;
-    }
-
-    return (usage & GRALLOC_USAGE_SW_READ_MASK) != 0;
-}
-
 void Camera3OutputStream::dumpImageToDisk(nsecs_t timestamp,
         ANativeWindowBuffer* anwBuffer, int fence) {
     // Deriver output file name
diff --git a/services/camera/libcameraservice/device3/Camera3OutputStream.h b/services/camera/libcameraservice/device3/Camera3OutputStream.h
index 4ab052b52d..45e995d995 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputStream.h
+++ b/services/camera/libcameraservice/device3/Camera3OutputStream.h
@@ -159,11 +159,6 @@ class Camera3OutputStream :
      */
     bool isConsumedByHWTexture() const;
 
-    /**
-     * Return if this output stream is consumed by CPU.
-     */
-    bool isConsumedByCPU() const;
-
     /**
      * Return if the consumer configuration of this stream is deferred.
      */
@@ -340,11 +335,6 @@ class Camera3OutputStream :
      */
     nsecs_t mTimestampOffset;
 
-    /**
-     * If camera readout time is used rather than the start-of-exposure time.
-     */
-    bool mUseReadoutTime;
-
     /**
      * Consumer end point usage flag set by the constructor for the deferred
      * consumer case.
diff --git a/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp b/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
index f4e3fad468..ed66df0eb1 100644
--- a/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
+++ b/services/camera/libcameraservice/device3/Camera3OutputUtils.cpp
@@ -787,12 +787,10 @@ void returnAndRemovePendingOutputBuffers(bool useHalBufManager,
         SessionStatsBuilder& sessionStatsBuilder) {
     bool timestampIncreasing =
             !((request.zslCapture && request.stillCapture) || request.hasInputBuffer);
-    nsecs_t readoutTimestamp = request.resultExtras.hasReadoutTimestamp ?
-            request.resultExtras.readoutTimestamp : 0;
     returnOutputBuffers(useHalBufManager, listener,
             request.pendingOutputBuffers.array(),
             request.pendingOutputBuffers.size(),
-            request.shutterTimestamp, readoutTimestamp,
+            request.shutterTimestamp, request.shutterReadoutTimestamp,
             /*requested*/true, request.requestTimeNs, sessionStatsBuilder, timestampIncreasing,
             request.outputSurfaces, request.resultExtras,
             request.errorBufStrategy, request.transform);
@@ -854,10 +852,7 @@ void notifyShutter(CaptureOutputStates& states, const camera_shutter_msg_t &msg)
             }
 
             r.shutterTimestamp = msg.timestamp;
-            if (msg.readout_timestamp_valid) {
-                r.resultExtras.hasReadoutTimestamp = true;
-                r.resultExtras.readoutTimestamp = msg.readout_timestamp;
-            }
+            r.shutterReadoutTimestamp = msg.readout_timestamp;
             if (r.minExpectedDuration != states.minFrameDuration) {
                 for (size_t i = 0; i < states.outputStreams.size(); i++) {
                     auto outputStream = states.outputStreams[i];
diff --git a/services/camera/libcameraservice/device3/InFlightRequest.h b/services/camera/libcameraservice/device3/InFlightRequest.h
index fa0049510f..493a9e2fb6 100644
--- a/services/camera/libcameraservice/device3/InFlightRequest.h
+++ b/services/camera/libcameraservice/device3/InFlightRequest.h
@@ -65,7 +65,6 @@ typedef struct camera_capture_result {
 typedef struct camera_shutter_msg {
     uint32_t frame_number;
     uint64_t timestamp;
-    bool readout_timestamp_valid;
     uint64_t readout_timestamp;
 } camera_shutter_msg_t;
 
@@ -105,6 +104,8 @@ typedef enum {
 struct InFlightRequest {
     // Set by notify() SHUTTER call.
     nsecs_t shutterTimestamp;
+    // Set by notify() SHUTTER call with readout time.
+    nsecs_t shutterReadoutTimestamp;
     // Set by process_capture_result().
     nsecs_t sensorTimestamp;
     int     requestStatus;
diff --git a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
index 0439501733..9112b939da 100644
--- a/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
+++ b/services/camera/libcameraservice/device3/PreviewFrameSpacer.cpp
@@ -27,20 +27,21 @@ namespace android {
 
 namespace camera3 {
 
-PreviewFrameSpacer::PreviewFrameSpacer(wp<Camera3OutputStream> parent, sp<Surface> consumer) :
+PreviewFrameSpacer::PreviewFrameSpacer(Camera3OutputStream& parent, sp<Surface> consumer) :
         mParent(parent),
         mConsumer(consumer) {
 }
 
 PreviewFrameSpacer::~PreviewFrameSpacer() {
+    Thread::requestExitAndWait();
 }
 
-status_t PreviewFrameSpacer::queuePreviewBuffer(nsecs_t timestamp, nsecs_t readoutTimestamp,
-        int32_t transform, ANativeWindowBuffer* anwBuffer, int releaseFence) {
+status_t PreviewFrameSpacer::queuePreviewBuffer(nsecs_t timestamp, int32_t transform,
+        ANativeWindowBuffer* anwBuffer, int releaseFence) {
     Mutex::Autolock l(mLock);
-    mPendingBuffers.emplace(timestamp, readoutTimestamp, transform, anwBuffer, releaseFence);
-    ALOGV("%s: mPendingBuffers size %zu, timestamp %" PRId64 ", readoutTime %" PRId64,
-            __FUNCTION__, mPendingBuffers.size(), timestamp, readoutTimestamp);
+    mPendingBuffers.emplace(timestamp, transform, anwBuffer, releaseFence);
+    ALOGV("%s: mPendingBuffers size %zu, timestamp %" PRId64, __FUNCTION__,
+            mPendingBuffers.size(), timestamp);
 
     mBufferCond.signal();
     return OK;
@@ -50,36 +51,32 @@ bool PreviewFrameSpacer::threadLoop() {
     Mutex::Autolock l(mLock);
     if (mPendingBuffers.size() == 0) {
         mBufferCond.waitRelative(mLock, kWaitDuration);
-        if (exitPending()) {
-            return false;
-        } else {
-            return true;
-        }
+        return true;
     }
 
     nsecs_t currentTime = systemTime();
     auto buffer = mPendingBuffers.front();
-    nsecs_t readoutInterval = buffer.readoutTimestamp - mLastCameraReadoutTime;
-    // If the readout interval exceeds threshold, directly queue
+    nsecs_t captureInterval = buffer.timestamp - mLastCameraCaptureTime;
+    // If the capture interval exceeds threshold, directly queue
     // cached buffer.
-    if (readoutInterval >= kFrameIntervalThreshold) {
+    if (captureInterval >= kFrameIntervalThreshold) {
         mPendingBuffers.pop();
         queueBufferToClientLocked(buffer, currentTime);
         return true;
     }
 
-    // Cache the frame to match readout time interval, for up to 33ms
-    nsecs_t expectedQueueTime = mLastCameraPresentTime + readoutInterval;
+    // Cache the frame to match capture time interval, for up to 33ms
+    nsecs_t expectedQueueTime = mLastCameraPresentTime + captureInterval;
     nsecs_t frameWaitTime = std::min(kMaxFrameWaitTime, expectedQueueTime - currentTime);
     if (frameWaitTime > 0 && mPendingBuffers.size() < 2) {
         mBufferCond.waitRelative(mLock, frameWaitTime);
         if (exitPending()) {
-            return false;
+            return true;
         }
         currentTime = systemTime();
     }
-    ALOGV("%s: readoutInterval %" PRId64 ", queueInterval %" PRId64 ", waited for %" PRId64
-            ", timestamp %" PRId64, __FUNCTION__, readoutInterval,
+    ALOGV("%s: captureInterval %" PRId64 ", queueInterval %" PRId64 ", waited for %" PRId64
+            ", timestamp %" PRId64, __FUNCTION__, captureInterval,
             currentTime - mLastCameraPresentTime, frameWaitTime, buffer.timestamp);
     mPendingBuffers.pop();
     queueBufferToClientLocked(buffer, currentTime);
@@ -95,13 +92,7 @@ void PreviewFrameSpacer::requestExit() {
 
 void PreviewFrameSpacer::queueBufferToClientLocked(
         const BufferHolder& bufferHolder, nsecs_t currentTime) {
-    sp<Camera3OutputStream> parent = mParent.promote();
-    if (parent == nullptr) {
-        ALOGV("%s: Parent camera3 output stream was destroyed", __FUNCTION__);
-        return;
-    }
-
-    parent->setTransform(bufferHolder.transform, true/*mayChangeMirror*/);
+    mParent.setTransform(bufferHolder.transform, true/*mayChangeMirror*/);
 
     status_t res = native_window_set_buffers_timestamp(mConsumer.get(), bufferHolder.timestamp);
     if (res != OK) {
@@ -110,20 +101,20 @@ void PreviewFrameSpacer::queueBufferToClientLocked(
     }
 
     Camera3Stream::queueHDRMetadata(bufferHolder.anwBuffer.get()->handle, mConsumer,
-            parent->getDynamicRangeProfile());
+            mParent.getDynamicRangeProfile());
 
     res = mConsumer->queueBuffer(mConsumer.get(), bufferHolder.anwBuffer.get(),
             bufferHolder.releaseFence);
     if (res != OK) {
         close(bufferHolder.releaseFence);
-        if (parent->shouldLogError(res)) {
+        if (mParent.shouldLogError(res)) {
             ALOGE("%s: Failed to queue buffer to client: %s(%d)", __FUNCTION__,
                     strerror(-res), res);
         }
     }
 
     mLastCameraPresentTime = currentTime;
-    mLastCameraReadoutTime = bufferHolder.readoutTimestamp;
+    mLastCameraCaptureTime = bufferHolder.timestamp;
 }
 
 }; // namespace camera3
diff --git a/services/camera/libcameraservice/device3/PreviewFrameSpacer.h b/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
index e165768b97..50625533e4 100644
--- a/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
+++ b/services/camera/libcameraservice/device3/PreviewFrameSpacer.h
@@ -42,19 +42,19 @@ class Camera3OutputStream;
  *
  * The PreviewFrameSpacer improves the viewfinder user experience by:
  * - Cache the frame buffers if the intervals between queueBuffer is shorter
- *   than the camera readout intervals.
- * - Queue frame buffers in the same cadence as the camera readout time.
+ *   than the camera capture intervals.
+ * - Queue frame buffers in the same cadence as the camera capture time.
  * - Maintain at most 1 queue-able buffer. If the 2nd preview buffer becomes
  *   available, queue the oldest cached buffer to the buffer queue.
  */
 class PreviewFrameSpacer : public Thread {
   public:
-    explicit PreviewFrameSpacer(wp<Camera3OutputStream> parent, sp<Surface> consumer);
+    explicit PreviewFrameSpacer(Camera3OutputStream& parent, sp<Surface> consumer);
     virtual ~PreviewFrameSpacer();
 
     // Queue preview buffer locally
-    status_t queuePreviewBuffer(nsecs_t timestamp, nsecs_t readoutTimestamp,
-            int32_t transform, ANativeWindowBuffer* anwBuffer, int releaseFence);
+    status_t queuePreviewBuffer(nsecs_t timestamp, int32_t transform,
+            ANativeWindowBuffer* anwBuffer, int releaseFence);
 
     bool threadLoop() override;
     void requestExit() override;
@@ -63,25 +63,24 @@ class PreviewFrameSpacer : public Thread {
     // structure holding cached preview buffer info
     struct BufferHolder {
         nsecs_t timestamp;
-        nsecs_t readoutTimestamp;
         int32_t transform;
         sp<ANativeWindowBuffer> anwBuffer;
         int releaseFence;
 
-        BufferHolder(nsecs_t t, nsecs_t readoutT, int32_t tr, ANativeWindowBuffer* anwb, int rf) :
-                timestamp(t), readoutTimestamp(readoutT), transform(tr), anwBuffer(anwb),
-                releaseFence(rf) {}
+        BufferHolder(nsecs_t t, int32_t tr, ANativeWindowBuffer* anwb, int rf) :
+                timestamp(t), transform(tr), anwBuffer(anwb), releaseFence(rf) {}
     };
 
     void queueBufferToClientLocked(const BufferHolder& bufferHolder, nsecs_t currentTime);
 
-    wp<Camera3OutputStream> mParent;
+
+    Camera3OutputStream& mParent;
     sp<ANativeWindow> mConsumer;
     mutable Mutex mLock;
     Condition mBufferCond;
 
     std::queue<BufferHolder> mPendingBuffers;
-    nsecs_t mLastCameraReadoutTime = 0;
+    nsecs_t mLastCameraCaptureTime = 0;
     nsecs_t mLastCameraPresentTime = 0;
     static constexpr nsecs_t kWaitDuration = 5000000LL; // 50ms
     static constexpr nsecs_t kFrameIntervalThreshold = 80000000LL; // 80ms
diff --git a/services/camera/libcameraservice/device3/aidl/AidlCamera3OutputUtils.cpp b/services/camera/libcameraservice/device3/aidl/AidlCamera3OutputUtils.cpp
index b2accc1c99..02eebd24f3 100644
--- a/services/camera/libcameraservice/device3/aidl/AidlCamera3OutputUtils.cpp
+++ b/services/camera/libcameraservice/device3/aidl/AidlCamera3OutputUtils.cpp
@@ -110,7 +110,6 @@ void notify(CaptureOutputStates& states,
             m.type = CAMERA_MSG_SHUTTER;
             m.message.shutter.frame_number = msg.get<Tag::shutter>().frameNumber;
             m.message.shutter.timestamp = msg.get<Tag::shutter>().timestamp;
-            m.message.shutter.readout_timestamp_valid = true;
             m.message.shutter.readout_timestamp = msg.get<Tag::shutter>().readoutTimestamp;
             break;
     }
diff --git a/services/camera/libcameraservice/device3/hidl/HidlCamera3OutputUtils.cpp b/services/camera/libcameraservice/device3/hidl/HidlCamera3OutputUtils.cpp
index ff6fc170d3..8b0cd65e62 100644
--- a/services/camera/libcameraservice/device3/hidl/HidlCamera3OutputUtils.cpp
+++ b/services/camera/libcameraservice/device3/hidl/HidlCamera3OutputUtils.cpp
@@ -105,7 +105,6 @@ void notify(CaptureOutputStates& states,
             m.type = CAMERA_MSG_SHUTTER;
             m.message.shutter.frame_number = msg.msg.shutter.frameNumber;
             m.message.shutter.timestamp = msg.msg.shutter.timestamp;
-            m.message.shutter.readout_timestamp_valid = false;
             m.message.shutter.readout_timestamp = 0LL;
             break;
     }
diff --git a/services/camera/libcameraservice/utils/SessionConfigurationUtils.cpp b/services/camera/libcameraservice/utils/SessionConfigurationUtils.cpp
index 3071a89a5f..6064088623 100644
--- a/services/camera/libcameraservice/utils/SessionConfigurationUtils.cpp
+++ b/services/camera/libcameraservice/utils/SessionConfigurationUtils.cpp
@@ -490,7 +490,7 @@ binder::Status createSurfaceFromGbp(
         return STATUS_ERROR(CameraService::ERROR_ILLEGAL_ARGUMENT, msg.string());
     }
     if (timestampBase < OutputConfiguration::TIMESTAMP_BASE_DEFAULT ||
-            timestampBase > OutputConfiguration::TIMESTAMP_BASE_MAX) {
+            timestampBase > OutputConfiguration::TIMESTAMP_BASE_CHOREOGRAPHER_SYNCED) {
         String8 msg = String8::format("Camera %s: invalid timestamp base %d",
                 logicalCameraId.string(), timestampBase);
         ALOGE("%s: %s", __FUNCTION__, msg.string());
@@ -651,10 +651,6 @@ convertToHALStreamCombination(
         stream.bufferSize = 0;
         stream.groupId = -1;
         stream.sensorPixelModesUsed = defaultSensorPixelModes;
-        using DynamicRangeProfile =
-            aidl::android::hardware::camera::metadata::RequestAvailableDynamicRangeProfilesMap;
-        stream.dynamicRangeProfile =
-            DynamicRangeProfile::ANDROID_REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES_MAP_STANDARD;
         streamConfiguration.streams[streamIdx++] = stream;
         streamConfiguration.multiResolutionInputImage =
                 sessionConfiguration.inputIsMultiResolution();
diff --git a/services/camera/libcameraservice/utils/SessionConfigurationUtilsHidl.cpp b/services/camera/libcameraservice/utils/SessionConfigurationUtilsHidl.cpp
index 5444f2a36a..4e6f832560 100644
--- a/services/camera/libcameraservice/utils/SessionConfigurationUtilsHidl.cpp
+++ b/services/camera/libcameraservice/utils/SessionConfigurationUtilsHidl.cpp
@@ -50,7 +50,7 @@ convertAidlToHidl37StreamCombination(
     for (const auto &stream : aidl.streams) {
         if (static_cast<int>(stream.dynamicRangeProfile) !=
                 ANDROID_REQUEST_AVAILABLE_DYNAMIC_RANGE_PROFILES_MAP_STANDARD) {
-            ALOGE("%s Dynamic range profile %" PRId64 " not supported by HIDL", __FUNCTION__,
+            ALOGE("%s  Dynamic range profile %" PRId64 " not supported by HIDL", __FUNCTION__,
                     stream.dynamicRangeProfile);
             return BAD_VALUE;
         }
-- 
2.38.1.windows.1

EOL
) &&
git -C $patch_dir commit --no-gpg-sign -am "$patch_name"