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

@end

@implementation PhotosGeneratingViewController
{
    BOOL                _isGenerating;
    NSInteger           _count;
    dispatch_queue_t    _drawingQueue;
    NSOperation         *_operation;
}

- (void)dealloc {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _isGenerating = NO;
    _drawingQueue = dispatch_queue_create("com.bytedance.drawing", DISPATCH_QUEUE_SERIAL);
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        _count = self.textField.text.integerValue;
    }];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSUInteger count = [PHAsset fetchAssetsWithOptions:nil].count;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mediaCountLabel.text = [NSString stringWithFormat:@"当前media: %lu", count];
        });
    });
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
        _operation = [self generateImageWithCount:_count progress:^(NSUInteger completed, NSUInteger failed) {
            self.progressLabel.text = [NSString stringWithFormat:@"已经生成：%lu/%ld", completed, _count];
            self.errorLabel.text = [NSString stringWithFormat:@"出错：%lu", failed];
        } completion:^{
            _isGenerating = NO;
            self.textField.enabled = YES;
            [_actionButton setTitle:@"开始生成" forState:UIControlStateNormal];
        }];
    } else {
        [_operation cancel];
        self.textField.enabled = YES;
    }
}


- (NSOperation *)generateImageWithCount:(NSUInteger)count progress:(void (^)(NSUInteger completed, NSUInteger failed))progress completion:(void (^)(void))completion {
    
    NSOperation *operation = [NSOperation new];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    
    NSDate *base = [formatter dateFromString:@"1990-01-01"];
    NSDate *now = [NSDate date];
    uint32_t interval = [now timeIntervalSinceDate:base];
    
    dispatch_async(_drawingQueue, ^{
        NSUInteger failed = 0;
        NSUInteger completed = 0;
        
        NSDictionary *attrsDictionary = @{ NSFontAttributeName: [UIFont systemFontOfSize:1200.0], NSForegroundColorAttributeName: [UIColor whiteColor] };
        while (completed != count && !operation.isCancelled) {
            CGSize size = (arc4random_uniform(2) == 0) ? CGSizeMake(1280, 1960) : CGSizeMake(1960, 1280);
            UIGraphicsBeginImageContextWithOptions(size, YES, 0);
//            [[UIColor colorWithHue:(arc4random_uniform(1000) + arc4random_uniform(1000))/2000.0 saturation:1 brightness:1 alpha:1] setFill];
            [[UIColor colorWithRed:arc4random_uniform(255)/255.0 green:arc4random_uniform(255)/255.0 blue:arc4random_uniform(255)/255.0 alpha:1] setFill];
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGRect rect = (CGRect){0, 0, size};
            CGContextFillRect(ctx, rect);
            
            CGRect r = CGRectMake(rect.origin.x,
                                  rect.origin.y + (rect.size.height - size.height)/2.0,
                                  rect.size.width,
                                  size.height);
            [[NSString stringWithFormat:@"%d", (int)completed] drawInRect:r withAttributes:attrsDictionary];
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            NSDate *creationDate = [base dateByAddingTimeInterval:arc4random_uniform(interval)];
            NSError *error = nil;
            if ([[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
                PHAssetChangeRequest *request = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                request.creationDate = creationDate;
            } error:&error]) {
                completed++;
            } else {
                failed++;
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


@end
