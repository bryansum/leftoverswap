//
//  LSSignupViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 9/13/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

//
//  PAWNewUserViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 2/1/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "LSSignupViewController.h"

#import <Parse/Parse.h>
#import "LSActivityView.h"
#import "LSMapViewController.h"

@interface LSSignupViewController ()

@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UITextField *emailField;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

- (void)p_validateFieldsAndSignUp;
- (void)textInputChanged:(NSNotification *)note;
- (BOOL)p_shouldEnableDoneButton;

@end

@implementation LSSignupViewController

#pragma mark - NSObject

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self.usernameField];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self.passwordField];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self.emailField];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Do any additional setup after loading the view from its nib.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextFieldTextDidChangeNotification object:self.usernameField];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextFieldTextDidChangeNotification object:self.passwordField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextFieldTextDidChangeNotification object:self.emailField];

	self.doneButton.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    [self.usernameField becomeFirstResponder];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == self.usernameField) {
		[self.passwordField becomeFirstResponder];
	} else if (textField == self.passwordField) {
		[self.emailField becomeFirstResponder];
	} else if (textField == self.emailField) {
        [self.emailField resignFirstResponder];
        [self p_validateFieldsAndSignUp];
    }

	return YES;
}

#pragma mark - ()

- (BOOL)p_shouldEnableDoneButton
{
	BOOL enableDoneButton = NO;
	if (self.usernameField.text != nil &&
		self.usernameField.text.length > 0 &&
		self.passwordField.text != nil &&
		self.passwordField.text.length > 0 &&
        self.emailField.text != nil &&
        self.emailField.text.length > 0) {
		enableDoneButton = YES;
	}
	return enableDoneButton;
}

- (void)textInputChanged:(NSNotification *)note
{
	self.doneButton.enabled = [self p_shouldEnableDoneButton];
}

- (IBAction)cancel:(id)sender
{
	[self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)done:(id)sender
{
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
    [self.emailField resignFirstResponder];
	[self p_validateFieldsAndSignUp];
}

- (void)p_validateFieldsAndSignUp
{
	// Check that we have a non-zero username and passwords.
	// Compare password and passwordAgain for equality
	// Throw up a dialog that tells them what they did wrong if they did it wrong.

	NSString *username = self.usernameField.text;
	NSString *password = self.passwordField.text;
    NSString *email = self.emailField.text;
	NSString *errorText = @"Please ";
	NSString *usernameBlankText = @"enter a username";
	NSString *passwordBlankText = @"enter a password";
    NSString *emailBlankText = @"enter an email address";
	NSString *joinText = @", and ";

	BOOL textError = NO;

	// Messaging nil will return 0, so these checks implicitly check for nil text.
	if (username.length == 0 || password.length == 0 || email.length == 0) {
		textError = YES;

		// Set up the keyboard for the first field missing input:
        if (email.length == 0) {
            [self.emailField becomeFirstResponder];
        }

		if (password.length == 0) {
			[self.passwordField becomeFirstResponder];
		}
		if (username.length == 0) {
			[self.usernameField becomeFirstResponder];
		}

        BOOL anyErrors = NO;
		if (username.length == 0) {
			errorText = [errorText stringByAppendingString:usernameBlankText];
            anyErrors = YES;
		} else if (email.length == 0) {
            errorText = [errorText stringByAppendingString:emailBlankText];
            anyErrors = YES;
        }

		if (password.length == 0) {
			if (anyErrors) { // We need some joining text in the error:
				errorText = [errorText stringByAppendingString:joinText];
			}
			errorText = [errorText stringByAppendingString:passwordBlankText];
		}
	}

	if (textError) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorText message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alertView show];
		return;
	}

	// Everything looks good; try to log in.
	// Disable the done button for now.
	self.doneButton.enabled = NO;

	LSActivityView *activityView = [[LSActivityView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.view.frame.size.width, self.view.frame.size.height)];
	UILabel *label = activityView.label;
	label.text = @"Signing You Up";
	label.font = [UIFont boldSystemFontOfSize:20.f];
	[activityView.activityIndicator startAnimating];
	[activityView layoutSubviews];

	[self.view addSubview:activityView];

	// Call into an object somewhere that has code for setting up a user.
	// The app delegate cares about this, but so do a lot of other objects.
	// For now, do this inline.

	PFUser *user = [PFUser user];
	user.username = username;
	user.password = password;
    user.email = email;

	[user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
		if (error) {
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[[error userInfo] objectForKey:@"error"] message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
			[alertView show];
			self.doneButton.enabled = [self p_shouldEnableDoneButton];
			[activityView.activityIndicator stopAnimating];
			[activityView removeFromSuperview];
			// Bring the keyboard back up, because they'll probably need to change something.
			[self.usernameField becomeFirstResponder];
			return;
		}

		// Success!
		[activityView.activityIndicator stopAnimating];
		[activityView removeFromSuperview];
        
        [self.delegate signupControllerDidFinish:self];
	}];
}

@end
