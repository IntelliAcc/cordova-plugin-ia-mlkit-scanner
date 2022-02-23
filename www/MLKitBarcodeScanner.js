var exec = require('cordova/exec');

var PLUGIN_NAME = 'MLKitBarcodeScanner';

var MLKitBarcodeScanner = {
	/** Open the barcode scanning interface to scan one barcode, then return the result. */
	scanBarcode: function (cameraFacing, success, failure) {
		if (!cameraFacing || cameraFacing > 1 || cameraFacing < 0) { cameraFacing = 0; }

		if (!success) { success = (barcode) => { }; }
		if (!failure) { failure = (error) => { }; }

		exec(success, failure, PLUGIN_NAME, "scanBarcode", [cameraFacing]);
	},
	/** Check if Google Play Services is available. Android ONLY. */
	checkSupport: function (success, failure) {
		if (!success) { success = (isSupported) => { }; }
		if (!failure) { failure = (error) => { }; }

		exec(success, failure, PLUGIN_NAME, "checkSupport", []);
	}
}

module.exports = MLKitBarcodeScanner;





//working in iOS
// var MLKitBarcodeScanner = function(){};

// MLKitBarcodeScanner.prototype.scanBarcode = function(success, failure){
//     cordova.exec(success, failure, "MLKitBarcodeScanner", "scanBarcode");
// };

// //Plug in to Cordova
// cordova.addConstructor(function() {

//     if (!window.Cordova) {
//         window.Cordova = cordova;
//     };

//     if(!window.plugins) window.plugins = {};
//     window.plugins.MLKitBarcodeScanner = new MLKitBarcodeScanner();
// });