//
//  LSConversationViewController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

//
//  DemoViewController.h
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

#import <JSQMessagesViewController/JSQMessages.h>

@class PFObject, LSConversationViewController;

@protocol LSConversationControllerDelegate
@required

- (void)conversationController:(LSConversationViewController*)conversationController didAddConversation:(PFObject*)conversation;

@end

@interface LSConversationViewController : JSQMessagesViewController

@property (nonatomic, readonly) PFObject *recipient;

@property (nonatomic, weak) id<LSConversationControllerDelegate> conversationDelegate;

- (void)updateConversations:(NSMutableArray*)conversations;
- (void)addMessage:(NSString*)text forPost:(PFObject*)post;

- (id)initWithConversations:(NSArray*)conversations recipient:(PFObject*)recipient;

@end
