//
//  XXDownloadView.m
//  XXDownloader
//
//  Created by uku on 2019/4/28.
//  Copyright © 2019 uku. All rights reserved.
//

#import "XXDownloadCell.h"
#import "Classes/XXDownloader.h"

@interface XXDownloadCell ()
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (assign, nonatomic) XXDownloadTaskID taskId;
@end

@implementation XXDownloadCell

- (void)setDownloadURL:(NSString *)downloadURL {
    self.progressView.progress = 0;
    _downloadURL = downloadURL;
    self.taskId = [[XXDownloader sharedDownloader] downloadTaskWith:self.downloadURL stateChanged:^(NSURLSessionTaskState state) {
        
        NSString *stateStr = nil;
        switch (state) {
            case NSURLSessionTaskStateRunning:
                stateStr = @"Running";
                break;
            case NSURLSessionTaskStateSuspended:
                stateStr = @"Suspended";
                break;
            case NSURLSessionTaskStateCanceling:
                stateStr = @"Canceling";
                break;
            case NSURLSessionTaskStateCompleted:
                stateStr = @"Completed";
                break;
            default:
                stateStr = @"Unknown";
                break;
        }
        NSLog(@"observeValueForKeyPath:newState:%@-taskIdentifier:%zd", stateStr, self.taskId);
        
    } progress:^(CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressView.progress = progress;
        });
    } completion:^(NSError *error, NSString *filePath) {
        NSLog(@"------------------------");
        NSLog(@"completionWithError:%@--filePath:%@", error.localizedDescription, filePath);
    }];
    
    
}

- (IBAction)onResumeBtnClicked:(UIButton *)sender {
    [[XXDownloader sharedDownloader] resume:self.taskId];
}
- (IBAction)onSuspendBtnClicked:(UIButton *)sender {
    [[XXDownloader sharedDownloader] suspend:self.taskId];
}
- (IBAction)onCancelBtnClicked:(UIButton *)sender {
    [[XXDownloader sharedDownloader] cancel:self.taskId];
}

@end
