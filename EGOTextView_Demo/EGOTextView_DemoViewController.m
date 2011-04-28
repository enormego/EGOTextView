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
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, self.view.bounds.size.height-216.0f)];
    textView.font = self.egoTextView.font;
    [self.view addSubview:textView];
    self.textView = textView;
    [view release];
    
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

- (BOOL)textViewShouldBeginEditing:(EGOTextView *)textView {
    NSLog(@"should begin");
    return YES;
}

- (BOOL)textViewShouldEndEditing:(EGOTextView *)textView {
    NSLog(@"should end");
    return YES;
}

- (void)textViewDidBeginEditing:(EGOTextView *)textView {
    NSLog(@"did begin");
}

- (void)textViewDidEndEditing:(EGOTextView *)textView {
    NSLog(@"did end");
}

- (void)textViewDidChange:(EGOTextView *)textView {

    return;
    NSMutableAttributedString *mutableAttribString = [[NSMutableAttributedString alloc] initWithAttributedString:textView.attributedString];
    
    CTFontRef font = CTFontCreateWithName((CFStringRef)textView.font.fontName, textView.font.pointSize, NULL);    
    CTFontRef boldFont = CTFontCreateCopyWithSymbolicTraits(font, 0.0, NULL, kCTFontBoldTrait, kCTFontBoldTrait);
    
    UIColor *textColor = [UIColor blackColor];
    
    NSMutableDictionary *boldStyle = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(NSString*)boldFont, kCTFontAttributeName, (id)textColor.CGColor, kCTForegroundColorAttributeName, nil];
    NSDictionary *defaultStyle = [NSDictionary dictionaryWithObjectsAndKeys:(NSString*)font, kCTFontAttributeName, (id)textColor.CGColor, kCTForegroundColorAttributeName, nil];
    
    [mutableAttribString setAttributes:defaultStyle range:NSMakeRange(0, mutableAttribString.string.length)];
    
    CFRelease(font);
    CFRelease(boldFont);
    
    if (([mutableAttribString.string rangeOfString:@"fringe"].location!=NSNotFound)) {
        textColor = [UIColor colorWithRed:0.757f green:0.000f blue:0.000f alpha:1.0f];
        [boldStyle setObject:(id)textColor.CGColor forKey:(NSString*)kCTForegroundColorAttributeName];
        [mutableAttribString setAttributes:boldStyle range:[mutableAttribString.string rangeOfString:@"fringe"]];
    }
    
    if (([mutableAttribString.string rangeOfString:@"test"].location!=NSNotFound)) {
        textColor = [UIColor colorWithRed:0.0f green:0.000f blue:0.757f alpha:1.0f];
        [boldStyle setObject:(id)textColor.CGColor forKey:(NSString*)kCTForegroundColorAttributeName];
        [mutableAttribString setAttributes:boldStyle range:[mutableAttribString.string rangeOfString:@"test"]];
    }
    
    [boldStyle release];
    
    if (![textView.attributedString isEqualToAttributedString:mutableAttribString]) {
        textView.attributedString = mutableAttribString;
    }
    [mutableAttribString release];

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
