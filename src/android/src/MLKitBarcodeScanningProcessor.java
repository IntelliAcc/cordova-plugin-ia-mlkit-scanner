package com.intelliacc.MLKitBarcodeScanner;

import android.app.Activity;
import android.content.Context;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.os.Build;
import android.util.Log;
import android.util.SparseIntArray;
import android.view.Surface;

import androidx.annotation.GuardedBy;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.annotation.UiThread;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;

import com.google.mlkit.vision.barcode.common.Barcode;
import com.google.mlkit.vision.barcode.BarcodeScanner;
import com.google.mlkit.vision.barcode.BarcodeScannerOptions;
import com.google.mlkit.vision.barcode.BarcodeScanning;
import com.google.mlkit.vision.common.InputImage;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.List;

import static android.content.Context.CAMERA_SERVICE;


public class MLKitBarcodeScanningProcessor {
    
    private static final String TAG = "Barcode-Processor";
    private final BarcodeScanner _Detector;
    private BarcodeUpdateListener _BarcodeUpdateListener;
    
    public MLKitBarcodeScanningProcessor(BarcodeScanner p_BarcodeDetector, Context p_Context) {
        _Detector = p_BarcodeDetector;
        if (p_Context instanceof BarcodeUpdateListener) {
            this._BarcodeUpdateListener = (BarcodeUpdateListener)p_Context;
        } else {
            throw new RuntimeException("Hosting activity must implement BarcodeUpdateListener");
        }
    }
    
    @GuardedBy("this")
    int _latestHeight;
    
    @GuardedBy("this")
    int _latestWidth;
    
    @GuardedBy("this")
    int _latestRotation;
    
    @GuardedBy("this")
    private ByteBuffer _LatestImage;
    
    @GuardedBy("this")
    private ByteBuffer _ProcessingImage;
    
    public synchronized void Process(ByteBuffer p_Data, int height, int width, int rotation) {
        _LatestImage = p_Data;
        _latestHeight = height;
        _latestWidth = width;
        _latestRotation = rotation;
        
        if (_ProcessingImage == null) {
            ProcessLatestImage();
        }
    }
    
    public void Stop() {
        _Detector.close();
    }
    
    private synchronized void ProcessLatestImage() {
        _ProcessingImage = _LatestImage;
        _LatestImage = null;
        
        if (_ProcessingImage != null) {
            ProcessImage(_ProcessingImage);
        }
    }
    
    private void ProcessImage(ByteBuffer p_Data) {
        InputImage image = InputImage.fromByteBuffer(
                p_Data,
                _latestWidth,
                _latestHeight,
                _latestRotation,
                InputImage.IMAGE_FORMAT_NV21);
        DetectInVisionImage(image);
    }
    
    private void DetectInVisionImage(InputImage p_Image) {
        BarcodeScannerOptions options =
                new BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS).build();
        
        BarcodeScanner scanner = BarcodeScanning.getClient(options);
        
        Task<List<Barcode>> result =
                scanner.process(p_Image).addOnSuccessListener(new OnSuccessListener<List<Barcode>>() {
                    
                    @Override
                    public void onSuccess(List<Barcode> barcodes) {
                        OnSuccess(barcodes);
                        ProcessLatestImage();
                    }
                }).addOnFailureListener(new OnFailureListener() {
                    
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        OnFailure(e);
                    }
                });
    }
    
    private void OnSuccess(List<Barcode> p_Barcodes) {
        for (Barcode barcode : p_Barcodes) {
            _BarcodeUpdateListener.onBarcodeDetected(barcode.getDisplayValue());
        }
    }
    
    private void OnFailure(Exception e) {
        Log.e(TAG, "Barcode detection failed " + e);
    }
    
    public interface BarcodeUpdateListener {
        
        @UiThread
        void onBarcodeDetected(String p_Barcode);
    }
    
    
    private static final SparseIntArray ORIENTATIONS = new SparseIntArray();
    
    static {
        ORIENTATIONS.append(Surface.ROTATION_0, 0);
        ORIENTATIONS.append(Surface.ROTATION_90, 90);
        ORIENTATIONS.append(Surface.ROTATION_180, 180);
        ORIENTATIONS.append(Surface.ROTATION_270, 270);
    }
    
    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private int getRotationCompensation(String cameraId, Activity activity, boolean isFrontFacing)
            throws CameraAccessException {
        // Get the device's current rotation relative to its "native" orientation.
        // Then, from the ORIENTATIONS table, look up the angle the image must be
        // rotated to compensate for the device's rotation.
        int deviceRotation = activity.getWindowManager().getDefaultDisplay().getRotation();
        int rotationCompensation = ORIENTATIONS.get(deviceRotation);
        
        // Get the device's sensor orientation.
        CameraManager cameraManager = (CameraManager)activity.getSystemService(CAMERA_SERVICE);
        int sensorOrientation =
                cameraManager.getCameraCharacteristics(cameraId).get(CameraCharacteristics.SENSOR_ORIENTATION);
        
        if (isFrontFacing) {
            rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else { // back-facing
            rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
        }
        return rotationCompensation;
    }
}
