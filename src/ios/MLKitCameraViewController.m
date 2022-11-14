// Note: This code was forked from https://github.com/dealrinc/cordova-gmv-barcode-scanner

@import AVFoundation;
@import MLKitBarcodeScanning;

#import <MLKitBarcodeScanning/MLKitBarcodeScanning.h>
#import <MLKitVision/MLKitVision.h>
#import "MLKitCameraViewController.h"

@interface MLKitCameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, weak) IBOutlet UIView *placeHolderView;
@property(nonatomic, weak) IBOutlet UIView *overlayView;
@property(nonatomic, strong) UIImageView *imageView;

@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property(nonatomic, strong) MLKBarcodeScanner *barcodeScanner;
@property(nonatomic, strong) UIButton *torchButton;
@property(nonatomic, retain) UITextField* txtBarcode;
@property(nonatomic, retain) NSMutableArray<MLKBarcode *> *_Nullable globalBarcodes;
@end

@implementation MLKitCameraViewController
@synthesize delegate;

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (BOOL)prefersHomeIndicatorAutoHidden
{
  return YES;
}

-(BOOL) shouldAutorotate
{
  return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskPortrait;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    _videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue",
                                                  DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.globalBarcodes = [NSMutableArray array];

  // Set up camera.
  self.session = [[AVCaptureSession alloc] init];
  self.session.sessionPreset = AVCaptureSessionPresetHigh;
  
  _videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue",
                                                DISPATCH_QUEUE_SERIAL);
  
  [self updateCameraSelection];
  
  // Set up video processing pipeline.
  [self setUpVideoProcessing];
  
  // Set up camera preview.
  [self setUpCameraPreview];
  
  
  MLKBarcodeScannerOptions *options = [[MLKBarcodeScannerOptions alloc] initWithFormats: MLKBarcodeFormatAll];
  
  // MLK *vision = [MLK vision];
  
  self.barcodeScanner = [MLKBarcodeScanner barcodeScannerWithOptions:options];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  self.previewLayer.frame = self.view.layer.bounds;
  self.previewLayer.position = CGPointMake(CGRectGetMidX(self.previewLayer.frame),
                                           CGRectGetMidY(self.previewLayer.frame));
}

- (void)viewDidUnload {
  [self cleanupCaptureSession];
  [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  //Force portrait orientation.
  [[UIDevice currentDevice] setValue:
   [NSNumber numberWithInteger: UIInterfaceOrientationPortrait]
                              forKey:@"orientation"];
  
  [self.session startRunning];
  
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [self.session stopRunning];
}

#pragma mark - UIImageOrientation

- (UIImageOrientation)
imageOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation
cameraPosition:(AVCaptureDevicePosition)cameraPosition {
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationLeftMirrored
      : UIImageOrientationRight;
      
    case UIDeviceOrientationLandscapeLeft:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationDownMirrored
      : UIImageOrientationUp;
    case UIDeviceOrientationPortraitUpsideDown:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationRightMirrored
      : UIImageOrientationLeft;
    case UIDeviceOrientationLandscapeRight:
      return cameraPosition == AVCaptureDevicePositionFront ? UIImageOrientationUpMirrored
      : UIImageOrientationDown;
    case UIDeviceOrientationUnknown:
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationFaceDown:
      return UIImageOrientationUp;
  }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
  MLKVisionImage *image = [[MLKVisionImage alloc] initWithBuffer:sampleBuffer];
  AVCaptureDevicePosition cameraPosition =
  AVCaptureDevicePositionBack;  // Set to the capture device you used.
  if([self.cameraFacing isEqualToNumber:@1]) {
    cameraPosition = AVCaptureDevicePositionFront;
  }
  image.orientation = [self imageOrientationFromDeviceOrientation:UIDevice.currentDevice.orientation cameraPosition:cameraPosition];
  
  [self.barcodeScanner processImage:image
                         completion:^(NSArray<MLKBarcode *> *_Nullable barcodes,
                                      NSError *_Nullable error) {
    if (error != nil) {
      // Error handling
      return;
    }
    
    if(barcodes.count > 0) {
      [self.globalBarcodes addObject:[barcodes objectAtIndex:0]];
    }
    if (self.globalBarcodes.count > 1) {
      if([self.globalBarcodes[0].rawValue isEqualToString: self.globalBarcodes[1].rawValue]) {
        for (MLKBarcode *barcode in barcodes) {
          
          NSLog(@"Barcode value: %@", barcode.rawValue);
          [self cleanupCaptureSession];
          [self->_session stopRunning];
          [self->delegate sendResult:barcode.rawValue];
          break;
        }
      } else {
        NSLog(@"error");
        [self cleanupCaptureSession];
        [self->_session stopRunning];
        [self->delegate errorOccurred];
      }
    }
  }];
}

