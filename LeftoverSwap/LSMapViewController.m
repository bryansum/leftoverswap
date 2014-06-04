//
//  LSMapViewController.m
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/7/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import "LSMapViewController.h"

#import <CoreLocation/CoreLocation.h>

#import "LSConstants.h"
#import "LSAppDelegate.h"
#import "LSLocationController.h"
#import "LSPost.h"
#import "LSPostDetailViewController.h"
#import "LSTabBarController.h"

// private methods and properties
@interface LSMapViewController ()

@property (nonatomic) LSLocationController *locationController;
@property (nonatomic) BOOL initialPinsPlaced;
@property (nonatomic) BOOL mapPannedSinceLocationUpdate;
@property (nonatomic) NSMutableArray *allPosts;

- (void)p_queryForAllPostsNearLocation:(CLLocationCoordinate2D)location;

// NSNotification callbacks
- (void)distanceFilterDidChange:(NSNotification *)note;
- (void)locationDidChange:(NSNotification *)note;
- (void)postWasCreated:(NSNotification *)note;

@end

@implementation LSMapViewController

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Map" image:[UIImage imageNamed:@"TabBarMap.png"] tag:0];
		self.allPosts = [[NSMutableArray alloc] initWithCapacity:10];

        LSAppDelegate *appDelegate = (LSAppDelegate*)[[UIApplication sharedApplication] delegate];
        self.locationController = appDelegate.locationController;
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(distanceFilterDidChange:) name:kLSFilterDistanceChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationDidChange:) name:kLSLocationChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasCreated:) name:kLSPostCreatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(postWasTaken:) name:kLSPostTakenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidLogIn:) name:kLSUserLogInNotification object:nil];

    //FIXME: where is this?
	self.mapView.region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(37.332495f, -122.029095f), MKCoordinateSpanMake(0.008516f, 0.021801f));
	self.mapPannedSinceLocationUpdate = NO;

    self.initialPinsPlaced = NO; // reset this for the next time we show the map.

    [self.locationController startUpdatingLocation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

	[self.locationController startUpdatingLocation];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[self.locationController stopUpdatingLocation];
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
	[self.locationController stopUpdatingLocation];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:kLSFilterDistanceChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kLSLocationChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kLSPostCreatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSPostTakenNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLSUserLogInNotification object:nil];
}

#pragma mark - NSNotificationCenter notification handlers

- (void)distanceFilterDidChange:(NSNotification *)note
{
	if (!self.mapPannedSinceLocationUpdate) {
        [self centerMapAtCurrentLocation];
	}
}

- (void)locationDidChange:(NSNotification *)note
{
	if (!self.mapPannedSinceLocationUpdate) {
        [self centerMapAtCurrentLocation];
	}
}

- (void)userDidLogIn:(NSNotification*)notification
{
    // The pins may have changed color when switching users
    for (LSPost *annotation in self.mapView.annotations) {
        MKAnnotationView *annotationView = [self.mapView viewForAnnotation:annotation];
        if ([annotationView isKindOfClass:[MKPinAnnotationView class]]) {
            ((MKPinAnnotationView*)annotationView).pinColor = annotation.pinColor;
        }
    }
}

- (void)postWasCreated:(NSNotification *)note
{
    PFObject *post = note.userInfo[kLSPostKey];
    PFGeoPoint *geoPoint = [post objectForKey:kPostLocationKey];
    CLLocationCoordinate2D postLocation = CLLocationCoordinate2DMake(geoPoint.latitude, geoPoint.longitude);

    [self.mapView setCenterCoordinate:postLocation animated:YES];

    //FIXME: change this to update the post without doing another query
    [self p_queryForAllPostsNearLocation:postLocation];
}

- (void)postWasTaken:(NSNotification *)note
{
    PFObject *post = note.userInfo[kLSPostKey];

    LSPost *toRemove = nil;
    for (LSPost *annotation in self.allPosts) {
        if ([[annotation.object objectId] isEqualToString:[post objectId]]) {
            toRemove = annotation;
            break;
        }
    }
    if (toRemove) {
        [self.allPosts removeObject:toRemove];
        [self.mapView removeAnnotation:toRemove];
    }
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id<MKAnnotation>)annotation
{
	if (![annotation isKindOfClass:[LSPost class]])
        return nil;

    static NSString *pinIdentifier = @"CustomPinAnnotation";

    // Try to dequeue an existing pin view first.
    MKPinAnnotationView *pinView = (MKPinAnnotationView*)[aMapView dequeueReusableAnnotationViewWithIdentifier:pinIdentifier];

    if (!pinView) {
        // If an existing pin view was not available, create one.
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pinIdentifier];
    } else {
        pinView.annotation = annotation;
    }

    [(LSPost*)annotation setupAnnotationView:pinView];
    
    return pinView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if (![[view annotation] isKindOfClass:[LSPost class]])
        return;

    // Have the TabBarController present this post view so the contact view => message view transition works as expected.
    UIViewController *controller = [(LSPost*)view.annotation viewControllerWithDelegate:(LSTabBarController*)self.tabBarController];
    [self.tabBarController presentViewController:controller animated:YES completion:nil];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
	id<MKAnnotation> annotation = view.annotation;
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        [self centerMapAtCurrentLocation];
	}
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	self.mapPannedSinceLocationUpdate = YES;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    // FIXME: We should be smarter about only re-querying when the bounds from the previous
    // query have been exceeded.
	[self p_queryForAllPostsNearLocation:self.mapView.centerCoordinate];
}

