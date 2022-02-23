MLKit Barcode Scanner
=======================

Scan barcodes using the Google MLKit. This plugin supports the `android` and `ios` platforms.

Install the plugin using:
``` 
npm install cordova-plugin-ia-mlkit-scanner
```

## Usage

### Barcode Scanner
To call up the barcode scanner, refer to this example code:

__NOTE: cameraFacing__ should be set to 0 for back camera, and 1 for front camera.

``` javascript
function onSuccess(barcode){
  console.log("Success:"+barcode);
}

function onError(message) {
  console.log("Error:"+message);
}

window['MLKitBarcodeScanner'].scanBarcode(cameraFacing, onSuccess, onError);
```

---
### Check Play Service Availability (ANDROID)
As this plugin is based on Google's MLKit, Play services is required for it to function correctly on Android devices. You can check if the host device has support, by calling __checkSupport__:

``` javascript
function onSuccess(isSupported){
  console.log("Has Support: " + isSupported);
}

function onError(message) {
  console.log("Error: " + message);
}

window['MLKitBarcodeScanner'].checkSupport(onSuccess, onError);
```
