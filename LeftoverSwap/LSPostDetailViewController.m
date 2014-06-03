//
//  LSPostDetailViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/16/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSPostDetailViewController.h"
#import "LSConstants.h"
#import "TTTTimeIntervalFormatter.h"
#import "LSTabBarController.h"
#import "LSConversationUtils.h"
#import "PFObject+Conversation.h"

@interface LSPostDetailViewController ()

@property (nonatomic, strong) IBOutlet PFImageView *imageView;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *detailsLabel;
@property (nonatomic, strong) IBOutlet UITextView *descriptionView;
@property (nonatomic, strong) IBOutlet UIButton *contactButton;
@property (nonatomic, strong) IBOutlet UIView *translucentInfoContainer;
@property (nonatomic, strong) PFObject *post;
@property (nonatomic, strong) PFUser *seller;

@end

static TTTTimeIntervalFormatter *timeFormatter;

@implementation LSPostDetailViewController

#pragma mark - NSObject

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSPostTakenNotification object:nil];
}

- (instancetype)initWithPost:(PFObject*)post
{
    self = [super init];
    if (self) {
        self.post = post;
        self.seller = [post objectForKey:kPostUserKey];

        if (!timeFormatter) {
            timeFormatter = [[TTTTimeIntervalFormatter alloc] init];
        }

        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleDone target:self action:@selector(p_cancel:)];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_postWasTaken:) name:kLSPostTakenNotification object:nil];
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor blackColor];

//    NSInteger adjustBottom = 548 - self.view.bounds.size.height;

    self.translucentInfoContainer.layer.cornerRadius = 5;
    self.translucentInfoContainer.clipsToBounds = YES;

    self.imageView.file = [self.post objectForKey:kPostImageKey];
    [self.imageView loadInBackground];

    self.titleLabel.text = [self.post objectForKey:kPostTitleKey];

    [self.seller fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
        NSString *postDate = [timeFormatter stringForTimeIntervalFromDate:[NSDate date] toDate:self.post.createdAt];
        NSString *name = [self.seller objectForKey:kUserDisplayNameKey];
        self.detailsLabel.text = [NSString stringWithFormat:@"Posted by %@ about %@", name, postDate];
        [self.detailsLabel setNeedsDisplay];
    }];

    self.descriptionView.textContainer.lineFragmentPadding = 0;
    self.descriptionView.textContainerInset = UIEdgeInsetsZero;
    NSString *description = [NSString stringWithFormat:@"“%@”", [self.post objectForKey:kPostDescriptionKey]];
    self.descriptionView.text = description;
    // Why is this set? http://stackoverflow.com/questions/19113673/uitextview-setting-font-not-working-with-ios-6-on-xcode-5
    self.descriptionView.selectable = NO;

    self.contactButton.layer.cornerRadius = 5;
    self.contactButton.clipsToBounds = YES;
    [self.contactButton addTarget:self action:@selector(p_contact:) forControlEvents:UIControlEventTouchUpInside];

    [self p_setContactButtonStyle];
}

#pragma mark - UINavigationBar

- (void)p_cancel:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)p_contact:(id)sender
{
    if ([self.post isTaken])
        return;

    if ([[self.post user] isCurrentUser]) {

        [self.post setObject:@(YES) forKey:kPostTakenKey];
        [self p_setContactButtonStyle];

        [self.post saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded) {
                NSLog(@"Taken set for post %@", [self.post objectForKey:kPostTitleKey]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kLSPostTakenNotification object:self userInfo:@{kLSPostKey: self.post}];
                    [LSConversationUtils sendTakenPushNotificationForPost:self.post];
                });
            } else {
                [self.post setObject:@(NO) forKey:kPostTakenKey];
                [self p_setContactButtonStyle];
            }
        }];

        if (self.delegate)
            [self.delegate postDetailControllerDidMarkAsTaken:self forPost:self.post];

    } else {
        if (self.delegate)
            [self.delegate postDetailControllerDidContact:self forPost:self.post];
    }
}

- (void)p_setContactButtonStyle
{
    NSString *title = nil;
    UIColor *backgroundColor = nil;
    if ([self.post isTaken]) {
        title = @"Taken";
        backgroundColor = [UIColor colorWithWhite:0.537 alpha:1.000];
    } else if ([[self.post user] isCurrentUser]) {
        title = @"Mark as taken";
        backgroundColor = [UIColor colorWithRed:0.900 green:0.247 blue:0.294 alpha:1.000];
    } else {
        title = @"contact";
        backgroundColor = [UIColor colorWithRed:0.357 green:0.844 blue:0.435 alpha:1.000];
    }
    [self.contactButton setTitle:title forState:UIControlStateNormal];
    self.contactButton.backgroundColor = backgroundColor;
    
    [self.view setNeedsDisplay];
}

- (void)p_postWasTaken:(NSNotification *)note
{
    if (note.object == self) return;
    
    PFObject *aPost = note.userInfo[kLSPostKey];
    if ([self.post isEqualToPost:aPost]) {
        self.post = aPost;
        [self p_setContactButtonStyle];
    }
}

@end
