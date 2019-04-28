//
//  XXDownloader.h
//  XXDownloader
//
//  Created by uku on 2019/4/27.
//  Copyright © 2019 uku. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^XXDownloadCompletion)(NSError *, NSString *);
typedef void(^XXDownloadProgress)(CGFloat );
typedef void(^XXDownloadStateChanged)(NSURLSessionTaskState);

typedef NSUInteger XXDownloadTaskID;

@interface XXDownloader : NSObject

+ (instancetype)sharedDownloader;

/**
 创建下载任务

 @param urlString 地址
 @param stateChangedBlock 任务的状态改变回调
 @param progress 下载进度
 @param completion 完成回调
 @return 任务Id
 */
- (XXDownloadTaskID)downloadTaskWith:(NSString *)urlString
                           stateChanged:(XXDownloadStateChanged)stateChangedBlock
                            progress:(XXDownloadProgress)progress
                          completion:(XXDownloadCompletion)completion;

/**
 执行任务
 
 @param downloadTaskID TaskID
 */
- (void)resume :(XXDownloadTaskID)downloadTaskID;

/**
 暂停任务
 
 @param downloadTaskID TaskID
 */
- (void)suspend:(XXDownloadTaskID)downloadTaskID;

/**
 取消任务

 @param downloadTaskID TaskID
 */
- (void)cancel :(XXDownloadTaskID)downloadTaskID;


@end
