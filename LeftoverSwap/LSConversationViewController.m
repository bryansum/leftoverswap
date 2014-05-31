//
//  LSConversationViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

//
//  DemoViewController.m
//
//  Created by Jesse Squires on 2/12/13.
//  Copyright (c) 2013 Hexed Bits. All rights reserved.
//
//  http://www.hexedbits.com
//
//
//  The MIT License
//  Copyright (c) 2013 Jesse Squires
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
//  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Parse/Parse.h>

#import "LSConversationViewController.h"
#import "LSConversationHeader.h"
#import "LSConstants.h"
#import "LSConversationUtils.h"
#import "PFObject+Conversation.h"
#import "PFObject+PrivateChannelName.h"

@interface LSConversationViewController ()

- (void)p_setHeaderView;

- (PFObject*)p_conversationForMessage:(NSString*)text;
- (void)p_sendPushForConversation:(PFObject*)conversation;
- (PFObject*)p_latestPost;

@property (nonatomic) NSMutableArray *locallyAddedConversations; /* PFObject */
@property (nonatomic) PFObject *recipient;
@property (nonatomic) NSMutableArray *conversations; /* PFObject */
@property (nonatomic) LSConversationHeader *header;

@end

@implementation LSConversationViewController

#pragma mark - NSObject

- (id)initWithConversations:(NSArray*)conversations recipient:(PFObject*)recipient
{
    self = [super init];
    if (self) {
        self.locallyAddedConversations = [NSMutableArray array];
        self.conversations = [conversations mutableCopy];
        self.recipient = recipient;
        self.title = [self.recipient objectForKey:kUserDisplayNameKey];
    }
    return self;
}

#pragma mark - UIView

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Remove the camera button
    self.inputToolbar.contentView.leftBarButtonItem = nil;
    
    [self p_setHeaderView];
}

#pragma mark - Conversations

- (void)setConversations:(NSMutableArray *)newConversations
{
    // Add conversations only seen locally
    NSMutableArray *stillNotAdded = [NSMutableArray array];
    for (PFObject *locallyAddedConversation in self.locallyAddedConversations) {
        if (![newConversations containsObject:locallyAddedConversation]) {
            [newConversations addObject:locallyAddedConversation];
            [stillNotAdded addObject:locallyAddedConversation];
        }
    }
    self.locallyAddedConversations = stillNotAdded;
    
    // Ensure proper sorting for conversations (ascending order)
    [newConversations sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDate *date1 = [(PFObject*)obj1 createdAt];
        if (!date1)
            date1 = [NSDate date];
        NSDate *date2 = [(PFObject*)obj2 createdAt];
        if (!date2)
            date2 = [NSDate date];
        return [date1 compare:date2];
    }];
    
    _conversations = newConversations;
}

- (void)updateConversations:(NSArray*)conversations
{
    self.conversations = [conversations mutableCopy];
    [self p_setHeaderView];
    
//    [self.tableView reloadData];
    [self scrollToBottomAnimated:NO];
}

- (void)p_setHeaderView
{
    PFObject *latestPost = [self p_latestPost];
    if (self.header.post == latestPost) return;
    
    if (self.header)
        [self.header removeFromSuperview];
    
    self.header = [[LSConversationHeader alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    self.header.post = latestPost;
    [self.view addSubview:self.header];
    
//    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:self.header.frame];
//    [self.tableView setNeedsDisplay];
}

#pragma mark - Instance methods

- (void)addMessage:(NSString*)text forPost:(PFObject*)post
{
    PFObject *newConversation = [self p_conversationForMessage:text];
    [newConversation setObject:post forKey:kConversationPostKey];
    
    [newConversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!succeeded)
            return;
        
// TODO: add play message sent sound
//        [JSMessageSoundEffect playMessageSentSound];
        [self p_sendPushForConversation:newConversation];
        
        if (self.conversationDelegate)
            [self.conversationDelegate conversationController:self didAddConversation:newConversation];
    }];
    
    [self.locallyAddedConversations addObject:newConversation];
    [self.conversations addObject:newConversation];
    [self p_setHeaderView];
//    [self.tableView reloadData];
    [self scrollToBottomAnimated:NO];
}

#pragma mark - UICollectionView DataSource

//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//    return self.conversations.count;
//}

//- (void)sendPressed:(UIButton *)sender withText:(NSString *)text
//{
//    PFObject *newConversation = [self p_conversationForMessage:text];
//    [newConversation setObject:[self latestPost] forKey:kConversationPostKey];
//    
//    [newConversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
//        if (!succeeded)
//            return;
//        
//        [JSQMessageSoundEffect playMessageSentSound];
//        [self p_sendPushForConversation:newConversation];
//        
//        if (self.conversationDelegate)
//            [self.conversationDelegate conversationController:self didAddConversation:newConversation];
//    }];
//    
//    [self.locallyAddedConversations addObject:newConversation];
//    [self.conversations addObject:newConversation];
//    [self p_setHeaderView];
//    [self finishSend];
//}
//
//- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    PFObject *fromUser = [self.conversations[indexPath.row] objectForKey:kConversationFromUserKey];
//    return [[fromUser objectId] isEqualToString:[[PFUser currentUser] objectId]] ? JSBubbleMessageTypeOutgoing : JSBubbleMessageTypeIncoming;
//}

#pragma mark - Messages view data source
- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.conversations[indexPath.row] objectForKey:kConversationMessageKey];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDate *conversationDate = [self.conversations[indexPath.row] createdAt];
    if (!conversationDate)
        conversationDate = [NSDate date];
    return conversationDate;
}

#pragma mark - Private methods

- (PFObject*)p_conversationForMessage:(NSString*)text
{
    PFObject *newConversation = [PFObject objectWithClassName:kConversationClassKey];
    [newConversation setObject:text forKey:kConversationMessageKey];
    [newConversation setObject:[PFUser currentUser] forKey:kConversationFromUserKey];
    [newConversation setObject:self.recipient forKey:kConversationToUserKey];
    
    PFACL *conversationACL = [PFACL ACL];
    for (PFUser *user in @[[PFUser currentUser], self.recipient]) {
        [conversationACL setReadAccess:YES forUser:user];
    }
    newConversation.ACL = conversationACL;
    return newConversation;
}

- (void)p_sendPushForConversation:(PFObject*)conversation
{
    PFPush *push = [[PFPush alloc] init];
    PFObject *recipient = [conversation objectForKey:kConversationToUserKey];
    [push setChannel:[recipient privateChannelName]];
    
    //  PFObject *post = [conversation objectForKey:kConversationPostKey];
    NSString *message = [NSString stringWithFormat:@"%@: %@",
                         [[PFUser currentUser] objectForKey:kUserDisplayNameKey],
                         [conversation objectForKey:kConversationMessageKey]];
    
    NSDictionary *data = @{
                           @"alert": message,
                           @"c": [conversation objectId],
                           @"badge": @"Increment" // +1 to application badge number
                           };
    [push setData:data];
    [push sendPushInBackground];
}

- (PFObject*)p_latestPost
{
    return [[self.conversations lastObject] objectForKey:kConversationPostKey];
}

@end
