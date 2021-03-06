//
//  KSYPhotoPickerController.m
//  KSYPhotoPickerKit
//
//  Created by sunyazhou on 2017/12/1.
//  Copyright © 2017年 ksyun.com. All rights reserved.
//

#import "KSYPhotoPickerController.h"
#import "KSYAlbumViewController.h"
#import "KSYPhotoManager.h"
#import <sys/utsname.h>


static const NSUInteger kMaxRetryLimit = 100;
@interface KSYPhotoPickerController ()

@property (nonatomic, strong) UILabel  *tipLabel;   //未授权提示
@property (nonatomic, strong) UIButton *settingBtn; //未授权设置按钮

@property (nonatomic, assign) NSUInteger authCount; //授权失败计数
@end

@implementation KSYPhotoPickerController

- (instancetype)init{
    self = [super init];
    if (self) {
        self = [self initWithDelegate:nil];
    }
    return self;
}

- (instancetype)initWithDelegate:(id <KSYPhotoPickerControllerDelegate>) delegate{
    //内部 root 控制器
    KSYAlbumViewController *albumPickerVC = [[KSYAlbumViewController alloc] init];
    self = [super initWithRootViewController:albumPickerVC];
    if (self) {
        self.authCount = 0;
        self.pickerDelegate = delegate;
        [self configDefaultSetting]; //默认配置
        [self pushPhotoPickerVCWhenAuthed];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationBar.translucent = NO;
    self.automaticallyAdjustsScrollViewInsets = NO;
    
}

#pragma mark -
#pragma mark - private methods 私有方法

- (void)configDefaultSetting{
    self.navigationBar.tintColor = [UIColor whiteColor];
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.autoDismiss = YES;
    self.pushPhotoPickerVC = YES;
    self.allowPickingPhoto = YES;
    self.allowPickingVideo = YES;
    self.selectedModels = [NSMutableArray array];
    
    [self configNavigationAppearance];
}

- (void)configNavigationAppearance{
    NSMutableDictionary *textAttrs = [NSMutableDictionary dictionary];
    if (self.navigationBarTitleColor) {
        textAttrs[NSForegroundColorAttributeName] = self.navigationBarTitleColor;
    } else {
        textAttrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
    }
    self.navigationBar.titleTextAttributes = textAttrs;
    
    if (self.navigationBarBgColor) {
        self.navigationBar.barTintColor = self.navigationBarBgColor;
    } else {
        self.navigationBar.barTintColor = kKSYPPKRGBA(34, 34, 34, 1);
    }
}

- (void)pushPhotoPickerVCWhenAuthed{
    if (![[KSYPhotoManager defaultManager] authorizationStatusAuthorized]) {
        //授权失败
        NSLog(@"授权失败");
        [self configTipSubviews:YES];
        //TODO:1.增加探测PHAuthorizationStatus 授权变化并自动push 逻辑
        if (self.authCount > kMaxRetryLimit) {
            self.authCount = 0;
        } else {
            self.authCount += 1;
            [self performSelector:@selector(pushPhotoPickerVCWhenAuthed) withObject:self afterDelay:0.5];
        }
    } else {
        if (self.authCount != 0) {
            //走到这里说明授权失败过
            [self hanldeAuthSuccess];
            self.authCount = 0;
        }
        NSLog(@"授权成功");
        [self configTipSubviews:NO];
        [self pushToPhotoPickerVC];
    }
}

- (void)configTipSubviews:(BOOL)isShow{
    if (isShow) {
        [self.tipLabel removeFromSuperview];
        self.tipLabel = nil;
        [self.settingBtn removeFromSuperview];
        self.settingBtn = nil;
        _tipLabel = [[UILabel alloc] init];
        
        _tipLabel.frame = CGRectMake(8, 120, CGRectGetWidth(self.view.frame) - 16, 60);
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.numberOfLines = 0;
        _tipLabel.font = [UIFont systemFontOfSize:16];
        _tipLabel.textColor = [UIColor blackColor];
        NSDictionary *infoDict = [NSBundle mainBundle].localizedInfoDictionary;
        if (!infoDict) {
            infoDict = [NSBundle mainBundle].infoDictionary;
        }
        NSString *appName = [infoDict valueForKey:@"CFBundleDisplayName"];
        if (!appName) { appName = [infoDict valueForKey:@"CFBundleName"]; }
        NSString *tipText = [NSString stringWithFormat:@"运行 %@ 访问相册请到 \"通用-> 隐私 -> 相册\"",appName];
        _tipLabel.text = tipText;
        [self.view addSubview:_tipLabel];
        
        _settingBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [_settingBtn setTitle:@"设置" forState:UIControlStateNormal];
        _settingBtn.frame = CGRectMake(0, 180, CGRectGetWidth(self.view.frame), 44);
        _settingBtn.titleLabel.font = [UIFont systemFontOfSize:18];
        [_settingBtn addTarget:self action:@selector(settingBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_settingBtn];
    } else {
        self.tipLabel.hidden = YES;
        self.settingBtn.hidden = YES;
        [self.tipLabel removeFromSuperview];
        [self.settingBtn removeFromSuperview];
        self.tipLabel = nil;
        self.settingBtn = nil;
    }
}
#pragma mark -
#pragma mark - public methods 公有方法
- (void)cancelButtonClick {
    if (self.autoDismiss) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self callDelegateMethod];
        }];
    } else {
        [self callDelegateMethod];
    }
}
#pragma mark -
#pragma mark - override methods 复写方法
#pragma mark -
#pragma mark - getters and setters 设置器和访问器
- (void)setNavigationBarBgColor:(UIColor *)navigationBarBgColor{
    _navigationBarBgColor = navigationBarBgColor;
    [self configNavigationAppearance];
}

