//
//  LSNewConversationViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSNewConversationViewController.h"
#import "LSConversationHeader.h"

@interface LSNewConversationViewController ()

@property (nonatomic) PFObject *post;

@end

@implementation LSNewConversationViewController

- (id)initWithPost:(PFObject*)post
{
    self = [super init];
    if (self) {
//        LSConversationHeader *header = [[LSConversationHeader alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
//        header.post = self.post = post;
//        //    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:header.frame];
//        [self.view addSubview:header];
    }
    return self;
}

#pragma mark - Initialization

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"New Conversation";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)];
    
    // Remove the camera button
    self.inputToolbar.contentView.leftBarButtonItem = nil;
}

- (void)cancelPressed:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - JSQMessagesViewController

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                    sender:(NSString *)sender
                      date:(NSDate *)date
{
    if (self.conversationDelegate) {
        [self.conversationDelegate conversationController:self didSendText:text forPost:self.post];
    }
}

@end
