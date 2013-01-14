//
//  EGOTextView_DemoViewController.m
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 enormego. All rights reserved.
//

#import "EGOTextView_DemoViewController.h"
#import "EGOTextView.h"

#import <QuartzCore/QuartzCore.h>

@implementation EGOTextView_DemoViewController

@synthesize egoTextView=_egoTextView;
@synthesize textView=_textView;

#pragma mark -
#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"UITextView", @"EGOTextView", nil]];
    segment.segmentedControlStyle = UISegmentedControlStyleBar;
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = segment;
    [segment release];
    
    if (_textView==nil) {
        
        UITextView *textView = [[UITextView alloc] initWithFrame:self.view.bounds];
        textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        textView.font = self.egoTextView.font;
        [self.view addSubview:textView];
        self.textView = textView;
        [textView release];
        
    }
    
    if (_egoTextView==nil) {
        
        EGOTextView *view = [[EGOTextView alloc] initWithFrame:self.view.bounds];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        view.delegate = (id<EGOTextViewDelegate>)self;
        [self.view addSubview:view];
        self.egoTextView = view;
        [view release];  
        [view becomeFirstResponder];
        
    }
     
    [segment setSelectedSegmentIndex:1];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


#pragma mark -
#pragma mark Actions

- (void)segmentChanged:(UISegmentedControl*)sender {
    
    if (sender.selectedSegmentIndex == 0) {
    
        self.egoTextView.hidden = YES;
        self.textView.hidden = NO;
        [self.textView becomeFirstResponder];
        
    } else {
                
        self.textView.hidden = YES;
        self.egoTextView.hidden = NO;
        [self.egoTextView becomeFirstResponder];
        
    }
    
}


#pragma mark -
#pragma mark EGOTextViewDelegate

- (BOOL)egoTextViewShouldBeginEditing:(EGOTextView *)textView {
    return YES;
}

- (BOOL)egoTextViewShouldEndEditing:(EGOTextView *)textView {
    return YES;
}

- (void)egoTextViewDidBeginEditing:(EGOTextView *)textView {
}

- (void)egoTextViewDidEndEditing:(EGOTextView *)textView {
}

- (void)egoTextViewDidChange:(EGOTextView *)textView {

}

- (void)egoTextViewDidChangeSelection:(EGOTextView*)textView {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)egoTextViewTouched:(EGOTextView*)textView {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)egoTextView:(EGOTextView*)textView didSelectURL:(NSURL *)URL {
        
}


#pragma mark -
#pragma mark Memory Management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];    
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [_textView release], _textView=nil;
    [_egoTextView release], _egoTextView=nil;
}

- (void)dealloc {
    [_textView release], _textView=nil;
    [_egoTextView release], _egoTextView=nil;
    [super dealloc];
}


@end
