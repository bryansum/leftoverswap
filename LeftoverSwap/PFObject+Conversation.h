//
//  PFObject+Conversation.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/10/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import <Parse/Parse.h>

#import <JSQMessagesViewController/JSQMessages.h>

@interface PFObject (Conversation) <JSQMessageData>

+ (instancetype)conversationForMessage:(NSString*)text recipient:(PFObject*)recipient;

- (void)sendPush;

/** The person that's not the current user. */
- (PFObject*)otherPerson;

- (PFObject*)fromUser;
- (PFObject*)toUser;

- (NSString *)name;

// Conversations are defined as equal if they have the same object id
- (BOOL)isEqualToConversation:(PFObject*)conversation;

- (BOOL)isEqual:(id)object;

- (NSUInteger)hash;

@end

@interface PFObject (User)

- (BOOL)isEqualToUser:(PFObject*)user;
- (BOOL)isCurrentUser;

@end
