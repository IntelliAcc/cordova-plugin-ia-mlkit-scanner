var exec = require('cordova/exec');

var PLUGIN_NAME = 'MLKitBarcodeScanner';

var MLKitBarcodeScanner = {
	scanBarcode: function (cameraFacing, success, failure) {
		exec(success, failure, PLUGIN_NAME, "scanBarcode", [cameraFacing]);
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