#pragma mark - Camera setup

- (void)cleanupVideoProcessing {
  if (self.videoDataOutput) {
    [self.session removeOutput:self.videoDataOutput];
  }
  self.videoDataOutput = nil;
}

- (void)cleanupCaptureSession {
  [self.session stopRunning];
  [self cleanupVideoProcessing];
  self.session = nil;
  [self.previewLayer removeFromSuperlayer];
}

- (void)setUpVideoProcessing {
  self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
  NSDictionary *rgbOutputSettings = @{
    (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
  };
  [self.videoDataOutput setVideoSettings:rgbOutputSettings];
  
  if (![self.session canAddOutput:self.videoDataOutput]) {
    [self cleanupVideoProcessing];
    NSLog(@"Failed to setup video output");
    return;
  }
  [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
  [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
  [self.session addOutput:self.videoDataOutput];
}

- (void)setUpCameraPreview {
  self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
  [self.previewLayer setBackgroundColor:[UIColor blackColor].CGColor];
  [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
  
  
  
  CGRect screenRect = [[UIScreen mainScreen] bounds];
  CGFloat screenWidth = screenRect.size.width;
  CGFloat screenHeight = screenRect.size.height;
  
  CGFloat frameWidth = screenWidth*_scanAreaWidth;
  CGFloat frameHeight = screenHeight*_scanAreaHeight;
  
  UIWindow *window = UIApplication.sharedApplication.keyWindow;
  CGFloat topPadding = window.safeAreaInsets.top;
  CGFloat bottomPadding = window.safeAreaInsets.bottom;
  
  int buttonWidth = 80;
  int buttonHeight = 40;
  int border = 5;
  if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ) {
    buttonWidth = 150;
    buttonHeight = 60;
    border = 8;
  }


  CGRect f = self.view.superview.bounds;
  f.size.height = screenHeight-buttonHeight;
  self.previewLayer.frame = f;
  
  [self.view.layer addSublayer:self.previewLayer];
  UIGestureRecognizer *tapper = [[UITapGestureRecognizer alloc]
                                 initWithTarget:self action:@selector(handleSingleTap:)];
  tapper.cancelsTouchesInView = NO;
  tapper.delegate = self;

  [self.view addGestureRecognizer:tapper];

  UILabel* verticalLine = [[UILabel alloc] init];
  
  verticalLine.frame = CGRectMake(screenWidth/2, 5, 1,  (screenHeight-buttonHeight-bottomPadding)-10);
  verticalLine.layer.masksToBounds = NO;
  verticalLine.layer.cornerRadius = 0;
  verticalLine.userInteractionEnabled = YES;
  verticalLine.layer.borderColor = [UIColor redColor].CGColor;
  verticalLine.layer.borderWidth = 0.5;
  
  UILabel* horizontalLine = [[UILabel alloc] init];
  
  horizontalLine.frame = CGRectMake(5, (screenHeight-buttonHeight-bottomPadding)/2, screenWidth-10, 1);
  horizontalLine.layer.masksToBounds = NO;
  horizontalLine.layer.cornerRadius = 0;
  horizontalLine.userInteractionEnabled = YES;
  horizontalLine.layer.borderColor = [UIColor redColor].CGColor;
  horizontalLine.layer.borderWidth = 0.5;
  
  
  UIView* bcView = [[UIView alloc]init];
  bcView.frame = CGRectMake(0, screenHeight-buttonHeight-bottomPadding, screenWidth, buttonHeight+bottomPadding);
  [bcView setBackgroundColor:[UIColor whiteColor]];

  self.txtBarcode = [[UITextField alloc] init];
  
  self.txtBarcode.frame = CGRectMake(border, 0, screenWidth-buttonWidth-border-border, buttonHeight);
//  self.txtBarcode.placeholder = @"Scan Barcode or type it here";
  
  CALayer *bottomLine = [[CALayer alloc]init];
  bottomLine.frame = CGRectMake(0.0, self.txtBarcode.frame.size.height - 1, self.txtBarcode.frame.size.width, 1.0);
  bottomLine.backgroundColor = [UIColor colorWithRed:152.0f/255.0f green:154.0f/255.0f blue:162.0f/255.0f alpha:152.0f/255.0f].CGColor;
  [self.txtBarcode setBorderStyle:UITextBorderStyleNone];
  [self.txtBarcode.layer addSublayer:bottomLine];
  [self.txtBarcode setTextColor:[UIColor colorWithRed:34/255.0f green:36/255.0f blue:40/255.0f alpha:1.0f] ];
  self.txtBarcode.delegate = self;
  UIColor *color = [UIColor colorWithRed:152.0f/255.0f green:154.0f/255.0f blue:162.0f/255.0f alpha:152.0f/255.0f];
  self.txtBarcode.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Scan Barcode or type it here" attributes:@{NSForegroundColorAttributeName: color}];
  [self.txtBarcode setAutocorrectionType:UITextAutocorrectionTypeNo];
  [self.txtBarcode setReturnKeyType:UIReturnKeyDone];
  
  UIButton* submitBarcode = [[UIButton alloc] init];
  
  submitBarcode.frame = CGRectMake(screenWidth-buttonWidth, 0, buttonWidth, buttonHeight);
  [submitBarcode setTitle:@"OK" forState:UIControlStateNormal];
  [submitBarcode setTitle:@"OK" forState:UIControlStateSelected];
  [submitBarcode setTitle:@"OK" forState:UIControlStateHighlighted];
  [submitBarcode setTitle:@"OK" forState:UIControlStateFocused];
  [submitBarcode setTitle:@"OK" forState:UIControlStateDisabled];
  [submitBarcode setTitle:@"OK" forState:UIControlStateReserved];
  [submitBarcode setTitle:@"OK" forState:UIControlStateApplication];
  [submitBarcode setBackgroundColor:[UIColor colorWithRed:0.0f green:106.0f/255.0f blue:166.0f/255.0f alpha:1.0f]];
  
  [submitBarcode addTarget:self
                    action:@selector(submitTextBarcode:)
          forControlEvents:UIControlEventTouchUpInside];
  
  UITapGestureRecognizer* tapScanner = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAtPoint:)];
  [verticalLine addGestureRecognizer:tapScanner];
  [horizontalLine addGestureRecognizer:tapScanner];
  
  CGFloat buttonSize = 45.0;
  
  
  UIButton *_cancelButton = [[UIButton alloc] init];
  [_cancelButton addTarget:self
                    action:@selector(closeView:)
          forControlEvents:UIControlEventTouchUpInside];
  
  NSString * cancelBase64String = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAQAAABpN6lAAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QAAKqNIzIAAAAJcEhZcwAADdcAAA3XAUIom3gAAAAHdElNRQfhCxMVEyaNvw4TAAADNElEQVR42u2dv1LqQBSHv1DwBjY0FjyAA7wCtna2ttrwLr6GY4PWKfQBJGNtb2PDMFQ2ewvmDheBC0l295zjYVO6Cb/vC4b82c0p+Lf1GDNkwAVfzKh4oyRguxWMGTFgyBnvVMwo+dzd8Y4F4cfyQl+aoFXr87LFtOCW4mfHc8qtjqtlyWS7u4lWMGG5h6rkfBN/vqfjapnSlaap3bpM/8s0Xyso9u799fJkTEGXp4NM5d9v9t3BrtYUHIMfCNwC9HYc+mwrOBY/sKAHN0d2tqLgePxA4Abua3TXr6AefuAeXmutoFtBXfzAKwd+AC0pqI8fmMNH7ZV0KmiCH/iAhwar6VPQDD/w0KFq9IFXPCpS0OWRq0ZrVnDZyJymb0HTvR8IXEKx43rJkoI2+C+rk+H+3msm/Qra4C/Xl/qTxhuRVdAGPzBZb6g4cOmoU0E7/OnmXY52G5NQED2xLQVJ0tpRkCypDQVJU+pXkDyhbgVZ0ulVkC2ZTgVZU+lTkD2RLgUiafQoEEuiQ4FoCnkF4glkA4jjy4ZQgS8XRA2+TBhV+PkDqcPPG0olfr5gavHzhFONnz6gevy0IU3gpwtqBj9NWFP48QObw48b2iR+vOBm8eOEN40fQ4Fx/PYKzONLKVCEL6FAGX5uBQrxcypQip9LgWL8HAqU46dWYAA/pQIj+KkUGMJPocAYfmwFBvFjKjCKH0uBYfwYCpLjd6QN/e7m/F/A+UHQ+c+g8xMh56fCzi+GnF8OO78h4vyWmPObos5vizt/MOL80Zjzh6POH487HyDhfIiM80FSzofJOR8o6XyorPPB0s6HyzufMOF8yozzSVPOp805nzjpfOqs88nTzqfPiwfw/v4I0RQ68MWS6MEXSaMLP3siffhZU+nEz5ZML36WdLrxkyfUj580pQ38ZEnt4CdJaws/emL3r9Z2/nJ156/Xd19gwXmJjQ6jhh/7zDXf0uwAfHPNc8N1R+7L7JwKLZ1KbTkvtla30pSeQ9+uVv9wWJ0KLp5Kbrovunoqu4v7wssrBa5Lb6+6uyy+vrlve4wZMuCCL2ZUvFESpBlatoIxIwYMOeOdihkln+s//wFFdoCM42fEswAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAxNy0xMS0xOVQyMToxOTozOCswMTowMPNH2M8AAAAldEVYdGRhdGU6bW9kaWZ5ADIwMTctMTEtMTlUMjE6MTk6MzgrMDE6MDCCGmBzAAAAGXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAABJRU5ErkJggg==";
  
  NSURL *cancelImageUrl = [NSURL URLWithString:cancelBase64String];
  NSData *cancelImageData = [NSData dataWithContentsOfURL:cancelImageUrl];
  UIImage *cancelIcon = [UIImage imageWithData:cancelImageData];
  [_cancelButton setImage:cancelIcon
                 forState:UIControlStateNormal];
  
  CGFloat screenOffset = (screenWidth/2 - frameWidth/2)/2 - buttonSize/2;
  NSLog(@"screenOffset %f", screenOffset);
  
  _cancelButton.frame = CGRectMake(screenOffset, screenHeight-screenOffset-buttonSize-buttonHeight-bottomPadding, buttonSize, buttonSize);
  _cancelButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.4];
  _cancelButton.transform=CGAffineTransformMakeRotation(M_PI / 2);
  _cancelButton.layer.cornerRadius = buttonSize/2;
  _cancelButton.contentEdgeInsets = UIEdgeInsetsMake(15, 15, 15, 15);
  
  [self.view addSubview:_cancelButton];
  
  self.torchButton = [[UIButton alloc] init];
  [self.torchButton addTarget:self
                       action:@selector(toggleFlashlight:)
             forControlEvents:UIControlEventTouchUpInside];
  
  NSString * torchBase64String = @"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAQAAABpN6lAAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QAAKqNIzIAAAAJcEhZcwAADdcAAA3XAUIom3gAAAAHdElNRQfhCxMVAzOqoPipAAADM0lEQVR42u2dv2sTcRyG38RWzGYHhxYHp+B+Lk7iIlhFXZvdPeAouOuS1X/AVCiiCBU6OjgIOffG+gvEgCIqlsQi9JxEbC/XJt8fz136eTJecve+T+6Su8t9czX5oqmWEiVa9DbHfAZKlaqrfuDlTERNbQ2VRXwM1VaNrv2v/nrU8n8f62VR0EbqZ8rUpqtLUjPyyv//htB0jV93FrCiBia/oRYv4BxWX5IS1xm4f4x8Cv7FV8RAS7SADKzvoYH7JlBxTAAdgMYE0AFoTAAdwDAMwzAMo7q8ws4IZsr0wjW++57gFqrfeenuAt6YAJLXvADbBFABJVgDPmobrP+DF5BpAxPwyH0WPk6IPKmyAB8/MJ/UZ80D9T/ojPtMfKwB3/UcqO/l/fd1TvAxIuAhstRclrQT/ShgzU/0Y17m8lMLOh9V+UjX3L8CfbKgr1Hf/zt04f3EvFLorU7QdfdzXFuR6v/SRbpsPjci1b9MFx3P7eD1d3SFLlnM3cD1r9IFD+Z+wJW/AvWluh4EqT/UJbraYZnTmvf627pA12IV3KQrTa7gqcf6z+g603BKXzzV/+Z6NSjFiicB9+gi07PhRcBZusb0XPdQ3/nXP5J5D58Dt8JGDHuZ3G8Pp60C//AS+jrBl85zeBc24FxgAe/HTulrVT2lkhIlao0d/RNYQGhO527Xu+rsGWnUUEe7uc+tOPXc+su5z13OVVB59lfqjH1u5ygI2CwYZtfQZmwB8a8WX9Vo7LSRurHjxBfQK5yaRs8TnL2rdPEow8XZ3wRKRnwBicPUmRBQPNY4uoDwlPxrML6AI78jZLvC5ToYCv83JOMqHPZwOHBCTkBJEtqOEB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgTQAWhMAB2AxgQEX8IAfHUpBLgNhg0+lDa8gJ7Tq2dgLLHLbXk93Fa3DEz/d6ttOrofpr01d2lure1DwaQ3Z492c/V4jptqKVFy4F2KB0qVqqt+nFh/ADjJgLiaxweIAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDE3LTExLTE5VDIxOjAzOjUxKzAxOjAwdhzbkgAAACV0RVh0ZGF0ZTptb2RpZnkAMjAxNy0xMS0xOVQyMTowMzo1MSswMTowMAdBYy4AAAAZdEVYdFNvZnR3YXJlAHd3dy5pbmtzY2FwZS5vcmeb7jwaAAAAAElFTkSuQmCCconv";
  
  NSURL *torchImageUrl = [NSURL URLWithString:torchBase64String];
  NSData *torchImageData = [NSData dataWithContentsOfURL:torchImageUrl];
  UIImage *torchIcon = [UIImage imageWithData:torchImageData];
  [self.torchButton setImage:torchIcon
                    forState:UIControlStateNormal];
  
  self.torchButton.frame = CGRectMake(screenWidth-buttonSize-screenOffset, screenHeight-screenOffset-buttonSize-buttonHeight-bottomPadding, buttonSize, buttonSize);
  self.torchButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.4];
  self.torchButton.transform=CGAffineTransformMakeRotation(M_PI / 2);
  self.torchButton.layer.cornerRadius = buttonSize/2;
  self.torchButton.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
  
  [self.view addSubview:self.torchButton];
  
  [self.view addSubview:bcView];
  [bcView addSubview:self.txtBarcode];
  [bcView addSubview:submitBarcode];
  
  [self.view addSubview:verticalLine];
  [self.view addSubview:horizontalLine];
  
  self.imageView = [[UIImageView alloc] initWithImage:nil];
  
  UIView *catView = [[UIView alloc] initWithFrame:CGRectMake(0,0,frameWidth,frameHeight)];
  self.imageView.frame = catView.bounds;
  
  // add the imageview to the superview
  [catView addSubview:self.imageView];
  
  //add the view to the main view
  
  [self.view addSubview:catView];
  
}