- (void)setNavigationBarTitleColor:(UIColor *)navigationBarTitleColor{
    _navigationBarTitleColor = navigationBarTitleColor;
    [self configNavigationAppearance];
}

- (void)setSelectedAssets:(NSMutableArray *)selectedAssets{
    _selectedAssets = selectedAssets;
    _selectedModels = [NSMutableArray array];
    for (PHAsset *asset in selectedAssets) {
        KSYAssetModelMediaType mediaType =[[KSYPhotoManager defaultManager] getAssetType:asset];
        KSYAssetModel *model = [KSYAssetModel modelWithAsset:asset type:mediaType];
        model.isSelected = YES;
        [_selectedModels addObject:model];
    }
}

#pragma mark -
#pragma mark - UITableViewDelegate
#pragma mark -
#pragma mark - CustomDelegate 自定义的代理
- (void)callDelegateMethod {
    if ([self.pickerDelegate respondsToSelector:@selector(ksyksyPhotoPickerControllerDidCancel:)]) {
        [self.pickerDelegate ksyksyPhotoPickerControllerDidCancel:self];
    }
    
}
#pragma mark -
#pragma mark - event response 所有触发的事件响应 按钮、通知、分段控件等
- (void)hanldeAuthSuccess{
    UIViewController *root = [self.viewControllers firstObject];
    if ([root isKindOfClass:[KSYAlbumViewController class]]) {
        [(KSYAlbumViewController *)root reset];
    }
}


//跳转系统设置页面
- (void)settingBtnClick {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

//进入相册选视频
- (void)pushToPhotoPickerVC{
//    if (self.pushPhotoPickerVC) {
//    [[KSYPhotoManager defaultManager] getAllAlbums:YES allowPickingImage:NO completion:^(NSArray<KSYAlbumModel *> *models) {
//        for (KSYAlbumModel *m in models) {
//            [m debugDescription];
//        }
////        NSLog(@"models:%@",);
//    }];
        //TODO:选择资源
//    }
}
#pragma mark -
#pragma mark - life cycle 视图的生命周期
#pragma mark -
#pragma mark - StatisticsLog 各种页面统计Log

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end


//------------------------------------------
//---------------工具类 helper---------------
//------------------------------------------
@implementation KSYCommonTools

+ (BOOL)ksy_isIPhoneX {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
    if ([platform isEqualToString:@"i386"] || [platform isEqualToString:@"x86_64"]) {
        // 模拟器下采用屏幕的高度来判断
        return (CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(375, 812)) ||
                CGSizeEqualToSize([UIScreen mainScreen].bounds.size, CGSizeMake(812, 375)));
    }
    // iPhone10,6是美版iPhoneX 感谢hegelsu指出：https://github.com/banchichen/TZImagePickerController/issues/635
    BOOL isIPhoneX = [platform isEqualToString:@"iPhone10,3"] || [platform isEqualToString:@"iPhone10,6"];
    return isIPhoneX;
}

+ (CGFloat)ksy_statusBarHeight {
    return [self ksy_isIPhoneX] ? 44 : 20;
}

// 获得Info.plist数据字典
+ (NSDictionary *)tz_getInfoDictionary {
    NSDictionary *infoDict = [NSBundle mainBundle].localizedInfoDictionary;
    if (!infoDict || !infoDict.count) {
        infoDict = [NSBundle mainBundle].infoDictionary;
    }
    if (!infoDict || !infoDict.count) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
        infoDict = [NSDictionary dictionaryWithContentsOfFile:path];
    }
    return infoDict ? infoDict : @{};
}
@end
