//
//  LSConstants.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 7/24/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSConstants.h"

#pragma mark - Application constants
NSTimeInterval const kLSTimeToExpiration = 2 * 7 * (60 * 60 * 24); // 2 weeks
UIColor *const kLSGreenColor = [UIColor colorWithRed:(40./255) green:(198./255) blue:(23./255) alpha:1];

#pragma mark - PFObject User Class
// Field keys
NSString *const kUserDisplayNameKey = @"username";
NSString *const kUserEmailKey = @"email";
NSString *const kUserPrivateChannelKey = @"channel";

#pragma mark - PFObject Post Class
// Class key
NSString *const kPostClassKey = @"Post";

// Field keys
NSString *const kPostImageKey = @"image";
NSString *const kPostThumbnailKey = @"thumbnail";
NSString *const kPostUserKey = @"user";
NSString *const kPostTitleKey = @"title";
NSString *const kPostDescriptionKey = @"description";
NSString *const kPostLocationKey = @"location";
NSString *const kPostTakenKey = @"taken";

#pragma mark - PFObject Comment Class
// Class key
NSString *const kConversationClassKey = @"Conversation";

// Field keys
NSString *const kConversationFromUserKey = @"fromUser";
NSString *const kConversationToUserKey = @"toUser";
NSString *const kConversationMessageKey = @"message";
NSString *const kConversationPostKey = @"post";

# pragma mark - NSNotfication topics

NSString * const kLSFilterDistanceChangeNotification = @"kLSFilterDistanceChangeNotification";
NSString * const kLSFilterDistanceKey = @"filterDistance";

NSString * const kLSLocationChangeNotification = @"kLSLocationChangeNotification";
NSString * const kLSLocationKey = @"location";

NSString *const kLSPostCreatedNotification = @"kPostCreatedNotification";
NSString *const kLSPostTakenNotification = @"kPostTakenNotification";
NSString *const kLSPostKey = @"post";

NSString *const kLSConversationCreatedNotification = @"kLSConversationCreatedNotification";
NSString *const kLSConversationKey = @"conversation";

NSString *const kLSUserLogInNotification = @"kLSUserLogInNotification";

#pragma mark - PFInstallation keys

NSString *const kLSInstallationChannelsKey = @"channels";

