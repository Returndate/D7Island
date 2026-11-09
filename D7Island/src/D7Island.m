//
//  D7Island.m 鈥?iPhone 14 Pro 灏哄鐨勫亣鐏靛姩宀涳紝iPhone 7 / iOS 15 / palera1n rootless
//  绾?Objective-C锛屼笉渚濊禆 Logos锛泃heos 鐢?tweak.mk 鐩存帴鍚?.m 鍗冲彲銆?//
//  灏哄 1:1 鐓ф惉 iPhone 14 Pro锛堝熀鍑嗗睆 393x852pt / 1179x2556@3x锛夛細
//    鎶樺彔  126 x 37  @ y=11  鍏ㄥ渾瑙?r=18.5锛堟爣鍑嗚兌鍥婏級
//    灞曞紑  371 x 88  @ y=11  鍏ㄥ渾瑙?r=30锛屽乏鍙冲悇鐣?11pt
//  iPhone 7 灞忓 375pt锛屽睍寮€瀹芥寜 11pt 杈硅窛绛夋瘮鎹㈢畻涓?353锛?//    鎶樺彔  126 x 37  @ y=11
//    灞曞紑  353 x 88  @ y=11
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#define K_COLL_W 126.0
#define K_COLL_H 37.0
#define K_EXP_W  353.0
#define K_EXP_H  88.0
#define K_TOP    11.0
#define K_COLL_R 18.5
#define K_EXP_R  30.0

#define D7LOG(...) NSLog(@"[D7Island] " __VA_ARGS__)

static UIWindow    *sWin;
static UIView      *sIsland;
static UIView      *sPanel;
static UIImageView *sArt;
static UILabel     *sTitle;
static UILabel     *sSub;
static BOOL         sOpen;
static int          sGen;
static CGRect       sHit;

// MediaRemote 绉佹湁 API锛坉lsym 鍙栫鍙凤紝涓嶉摼鎺ョ鏈夋鏋讹紝閬垮厤 SDK 閲屾病鏈?stub 鏃剁紪璇戝け璐ワ級
typedef void (^D7MRInfoBlock)(CFDictionaryRef info);
typedef void (^D7MRPlayBlock)(Boolean playing);
static void (*sMRGetInfo)(dispatch_queue_t, D7MRInfoBlock);
static void (*sMRIsPlaying)(dispatch_queue_t, D7MRPlayBlock);
static BOOL   sPlaying;
static NSString *sNowTitle;
static NSString *sNowArtist;
static UIImage  *sNowArt;

@interface D7Win : UIWindow
@end

@implementation D7Win
// 鍙湁宀涗綋鍐呮帴鏀惰Е鎽革紝鍏朵綑鍏ㄩ儴绌块€忕粰涓嬮潰鐨?App / 妗岄潰
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(sHit, point);
}
@end

@interface D7Tap : NSObject
- (void)tap:(UITapGestureRecognizer *)g;
@end

static CGRect d7Rect(BOOL open) {
    CGFloat W = UIScreen.mainScreen.bounds.size.width;
    CGFloat w = open ? K_EXP_W : K_COLL_W;
    CGFloat h = open ? K_EXP_H : K_COLL_H;
    return CGRectMake((W - w) / 2.0, K_TOP, w, h);
}

static void d7Render(void) {
    static NSDateFormatter *fmt = nil;
    if (!fmt) {
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"HH:mm";
    }
    if (sPlaying && sNowTitle) {
        sTitle.text = sNowTitle;
        sSub.text   = sNowArtist ?: @"";
        sArt.image  = sNowArt;
    } else {
        sTitle.text = [fmt stringFromDate:[NSDate date]];
        sSub.text   = [NSString stringWithFormat:@"鐢甸噺 %.0f%%",
                       MAX(0.0, UIDevice.currentDevice.batteryLevel * 100.0)];
        sArt.image  = nil;
    }
}

static void d7Poll(void) {
    if (sMRIsPlaying) {
        sMRIsPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
            sPlaying = playing ? YES : NO;
            d7Render();
        });
    } else {
        // 鍏滃簳锛歋pringBoard 閲岃繖鏉￠€氬父鍙栦笉鍒板€硷紝鍙栦笉鍒板氨鎸?鏈挱鏀?澶勭悊
        NSDictionary *np = [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;
        sPlaying = (np && [[np objectForKey:MPNowPlayingInfoPropertyPlaybackRate] doubleValue] > 0.0);
        sNowTitle  = [np objectForKey:MPMediaItemPropertyTitle];
        sNowArtist = [np objectForKey:MPMediaItemPropertyArtist];
        sNowArt    = nil;
        d7Render();
    }

    if (!sMRGetInfo) return;
    sMRGetInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
        if (!info) { sNowTitle = nil; sNowArtist = nil; sNowArt = nil; return; }
        id t = (__bridge id)CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoTitle"));
        id a = (__bridge id)CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoArtist"));
        id d = (__bridge id)CFDictionaryGetValue(info, CFSTR("kMRMediaRemoteNowPlayingInfoArtworkData"));
        sNowTitle  = [t isKindOfClass:[NSString class]] ? t : nil;
        sNowArtist = [a isKindOfClass:[NSString class]] ? a : nil;
        sNowArt    = [d isKindOfClass:[NSData class]] ? [UIImage imageWithData:d] : nil;
        d7Render();
    });
}

