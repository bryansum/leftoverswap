//
//  LSPostPhotoViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import <Parse/Parse.h>

#import "LSAppDelegate.h"
#import "LSLocationController.h"
#import "LSConstants.h"
#import "LSPostPhotoViewController.h"

#import "UIImage+Resize.h"
#import "UIImage+FixRotation.h"

@interface LSPostPhotoViewController ()

@property PFFile *photoFile;
@property PFFile *thumbnailFile;

@property (weak, nonatomic) IBOutlet UIView *translucentInfoContainer;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UITextView *descriptionTextView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *postButton;

@property (assign, nonatomic) UIBackgroundTaskIdentifier fileUploadBackgroundTaskId;
@property (assign, nonatomic) UIBackgroundTaskIdentifier photoPostBackgroundTaskId;

- (UIView*)p_findUnfilledTextView;
- (PFGeoPoint*)p_currentLocation;

- (IBAction)cancelPost:(id)sender;
- (IBAction)postPost:(id)sender;

@end

@implementation LSPostPhotoViewController

static NSString *const kLSDescriptionPlaceholderText = @"Anything else to add?";

#pragma mark - NSObject

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // This is a simple way to make the status bar white.
    // http://stackoverflow.com/questions/19022210/preferredstatusbarstyle-isnt-called
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;

    self.translucentInfoContainer.layer.cornerRadius = 5;
    self.translucentInfoContainer.clipsToBounds = YES;

    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setDefaults];
    self.translucentInfoContainer.layer.backgroundFilters = @[blur];

    self.fileUploadBackgroundTaskId = UIBackgroundTaskInvalid;
    self.photoPostBackgroundTaskId = UIBackgroundTaskInvalid;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_textInputChanged:) name:UITextViewTextDidChangeNotification object:nil];

    self.titleTextField.delegate = self;
    self.descriptionTextView.delegate = self;

    self.imageView.image = self.image;
    self.imageView.clipsToBounds = YES;

    self.titleTextField.layer.cornerRadius = 3;
    self.titleTextField.clipsToBounds = YES;

    self.descriptionTextView.layer.cornerRadius = 3;
    self.descriptionTextView.clipsToBounds = YES;

    [self p_shouldUploadImage:self.image];

//    self.titleTextField.leftRightPadding = 4;

    [self.titleTextField becomeFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.descriptionTextView becomeFirstResponder];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength > 33) ? NO : YES;
}

-(BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    //  [self.scrollView setContentOffset:CGPointMake(0, CGRectGetMinY(textView.frame)) animated:YES];
    return YES;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:kLSDescriptionPlaceholderText]) {
        textView.text = @"";
        textView.textColor = [UIColor blackColor]; //optional
    }
    [textView becomeFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@""]) {
        textView.text = kLSDescriptionPlaceholderText;
        textView.textColor = [UIColor lightGrayColor]; //optional
    }
    [textView resignFirstResponder];
}

#pragma mark - LSPostPhotoViewController

