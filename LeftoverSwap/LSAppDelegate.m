//
//  LSAppDelegate.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 7/23/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSAppDelegate.h"
#import "LSTabBarController.h"
#import <Parse/Parse.h>
#import "PFObject+PrivateChannelName.h"
#import "LSConstants.h"
#import <HockeySDK/HockeySDK.h>

static NSString *const kLastTimeOpenedKey = @"lastTimeOpened";

@interface LSAppDelegate ()

@property (nonatomic) UIViewController *viewController;
@property (nonatomic) LSTabBarController *tabBarController;

-(void)setupAppearance;

@end

@implementation LSAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize locationController;
@synthesize tabBarController;

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

  [Parse setApplicationId:@"rxURqAiZdT4w3QiLPpecMAOyFF2qzVxsLPD1FcGR"
                clientKey:@"HF41j3NxMvnykjW2Cbu7LL48NA2Ebk98qUCT252h"];

  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"5626fb490590f2c11ca90eece15c0a23" delegate:self];
  [[BITHockeyManager sharedHockeyManager] startManager];

  [self resetApplicationBadgeNumber:application];
  
  [self setupAppearance];
  
  self.locationController = [[LSLocationController alloc] init];

  self.tabBarController = [[LSTabBarController alloc] init];

  self.viewController = self.tabBarController;
  self.window.rootViewController = self.viewController;

  [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
  
  NSDictionary *notificationPayload = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
  if (notificationPayload) {
    NSLog(@"notification payload received");
    [self application:application didReceiveRemoteNotification:notificationPayload];
  }

  [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound];

  self.window.tintColor = [UIColor colorWithRed:(40./255) green:(198./255) blue:(23./255) alpha:1];
  [self.window makeKeyAndVisible];

  if (![PFUser currentUser]) {
    [self.tabBarController presentSignInViewAnimated:NO];
  }
  
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Only do a "last-time opened" save when we've moved on from welcome / sign-in views.
//  if (!self.tabBarController.presentedViewController) {
//    NSDate *now = [NSDate date];
//    [[NSUserDefaults standardUserDefaults] setObject:now forKey:kLastTimeOpenedKey];
//    [[NSUserDefaults standardUserDefaults] synchronize];
//  }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // TODO: is this really needed?
  [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound];

  [self resetApplicationBadgeNumber:application];
}

#pragma mark - LSAppDelegate

- (void)setupAppearance {  
  // set the global navigation bar tint

  [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:0.411 green:0.858 blue:0.509 alpha:1.000]];
//  [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor], UITextAttributeTextColor, [NSValue valueWithUIOffset:UIOffsetMake(0, 0)], UITextAttributeTextShadowOffset, nil]];
}

#pragma mark - Remote notifications

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
  [self resetApplicationBadgeNumber:application];

  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  [currentInstallation setDeviceTokenFromData:newDeviceToken];
  
  PFUser *user = [PFUser currentUser];
  if (user) {
    [currentInstallation addUniqueObject:[user privateChannelName] forKey:kLSInstallationChannelsKey];
  }

  [currentInstallation saveEventually];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
  if ([error code] != 3010) { // 3010 is for the iPhone Simulator
    NSLog(@"Application failed to register for push notifications: %@", error);
	}
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
  if (![PFUser currentUser]) {
    NSLog(@"Receiving a remote notification should only occur if we're signed in");
    return;
  }

  [self resetApplicationBadgeNumber:application];

  if (application.applicationState != UIApplicationStateActive) {
    // The application was just brought from the background to the foreground,
    // so we consider the app as having been "opened by a push notification."
    [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
  }

  if (userInfo[@"c"]) { // conversation created
    
    NSString *objectId = userInfo[@"c"];

    // Send a notification only if the user is using the app. The backgrounded
    // case will still cause an onActive update in the conversations view.
    if (application.applicationState == UIApplicationStateActive) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kLSConversationCreatedNotification object:nil userInfo:@{kLSConversationKey: objectId}];
      });
    } else {
      [self.tabBarController dismissViewControllerAnimated:NO completion:nil];
      [self.tabBarController selectConversations];
    }

  } else if (userInfo[@"pt"]) { // post taken

    NSString *objectId = userInfo[@"pt"];

    PFQuery *query = [PFQuery queryWithClassName:kPostClassKey];
    [query includeKey:kPostUserKey];
    [query getObjectInBackgroundWithId:objectId block:^(PFObject *object, NSError *error) {
      if (!error)
        dispatch_async(dispatch_get_main_queue(), ^{
          [[NSNotificationCenter defaultCenter] postNotificationName:kLSPostTakenNotification object:nil userInfo:@{kLSPostKey: object}];
        });
    }];

  }
}

- (void)resetApplicationBadgeNumber:(UIApplication*)application
{
  application.applicationIconBadgeNumber = 0;
  PFInstallation *currentInstallation = [PFInstallation currentInstallation];
  if (currentInstallation.deviceToken) {
    currentInstallation.badge = 0;
    [currentInstallation saveEventually];
  }
}

#pragma mark - BITHockeyManagerDelegate

- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager
{
  if (![PFUser currentUser]) return nil;
  return [[PFUser currentUser] objectForKey:kUserDisplayNameKey];
}

- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager
{
  if (![PFUser currentUser]) return nil;
  return [[PFUser currentUser] objectForKey:kUserEmailKey];
}

- (NSString *)customDeviceIdentifierForUpdateManager:(BITUpdateManager *)updateManager {
//#ifndef CONFIGURATION_AppStore
//  if ([[UIDevice currentDevice] respondsToSelector:@selector(uniqueIdentifier)])
//    return [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
//#endif
  return nil;
}

@end
