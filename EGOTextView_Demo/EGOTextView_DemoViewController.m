//
//  EGOTextView_DemoViewController.m
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
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
    
    self.view.backgroundColor = [UIColor grayColor];

    EGOTextView *view = [[EGOTextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, self.view.bounds.size.height-216.0f)];
    view.delegate = (id<EGOTextViewDelegate>)self;
    [self.view addSubview:view];
    self.egoTextView = view;
    [view release];
    
    
    
    CTFontRef font = CTFontCreateWithName((CFStringRef)@"Cochin-BoldItalic", 20, NULL);        
    UIColor *textColor = [UIColor blueColor];    
    NSDictionary *defaultStyle = [NSDictionary dictionaryWithObjectsAndKeys:(NSString*)font, kCTFontAttributeName, (id)textColor.CGColor, kCTForegroundColorAttributeName, nil];
    CFRelease(font);
    
    NSMutableAttributedString *mutableAttribString = [[NSMutableAttributedString alloc] initWithString:@"EGOTextView" attributes:defaultStyle];
    [self.egoTextView setAttributedString:mutableAttribString];
    [mutableAttribString release];
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, self.view.bounds.size.height-216.0f)];
    textView.font = self.egoTextView.font;
    [self.view addSubview:textView];
    self.textView = textView;
    [textView release];
    
    //self.textView.text = self.egoTextView.text;
    
    [segment setSelectedSegmentIndex:1];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
