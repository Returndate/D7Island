//
//  D7Island.m - fake Dynamic Island sized like iPhone 14 Pro.
//  Target: iPhone 7 (iPhone9,1, arm64), iOS 15.x, palera1n rootless jailbreak.
//  Pure Objective-C, no Logos. Compiles with clang + iPhoneOS SDK.
//
//  Sizes copied 1:1 from iPhone 14 Pro (base screen 393x852pt / 1179x2556@3x):
//    collapsed  126 x 37 @ y=11  corner radius 18.5
//    expanded   371 x 88 @ y=11  corner radius 30, 11pt side margins
//  iPhone 7 screen is 375pt wide, so expanded width becomes 375 - 22 = 353:
//    collapsed  126 x 37 @ y=11
//    expanded   353 x 88 @ y=11
//
//  This file is intentionally ASCII-only: the GitHub web editor mangles
//  multi-byte text on paste, so every comment and string is plain ASCII.
//  The battery label uses \u7535\u91cc escapes for the Chinese label if wanted;
//  here we keep it ASCII ("BAT") to stay safe.
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

// MediaRemote private API, resolved with dlsym so we never link the
// private framework (no stubs in the public SDK).
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
// Only the island rect takes touches; everything else falls through
// to the app / home screen underneath.
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
        sSub.text   = [NSString stringWithFormat:@"BAT %.0f%%",
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
        // Fallback: inside SpringBoard this normally has no value, so treat
        // a missing value as "not playing".
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

// Haptics removed on request: only the visual spring animation happens now.
static void d7SetOpen(BOOL open, BOOL haptic) {
    (void)haptic;
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
        // The scene is not active yet during early boot: retry every 0.5s,
        // at most 40 times (about 20s), then give up.
        static int tries = 0;
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
    sWin.hidden = NO;                 // never call makeKeyAndVisible

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
