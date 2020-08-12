//
//  AppDelegate.m
//  OpenGL_ES_Filter_02
//
//  Created by tlab on 2020/8/12.
//  Copyright © 2020 yuanfangzhuye. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    // Override point for customization after application launch.
    return YES;
}


@end
