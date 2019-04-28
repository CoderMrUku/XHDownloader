//
//  XXDownloader.m
//  XXDownloader
//
//  Created by uku on 2019/4/27.
//  Copyright © 2019 uku. All rights reserved.
//

#import "XXDownloader.h"

@interface XXDownloader()<NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@property (strong, nonatomic) NSURLSession *session;
@property (strong, atomic) NSMutableDictionary<NSNumber *, XXDownloadProgress> *progressDict;
@property (strong, atomic) NSMutableDictionary<NSNumber *, XXDownloadCompletion> *completionDict;
@property (strong, atomic) NSMutableDictionary<NSNumber *, XXDownloadStateChanged> *taskStateChangeDict;
@property (strong, atomic) NSMutableDictionary<NSNumber *, NSURLSessionDownloadTask *> *downloadTasks;
@end

@implementation XXDownloader

+ (instancetype)sharedDownloader
{
    static XXDownloader *sharedDownloader_ = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDownloader_ = [[[self class] alloc] init];
    });
    return sharedDownloader_;
}

- (NSURLSession *)session {
    @synchronized (self) {
        if (!_session) {
            NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
            _session = [NSURLSession sessionWithConfiguration:config
                                                     delegate:self
                                                delegateQueue:nil];
        }
    }
    return _session;
}

/**
 *创建单例对象
 *
 @return 该方法中的代码也是线程安全的，所有子成员只创建一份。
 */
- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _progressDict = [NSMutableDictionary dictionary];
        _completionDict = [NSMutableDictionary dictionary];
        _downloadTasks = [NSMutableDictionary dictionary];
        _taskStateChangeDict = [NSMutableDictionary dictionary];
        
    }
    return self;
}

- (XXDownloadTaskID)downloadTaskWith:(NSString *)urlString
                        stateChanged:(XXDownloadStateChanged)stateChangedBlock
                            progress:(XXDownloadProgress)progress
                          completion:(XXDownloadCompletion)completion
{
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSAssert(url, @"URL is illegal");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    
    self.downloadTasks[@(task.taskIdentifier)] = task;
    self.completionDict[@(task.taskIdentifier)] = completion;
    self.progressDict[@(task.taskIdentifier)] = progress;
    self.taskStateChangeDict[@(task.taskIdentifier)] = stateChangedBlock;
    
    return task.taskIdentifier;
}

#pragma mark - Control task

- (void)resume :(XXDownloadTaskID)downloadTaskID {
    
    NSURLSessionDownloadTask *task = self.downloadTasks[@(downloadTaskID)];
    if (task) {
        if (task.state == NSURLSessionTaskStateRunning) return;
        [self internalResumeTask:task];
        return;
    }
    
    NSURL *resumeDataURL = [self resumeDataURLOfTask:downloadTaskID];
    
    // 这是一个下载完成的任务
    if (![[NSFileManager defaultManager] fileExistsAtPath:resumeDataURL.path]) {
        return;
    }
    
    // 这是一个被取消的任务
    task = [self recreateTaskWithResumeDataURL:resumeDataURL oldTaskID:downloadTaskID];
    
    [self internalResumeTask:task];
    
}

- (void)suspend:(XXDownloadTaskID)downloadTaskID {
    [self.downloadTasks[@(downloadTaskID)] suspend];
}

- (void)cancel :(XXDownloadTaskID)downloadTaskID {
    NSURLSessionDownloadTask *task = self.downloadTasks[@(downloadTaskID)];
    NSLog(@"%zd", task.state);
    
    // a task never started cannot be cacelled
    if (task.state != NSURLSessionTaskStateCanceling) {
        
    }
    
    [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        
        NSURL *destURL = [self resumeDataURLOfTask:downloadTaskID];

        // 将resumeData写入沙盒
        NSError *writtenError;
        NSAssert([resumeData writeToURL:destURL options:kNilOptions error:&writtenError], writtenError.localizedDescription);
        NSLog(@"createResumeDataAtPath:%@", destURL.path);
    }];
}

#pragma mark - Other

/**
 真正的开始任务
 */
- (void)internalResumeTask:(NSURLSessionDownloadTask *)task {
    if ([task respondsToSelector:@selector(state)]) {
        [task addObserver:self forKeyPath:NSStringFromSelector(@selector(state)) options:NSKeyValueObservingOptionNew context:nil];
    }
    [task resume];
}

/**
 使用reuseData重新构造downloadTask
 
 @param url reuseData的本地URL
 @param oldTaskId 被取消的taskID
 @return a downloadTask instance
 */
