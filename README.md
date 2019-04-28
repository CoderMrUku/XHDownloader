# XHDownloader

> 基于NSURLSessionDownloadTask封装的下载工具类。
> 

## 现有功能

- 暂停 / 继续
- 取消 / 继续
- 高并发下载多个文件，线程安全

## 未实现

- 离线下载
- 后台下载

## Screenshot
![shot](https://github.com/CoderMrUku/XHDownloader/blob/master/screenshot.png)

## 使用步骤：

```objective-c
// 创建下载任务
XXDownloadTaskID taskId = 
[[XXDownloader sharedDownloader] downloadTaskWith:self.downloadURL
                                     stateChanged:^(NSURLSessionTaskState state) {}
                                         progress:^(CGFloat progress) {}
                                       completion:^(NSError *error, NSString *filePath) {}
 ];

// 开始 / 继续任务
[[XXDownloader sharedDownloader] resume:taskId];

// 暂停任务
[[XXDownloader sharedDownloader] suspend:taskId];

// 取消任务
[[XXDownloader sharedDownloader] cancel:taskId];
```

