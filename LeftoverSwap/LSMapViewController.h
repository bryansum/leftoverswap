//
//  LSMapViewController.h
//  LeftoverSwap
//
//  Created by Bryan Summersett on 8/7/13.
//  Copyright (c) 2013 LeftoverSwap. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@class LSLocationController;

@interface LSMapViewController : UIViewController <MKMapViewDelegate>

@property (nonatomic, strong) IBOutlet MKMapView *mapView;

- (void)centerMapAtCurrentLocation;

@end