- (void)handleSingleTap:(UITapGestureRecognizer *) sender
{
    [self.view endEditing:YES];
}

-(BOOL) textFieldShouldReturn:(UITextField *)textField
{
  [self cleanupCaptureSession];
  [self->_session stopRunning];
  [self->delegate sendResult:self.txtBarcode.text];

   return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch{
  BOOL isControlTapped = [touch.view isKindOfClass:[UIButton class]];
  return !isControlTapped;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:.3];
  [UIView setAnimationBeginsFromCurrentState:TRUE];
  self.view.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y -260., self.view.frame.size.width, self.view.frame.size.height);
  
  UITextInputAssistantItem* item = [textField inputAssistantItem];
  item.leadingBarButtonGroups = @[];
  item.trailingBarButtonGroups = @[];
  
  [UIView commitAnimations];
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
  [UIView beginAnimations:nil context:nil];
  [UIView setAnimationDuration:.3];
  [UIView setAnimationBeginsFromCurrentState:TRUE];
  self.view.frame = CGRectMake(self.view.frame.origin.x, 0, self.view.frame.size.width, self.view.frame.size.height);
  
  [UIView commitAnimations];
}

-(void)submitTextBarcode:(id)sender {
  [self cleanupCaptureSession];
  [self->_session stopRunning];
  [self->delegate sendResult:self.txtBarcode.text];
}

