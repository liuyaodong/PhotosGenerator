//
//  PhotosGeneratingViewController.m
//  PhotosGenerator
//
//  Created by LiuYaodong on 1/18/17.
//  Copyright © 2017 ByteDance. All rights reserved.
//

#import "PhotosGeneratingViewController.h"
@import Photos;

@interface PhotosGeneratingViewController ()<UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *mediaCountLabel;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak, nonatomic) IBOutlet UISwitch *randomDateSwitch;

@end

@implementation PhotosGeneratingViewController
{
    BOOL                _isGenerating;
    BOOL                _randomDate;
    NSInteger           _count;
    dispatch_queue_t    _drawingQueue;
    NSOperation         *_operation;
    NSDateFormatter     *_formatter;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _randomDate = YES;
    _isGenerating = NO;
    _drawingQueue = dispatch_queue_create("com.bytedance.drawing", DISPATCH_QUEUE_SERIAL);
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        _count = self.textField.text.integerValue;
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self.view addGestureRecognizer:tap];
    
    _formatter = [NSDateFormatter new];
    _formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger count = [PHAsset fetchAssetsWithOptions:nil].count;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mediaCountLabel.text = [NSString stringWithFormat:@"当前media: %lu", (unsigned long)count];
        });
    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_operation cancel];
}

- (void)tapped:(id)sender
{
    [self.textField resignFirstResponder];
}

- (IBAction)actionButtonClicked:(id)sender {
    if (_count <= 0) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"输入错误" message:@"请输入有意义的数字" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { }]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    _isGenerating = !_isGenerating;
    [_actionButton setTitle:_isGenerating ? @"停止生成" : @"开始生成" forState:UIControlStateNormal];
    
    if (_isGenerating) {
        self.textField.enabled = NO;
        self.randomDateSwitch.enabled = NO;
        _operation = [self generateImageWithCount:_count progress:^(NSUInteger completed, NSUInteger failed) {
            self.progressLabel.text = [NSString stringWithFormat:@"已经生成：%lu/%ld", (unsigned long)completed, (long)_count];
            self.errorLabel.text = [NSString stringWithFormat:@"出错：%lu", (unsigned long)failed];
        } completion:^{
            _isGenerating = NO;
            self.textField.enabled = YES;
            [_actionButton setTitle:@"开始生成" forState:UIControlStateNormal];
        }];
    } else {
        [_operation cancel];
        self.textField.enabled = YES;
        self.randomDateSwitch.enabled = YES;
    }
}

- (NSURL *)replaceTakenDateOfImage:(UIImage *)image withDate:(NSDate *)date
{
    NSString *dateString = [_formatter stringFromDate:date];
    NSDictionary *imageMeta = @{};
    if (_randomDate) {
        imageMeta = @{(NSString *)kCGImagePropertyExifDictionary:
              @{
                  (NSString *)kCGImagePropertyExifDateTimeOriginal: dateString,
                  (NSString *)kCGImagePropertyExifDateTimeDigitized: dateString
                  }
          };
    }
    NSData *imageData = UIImagePNGRepresentation(image);
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    CFStringRef UTI = CGImageSourceGetType(source);
    NSURL *tmpURL = [[[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject] URLByAppendingPathComponent:@"temp"] URLByAppendingPathExtension:@"png"];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef) tmpURL, UTI, 1, NULL);
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)imageMeta);
    CGImageDestinationFinalize(destination);
    CFRelease(source);
    CFRelease(destination);
    return tmpURL;
 
}

- (NSOperation *)generateImageWithCount:(NSUInteger)count progress:(void (^)(NSUInteger completed, NSUInteger failed))progress completion:(void (^)(void))completion {
    
    NSOperation *operation = [NSOperation new];
    
    NSDate *base = [_formatter dateFromString:@"1990:01:01 00:00:00"];
    NSDate *now = [NSDate date];
    uint32_t interval = [now timeIntervalSinceDate:base];
    
    dispatch_async(_drawingQueue, ^{
        NSUInteger failed = 0;
        NSUInteger completed = 0;
        
        NSDictionary *attrsDictionary = @{ NSFontAttributeName: [UIFont systemFontOfSize:1200.0], NSForegroundColorAttributeName: [UIColor whiteColor] };
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init] ;
        [paragraphStyle setAlignment:NSTextAlignmentRight];
        NSDictionary *dateStringAttributes = @{ NSFontAttributeName: [UIFont systemFontOfSize:120.0], NSForegroundColorAttributeName: [UIColor whiteColor], NSParagraphStyleAttributeName: paragraphStyle};
        while (completed != count && !operation.isCancelled) {
            @autoreleasepool {
                CGSize size = (arc4random_uniform(2) == 0) ? CGSizeMake(1280, 1960) : CGSizeMake(1960, 1280);
                UIGraphicsBeginImageContextWithOptions(size, YES, 0);
                [[UIColor colorWithRed:arc4random_uniform(255)/255.0 green:arc4random_uniform(255)/255.0 blue:arc4random_uniform(255)/255.0 alpha:1] setFill];
                NSDate *takenDate = [base dateByAddingTimeInterval:arc4random_uniform(interval)];
                
                CGContextRef ctx = UIGraphicsGetCurrentContext();
                CGRect rect = (CGRect){0, 0, size};
                CGContextFillRect(ctx, rect);
                
                CGRect r = CGRectMake(rect.origin.x,
                                      rect.origin.y + (rect.size.height - size.height)/2.0,
                                      rect.size.width,
                                      size.height);
                CGRect dateRect = CGRectMake(rect.origin.x, rect.origin.y / 2.0, rect.size.width, rect.size.height / 2.0);
                [[NSString stringWithFormat:@"%d", (int)completed] drawInRect:r withAttributes:attrsDictionary];
                [[_formatter stringFromDate:takenDate] drawInRect:dateRect withAttributes:dateStringAttributes];
                UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                NSURL *imageURL = [self replaceTakenDateOfImage:image withDate:takenDate];
                NSError *error = nil;
                if ([[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:imageURL];
                } error:&error]) {
                    completed++;
                } else {
                    failed++;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                progress(completed, failed);
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    });
    return operation;
}

- (IBAction)randomDateSwitchChanged:(id)sender {
    _randomDate = !_randomDate;
}


@end
