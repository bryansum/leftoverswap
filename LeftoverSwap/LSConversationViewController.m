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

@interface LSConversationViewController ()

@property (nonatomic) NSMutableArray *locallyAddedConversations; /* PFObject */
@property (nonatomic) PFUser *otherPerson;
@property (nonatomic) NSMutableArray *conversations; /* PFObject */
@property (nonatomic, weak) UINavigationController *navigationController;
//@property (nonatomic) LSConversationHeader *header;

@property (strong, nonatomic) UIImageView *outgoingBubbleImageView;
@property (strong, nonatomic) UIImageView *incomingBubbleImageView;

@end

@implementation LSConversationViewController

#pragma mark - NSObject

- (instancetype)initWithConversations:(NSArray*)conversations otherPerson:(PFUser*)person
{
    NSParameterAssert(conversations != nil);
    NSParameterAssert(person != nil);

    self = [super init];
    if (self) {
        self.locallyAddedConversations = [NSMutableArray array];
        self.conversations = [conversations mutableCopy];
        self.otherPerson = person;
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = [self.otherPerson name];
    self.sender = [[PFUser currentUser] name];

    self.outgoingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    outgoingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
    
    self.incomingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    incomingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleGreenColor]];

    // Remove the camera button
    self.inputToolbar.contentView.leftBarButtonItem = nil;
    
    // No avatars for now
    self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
    self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;

    [self scrollToBottomAnimated:NO];
//    [self p_setHeaderView];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    // HACK: Because we had previously turned off translucency for the VC in
    // pushIntoNavigationController, turn it back on as we're popping.
    self.navigationController.tabBarController.tabBar.translucent = YES;
}

#pragma mark - LSConversationViewController

- (void)pushIntoNavigationController:(UINavigationController*)navigationController
{
    // HACK: When the tab bar is translucent, animating the push causes will
    // swap the translucent BG only after viewDidLoad in CVC. This causes an
    // unsightly translucent BG pop. Turning off the translucency during animation temporarily
    // (to be turned on in viewDidLoad in the other VC) fixes this issue.
    self.navigationController = navigationController;
    navigationController.tabBarController.tabBar.translucent = NO;
    [navigationController pushViewController:self animated:YES];
}

/**
 * This logic is to make it so that locally added conversations
 * (ones that aren't reflected in the original input conversations array)
 * are kept track of so that when the caller updates its conversations array with
 * confirmed conversations, we make sure not to lose it. 
 * 
 * This also functions as a dupe-check mechanism in case that a locally-added conversation 
 * *and* its canonical version is passed in; in this case, it's no longer only locally-added,
 * so we remove it from the array.
 */
- (void)updateConversations:(NSArray*)conversations
{
    NSMutableArray *newConversations = [conversations mutableCopy];
    
    // Add Locally
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
    self.conversations = newConversations;
    
//    [self p_setHeaderView];
    
    [self.collectionView reloadData];
    [self scrollToBottomAnimated:NO];
}

- (void)addMessage:(NSString*)text forPost:(PFObject*)post
{
    PFObject *newConversation = [PFObject conversationForMessage:text recipient:self.otherPerson];
    [newConversation setObject:post forKey:kConversationPostKey];
    
    [newConversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!succeeded)
            return;
        
        [JSQSystemSoundPlayer jsq_playMessageSentSound];
        [newConversation sendPush];
        
        if (self.conversationDelegate)
            [self.conversationDelegate conversationController:self didAddConversation:newConversation];
    }];
    
    [self.locallyAddedConversations addObject:newConversation];
    [self.conversations addObject:newConversation];
//    [self p_setHeaderView];
    [self.collectionView reloadData];
    [self scrollToBottomAnimated:NO];
}

#pragma mark - JSQMessagesViewController

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                    sender:(NSString *)sender
                      date:(NSDate *)date
{
    /**
     *  Sending a message. Your implementation of this method should do *at least* the following:
     *
     *  1. Play sound (optional)
     *  2. Add new id<JSQMessageData> object to your data source
     *  3. Call `finishSendingMessage`
     */
    [JSQSystemSoundPlayer jsq_playMessageSentSound];

    PFObject *newConversation = [PFObject conversationForMessage:text recipient:self.otherPerson];
    [newConversation setObject:[self p_latestPost] forKey:kConversationPostKey];
    
    [newConversation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!succeeded)
            return;
        
        [newConversation sendPush];
        
        if (self.conversationDelegate)
            [self.conversationDelegate conversationController:self didAddConversation:newConversation];
    }];
    