- (IBAction)postPost:(id)sender
{
    [self.titleTextField resignFirstResponder];
    [self.descriptionTextView resignFirstResponder];

    UIView *emptyView = [self p_findUnfilledTextView];

    if (emptyView) {
		[emptyView becomeFirstResponder];
		return;
	}

    //NSDictionary *userInfo = [NSDictionary dictionary];
    NSString *trimmedTitle = [self.titleTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *trimmedDescription;
    if ([self.descriptionTextView.text isEqualToString:kLSDescriptionPlaceholderText]) {
        trimmedDescription = @"";
    } else {
        trimmedDescription = [self.descriptionTextView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }

    if (!self.photoFile || !self.thumbnailFile) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't post your photo" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Dismiss", nil];
        [alert show];
        return;
    }

    // create a photo object
    PFObject *post = [PFObject objectWithClassName:kPostClassKey];
    [post setObject:[PFUser currentUser] forKey:kPostUserKey];
    [post setObject:self.photoFile forKey:kPostImageKey];
    [post setObject:self.thumbnailFile forKey:kPostThumbnailKey];
    [post setObject:trimmedDescription forKey:kPostDescriptionKey];
    [post setObject:trimmedTitle forKey:kPostTitleKey];
    [post setObject:[self p_currentLocation] forKey:kPostLocationKey];

    // photos are public, but may only be modified by the user who uploaded them
    PFACL *photoACL = [PFACL ACLWithUser:[PFUser currentUser]];
    [photoACL setPublicReadAccess:YES];
    post.ACL = photoACL;

    // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
    self.photoPostBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];

    // save
    [post saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded");

            NSLog(@"Successfully saved!");
			NSLog(@"%@", post);
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:kLSPostCreatedNotification object:nil userInfo:@{kLSPostKey: post}];
			});
        } else {
            NSLog(@"Photo failed to save: %@", error);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't post your photo" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Dismiss", nil];
            [alert show];
        }
        [[UIApplication sharedApplication] endBackgroundTask:self.photoPostBackgroundTaskId];
    }];

    if (self.delegate && [self.delegate respondsToSelector:@selector(postPhotoControllerDidFinishPosting:)]) {
        [self.delegate postPhotoControllerDidFinishPosting:self];
    }
}

- (IBAction)cancelPost:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(postPhotoControllerDidCancel:)]) {
        [self.delegate postPhotoControllerDidCancel:self];
    }
}

- (BOOL)p_shouldUploadImage:(UIImage *)anImage
{
    anImage = [anImage fixOrientation];
    UIImage *resizedImage = [anImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(560.0f, 560.0f) interpolationQuality:kCGInterpolationHigh];
    UIImage *thumbnailImage = [anImage thumbnailImage:86.0f transparentBorder:0.0f cornerRadius:10.0f interpolationQuality:kCGInterpolationDefault];

    // JPEG to decrease file size and enable faster uploads & downloads
    NSData *imageData = UIImageJPEGRepresentation(resizedImage, 0.8f);
    NSData *thumbnailImageData = UIImagePNGRepresentation(thumbnailImage);

    if (!imageData || !thumbnailImageData) {
        return NO;
    }

    self.photoFile = [PFFile fileWithData:imageData];
    self.thumbnailFile = [PFFile fileWithData:thumbnailImageData];

    // Request a background execution task to allow us to finish uploading the photo even if the app is backgrounded
    self.fileUploadBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
    }];

    NSLog(@"Requested background expiration task with id %ld for LeftoverSwap photo upload", (long)self.fileUploadBackgroundTaskId);
    [self.photoFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@"Photo uploaded successfully");
            [self.thumbnailFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    NSLog(@"Thumbnail uploaded successfully");
                }
                [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
            }];
        } else {
            [[UIApplication sharedApplication] endBackgroundTask:self.fileUploadBackgroundTaskId];
        }
    }];
    
    return YES;
}

#pragma mark - UITextView nofitication methods

- (void)p_textInputChanged:(NSNotification *)note
{
    self.postButton.enabled = [self p_findUnfilledTextView] == nil;
}

#pragma mark Private helper methods

- (PFGeoPoint*)p_currentLocation
{
    LSAppDelegate *appDelegate = (LSAppDelegate*)[[UIApplication sharedApplication] delegate];
    CLLocationCoordinate2D currentCoordinate = appDelegate.locationController.currentLocation.coordinate;
	PFGeoPoint *currentPoint = [PFGeoPoint geoPointWithLatitude:currentCoordinate.latitude longitude:currentCoordinate.longitude];
    return currentPoint;
}

- (UIView*)p_findUnfilledTextView
{
    if (self.titleTextField.text.length == 0) {
        return self.titleTextField;
    } else if (self.descriptionTextView == 0) {
        return self.descriptionTextView;
    } else {
        return nil;
    }
}

@end
