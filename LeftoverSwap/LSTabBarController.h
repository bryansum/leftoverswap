//
//  LSTabBarController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/17/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LSWelcomeViewController.h"

@interface LSTabBarController : UITabBarController <LSWelcomeControllerDelegate, UITabBarControllerDelegate>

- (void)presentSignInView;
- (void)presentWelcomeView;

@end