- (NSURLSessionDownloadTask *)recreateTaskWithResumeDataURL:(NSURL *)url oldTaskID:(XXDownloadTaskID)oldTaskId {
    
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithResumeData:[NSData dataWithContentsOfURL:url]];
    
    // 新建的task的taskIdentifier已经改变，这里强制赋值旧的，以便taskIdentifier相对应的其它属性取得联系。
    [task setValue:@(oldTaskId) forKeyPath:NSStringFromSelector(@selector(taskIdentifier))];
    
    // retain in Dictionary
    self.downloadTasks[@(oldTaskId)] = task;
    
    // 删除resumedata
    NSError *deleteError = nil;
    NSAssert([[NSFileManager defaultManager] removeItemAtURL:url error:&deleteError], deleteError.localizedDescription);
    return task;
}

- (NSURL *)resumeDataURLOfTask:(XXDownloadTaskID)taskId {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *cancelledURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"Cancelled"];
    
    // create dirctory of ~/Document/Cancelled/
    if (![fileManager fileExistsAtPath:cancelledURL.path isDirectory:NULL]) {
        NSError *creationError;
        NSAssert([fileManager createDirectoryAtURL:cancelledURL withIntermediateDirectories:YES attributes:nil error:&creationError], creationError.localizedDescription);
    }
    return [cancelledURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%zd.cancelled", taskId]];
}

- (NSURL *)destinationURLForDownloadTask:(NSURLSessionDownloadTask *)task {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL *destionationDirectory = [documentURL URLByAppendingPathComponent:@"Completed"];
    if (![fileManager createDirectoryAtURL:destionationDirectory withIntermediateDirectories:YES attributes:nil error:nil]) {
        // 目标文件夹创建失败
    }
    NSURL *destinationURL = [destionationDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%zd.%@", task.taskIdentifier, [task.response.MIMEType lastPathComponent]]];
    
    // 处理目标文件存在的情况
    if ([fileManager fileExistsAtPath:destinationURL.path]) {
        
        // 尝试删除之前的旧文件，这里只是一个示范，具体操作看需求。
        NSError *deleteError;
        if ([fileManager removeItemAtURL:destinationURL error:&deleteError]) {
            NSLog(@"------------------------");
            NSLog(@"removeItemAtURLSuccess:%@", destinationURL.absoluteString);
        }
    }
    
    return destinationURL;
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([object isKindOfClass:[NSURLSessionDownloadTask class]]) {
        
        NSURLSessionDownloadTask *task = (NSURLSessionDownloadTask *)object;
        
        XXDownloadStateChanged stateChangedBlock = self.taskStateChangeDict[@(task.taskIdentifier)];
        if (stateChangedBlock) {
            stateChangedBlock([[change objectForKey:NSKeyValueChangeNewKey] integerValue]);
        }
    }
}

#pragma mark - DataDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    
    // remove observer of receiver that has completed or been cancelled.
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
    
    // release task that has completed or been cancelled.
    [self.downloadTasks removeObjectForKey:@(task.taskIdentifier)];
    
    // Code：-999 "cancelled" 被取消的任务
    if (error.code != -999) {
        [self.completionDict removeObjectForKey:@(task.taskIdentifier)];
        [self.progressDict removeObjectForKey:@(task.taskIdentifier)];
        [self.taskStateChangeDict removeObjectForKey:@(task.taskIdentifier)];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    // 验证请求状态，是否成功
    NSHTTPURLResponse *res = (NSHTTPURLResponse *)downloadTask.response;

    XXDownloadCompletion downloadCompletion = [self.completionDict objectForKey:@(downloadTask.taskIdentifier)];
    
    // 成功状态码： 200...299
    if (res.statusCode < 200 || res.statusCode > 299) {
        if (downloadCompletion) {
            downloadCompletion([NSError errorWithDomain:NSNetServicesErrorDomain code:res.statusCode userInfo:@{NSLocalizedDescriptionKey : @"下载不成功"}], nil);
        }
        return;
    }
    
    NSURL *destinationURL = [self destinationURLForDownloadTask:downloadTask];
    
    // move file to document directory.
    NSError *writtenError;
    if ([[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&writtenError]) {
        if (downloadCompletion) {
            downloadCompletion(nil, destinationURL.absoluteString);
        }
    }
    else {
        if (downloadCompletion) {
            downloadCompletion(writtenError, nil);
        }
    }
    
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    XXDownloadProgress progress = [self.progressDict objectForKey:@(downloadTask.taskIdentifier)];
    
    if (progress) {
        progress(1.0 * totalBytesWritten / totalBytesExpectedToWrite);
    }
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"------------------------");
    NSLog(@"didResumeAtOffset-%lld", fileOffset);
}


@end
