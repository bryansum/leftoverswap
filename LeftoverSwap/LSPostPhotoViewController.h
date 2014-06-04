//
//  LSPostPhotoViewController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/8/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

@class LSPaddedTextField;

@class LSPostPhotoViewController;

@protocol LSPostPhotoViewControllerDelegate <NSObject>

- (void)postPhotoControllerDidFinishPosting:(LSPostPhotoViewController *)post;
- (void)postPhotoControllerDidCancel:(LSPostPhotoViewController *)post;

@end

@interface LSPostPhotoViewController : UIViewController <UITextFieldDelegate, UITextViewDelegate>

@property (strong, nonatomic) UIImage *image;
@property (weak, nonatomic) id<LSPostPhotoViewControllerDelegate> delegate;

@end