#pragma mark - Helper Functions

- (void)focusAtPoint:(id) sender{
  NSLog(@"captured touch");
  CGPoint touchPoint = [(UITapGestureRecognizer*)sender locationInView:self.view];
  double focus_x = touchPoint.x/self.previewLayer.frame.size.width;
  double focus_y = (touchPoint.y+66)/self.previewLayer.frame.size.height;
  
  NSError *error;
  NSArray *devices = [AVCaptureDevice devices];
  
  for (AVCaptureDevice *device in devices){
    NSLog(@"Device name: %@", [device localizedName]);
    if ([device hasMediaType:AVMediaTypeVideo]) {
      
      AVCaptureDevicePosition selectedPos = AVCaptureDevicePositionBack;
      if([self.cameraFacing isEqualToNumber:@1]) {
        selectedPos = AVCaptureDevicePositionFront;
      }
      if ([device position] == selectedPos) {
        NSLog(@"Device position : back");
        CGPoint point = CGPointMake(focus_y, 1-focus_x);
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [device lockForConfiguration:&error]){
          [device setFocusPointOfInterest:point];
          
          for (UIView *subView in self.view.subviews)
          {
            if (subView.tag == 99)
            {
              [subView removeFromSuperview];
            }
          }
          
          CGRect rect = CGRectMake(touchPoint.x-30, touchPoint.y-30, 60, 60);
          UIView *focusRect = [[UIView alloc] initWithFrame:rect];
          focusRect.layer.borderColor = [UIColor colorWithRed:0.98 green:0.80 blue:0.18 alpha:.7].CGColor;
          focusRect.layer.borderWidth = 1;
          focusRect.tag = 99;
          [self.view addSubview:focusRect];
          
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [focusRect removeFromSuperview];
          });
          
          [device setFocusMode:AVCaptureFocusModeAutoFocus];
          [device unlockForConfiguration];
        }
      }
    }
  }
}

