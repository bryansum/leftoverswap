//
//  LSConversationSummaryViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/9/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSConversationSummaryViewController.h"
#import "LSConversationSummaryCell.h"
#import "LSConstants.h"
#import "LSConversationViewController.h"
#import "LSConversationUtils.h"
#import "PFObject+Conversation.h"

@interface LSConversationSummaryViewController ()

@property (nonatomic) NSArray *objects; /* PFObject */
@property (nonatomic, weak) LSConversationViewController *conversationController;
@property (nonatomic) NSMutableDictionary *recipientConversations; /* NSString *objectId => NSArray of PFObjects */
@property (nonatomic) NSArray *summarizedObjects; /* NSArray of PFObjects */

@end

@implementation LSConversationSummaryViewController

#pragma mark - NSObject

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSConversationCreatedNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSUserLogInNotification object:nil];
}

#pragma mark - UITableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Conversations" image:[UIImage imageNamed:@"TabBarMessage"] tag:1];
        self.title = @"Conversations";
        self.recipientConversations = [NSMutableDictionary dictionary];
        self.objects = [NSArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_conversationCreated:) name:kLSConversationCreatedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_userDidLogIn:) name:kLSUserLogInNotification object:nil];
    }
    return self;
}

#pragma mark - UIView

- (void)viewWillAppear:(BOOL)animated
{
    // Reset badge values (we're looking at this view now)
    self.navigationController.tabBarItem.badgeValue = nil;
    
    // Need to refresh timestamps
    [self.tableView reloadData];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [LSConversationSummaryCell heightForCell];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PFObject *conversation = self.summarizedObjects[indexPath.row][0];
    PFObject *recipient = [conversation otherPerson];
    
    LSConversationViewController *conversationController = [[LSConversationViewController alloc] initWithConversations:[self p_conversationsForRecipient:recipient] recipient:recipient];
    conversationController.conversationDelegate = self;
    conversationController.hidesBottomBarWhenPushed = YES;
    self.conversationController = conversationController;
    [self.navigationController pushViewController:conversationController animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.summarizedObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellIdentifier = @"LSConversationSummaryCell";
    
    LSConversationSummaryCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[LSConversationSummaryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.conversation = self.summarizedObjects[indexPath.row][0];
    return cell;
}

#pragma mark - Instance methods

- (void)addNewConversation:(NSString*)text forPost:(PFObject*)post
{
    PFObject *recipient = [post objectForKey:kPostUserKey];
    
    LSConversationViewController *conversationController = [[LSConversationViewController alloc] initWithConversations:[self p_conversationsForRecipient:recipient] recipient:recipient];
    conversationController.conversationDelegate = self;
    conversationController.hidesBottomBarWhenPushed = YES;
    self.conversationController = conversationController;
    [self.navigationController pushViewController:conversationController animated:NO];
    [conversationController addMessage:text forPost:post];
}

#pragma mark - LSConversationControllerDelegate

- (void)conversationController:(LSConversationViewController *)conversationController didAddConversation:(PFObject *)conversation
{
    [[self p_conversationsForRecipient:[conversation otherPerson]] insertObject:conversation atIndex:0];
    [self p_updateSummarizedObjects];
    [self.tableView reloadData];
}

#pragma mark - NSNotification callbacks

- (void)p_didBecomeActive:(NSNotification*)notification
{
    if (![PFUser currentUser]) return;
    [self p_loadNewConversationsWithBadgeUpdate:NO];
}

- (void)p_userDidLogIn:(NSNotification*)notification
{
    // Clear them out immediately
    self.recipientConversations = [NSMutableDictionary dictionary];
    self.summarizedObjects = [NSArray array];
    [self.tableView reloadData];
    self.navigationController.tabBarItem.badgeValue = nil;
    
    // then load conversations
    [self p_loadConversations];
}

- (void)p_conversationCreated:(NSNotification*)notification
{
    [self p_loadNewConversationsWithBadgeUpdate:YES];
}

#pragma mark - Private

- (void)p_loadConversations
{
    PFQuery *query = [self p_queryForTable];
    query.cachePolicy = kPFCachePolicyNetworkElseCache;
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (error)
            return;
        
        self.objects = objects;
        [self p_partitionConversationsByRecipient:objects];
        [self.tableView reloadData];
        
        // Refresh conversation view.
        if (self.conversationController) {
            [self.conversationController updateConversations:[self p_conversationsForRecipient:self.conversationController.recipient]];
        }
    }];
}

