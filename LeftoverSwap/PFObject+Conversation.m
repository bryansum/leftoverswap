//
//  PFObject+Conversation.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/10/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "PFObject+Conversation.h"

#import "PFObject+PrivateChannelName.h"
#import "LSConstants.h"

@implementation PFObject (Conversation)

+ (instancetype)conversationForMessage:(NSString*)text recipient:(PFObject*)recipient
{
    NSParameterAssert(recipient != nil);
    
    PFObject *newConversation = [PFObject objectWithClassName:kConversationClassKey];
    [newConversation setObject:text forKey:kConversationMessageKey];
    [newConversation setObject:[PFUser currentUser] forKey:kConversationFromUserKey];
    [newConversation setObject:recipient forKey:kConversationToUserKey];
    
    PFACL *conversationACL = [PFACL ACL];
    for (PFUser *user in @[[PFUser currentUser], recipient]) {
        [conversationACL setReadAccess:YES forUser:user];
    }
    newConversation.ACL = conversationACL;
    return newConversation;
}

- (void)sendPush
{
    PFUser *currentUser = [PFUser currentUser];
    NSAssert(currentUser, @"current user can't be nil");
    
    PFPush *push = [[PFPush alloc] init];
    PFObject *recipient = [self objectForKey:kConversationToUserKey];
    [push setChannel:[recipient privateChannelName]];
    
    //  PFObject *post = [conversation objectForKey:kConversationPostKey];
    NSString *message = [NSString stringWithFormat:@"%@: %@",
                         [currentUser name],
                         [self text]];
    
    NSDictionary *data = @{
                           @"alert": message,
                           @"c": [self objectId],
                           @"badge": @"Increment" // +1 to application badge number
                           };
    [push setData:data];
    [push sendPushInBackground];
}

- (PFObject*)otherPerson
{
    PFUser *currentUser = [PFUser currentUser];
    NSAssert(currentUser, @"current user can't be nil");
    
    PFObject *toUser = [self toUser];
    PFObject *fromUser = [self fromUser];
    if ([[toUser objectId] isEqualToString:[currentUser objectId]]) {
        return fromUser;
    } else {
        return toUser;
    }
}

- (PFUser*)fromUser
{
    return [self objectForKey:kConversationFromUserKey];
}

- (PFObject*)toUser
{
    return [self objectForKey:kConversationToUserKey];
}

- (NSString *)name
{
    return [self objectForKey:kUserDisplayNameKey];
}

- (BOOL)isEqualToConversation:(PFObject*)conversation
{
    return [self.objectId isEqualToString:conversation.objectId];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[PFObject class]]) return NO;
    return [self isEqualToConversation:(PFObject*)object];
}

- (NSUInteger)hash
{
    return self.objectId.hash;
}

#pragma mark - JSQMessageData

- (NSString *)text
{
    return [self objectForKey:kConversationMessageKey];
}

- (NSString *)sender
{
    return [[self objectForKey:kConversationFromUserKey] name];
}

- (NSDate *)date
{
    return [self createdAt];
}

@end

@implementation PFUser (User)

- (BOOL)isEqualToUser:(PFUser*)user
{
    return [self.objectId isEqualToString:user.objectId];
}

- (BOOL)isCurrentUser
{
    return [self isEqualToUser:[PFUser currentUser]];
}

@end

@implementation PFObject (Post)

- (BOOL)isEqualToPost:(PFObject*)post
{
    return [self.objectId isEqualToString:post.objectId];
}

- (PFUser*)user
{
    return [self objectForKey:kPostUserKey];
}

- (BOOL)isTaken
{
    NSNumber *taken = [self objectForKey:kPostTakenKey];
    if (!taken) {
        return NO;
    } else {
        return [taken boolValue];
    }
}

- (BOOL)isExpired
{
    NSDate *createdAt = [self createdAt];
    return -[createdAt timeIntervalSinceNow] > kLSTimeToExpiration;
}

@end
