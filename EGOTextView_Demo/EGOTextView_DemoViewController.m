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

@interface CHTextAttachmentCell : NSObject <EGOTextAttachmentCell>

@property (nonatomic, strong) UIImage *image;

@end

@implementation CHTextAttachmentCell

- (UIView *)attachmentView
{
    return [[UIImageView alloc] initWithImage:self.image];
}

- (CGSize) attachmentSize
{
    return CGSizeMake(20, 20);
}

- (void) attachmentDrawInRect: (CGRect)r
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextDrawImage(ctx, r, _image.CGImage);

}

@end

@implementation EGOTextView_DemoViewController
{
    UIToolbar *_toolbar;
    CGRect _keyboardFrame;
    UIScrollView *_emoticonScrollView;
}

@synthesize egoTextView=_egoTextView;
@synthesize textView=_textView;

#pragma mark -
#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _keyboardFrame = CGRectNull;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    
    EGOTextView *view = [[EGOTextView alloc] initWithFrame:self.view.bounds];

    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.delegate = (id<EGOTextViewDelegate>)self;
    [self.view addSubview:view];
    self.egoTextView = view;
    [view becomeFirstResponder];
    
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, view.bounds.size.height, view.bounds.size.width, 40)];
    [self.view addSubview:_toolbar];
    
    UIBarButtonItem *keyboardItem = [[UIBarButtonItem alloc] initWithTitle:@"keyboard" style:UIBarButtonItemStyleBordered target:self action:@selector(showKeyboard)];
    
    UIBarButtonItem *emoticonItem = [[UIBarButtonItem alloc] initWithTitle:@"emoticon" style:UIBarButtonItemStyleBordered target:self action:@selector(showEmoticon)];
    
    _toolbar.items = @[keyboardItem, emoticonItem];
    
    
    
    _emoticonScrollView=[[UIScrollView alloc] initWithFrame:CGRectMake(0, 400, 320, 180)];
    [_emoticonScrollView setBackgroundColor:[UIColor grayColor]];
    for (int i=0; i<3; i++) {
        FacialView *fview=[[FacialView alloc] initWithFrame:CGRectMake(320*i, 0, 320, 180)];
        fview.delegate = self;
        fview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [fview loadFacialView:i size:CGSizeMake(45, 45)];
        [_emoticonScrollView addSubview:fview];
        
    }
    _emoticonScrollView.contentSize=CGSizeMake(320*3, 180);
    _emoticonScrollView.showsVerticalScrollIndicator  = NO;
    _emoticonScrollView.showsHorizontalScrollIndicator = NO;
    _emoticonScrollView.scrollEnabled = YES;
    _emoticonScrollView.pagingEnabled=YES;
    
    [self.view addSubview:_emoticonScrollView];
}

- (void)showKeyboard
{
    [self.egoTextView becomeFirstResponder];
}

- (void)showEmoticon
{
    [self.egoTextView resignFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)keyboardWillChangeFrame:(NSNotification*)notification
{
    CGRect keyboardFrame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    if (CGRectIsNull(_keyboardFrame)) {
        _keyboardFrame = keyboardFrame;
    }
    
    if (keyboardFrame.origin.y >= self.view.bounds.size.height) {//Hide
        self.egoTextView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - _keyboardFrame.size.height - 40);
        _toolbar.frame = CGRectMake(0, self.egoTextView.bounds.size.height, self.view.bounds.size.width, 40);
        _emoticonScrollView.frame = CGRectMake(0, _toolbar.frame.origin.y + 40, self.view.bounds.size.width, self.view.bounds.size.height - _toolbar.frame.origin.y + 40);
    }
    else {//Show
        self.egoTextView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - keyboardFrame.size.height - 40);
        _toolbar.frame = CGRectMake(0, self.egoTextView.bounds.size.height, self.view.bounds.size.width, 40);
        _emoticonScrollView.frame = CGRectMake(0, _toolbar.frame.origin.y + 40, self.view.bounds.size.width, self.view.bounds.size.height - _toolbar.frame.origin.y + 40);

    }
    
    
    
    
}

-(void)selectedFacialView:(NSString*)str
{
    NSMutableAttributedString *attributedString = [self.egoTextView.attributedString mutableCopy];
    
    [attributedString replaceCharactersInRange:self.egoTextView.selectedRange withString:@"\ufffc"];
    NSRange emoticonRange = self.egoTextView.selectedRange;
    emoticonRange.length = 1;
    CHTextAttachmentCell *cell = [[CHTextAttachmentCell alloc] init];
    cell.image = [UIImage imageNamed:str];
    [attributedString addAttribute:EGOTextAttachmentAttributeName value:cell range:emoticonRange];
    
    
    
    NSRange range = self.egoTextView.selectedRange;

    self.egoTextView.attributedString = attributedString;
    
    range.location += 1;
    range.length = 0;
    self.egoTextView.selectedRange = range;
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

- (void)egoTextView:(EGOTextView*)textView didSelectURL:(NSURL *)URL {
        
}


#pragma mark -
#pragma mark Memory Management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];    
}



@end
