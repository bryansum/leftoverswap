//
//  LSLoginSignupViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/13/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

//
//  PAWViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 1/30/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "LSLoginSignupViewController.h"

#import "LSLoginViewController.h"
#import "LSSignupViewController.h"

@interface LSLoginSignupViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *logoView;
@property (weak, nonatomic) IBOutlet UIButton *logInButton;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;

@property (strong, nonatomic) UIStoryboard *loginSignupStoryboard;

@property (strong, nonatomic) NSArray *watermelons;
@property (assign, nonatomic) NSUInteger watermelonIndex;

- (void)p_didTapWatermelon:(UIGestureRecognizer *)recognizer;

@end

@implementation LSLoginSignupViewController

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.watermelonIndex = 0;
        self.watermelons = @[@"plain.png", @"plain2.png", @"plain3.png", @"plain4.png"];
    }
    return self;
}

- (void)viewDidLoad
{
    self.loginSignupStoryboard = [UIStoryboard storyboardWithName:@"LoginSignup" bundle:nil];
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(p_didTapWatermelon:)];
    singleTap.numberOfTapsRequired = 1;
    singleTap.numberOfTouchesRequired = 1;
    [self.logoView addGestureRecognizer:singleTap];

    self.logInButton.layer.cornerRadius = 5;
    self.logInButton.clipsToBounds = YES;

    self.signInButton.layer.cornerRadius = 5;
    self.signInButton.clipsToBounds = YES;

    UIInterpolatingMotionEffect *ri = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"layer.transform.rotation" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    ri.minimumRelativeValue = @(M_PI/4);
    ri.maximumRelativeValue = @(-M_PI/8);

//    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
//    group.motionEffects = @[rxi, ryi];

    [self.logoView addMotionEffect:ri];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - Transition methods

- (IBAction)loginButtonSelected:(id)sender
{
    UINavigationController *navController = (UINavigationController*)[self.loginSignupStoryboard instantiateViewControllerWithIdentifier:@"loginViewController"];
    LSLoginViewController *loginViewController = (LSLoginViewController*)navController.topViewController;
    loginViewController.delegate = self.delegate;
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	[self presentViewController:navController animated:YES completion:nil];
}

- (IBAction)signUpSelected:(id)sender
{
    UINavigationController *navController = (UINavigationController*)[self.loginSignupStoryboard  instantiateViewControllerWithIdentifier:@"signupViewController"];
    LSSignupViewController *signupViewController = (LSSignupViewController*)navController.topViewController;
    signupViewController.delegate = self.delegate;
    navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)p_didTapWatermelon:(UIGestureRecognizer *)recognizer
{
    self.logoView.image = [UIImage imageNamed:self.watermelons[++self.watermelonIndex % self.watermelons.count]];
    [self.view setNeedsDisplay];
}

@end
