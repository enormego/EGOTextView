//
//  EGOTextView_DemoAppDelegate.h
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 enormego. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EGOTextView_DemoViewController;

@interface EGOTextView_DemoAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet EGOTextView_DemoViewController *viewController;

@end
