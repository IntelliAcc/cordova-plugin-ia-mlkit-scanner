// View controller demonstraing how to use the barcode detector with the AVFoundation
// video pipeline.
@protocol senddataProtocol <NSObject>

-(void)closeScanner;
-(void)sendResult:(NSString *)result;
-(void)errorOccurred;

@end

@interface MLKitCameraViewController : UIViewController<UITextFieldDelegate,UIGestureRecognizerDelegate>

@property(nonatomic,assign)id delegate;
@property(nonatomic,assign) NSNumber *barcodeFormats;
@property(nonatomic,assign) CGFloat scanAreaWidth;
@property(nonatomic,assign) CGFloat scanAreaHeight;

@end