//    [self p_setHeaderView];

    [self.locallyAddedConversations addObject:newConversation];
    [self.conversations addObject:newConversation];
    
    [self finishSendingMessage];
}

- (void)didPressAccessoryButton:(UIButton *)sender
{
    NSLog(@"Camera pressed!");
    /**
     *  Accessory button has no default functionality, yet.
     */
}

#pragma mark - JSQMessages CollectionView DataSource

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.conversations objectAtIndex:indexPath.item];
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PFUser *fromUser = [self.conversations[indexPath.row] fromUser];
    if ([fromUser isCurrentUser]) {
        return [[UIImageView alloc] initWithImage:self.outgoingBubbleImageView.image
                                 highlightedImage:self.outgoingBubbleImageView.highlightedImage];
    } else {
        return [[UIImageView alloc] initWithImage:self.incomingBubbleImageView.image
                                 highlightedImage:self.incomingBubbleImageView.highlightedImage];
    }
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Return `nil` here if you do not want avatars.
     *  If you do return `nil`, be sure to do the following in `viewDidLoad`:
     *
     *  self.collectionView.collectionViewLayout.incomingAvatarViewSize = CGSizeZero;
     *  self.collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSizeZero;
     *
     *  It is possible to have only outgoing avatars or only incoming avatars, too.
     */
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [self.conversations objectAtIndex:indexPath.item];
        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
    }
    
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [self.conversations objectAtIndex:indexPath.item];
    
    /**
     *  iOS7-style sender name labels
     */
    if ([message.sender isEqualToString:self.sender]) {
        return nil;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.conversations objectAtIndex:indexPath.item - 1];
        if ([[previousMessage sender] isEqualToString:message.sender]) {
            return nil;
        }
    }
    
    return nil;
//    
//    /**
//     *  Don't specify attributes to use the defaults.
//     */
//    return [[NSAttributedString alloc] initWithString:message.sender];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.conversations count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Override point for customizing cells
     */
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    /**
     *  Configure almost *anything* on the cell
     *
     *  Text colors, label text, label colors, etc.
     *
     *
     *  DO NOT set `cell.textView.font` !
     *  Instead, you need to set `self.collectionView.collectionViewLayout.messageBubbleFont` to the font you want in `viewDidLoad`
     *
     *
     *  DO NOT manipulate cell layout information!
     *  Instead, override the properties you want on `self.collectionView.collectionViewLayout` from `viewDidLoad`
     */
    
    JSQMessage *msg = [self.conversations objectAtIndex:indexPath.item];
    
    if ([msg.sender isEqualToString:self.sender]) {
        cell.textView.textColor = [UIColor blackColor];
    }
    else {
        cell.textView.textColor = [UIColor whiteColor];
    }
    
    cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
                                          NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    
    return cell;
}

#pragma mark - JSQMessages collection view flow layout delegate

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Each label in a cell has a `height` delegate method that corresponds to its text dataSource method
     */
    
    /**
     *  This logic should be consistent with what you return from `attributedTextForCellTopLabelAtIndexPath:`
     *  The other label height delegate methods should follow similarly
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  iOS7-style sender name labels
     */
    JSQMessage *currentMessage = [self.conversations objectAtIndex:indexPath.item];
    if ([[currentMessage sender] isEqualToString:self.sender]) {
        return 0.0f;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.conversations objectAtIndex:indexPath.item - 1];
        if ([[previousMessage sender] isEqualToString:[currentMessage sender]]) {
            return 0.0f;
        }
    }
    
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
    NSLog(@"Load earlier messages!");
}

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

//#pragma mark - Messages view data source
//- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    return [self.conversations[indexPath.row] objectForKey:kConversationMessageKey];
//}
//
//- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    NSDate *conversationDate = [self.conversations[indexPath.row] createdAt];
//    if (!conversationDate)
//        conversationDate = [NSDate date];
//    return conversationDate;
//}

#pragma mark private

//- (void)p_setHeaderView
//{
//    PFObject *latestPost = [self p_latestPost];
//    if (self.header.post == latestPost) return;
//    
//    if (self.header)
//        [self.header removeFromSuperview];
//    
//    self.header = [[LSConversationHeader alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
//    self.header.post = latestPost;
//    [self.view addSubview:self.header];
//    
//    //    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:self.header.frame];
//    //    [self.tableView setNeedsDisplay];
//}

- (PFObject*)p_latestPost
{
    return [[self.conversations lastObject] objectForKey:kConversationPostKey];
}

@end
