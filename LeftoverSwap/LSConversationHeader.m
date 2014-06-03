//
//  LSConversationHeader.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSConversationHeader.h"

#import <Parse/Parse.h>
#import <QuartzCore/QuartzCore.h>

#import "LSConstants.h"
#import "PFObject+Conversation.h"
#import "LSConversationUtils.h"

typedef NS_ENUM(NSUInteger, LSConversationHeaderState) {
    LSConversationHeaderStateDefault,
    LSConversationHeaderStateSeller,
    LSConversationHeaderStateTaken,
    LSConversationHeaderStateExpired
};

@interface LSConversationHeader ()

@property (nonatomic) PFImageView *imageView;
@property (nonatomic) LSConversationHeaderState state;

@end

@implementation LSConversationHeader

#pragma mark - NSObject

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSPostTakenNotification object:nil];
}

#pragma mark - UIView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.state = LSConversationHeaderStateDefault;
        self.imageView = [[PFImageView alloc] initWithFrame:CGRectMake(8, 7, 35, 35)];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_postWasTaken:) name:kLSPostTakenNotification object:nil];
    }
    return self;
}

#pragma mark - LSConversationHeader

- (void)setPost:(PFObject *)post
{
    _post = post;
    
    if ([self.post isTaken])
        self.state = LSConversationHeaderStateTaken;
    else if ([self.post isExpired])
        self.state = LSConversationHeaderStateExpired;
    else if ([[self.post user] isCurrentUser])
        self.state = LSConversationHeaderStateSeller;
    
    [self p_setViewsForState:self.state];
    
    [self setNeedsDisplay];
}

#pragma mark private

- (void)p_postWasTaken:(NSNotification*)notification
{
    if (notification.object == self) return;
    
    PFObject *aPost = notification.userInfo[kLSPostKey];
    if ([self.post isEqualToPost:aPost]) {
        // TODO: is this a bug? We should probably be setting self.state here too
        [self p_setViewsForState:LSConversationHeaderStateTaken];
        [self setNeedsDisplay];
    }
}

- (void)p_markAsTaken:(id)sender
{
    [self.post setObject:@(YES) forKey:kPostTakenKey];
    
    self.state = LSConversationHeaderStateTaken;
    [self p_setViewsForState:self.state];
    
    [self.post saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Taken set for post %@", [self.post objectForKey:kPostTitleKey]);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kLSPostTakenNotification object:self userInfo:@{kLSPostKey: self.post}];
                [LSConversationUtils sendTakenPushNotificationForPost:self.post];
            });
        } else {
            [self.post setObject:@(NO) forKey:kPostTakenKey];
            
            if ([self.post isExpired])
                self.state = LSConversationHeaderStateExpired;
            else if ([[self.post user] isCurrentUser])
                self.state = LSConversationHeaderStateSeller;
            else
                self.state = LSConversationHeaderStateDefault;
            
            [self p_setViewsForState:self.state];
        }
    }];
}

- (void)p_setViewsForState:(LSConversationHeaderState)state
{
    for(UIView *subview in [self subviews]) {
        [subview removeFromSuperview];
    }
    
    CGFloat labelMaxWidth = 200;
    
    UIButton *takenButton;
    UILabel *takenLabel, *expiredLabel;
    
    switch (state) {
        case LSConversationHeaderStateDefault:
            break;
        case LSConversationHeaderStateSeller:
            labelMaxWidth = 143;
            
            takenButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [takenButton addTarget:self action:@selector(p_markAsTaken:) forControlEvents:UIControlEventTouchUpInside];
            takenButton.backgroundColor = [UIColor colorWithRed:0.900 green:0.247 blue:0.294 alpha:1.000];
            [takenButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [takenButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
            takenButton.layer.cornerRadius = 3;
            takenButton.clipsToBounds = YES;
            //      [takenButton setTitleEdgeInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
            //      [takenButton.layer setBorderColor:[UIColor colorWithWhite:0.797 alpha:1.000].CGColor];
            //      [takenButton.layer setBorderWidth:1];
            [takenButton setTitle:@"Mark as taken" forState:UIControlStateNormal];
            takenButton.frame = CGRectMake(196, 12, 112, 26);
            takenButton.titleLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:15];
            //      takenButton.titleLabel.textColor = [UIColor colorWithRed:0.900 green:0.247 blue:0.294 alpha:1.000];
            //      takenButton.titleLabel.text = @"Mark as taken";
            //      takenButton.titleLabel.backgroundColor = [UIColor clearColor];
            [self addSubview:takenButton];
            
            break;
        case LSConversationHeaderStateTaken:
            
            takenLabel = [[UILabel alloc] initWithFrame:CGRectMake(260, 13, 50, 25)];
            takenLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:17];
            takenLabel.textColor = [UIColor colorWithWhite:0.537 alpha:1.000];
            takenLabel.text = @"Taken";
            takenLabel.textAlignment = NSTextAlignmentRight;
            takenLabel.backgroundColor = [UIColor clearColor];
            [self addSubview:takenLabel];
            break;
        case LSConversationHeaderStateExpired:
            
            expiredLabel = [[UILabel alloc] initWithFrame:CGRectMake(225, 13, 85, 25)];
            expiredLabel.font = [UIFont fontWithName:@"HelveticaNeue-Italic" size:17];
            expiredLabel.textColor = [UIColor colorWithWhite:0.537 alpha:1.000];
            expiredLabel.text = @"Expired";
            expiredLabel.textAlignment = NSTextAlignmentRight;
            expiredLabel.backgroundColor = [UIColor clearColor];
            [self addSubview:expiredLabel];
            
            break;
    }
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(49, 6, labelMaxWidth, 18)];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [self.post objectForKey:kPostTitleKey];
    titleLabel.numberOfLines = 1;
    titleLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:titleLabel];
    
    UILabel *descriptionLabel = [[UILabel alloc] initWithFrame:CGRectMake(49, 26, labelMaxWidth, 14)];
    descriptionLabel.text = [self.post objectForKey:kPostDescriptionKey];
    descriptionLabel.font = [UIFont systemFontOfSize:12];
    descriptionLabel.textColor = [UIColor blackColor];
    descriptionLabel.numberOfLines = 1;
    descriptionLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:descriptionLabel];
    
    PFFile *thumbnail = [self.post objectForKey:kPostThumbnailKey];
    
    // Only load if the url changes
    if (self.imageView.file.url != thumbnail.url) {
        self.imageView.image = nil;
        self.imageView.file = thumbnail;
        [self.imageView loadInBackground];
    }
    [self addSubview:self.imageView];
}


@end
