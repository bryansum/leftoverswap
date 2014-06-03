//
//  LSSignupViewController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/13/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

//
//  PAWNewUserViewController.h
//  Anywall
//
//  Created by Christopher Bowns on 2/1/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LSLoginSignupViewController.h"

@interface LSSignupViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) id<LSLoginControllerDelegate> delegate;

@end
