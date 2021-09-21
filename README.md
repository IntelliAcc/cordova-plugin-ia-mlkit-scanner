MLKit Barcode Scanner
=======================

Scan barcodes using the Google MLKit. This plugin supports the `android` and `ios` platforms.

Install the plugin using:
``` 
npm install cordova-plugin-ia-mlkit-scanner
```

Use the plugin in your code:
``` javascript
window['MLKitBarcodeScanner'].scanBarcode(cameraFacing, onSuccess, onError);
```
__NOTE: cameraFacing__ should be set to 0 for back camera, and 1 for front camera.


Be sure to pass the two handler functions.
Example:
``` javascript
function onSuccess(barcode){
  console.log("Success:"+barcode);
}

function onError(result) {
  console.log("Error:"+result);
}
```
