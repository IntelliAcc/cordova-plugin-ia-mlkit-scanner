var exec = require('cordova/exec');

var PLUGIN_NAME = 'MLKitBarcodeScanner';

var MLKitBarcodeScanner = {
	/** Open the barcode scanning interface to scan one barcode, then return the result. */
	scanBarcode: function (cameraFacing, success, failure) {
		if (![0, 1].includes(cameraFacing)) { cameraFacing = 0; }

		if (!success) { success = (_) => { }; }
		if (!failure) { failure = (_) => { }; }

		exec(success, failure, PLUGIN_NAME, "scanBarcode", [cameraFacing]);
	},
	/** Check if Google Play Services is available. Android ONLY. */
	checkSupport: function (success, failure) {
		if (!success) { success = (_) => { }; }
		if (!failure) { failure = (_) => { }; }

		exec(success, failure, PLUGIN_NAME, "checkSupport", []);
	}
}

module.exports = MLKitBarcodeScanner;