//
//  LSNewConversationViewController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import <JSQMessagesViewController/JSQMessages.h>

@class PFObject, LSNewConversationViewController;

@protocol LSNewConversationDelegate <NSObject>

- (void)conversationController:(LSNewConversationViewController*)conversation didSendText:(NSString*)text forPost:(PFObject*)post;

@end

@interface LSNewConversationViewController : JSQMessagesViewController <JSQMessagesCollectionViewDelegateFlowLayout>

@property (nonatomic, weak) id<LSNewConversationDelegate> conversationDelegate;

-initWithPost:(PFObject*)post;

@end
