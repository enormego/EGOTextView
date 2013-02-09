//
//  EGOTextView_DemoViewController.h
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 enormego. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EGOTextView;
@interface EGOTextView_DemoViewController : UIViewController {
    
    EGOTextView *_egoTextView;
    UITextView *_textView;
    
}

@property(nonatomic,strong) EGOTextView *egoTextView;
@property(nonatomic,strong) UITextView *textView;

@end
