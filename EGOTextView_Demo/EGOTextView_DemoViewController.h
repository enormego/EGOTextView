//
//  EGOTextView_DemoViewController.h
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EGOTextView;
@interface EGOTextView_DemoViewController : UIViewController {
    
    EGOTextView *_egoTextView;
    UITextView *_textView;
    
}

@property(nonatomic,retain) EGOTextView *egoTextView;
@property(nonatomic,retain) UITextView *textView;

@end
