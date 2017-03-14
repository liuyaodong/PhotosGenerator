//
//  ViewController.m
//  PhotosGenerator
//
//  Created by LiuYaodong on 1/18/17.
//  Copyright © 2017 ByteDance. All rights reserved.
//

#import "ViewController.h"
@import Photos;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"0.2.0";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 1) {
        PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithOptions:nil];
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest deleteAssets:result];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            
        }];
    }
}



@end
