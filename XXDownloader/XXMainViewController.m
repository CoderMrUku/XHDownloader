//
//  XXMainViewController.m
//  XXDownloader
//
//  Created by uku on 2019/4/28.
//  Copyright © 2019 uku. All rights reserved.
//

#import "XXMainViewController.h"
#import "XXDownloadCell.h"

static NSString *url = @"http://mvvideo2.meitudata.com/5785a7e3e6a1b824.mp4";

@interface XXMainViewController ()
@property (strong, nonatomic) NSMutableArray<NSString *> *urlPaths;
@end

@implementation XXMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (IBAction)onResetBarButtonItemClicked:(UIBarButtonItem *)sender {
    [self.tableView reloadData];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    [fileManager removeItemAtURL:documentURL error:NULL];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.urlPaths.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    XXDownloadCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([XXDownloadCell class]) forIndexPath:indexPath];
    cell.downloadURL = self.urlPaths[indexPath.row];
    return cell;
}

- (NSMutableArray<NSString *> *)urlPaths {
    if (!_urlPaths) {
        _urlPaths = [NSMutableArray arrayWithCapacity:6];
        [_urlPaths addObject:url];
        [_urlPaths addObject:url];
        [_urlPaths addObject:url];
        [_urlPaths addObject:@"https://cdn.pixabay.com/photo/2017/02/17/23/15/duiker-island-2076042_960_720.jpg"];
        [_urlPaths addObject:@"https://cdn.pixabay.com/photo/2019/04/10/23/51/dog-4118585__340.jpg"];
        [_urlPaths addObject:@"https://cdn.pixabay.com/photo/2017/01/20/13/01/africa-1994846__340.jpg"];
    }
    return _urlPaths;
}

@end
