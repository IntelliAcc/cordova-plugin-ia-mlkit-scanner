#import <Cordova/CDVPlugin.h>
#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>
#import "MLKitCameraViewController.h"

@class UIViewController;

@interface MLKitBarcodeScanner : CDVPlugin {
  NSString *_callback;
  Boolean _scannerOpen;
}

@property (nonatomic, retain) MLKitCameraViewController* cameraViewController;

- (void) scanBarcode:(CDVInvokedUrlCommand*)command;

@end