#pragma mark - Fetch map pins

- (void)centerMapAtCurrentLocation
{
    CLLocation *currentLocation = self.locationController.currentLocation;
    CLLocationAccuracy filterDistance = self.locationController.filterDistance;

    // Center the map on the user's current location:
    MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, filterDistance * 2, filterDistance * 2);

    [self.mapView setRegion:newRegion animated:YES];
    self.mapPannedSinceLocationUpdate = NO;
}

- (void)p_queryForAllPostsNearLocation:(CLLocationCoordinate2D)location
{
    // FIXME: 20 posts is probably not reasonable
    static NSUInteger const kPostLimit = 20;
    
	PFQuery *query = [PFQuery queryWithClassName:kPostClassKey];
    
	// If no objects are loaded in memory, we look to the cache first to fill the table
	// and then subsequently do a query against the network.
	if ([self.allPosts count] == 0) {
		query.cachePolicy = kPFCachePolicyNetworkElseCache;
	}
    
	// Query for posts sort of kind of near our current location.
	PFGeoPoint *point = [PFGeoPoint geoPointWithLatitude:location.latitude longitude:location.longitude];
	[query whereKey:kPostLocationKey nearGeoPoint:point withinKilometers:100];
    [query whereKey:kPostTakenKey notEqualTo:@(YES)]; // exclude taken posts
    [query whereKey:@"createdAt" greaterThan:[NSDate dateWithTimeIntervalSinceNow:-kLSTimeToExpiration]];
	[query includeKey:kPostUserKey];
	query.limit = kPostLimit;
    
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		if (error) {
			NSLog(@"error in geo query!"); // todo why is this ever happening?
            return;
        }
        
        // We need to make new post objects from objects,
        // and update allPosts and the map to reflect this new array.
        // But we don't want to remove all annotations from the mapview blindly,
        // so let's do some work to figure out what's new and what needs removing.
        
        // 1. Find genuinely new posts:
        NSMutableArray *newPosts = [[NSMutableArray alloc] initWithCapacity:kPostLimit];
        // (Cache the objects we make for the search in step 2:)
        NSMutableArray *allNewPosts = [[NSMutableArray alloc] initWithCapacity:kPostLimit];
        for (PFObject *object in objects) {
            LSPost *newPost = [[LSPost alloc] initWithPFObject:object];
            [allNewPosts addObject:newPost];
            BOOL found = NO;
            for (LSPost *currentPost in self.allPosts) {
                if ([newPost equalToPost:currentPost]) {
                    found = YES;
                }
            }
            if (!found) {
                [newPosts addObject:newPost];
            }
        }
        // newPosts now contains our new objects.
        
        // 2. Find posts in allPosts that didn't make the cut.
        NSMutableArray *postsToRemove = [[NSMutableArray alloc] initWithCapacity:kPostLimit];
        for (LSPost *currentPost in self.allPosts) {
            BOOL found = NO;
            // Use our object cache from the first loop to save some work.
            for (LSPost *allNewPost in allNewPosts) {
                if ([currentPost equalToPost:allNewPost]) {
                    found = YES;
                }
            }
            if (!found) {
                [postsToRemove addObject:currentPost];
            }
        }
        // postsToRemove has objects that didn't come in with our new results.
        
        // 3. Configure our new posts; these are about to go onto the map.
        for (LSPost *newPost in newPosts) {
            // Animate all pins after the initial load:
            newPost.animatesDrop = self.initialPinsPlaced;
        }
        if (newPosts.count)
            self.initialPinsPlaced = YES;
        
        
        // At this point, newAllPosts contains a new list of post objects.
        // We should add everything in newPosts to the map, remove everything in postsToRemove,
        // and add newPosts to allPosts.
        [self.mapView removeAnnotations:postsToRemove];
        [self.mapView addAnnotations:newPosts];
        [self.allPosts addObjectsFromArray:newPosts];
        [self.allPosts removeObjectsInArray:postsToRemove];
	}];
}


@end