static inline double radians (double degrees) {return degrees * M_PI/180;}
- (UIImage*) rotateImage:(UIImage*)src toOrientation:(UIImageOrientation) orientation
{
  UIGraphicsBeginImageContext(src.size);
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  if (orientation == UIImageOrientationRight) {
    CGContextRotateCTM (context, radians(90));
  } else if (orientation == UIImageOrientationLeft) {
    CGContextRotateCTM (context, radians(-90));
  } else if (orientation == UIImageOrientationDown) {
    // NOTHING
  } else if (orientation == UIImageOrientationUp) {
    CGContextRotateCTM (context, radians(90));
  }
  
  [src drawAtPoint:CGPointMake(0, 0)];
  
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect
{
  //CGRect CropRect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height+15);
  
  CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
  UIImage *cropped = [UIImage imageWithCGImage:imageRef];
  CGImageRelease(imageRef);
  
  return cropped;
}

- (void) toggleFlashlight:(id)sender
{
  // check if flashlight available
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass != nil) {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch] && [device hasFlash]){
      
      [device lockForConfiguration:nil];
      if (device.torchMode == AVCaptureTorchModeOff)
      {
        self.torchButton.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
        [device setTorchMode:AVCaptureTorchModeOn];
        [device setFlashMode:AVCaptureFlashModeOn];
        //torchIsOn = YES;
      }
      else
      {
        self.torchButton.backgroundColor = [UIColor colorWithWhite:1 alpha:.4];
        [device setTorchMode:AVCaptureTorchModeOff];
        [device setFlashMode:AVCaptureFlashModeOff];
        // torchIsOn = NO;
      }
      [device unlockForConfiguration];
    }
  } }