static void d7SetOpen(BOOL open, BOOL haptic) {
    (void)haptic;   /* 瑙︽劅宸插叧闂細涓嶉渿鍔ㄣ€佷笉鍙戝０锛屽彧鏈夎瑙夊姩鐢?*/
    sOpen = open;
    sGen++;
    int me = sGen;

    CGRect r = d7Rect(open);
    sHit = r;
    d7Poll();

    [UIView animateWithDuration:0.44
                          delay:0.0
         usingSpringWithDamping:0.74
          initialSpringVelocity:0.35
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        sIsland.frame = r;
        sIsland.layer.cornerRadius = open ? K_EXP_R : K_COLL_R;
        sPanel.alpha = open ? 1.0 : 0.0;
    } completion:^(BOOL finished) {
        if (open) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (me == sGen && sOpen) d7SetOpen(NO, NO);
            });
        }
    }];
}

@implementation D7Tap
- (void)tap:(UITapGestureRecognizer *)g {
    d7SetOpen(!sOpen, YES);
}
@end

static D7Tap *sTap = nil;

static void d7Start(void) {
    if (sWin) return;

    UIWindowScene *scene = nil;
    for (UIWindowScene *sc in [[UIApplication sharedApplication] connectedScenes]) {
        if (sc.activationState == UISceneActivationStateForegroundActive) { scene = sc; break; }
    }
    if (!scene) {
        // 鍚姩鏃╂湡 scene 杩樻病婵€娲伙紝姣?0.5s 閲嶈瘯涓€娆★紝鏈€澶?40 娆?        static int tries = 0;
        if (tries++ < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ d7Start(); });
        } else {
            D7LOG(@"no foreground scene, give up");
        }
        return;
    }

    sMRGetInfo  = (void (*)(dispatch_queue_t, D7MRInfoBlock))dlsym(RTLD_DEFAULT,
                    "MRMediaRemoteGetNowPlayingInfo");
    sMRIsPlaying = (void (*)(dispatch_queue_t, D7MRPlayBlock))dlsym(RTLD_DEFAULT,
                    "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    D7LOG(@"MediaRemote symbols: info=%p playing=%p", sMRGetInfo, sMRIsPlaying);

    sWin = [[D7Win alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sWin.windowScene = scene;
    sWin.backgroundColor = [UIColor clearColor];
    sWin.windowLevel = UIWindowLevelStatusBar + 1;

    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    sWin.rootViewController = root;

    sIsland = [[UIView alloc] initWithFrame:d7Rect(NO)];
    sIsland.backgroundColor = [UIColor blackColor];
    sIsland.clipsToBounds = YES;
    sIsland.userInteractionEnabled = YES;
    sIsland.layer.cornerRadius = K_COLL_R;
    sIsland.layer.contentsScale = UIScreen.mainScreen.scale;

    sTap = [D7Tap new];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:sTap action:@selector(tap:)];
    [sIsland addGestureRecognizer:tap];

    sPanel = [[UIView alloc] initWithFrame:sIsland.bounds];
    sPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sPanel.backgroundColor = [UIColor clearColor];
    sPanel.alpha = 0.0;
    sPanel.userInteractionEnabled = NO;

    sArt = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 56, 56)];
    sArt.contentMode = UIViewContentModeScaleAspectFill;
    sArt.clipsToBounds = YES;
    sArt.layer.cornerRadius = 12;
    sArt.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    sArt.userInteractionEnabled = NO;
    [sPanel addSubview:sArt];

    sTitle = [[UILabel alloc] initWithFrame:CGRectMake(84, 22, 190, 22)];
    sTitle.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    sTitle.textColor = [UIColor whiteColor];
    sTitle.userInteractionEnabled = NO;
    [sPanel addSubview:sTitle];

    sSub = [[UILabel alloc] initWithFrame:CGRectMake(84, 46, 190, 18)];
    sSub.font = [UIFont systemFontOfSize:12.0];
    sSub.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    sSub.userInteractionEnabled = NO;
    [sPanel addSubview:sSub];

    [sIsland addSubview:sPanel];
    [root.view addSubview:sIsland];

    sHit = sIsland.frame;
    sWin.hidden = NO;                 // 涓ョ makeKeyAndVisible

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    d7Render();

    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        if (sOpen) d7Poll();
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

    D7LOG(@"island up: collapsed %.0fx%.0f @ y=%.0f", K_COLL_W, K_COLL_H, K_TOP);
}

__attribute__((constructor))
static void d7Ctor(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ d7Start(); });
}
