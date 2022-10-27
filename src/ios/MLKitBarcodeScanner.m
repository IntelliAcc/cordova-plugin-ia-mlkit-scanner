#import <Cordova/CDVPlugin.h>

#import "MLKitBarcodeScanner.h"

#import <MLKitBarcodeScanning/MLKitBarcodeScanning.h>
#import <MLKitVision/MLKitVision.h>

@class UIViewController;

@interface MLKitBarcodeScanner ()
{
  NSInteger _previousStatusBarStyle;
}
@end

@implementation MLKitBarcodeScanner

- (void)pluginInitialize
{
  _previousStatusBarStyle = -1;
//  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

//- (void)finishLaunching:(NSNotification *)notification
//{
//
//}

// - (void) isCallSupported:(CDVInvokedUrlCommand*)command {
//     [self.commandDelegate runInBackground: ^{
//         CDVPluginResult* pluginResult = [CDVPluginResult
//             resultWithStatus:CDVCommandStatus_OK
//             messageAsBool:[MLKitBarcodeScanner available]];
//         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//     }];
// }

- (void) scanBarcode:(CDVInvokedUrlCommand*)command {
 //Force portrait orientation.
  [[UIDevice currentDevice] setValue:
   [NSNumber numberWithInteger: UIInterfaceOrientationPortrait]
                forKey:@"orientation"];
  dispatch_async(dispatch_get_main_queue(), ^{
    NSLog(@"Arguments %@", command.arguments);
    if(self->_scannerOpen == YES) {
      //Scanner is currently open, throw error.
      CDVPluginResult *pluginResult=[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"SCANNER_OPEN"];
      
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
      //Open scanner.
      self->_scannerOpen = YES;
      self.cameraViewController = [[MLKitCameraViewController alloc] init];
      self.cameraViewController.modalPresentationStyle = UIModalPresentationFullScreen;
      self.cameraViewController.delegate = self;
      
      //Provide settings to the camera view.
      NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
      f.numberStyle = NSNumberFormatterDecimalStyle;
      NSNumber * barcodeFormats = [command argumentAtIndex:1 withDefault:@1234];
			
      self.cameraViewController.cameraFacing = [command argumentAtIndex:0 withDefault:1] ;
      self.cameraViewController.scanAreaWidth = (CGFloat)[[command argumentAtIndex:2 withDefault:@.5] floatValue];
      self.cameraViewController.scanAreaHeight = (CGFloat)[[command argumentAtIndex:3 withDefault:@.7] floatValue];
      self.cameraViewController.barcodeFormats = barcodeFormats;
      
      
      [self.viewController presentViewController:self.cameraViewController animated: NO completion:nil];
        self->_callback = command.callbackId;
    }
  });
}

- (void) checkSupport:(CDVInvokedUrlCommand*)command {
  // This command is only for Android to check availability of Google Play Services
  CDVPluginResult *pluginResult=[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

      
-(void)sendResult:(NSString *)value
{
  [self.cameraViewController dismissViewControllerAnimated:NO completion:nil];
  _scannerOpen = NO;
  
  // NSArray *response = @[value, @"", @""];
  CDVPluginResult *pluginResult=[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:value];
  
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_callback];
}

-(void)errorOccurred
{
  [self.cameraViewController dismissViewControllerAnimated:NO completion:nil];
  _scannerOpen = NO;
  
  CDVPluginResult *pluginResult=[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"BARCODE_NOT_MATCH"];
  
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_callback];
  
}

-(void)closeScanner
{
  [self.cameraViewController dismissViewControllerAnimated:NO completion:nil];
  _scannerOpen = NO;
  
  CDVPluginResult *pluginResult=[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"USER_CANCELLED"];
  
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_callback];
  
}


- (void)show:(CDVInvokedUrlCommand*)command
{
  if (self.cameraViewController == nil) {
    NSLog(@"Tried to show scanner after it was closed.");
    return;
  }
  if (_previousStatusBarStyle != -1) {
    NSLog(@"Tried to show scanner while already shown");
    return;
  }
  
  _previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
  
  __block UINavigationController* nav = [[UINavigationController alloc]
                       initWithRootViewController:self.cameraViewController];
  //nav.orientationDelegate = self.cameraViewController;
  nav.navigationBarHidden = YES;
  nav.modalPresentationStyle = self.cameraViewController.modalPresentationStyle;
  
  __weak MLKitBarcodeScanner* weakSelf = self;
  
  // Run later to avoid the "took a long time" log message.
  dispatch_async(dispatch_get_main_queue(), ^{
    if (weakSelf.cameraViewController != nil) {
      CGRect frame = [[UIScreen mainScreen] bounds];
      UIWindow *tmpWindow = [[UIWindow alloc] initWithFrame:frame];
      UIViewController *tmpController = [[UIViewController alloc] init];
      [tmpWindow setRootViewController:tmpController];
      [tmpWindow setWindowLevel:UIWindowLevelNormal];
      
      [tmpWindow makeKeyAndVisible];
      [tmpController presentViewController:nav animated:NO completion:nil];
    }
  });
}

@end