- (void) closeView :(id)sender{
  
  [ self cleanupCaptureSession];
  
  [_session stopRunning];
  
  [delegate closeScanner];
}


- (void)updateCameraSelection {
  [self.session beginConfiguration];
  
  // Remove old inputs
  NSArray *oldInputs = [self.session inputs];
  for (AVCaptureInput *oldInput in oldInputs) {
    [self.session removeInput:oldInput];
  }
  
  AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionBack;
  if([self.cameraFacing isEqualToNumber:@1]) {
    desiredPosition = AVCaptureDevicePositionFront;
  }
  AVCaptureDeviceInput *input = [self captureDeviceInputForPosition:desiredPosition];
  if (!input) {
    // Failed, restore old inputs
    for (AVCaptureInput *oldInput in oldInputs) {
      [self.session addInput:oldInput];
    }
  } else {
    // Succeeded, set input and update connection states
    [self.session addInput:input];
  }
  [self.session commitConfiguration];
}

- (AVCaptureDeviceInput *)captureDeviceInputForPosition:(AVCaptureDevicePosition)desiredPosition {
  for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
    if (device.position == desiredPosition) {
      NSError *error = nil;
      AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                          error:&error];
      if (error) {
        NSLog(@"Could not initialize for AVMediaTypeVideo for device %@", device);
      } else if ([self.session canAddInput:input]) {
        return input;
      }
    }
  }
  return nil;
}



@end


