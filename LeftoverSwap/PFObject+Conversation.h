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
- (PFUser*)otherPerson;

- (PFUser*)fromUser;
- (PFUser*)toUser;

- (NSString *)name;

// Conversations are defined as equal if they have the same object id
- (BOOL)isEqualToConversation:(PFObject*)conversation;

- (BOOL)isEqual:(id)object;

- (NSUInteger)hash;

@end

@interface PFUser (User)

- (BOOL)isEqualToUser:(PFUser*)user;
- (BOOL)isCurrentUser;

@end

@interface PFObject (Post)

- (BOOL)isEqualToPost:(PFObject*)post;

- (PFUser*)user;
- (BOOL)isTaken;
- (BOOL)isExpired;

@end

