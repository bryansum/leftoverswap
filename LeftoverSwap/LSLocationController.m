//
//  LSLocationController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/7/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSLocationController.h"
#import "LSConstants.h"

static double const kLSFeetToMeters = 0.3048; // this is an exact value.

static NSString * const kDefaultsFilterDistanceKey = @"filterDistance";
static NSString * const kDefaultsLocationKey = @"currentLocation";

@interface LSLocationController ()

// CLLocationManagerDelegate methods:
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation;

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;

@end

@implementation LSLocationController

- (id)init
{
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc] init];

        CLAuthorizationStatus authStatus = [CLLocationManager authorizationStatus];
        if (authStatus == kCLAuthorizationStatusRestricted ||
            authStatus == kCLAuthorizationStatusDenied) {
            // This will be handled by the location manager delegate authorization update below.
        } else if (authStatus == kCLAuthorizationStatusNotDetermined) {
            if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                [self.locationManager requestWhenInUseAuthorization];
            }
        }

        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;

        // Set a movement threshold for new events.
        self.locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters;

//        self.currentLocation = self.locationManager.location;

        // Grab values from NSUserDefaults:
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        if ([userDefaults doubleForKey:kDefaultsFilterDistanceKey]) {
            // use the ivar instead of self.accuracy to avoid an unnecessary write to NAND on launch.
            self.filterDistance = [userDefaults doubleForKey:kDefaultsFilterDistanceKey];
        } else {
            // if we have no accuracy in defaults, set it to 1000 feet.
            self.filterDistance = 1000 * kLSFeetToMeters;
        }
        
    }
    return self;
}

- (void)dealloc
{
    [self.locationManager stopUpdatingLocation];
}

- (void)startUpdatingLocation {
    [self.locationManager startUpdatingLocation];
}

- (void)stopUpdatingLocation {
    [self.locationManager stopUpdatingLocation];
}

#pragma mark - Custom setters

- (void)setFilterDistance:(CLLocationAccuracy)aFilterDistance
{
    _filterDistance = aFilterDistance;

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:_filterDistance forKey:kDefaultsFilterDistanceKey];
    [userDefaults synchronize];

    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:_filterDistance] forKey:kLSFilterDistanceKey];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kLSFilterDistanceChangeNotification object:nil userInfo:userInfo];
    });
}

- (void)setCurrentLocation:(CLLocation *)aCurrentLocation
{
	_currentLocation = aCurrentLocation;
  
	// Notify the app of the location change:
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:_currentLocation forKey:kLSLocationKey];
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kLSLocationChangeNotification object:nil userInfo:userInfo];
	});
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusAuthorized:
            [self.locationManager startUpdatingLocation];
            break;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
            [self p_alertLocationWarning];
            break;
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	self.currentLocation = newLocation;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"Error: %@", [error description]);
  
	if (error.code == kCLErrorDenied) {
		[self.locationManager stopUpdatingLocation];
	} else if (error.code == kCLErrorLocationUnknown) {
		// todo: retry?
		// set a timer for five seconds to cycle location, and if it fails again, bail and tell the user.
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error retrieving location"
		                                                message:[error description]
		                                               delegate:nil
		                                      cancelButtonTitle:nil
		                                      otherButtonTitles:@"OK", nil];
		[alert show];
	}
}

#pragma mark - Private

- (void)p_alertLocationWarning
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"LeftoverSwap can't access your current location.\n\nTo view nearby posts or create a post at your current location, turn on location access in Settings → Privacy → Location Services." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

@end