- (void)p_loadNewConversationsWithBadgeUpdate:(BOOL)badgeUpdate
{
    // Find newer posts than now, and integrate them
    PFQuery *query = [self p_queryForTable];
    query.cachePolicy = kPFCachePolicyNetworkOnly;
    
    if (self.objects.count)
        [query whereKey:@"createdAt" greaterThan:[self.objects[0] createdAt]];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *newConversations, NSError *error) {
        if (error)
            return;
        
        NSArray *oldConversations = self.objects;
        NSMutableArray *toAdd = [newConversations mutableCopy];
        [toAdd removeObjectsInArray:oldConversations];
        
        if (badgeUpdate) {
            // All new conversations not from us
            NSInteger badgeCount = 0;
            for (PFObject *newConversation in toAdd) {
                if (![[newConversation objectForKey:kConversationFromUserKey] isCurrentUser])
                    ++badgeCount;
            }
            [self p_incrementBadgeCount:badgeCount];
        }
        
        self.objects = [toAdd arrayByAddingObjectsFromArray:self.objects];
        [self p_partitionConversationsByRecipient:self.objects];
        [self.tableView reloadData];
        
        // Refresh conversation view.
        if (self.conversationController) {
            [self.conversationController updateConversations:[self p_conversationsForRecipient:self.conversationController.recipient]];
        }
    }];
}

/** Queries all conversations from, or to, a user, and the most up-to-date topic for these. */
- (PFQuery *)p_queryForTable
{
    NSAssert([PFUser currentUser], @"User can't be nil");
    
    PFQuery *toUserQuery = [PFQuery queryWithClassName:kConversationClassKey];
    [toUserQuery whereKey:kConversationToUserKey equalTo:[PFUser currentUser]];
    
    PFQuery *fromUserQuery = [PFQuery queryWithClassName:kConversationClassKey];
    [fromUserQuery whereKey:kConversationFromUserKey equalTo:[PFUser currentUser]];
    
    PFQuery *query = [PFQuery orQueryWithSubqueries:@[toUserQuery, fromUserQuery]];
    
    [query includeKey:kConversationFromUserKey];
    [query includeKey:kConversationToUserKey];
    [query includeKey:kConversationPostKey];
    
    [query orderByDescending:@"createdAt"];
    
    return query;
}

- (void)p_incrementBadgeCount:(NSInteger)badgeCount
{
    UITabBarItem *tabBarItem = self.navigationController.tabBarItem;
    NSString *currentBadgeValue = tabBarItem.badgeValue;
    if (currentBadgeValue && currentBadgeValue.length > 0) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        NSNumber *badgeValue = [numberFormatter numberFromString:currentBadgeValue];
        tabBarItem.badgeValue = [numberFormatter stringFromNumber:@([badgeValue intValue] + badgeCount)];
    } else if (badgeCount != 0) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        tabBarItem.badgeValue = [numberFormatter stringFromNumber:@(badgeCount)];
    }
}

- (NSMutableArray*)p_conversationsForRecipient:(PFObject*)recipient
{
    NSString *recipientId = [recipient objectId];
    NSMutableArray *conversations = self.recipientConversations[recipientId];
    if (!conversations)
        self.recipientConversations[recipientId] = conversations = [NSMutableArray array];
    return conversations;
}

- (void)p_partitionConversationsByRecipient:(NSArray*)conversations
{
    NSMutableDictionary *recipientConversations = [NSMutableDictionary dictionary];
    for (PFObject* conversation in conversations) {
        NSString *recipientId = [[conversation otherPerson] objectId];
        NSMutableArray *conversationsForRecipient = recipientConversations[recipientId];
        if (!conversationsForRecipient)
            recipientConversations[recipientId] = conversationsForRecipient = [NSMutableArray array];
        [conversationsForRecipient addObject:conversation];
    }
    self.recipientConversations = recipientConversations;
    [self p_updateSummarizedObjects];
}

- (void)p_updateSummarizedObjects
{
    // Ensure all results are sorted by recency
    self.summarizedObjects = [[self.recipientConversations allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[(PFObject*)((NSArray*)obj2[0]) createdAt] compare:[(PFObject*)((NSArray*)obj1[0]) createdAt]];
    }];
}

@end
