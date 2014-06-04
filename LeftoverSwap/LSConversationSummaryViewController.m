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

@property (nonatomic, strong) NSArray *objects; /* convs.; created_at DESC */
@property (nonatomic, weak) LSConversationViewController *conversationController;
@property (nonatomic, strong) NSMutableDictionary *conversationsByPerson; /* NSString *objectId => NSArray of convs.; created_at ASC */
@property (nonatomic, strong) NSArray *summarizedObjects; /* NSArray of NSArray of convs.; Inner is created_at ASC; Outer is by most recent conv.'s created_at DESC */

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

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Conversations" image:[UIImage imageNamed:@"TabBarMessage"] tag:1];
        self.title = @"Conversations";
        self.conversationsByPerson = [NSMutableDictionary dictionary];
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
    PFObject *conversation = [self.summarizedObjects[indexPath.row] lastObject];
    PFUser *person = [conversation otherPerson];
    
    LSConversationViewController *conversationController = [[LSConversationViewController alloc] initWithConversations:[self p_conversationsWithPerson:person] otherPerson:person];
    conversationController.conversationDelegate = self;
    conversationController.hidesBottomBarWhenPushed = YES;
    self.conversationController = conversationController;
    
    [conversationController pushIntoNavigationController:self.navigationController];
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
    cell.conversation = [self.summarizedObjects[indexPath.row] lastObject];
    return cell;
}

#pragma mark - Instance methods

- (void)addNewConversation:(NSString*)text forPost:(PFObject*)post
{
    PFUser *person = [post user];
    
    LSConversationViewController *conversationController = [[LSConversationViewController alloc] initWithConversations:[self p_conversationsWithPerson:person] otherPerson:person];
    conversationController.conversationDelegate = self;
    conversationController.hidesBottomBarWhenPushed = YES;
    self.conversationController = conversationController;
    
    [conversationController pushIntoNavigationController:self.navigationController];
    [conversationController addMessage:text forPost:post];
}

#pragma mark - LSConversationControllerDelegate

- (void)conversationController:(LSConversationViewController *)conversationController didAddConversation:(PFObject *)conversation
{
    [[self p_conversationsWithPerson:[conversation otherPerson]] addObject:conversation];
    [self p_updateSummarizedObjects];
    [self.tableView reloadData];
}

#pragma mark - NSNotification callbacks

- (void)p_didBecomeActive:(NSNotification*)notification
{
    if (![PFUser currentUser]) return;
//    [self p_loadConversations];
    [self p_loadNewConversationsWithBadgeUpdate:NO];
}

- (void)p_userDidLogIn:(NSNotification*)notification
{
    // Clear them out immediately
    self.conversationsByPerson = [NSMutableDictionary dictionary];
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
        if (error || ![PFUser currentUser])
            return;
        
        self.objects = objects;
        [self p_partitionConversationsByPerson:objects];
        [self.tableView reloadData];
        
        // Refresh conversation view.
        if (self.conversationController) {
            [self.conversationController updateConversations:[self p_conversationsWithPerson:self.conversationController.otherPerson]];
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
        if (error || ![PFUser currentUser])
            return;
        
        NSArray *oldConversations = self.objects;
        NSMutableArray *toAdd = [newConversations mutableCopy];
        [toAdd removeObjectsInArray:oldConversations];
        
        if (badgeUpdate) {
            // All new conversations not from us
            NSInteger badgeCount = 0;
            for (PFObject *newConversation in toAdd) {
                if (![[newConversation fromUser] isCurrentUser])
                    ++badgeCount;
            }
            [self p_incrementBadgeCount:badgeCount];
        }
        
        self.objects = [toAdd arrayByAddingObjectsFromArray:self.objects];
        [self p_partitionConversationsByPerson:self.objects];
        [self.tableView reloadData];
        
        // Refresh conversation view.
        if (self.conversationController) {
            [self.conversationController updateConversations:[self p_conversationsWithPerson:self.conversationController.otherPerson]];
        }
    }];
}

/** 
  * Queries all conversations from, or to, a user, and the most up-to-date post for these conversations.
  *
  * Crucially, this query returns the most recent 100 posts as per the Parse API, and is sorted in
  * descending order of recency.
  */
- (PFQuery *)p_queryForTable
{
    PFUser *currentUser = [PFUser currentUser];
    NSAssert(currentUser, @"User can't be nil");
    
    PFQuery *toUserQuery = [PFQuery queryWithClassName:kConversationClassKey];
    [toUserQuery whereKey:kConversationToUserKey equalTo:currentUser];
    
    PFQuery *fromUserQuery = [PFQuery queryWithClassName:kConversationClassKey];
    [fromUserQuery whereKey:kConversationFromUserKey equalTo:currentUser];
    
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

- (NSMutableArray*)p_conversationsWithPerson:(PFUser*)person
{
    NSString *personId = [person objectId];
    NSMutableArray *conversations = self.conversationsByPerson[personId];
    if (!conversations)
        self.conversationsByPerson[personId] = conversations = [NSMutableArray array];
    return conversations;
}

/**
  * Takes in a list of conversations (assuming most recent to least); 
  * output is a dictionary of other people => list of conversations (least recent => most recent).
  * Also calls p_updateSummarizedObjects.
  */
- (void)p_partitionConversationsByPerson:(NSArray*)conversations
{
    NSMutableDictionary *conversationsByPerson = [NSMutableDictionary dictionary];
    for (PFObject* conversation in conversations) {
        NSString *personId = [[conversation otherPerson] objectId];
        NSMutableArray *existingConversation = conversationsByPerson[personId];
        if (!existingConversation)
            conversationsByPerson[personId] = existingConversation = [NSMutableArray array];
        [existingConversation insertObject:conversation atIndex:0];
//        [conversationsForRecipient addObject:conversation];
    }
    self.conversationsByPerson = conversationsByPerson;
    [self p_updateSummarizedObjects];
}

/**
  * Sets all conversation summaries, which is a list of conversations. 
  * The inner conversations are sorted from least recent => most recent conversation.
  * The outer list is sorted by the most recent inner conversation for each entry, from newest to oldest.
  */
- (void)p_updateSummarizedObjects
{
    // Ensure all results are sorted by recency
    self.summarizedObjects = [[self.conversationsByPerson allValues] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [[(PFObject*)[(NSArray*)obj2 lastObject] createdAt] compare:[(PFObject*)[(NSArray*)obj1 lastObject] createdAt]];
    }];
}

@end
