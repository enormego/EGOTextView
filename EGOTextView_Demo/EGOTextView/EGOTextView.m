//
//  EGOTextView.m
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "EGOTextView.h"
#import <UIKit/UITextChecker.h>
#import <QuartzCore/QuartzCore.h>
#include <objc/runtime.h>

typedef enum {
    EGOWindowLoupe = 0,
    EGOWindowMagnify,
} EGOWindowType;

typedef enum {
    EGOSelectionTypeLeft=0,
    EGOSelectionTypeRight,
} EGOSelectionType;

#pragma mark EGOContentView definition

@interface EGOContentView : UIView {
@private
    id _delegate;
}
@property(nonatomic,assign) id delegate;
@end

#pragma mark EGOCaretView definition

@interface EGOCaretView : UIView {
    NSTimer *_blinkTimer;
}

- (void)delayBlink;
- (void)show;
@end


#pragma mark EGOLoupeView definition

@interface EGOLoupeView : UIView {
@private
    UIImage *_contentImage;
}
- (void)setContentImage:(UIImage*)image;
@end


#pragma mark MagnifyView definition

@interface EGOMagnifyView : UIView {
@private
    UIImage *_contentImage;
}
- (void)setContentImage:(UIImage*)image;
@end


#pragma mark EGOTextWindow definition

@interface EGOTextWindow : UIWindow {
@private
    UIView              *_view;
    EGOWindowType       _type;
    EGOSelectionType    _selectionType;
    BOOL                _showing;
    
}
@property(nonatomic,assign) EGOWindowType type;
@property(nonatomic,assign) EGOSelectionType selectionType;
@property(nonatomic,readonly,getter=isShowing) BOOL showing;
- (void)setType:(EGOWindowType)type;
- (void)renderWithContentView:(UIView*)view fromRect:(CGRect)rect;
- (void)showFromView:(UIView*)view rect:(CGRect)rect;
- (void)hide:(BOOL)animated;
@end


#pragma mark EGOSelectionView definition

@interface EGOSelectionView : UIView {
@private
    UIView *_leftDot;
    UIView *_rightDot;
    UIView *_leftCaret;
    UIView *_rightCaret;
}
- (void)setBeginCaret:(CGRect)begin endCaret:(CGRect)rect;
@end

#pragma mark UITextPosition  definition

@interface IndexedPosition : UITextPosition {
    NSUInteger               _index;
    id <UITextInputDelegate> _inputDelegate;
}

@property (nonatomic) NSUInteger index;
+ (IndexedPosition *)positionWithIndex:(NSUInteger)index;

@end

#pragma mark UITextRange definition

@interface IndexedRange : UITextRange {
    NSRange _range;
}

@property (nonatomic) NSRange range;
+ (IndexedRange *)rangeWithNSRange:(NSRange)range;
@end

#pragma mark EGOTextView private

@interface EGOTextView (Private)

    NSMutableAttributedString          *_mutableAttributedString;
    NSDictionary                       *_markedTextStyle;
    id <UITextInputDelegate>           _inputDelegate;
    UITextInputStringTokenizer         *_tokenizer;
    UITextChecker                      *_textChecker;


@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;        
@property(nonatomic) UIKeyboardType keyboardType;                       
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;             
@property(nonatomic) UIReturnKeyType returnKeyType;                    
@property(nonatomic) BOOL enablesReturnKeyAutomatically; 

- (CGRect)caretRectForIndex:(int)index;
- (CGRect)firstRectForNSRange:(NSRange)range;
- (NSInteger)closestIndexToPoint:(CGPoint)point;
- (NSInteger)closestWhiteSpaceIndexToPoint:(CGPoint)point;
- (NSRange)characterRangeAtPoint_:(CGPoint)point;
- (void)checkSpelling;
- (void)textChanged;
- (void)removeCorrectionAttributesForRange:(NSRange)range;
- (void)insertCorrectionAttributesForRange:(NSRange)range;

+ (UIColor *)selectionColor;
+ (UIColor *)spellingSelectionColor;
+ (UIColor *)caretColor;
@end

@interface EGOTextView ()
@property(nonatomic,retain) NSDictionary *defaultAttributes;
@property(nonatomic,retain) NSDictionary *correctionAttributes;
@property(nonatomic,retain) NSMutableDictionary *menuItemActions;
@property(nonatomic) NSRange correctionRange;
@end


@implementation EGOTextView

@synthesize delegate;
@synthesize attributedString=_attributedString;
@synthesize font=_font;
@synthesize editing=_editing;
@synthesize editable=_editable;
@synthesize markedRange=_markedRange;
@synthesize selectedRange=_selectedRange;
@synthesize correctionRange=_correctionRange;
@synthesize defaultAttributes=_defaultAttributes;
@synthesize correctionAttributes=_correctionAttributes;
@synthesize markedTextStyle=_markedTextStyle;
@synthesize inputDelegate=_inputDelegate;
@synthesize menuItemActions;

@synthesize autocapitalizationType;
@synthesize autocorrectionType;
@synthesize keyboardType;
@synthesize keyboardAppearance;
@synthesize returnKeyType;
@synthesize enablesReturnKeyAutomatically;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
                
        [self setText:@""];
        self.alwaysBounceVertical = YES;
        self.editable = YES;
        self.font = [UIFont systemFontOfSize:17];
        self.backgroundColor = [UIColor whiteColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        EGOContentView *contentView = [[EGOContentView alloc] initWithFrame:CGRectInset(self.bounds, 8.0f, 8.0f)];
        contentView.autoresizingMask = 0;
        contentView.delegate = self;
        [self addSubview:contentView];
        _textContentView = [contentView retain];
        [contentView release];
            
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        [self addGestureRecognizer:gesture];
        [gesture release];
        _longPress = gesture;

    }
    return self;
}

- (id)init {
    if ((self = [self initWithFrame:CGRectZero])) {}
    return self;
}

- (void)clearPreviousLayoutInformation {
        
    if (_framesetter != NULL) {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
    
    if (_frame != NULL) {
        CFRelease(_frame);
        _frame = NULL;
    }
}

- (void)setFont:(UIFont *)font {
   
    UIFont *oldFont = _font;
    _font = [font retain];
    [oldFont release];

    CTFontRef ctFont = CTFontCreateWithName((CFStringRef) self.font.fontName, self.font.pointSize, NULL);  
    NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:(id)ctFont, (NSString *)kCTFontAttributeName, (id)[UIColor blackColor].CGColor, kCTForegroundColorAttributeName, nil];
    self.defaultAttributes = dictionary;
    [dictionary release];
    CFRelease(ctFont);        
    
    [self textChanged];
    
}

- (CGFloat)boundingWidthForHeight:(CGFloat)height {
    
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(CGFLOAT_MAX, height), NULL);
    return suggestedSize.width;   

}

- (CGFloat)boundingHeightForWidth:(CGFloat)width {
    
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(_framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(width, CGFLOAT_MAX), NULL);
    return suggestedSize.height;

}

- (void)textChanged {
    
    if ([[UIMenuController sharedMenuController] isMenuVisible]) {
        [[UIMenuController sharedMenuController] setMenuVisible:NO animated:NO];
    }
           
    CTFramesetterRef framesetter = _framesetter;
    _framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedString);
    if (framesetter!=NULL) {
        CFRelease(framesetter); 
    }
    
    CGRect rect = _textContentView.frame;
    CGFloat height = [self boundingHeightForWidth:rect.size.width];
    rect.size.height = height+self.font.lineHeight;
    _textContentView.frame = rect;    
    self.contentSize = CGSizeMake(self.frame.size.width, rect.size.height+(self.font.lineHeight*2));

    UIBezierPath *path = [UIBezierPath bezierPathWithRect:_textContentView.bounds];

    CTFrameRef frameRef = _frame;
    _frame =  CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), [path CGPath], NULL);
    if (frameRef!=NULL) {
        CFRelease(frameRef);
    }
        
    [_textContentView setNeedsDisplay];
    
}

- (NSString *)text {
    return _attributedString.string;
}

- (void)setAttributedString:(NSAttributedString*)string {
    
    NSAttributedString *aString = _attributedString;
    _attributedString = [string copy];
    [aString release], aString = nil;
    
    [self textChanged];

    if (([self.delegate respondsToSelector:@selector(textViewDidChange:)])) {
        [self.delegate textViewDidChange:self];
    }
    
}

- (void)setText:(NSString *)_text {
    
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:_text attributes:self.defaultAttributes];
    [self setAttributedString:string];
    [string release];

}


#pragma mark -
#pragma mark Layout Methods

- (NSRange)rangeIntersection:(NSRange)first withSecond:(NSRange)second {

    NSRange result = NSMakeRange(NSNotFound, 0);
    
    if (first.location > second.location) {
        NSRange tmp = first;
        first = second;
        second = tmp;
    }
    
    if (second.location < first.location + first.length) {
        result.location = second.location;
        NSUInteger end = MIN(first.location + first.length, second.location + second.length);
        result.length = end - result.location;
    }
    
    return result;    
}

- (void)drawPathFromRects:(NSArray*)array {
    
    if (array==nil || [array count] == 0) return;
    
    CGMutablePathRef _path = CGPathCreateMutable();
    
    CGRect firstRect = CGRectFromString([array lastObject]);
    CGRect lastRect = CGRectFromString([array objectAtIndex:0]);  
    if ([array count]>1) {
        lastRect.size.width = _textContentView.bounds.size.width-lastRect.origin.x;
    }
    CGPathAddRect(_path, NULL, firstRect);
    CGPathAddRect(_path, NULL, lastRect);
    
    if ([array count] > 1) {
                
        CGRect fillRect = CGRectZero;
        
        CGFloat originX = ([array count]==2) ? MIN(CGRectGetMinX(firstRect), CGRectGetMinX(lastRect)) : 0.0f;
        CGFloat originY = firstRect.origin.y + firstRect.size.height;
        CGFloat width = ([array count]==2) ? originX+MIN(CGRectGetMaxX(firstRect), CGRectGetMaxX(lastRect)) : _textContentView.bounds.size.width;
        CGFloat height =  MAX(0.0f, lastRect.origin.y-originY);
        
        fillRect = CGRectMake(originX, originY, width, height);
        CGPathAddRect(_path, NULL, fillRect);

    }
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddPath(ctx, _path);
    CGContextFillPath(ctx);
    CGPathRelease(_path);

}

- (void)drawBoundingRangeAsSelection:(NSRange)selectionRange {
	
    if (!self.editing || selectionRange.length == 0 || selectionRange.location == NSNotFound) {
        return;
    }
    
    NSMutableArray *pathRects = [[NSMutableArray alloc] init];
    NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    CGPoint *origins = (CGPoint*)malloc([lines count] * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, [lines count]), origins);
    NSInteger count = [lines count];
    
    for (int i = 0; i < count; i++) {
       
        CTLineRef line = (CTLineRef) [lines objectAtIndex:i];
        CFRange lineRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(lineRange.location==kCFNotFound ? NSNotFound : lineRange.location, lineRange.length);
        NSRange intersection = [self rangeIntersection:range withSecond:selectionRange];
        
        if (intersection.location != NSNotFound && intersection.length > 0) {

            CGFloat xStart = CTLineGetOffsetForStringIndex(line, intersection.location, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, intersection.location + intersection.length, NULL);
            
            CGPoint origin = origins[i];
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            
            CGRect selectionRect = CGRectMake(xStart, origin.y - descent, xEnd - xStart, ascent + descent); 
            
            if (range.length==1) {
                selectionRect.size.width = _textContentView.bounds.size.width;
            }
            
            [pathRects addObject:NSStringFromCGRect(selectionRect)];
            
        } 
    }  
    
    [self drawPathFromRects:pathRects];
    [pathRects release];
    free(origins);

}

- (void)drawContentInRect:(CGRect)rect {    

    [[EGOTextView selectionColor] setFill];
    [self drawBoundingRangeAsSelection:self.selectedRange];
    [[EGOTextView spellingSelectionColor] setFill];
    [self drawBoundingRangeAsSelection:self.correctionRange];
        
	CGPathRef framePath = CTFrameGetPath(_frame);
	CGRect frameRect = CGPathGetBoundingBox(framePath);
        
	NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    NSInteger count = [lines count];

    CGPoint *origins = (CGPoint*)malloc(count * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, count), origins);    
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	for (int i = 0; i < count; i++) {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex((CFArrayRef)lines, i);
        CGContextSetTextPosition(ctx, frameRect.origin.x + origins[i].x, frameRect.origin.y + origins[i].y);
        CTLineDraw(line, ctx);
	}
    free(origins);
    
}

- (NSInteger)closestWhiteSpaceIndexToPoint:(CGPoint)point {
    
    point = [self convertPoint:point toView:_textContentView];
    __block NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    NSInteger count = [lines count];
    CGPoint *origins = (CGPoint*)malloc(count * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, count), origins); 
    __block NSRange returnRange = NSMakeRange(_attributedString.length, 0);
    
    for (int i = 0; i < lines.count; i++) {
        if (point.y > origins[i].y) {
            
            CTLineRef line = (CTLineRef)[lines objectAtIndex:i];
            CFIndex index = CTLineGetStringIndexForPosition(line, point);  
           
            char character = [_attributedString.string characterAtIndex:MAX(0, index-1)];
            if (character == '\n' || character == ' ') {
                returnRange = NSMakeRange(index, 0);
                break;
            }
            
            CFRange cfRange = CTLineGetStringRange(line);
            NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length);

            if (index==_attributedString.length) {
                break;
            } else if (index==range.location){
                returnRange = NSMakeRange(index, 0);
                break;
            }
            
            [_attributedString.string enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){

                if ((index - enclosingRange.location <= enclosingRange.length)) {

                    if (subStringRange.length == 1) {
                    
                        returnRange = subStringRange;
                    
                    } else if (index < roundf((subStringRange.length/2))) {
                        
                        returnRange = NSMakeRange(subStringRange.location, 0);
                        
                    } else {

                        returnRange = NSMakeRange(subStringRange.location+subStringRange.length, 0);
                        
                    }

                    *stop = YES;
                    
                }
                
            }];
            
            break;
        }
    }
    
    free(origins);
    return  returnRange.location;
    
}

- (NSInteger)closestIndexToPoint:(CGPoint)point {	

    point = [self convertPoint:point toView:_textContentView];
    NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    NSInteger count = [lines count];
    CGPoint *origins = (CGPoint*)malloc(count * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, count), origins);    
    
    for (int i = 0; i < lines.count; i++) {
        if (point.y > origins[i].y) {
            CTLineRef line = (CTLineRef)[lines objectAtIndex:i];
            free(origins);
            return CTLineGetStringIndexForPosition(line, point);            
        }
    }
    
    free(origins);
    return  [_attributedString length];
    
}

- (NSRange)characterRangeAtPoint_:(CGPoint)point {
    
    __block NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    
    CGPoint *origins = (CGPoint*)malloc([lines count] * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, [lines count]), origins);    
    __block NSRange returnRange = NSMakeRange(NSNotFound, 0);

    for (int i = 0; i < lines.count; i++) {
        if (point.y > origins[i].y) {

            CTLineRef line = (CTLineRef)[lines objectAtIndex:i];
            NSInteger index = CTLineGetStringIndexForPosition(line, point);
           
            CFRange cfRange = CTLineGetStringRange(line);
            NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length);

            [_attributedString.string enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                
                if (index - subStringRange.location <= subStringRange.length) {
                    returnRange = subStringRange;
                    *stop = YES;
                }
                
            }];
            break;
        }
    }
    
    free(origins);
    return  returnRange;
    
}


- (NSRange)characterRangeAtIndex:(NSInteger)index {
    
    __block NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    NSInteger count = [lines count];  
   __block NSRange returnRange = NSMakeRange(NSNotFound, 0);
       
    for (int i=count-1; i >= 0; i--) {
        
        __block CTLineRef line = (CTLineRef)[lines objectAtIndex:i];
        CFRange cfRange = CTLineGetStringRange(line);
        NSRange range = NSMakeRange(cfRange.location == kCFNotFound ? NSNotFound : cfRange.location, cfRange.length == kCFNotFound ? 0 : cfRange.length);
        
        if ((index - range.location <= range.length)) {
  
            [_attributedString.string enumerateSubstringsInRange:range options:NSStringEnumerationByWords usingBlock:^(NSString *subString, NSRange subStringRange, NSRange enclosingRange, BOOL *stop){
                
                if (index - subStringRange.location <= subStringRange.length) {
                    returnRange = subStringRange;
                    *stop = YES;
                }
   
            }];
            
            break;
        }
    }

    return returnRange;
    
}

- (CGRect)caretRectForIndex:(NSInteger)index {  
    
    if(_attributedString==nil) return CGRectZero;

    NSArray *lines = (NSArray*)CTFrameGetLines(_frame);
    
    if (_attributedString.length == 0) {
        CGPoint origin = CGPointMake(CGRectGetMinX(_textContentView.bounds), CGRectGetMaxY(_textContentView.bounds) - self.font.leading);
        return CGRectMake(origin.x, origin.y - fabs(self.font.descender), 3, MAX(self.font.ascender + fabs(self.font.descender), self.font.lineHeight));
    }    
    
    /*
    if (_selectedRange.length > 0 && [_attributedString.string characterAtIndex:index-1] == '\n') {
        
        CTLineRef line = (CTLineRef)[lines lastObject];
        CFRange range = CTLineGetStringRange(line);
        CGFloat xPos = CTLineGetOffsetForStringIndex(line, range.location, NULL);
        CGFloat ascent, descent;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
        
        CGPoint origin;
        CGPoint *origins = (CGPoint*)malloc(1 * sizeof(CGPoint));
        CTFrameGetLineOrigins(_frame, CFRangeMake([lines count]-1, 0), origins);
        origin = origins[0];
        free(origins);
        
        origin.y -= self.font.leading;
        return CGRectMake(_textContentView.bounds.size.width - 3.0f, floorf(origin.y - descent), 3, MAX(floorf(ascent + descent), self.font.lineHeight));  
        
    }*/

    if (index == _attributedString.length && [_attributedString.string characterAtIndex:(index - 1)] == '\n' ) {
       
        CTLineRef line = (CTLineRef) [lines lastObject];
        CFRange range = CTLineGetStringRange(line);
        CGFloat xPos = CTLineGetOffsetForStringIndex(line, range.location, NULL);
        CGFloat ascent, descent;
        CTLineGetTypographicBounds(line, &ascent, &descent, NULL);

        CGPoint origin;
        CGPoint *origins = (CGPoint*)malloc(1 * sizeof(CGPoint));
        CTFrameGetLineOrigins(_frame, CFRangeMake([lines count]-1, 0), origins);
        origin = origins[0];
        free(origins);
        
        origin.y -= self.font.leading;
        return CGRectMake(xPos, floorf(origin.y - descent), 3, MAX(floorf(ascent + descent), self.font.lineHeight));   
        
    }

    index = MAX(index, 0);
    index = MIN(_attributedString.string.length, index);

    NSInteger count = [lines count];  
    CGPoint *origins = (CGPoint*)malloc(count * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, count), origins);
    CGRect returnRect = CGRectZero;
    
    for (int i=count-1; i >= 0; i--) {

        CTLineRef line = (CTLineRef)[lines objectAtIndex:i];
        CFRange range = CTLineGetStringRange(line);
        NSRange _range = NSMakeRange(range.location == kCFNotFound ? NSNotFound : range.location, range.length == kCFNotFound ? 0 : range.length);

        BOOL contains = (index - _range.location <= _range.length);         
                
        if (contains) {
        
            if ([_attributedString.string characterAtIndex:index-1] == '\n' && _range.location!=index) {
                index = MAX(0, index-1);
            }
            
            CGFloat xPos;                
            xPos = CTLineGetOffsetForStringIndex((CTLineRef)[lines objectAtIndex:i], index, NULL);                
            
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            
            CGPoint origin = origins[i];
            returnRect = CGRectMake(xPos,  floorf(origin.y - descent), 3, MAX(floorf(ascent + descent), self.font.lineHeight));
           
            break;
        }
    }
    
    free(origins);
    return returnRect;
}

- (CGRect)firstRectForNSRange:(NSRange)range {
    NSInteger index = range.location;
    
    NSArray *lines = (NSArray *) CTFrameGetLines(_frame);
    NSInteger count = [lines count];
    CGPoint *origins = (CGPoint*)malloc(count * sizeof(CGPoint));
    CTFrameGetLineOrigins(_frame, CFRangeMake(0, count), origins);
    CGRect returnRect = CGRectNull;
    
    for (int i = 0; i < count; i++) {
       
        CTLineRef line = (CTLineRef) [lines objectAtIndex:i];
        CFRange lineRange = CTLineGetStringRange(line);
        NSInteger localIndex = index - lineRange.location;
      
        if (localIndex >= 0 && localIndex < lineRange.length) {

            NSInteger finalIndex = MIN(lineRange.location + lineRange.length, range.location + range.length);
            CGFloat xStart = CTLineGetOffsetForStringIndex(line, index, NULL);
            CGFloat xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, NULL);
            CGPoint origin = origins[i];
            CGFloat ascent, descent;
            CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
            
            returnRect = [_textContentView convertRect:CGRectMake(xStart, origin.y - descent, xEnd - xStart, ascent + descent) toView:self];
            break;
        }
    }
    
    free(origins);
    return returnRect;
}


#pragma mark -
#pragma mark Text Selection

- (void)selectionChanged {
    
    if (!self.editing) {
        [_caretView removeFromSuperview];
        return;
    }
    
    if (self.selectedRange.length == 0) {

        if (_selectionView!=nil) {
            [_selectionView removeFromSuperview];
            _selectionView=nil;
        }

        if (!_caretView.superview) {
            [_textContentView addSubview:_caretView];
            [_textContentView setNeedsDisplay];            
        }

        _caretView.frame = [self caretRectForIndex:self.selectedRange.location];
        [_caretView delayBlink];
        
        CGRect frame = _caretView.frame;
        frame.origin.y -= (self.font.lineHeight*2);
        [self scrollRectToVisible:[_textContentView convertRect:frame toView:self] animated:YES];
        
        [_textContentView setNeedsDisplay];
        
        _longPress.minimumPressDuration = 0.5f;
        
    } else {
        
        _longPress.minimumPressDuration = 0.1f;
        
        if (_selectionView==nil) {
            EGOSelectionView *view = [[EGOSelectionView alloc] initWithFrame:_textContentView.bounds];
            [_textContentView addSubview:view];
            _selectionView=view;
            [view release];            
        }
        
        if (_caretView.superview) {
            [_caretView removeFromSuperview];
        }
        
        CGRect begin = [self caretRectForIndex:_selectedRange.location];
        CGRect end = [self caretRectForIndex:_selectedRange.location+_selectedRange.length];
        [_selectionView setBeginCaret:begin endCaret:end];

        [_textContentView setNeedsDisplay];
        
    }    
    
    if (self.markedRange.location != NSNotFound) {
        [_textContentView setNeedsDisplay];
    }
}

- (NSRange)markedRange {
    return _markedRange;
}

- (void)setMarkedRange:(NSRange)range {    
    _markedRange = range;
    //[self selectionChanged];
}

- (NSRange)selectedRange {
    return _selectedRange;
}

- (void)setSelectedRange:(NSRange)range {
    _selectedRange = range;
    [self selectionChanged];
}

- (void)setCorrectionRange:(NSRange)range {

    if (NSEqualRanges(range, _correctionRange) && range.location == NSNotFound && range.length == 0) {
        _correctionRange = range;
        return;
    }
    
    _correctionRange = range;
    if (range.location != NSNotFound && range.length > 0) {
        
        if (_caretView.superview) {
            [_caretView removeFromSuperview];
        }
        
        [self removeCorrectionAttributesForRange:_correctionRange];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        NSString *string = [_attributedString.string substringWithRange:range];
        NSString *theLanguage = [[UITextChecker availableLanguages] objectAtIndex:0];
        if (!theLanguage)
            theLanguage = @"en_US";
        NSArray *guesses = [_textChecker guessesForWordRange:range inString:string language:theLanguage];
        
        if (guesses!=nil && [guesses count]>0) {
            
            NSMutableArray *items = [[NSMutableArray alloc] init];
            
            if (self.menuItemActions==nil) {
                self.menuItemActions = [NSMutableDictionary dictionary];
            }
            
            for (NSString *word in guesses){
                
                NSString *selString = [NSString stringWithFormat:@"spellCheckMenu_%i:", [word hash]];
                SEL sel = sel_registerName([selString UTF8String]);
                
                [self.menuItemActions setObject:word forKey:NSStringFromSelector(sel)]; 
                class_addMethod([self class], sel, [[self class] instanceMethodForSelector:@selector(spellingCorrection:)], "v@:@");
                
                UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:word action:sel];
                [items addObject:item];
                [item release];
                if ([items count]>=4) {
                    break;
                }
            }
            
            [menuController setMenuItems:items];  
            [items release];
            
            [menuController setTargetRect:[self firstRectForNSRange:_correctionRange] inView:self];
            [menuController setMenuVisible:YES animated:YES];
            
            
        } else {
            
            UIMenuItem *item = [[UIMenuItem alloc] initWithTitle:@"No Replacements Found" action:@selector(spellCheckMenuEmpty:)];
            [menuController setMenuItems:[NSArray arrayWithObject:item]];
            [item release];
            
            [menuController setTargetRect:[self firstRectForNSRange:_correctionRange] inView:self];
            [menuController setMenuVisible:YES animated:YES];
            
        }
        
    } else {
        
        if (!_caretView.superview) {
            [_textContentView addSubview:_caretView];
            [_caretView delayBlink];
        }
        
    }
   
    [_textContentView setNeedsDisplay];
    
}

- (void)setEditing:(BOOL)editing {
    _editing = editing;
    [self selectionChanged];
}

- (void)setEditable:(BOOL)editable {
    
    if (editable) {
        
        if (_caretView==nil) {
            _caretView = [[EGOCaretView alloc] initWithFrame:CGRectZero];
        }
        
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
        _textChecker = [[UITextChecker alloc] init];
        _mutableAttributedString = [[NSMutableAttributedString alloc] init];

         NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:(int)(kCTUnderlineStyleThick|kCTUnderlinePatternDot)], kCTUnderlineStyleAttributeName, (id)[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f].CGColor, kCTUnderlineColorAttributeName, nil];
        self.correctionAttributes = dictionary;
        [dictionary release];
        
    } else {
        
        if (_caretView) {
            [_caretView removeFromSuperview];
            [_caretView release], _caretView=nil;
        }
        
        self.correctionAttributes=nil;
        [_textChecker release], _textChecker=nil;
        [_tokenizer release], _tokenizer=nil;
        [_mutableAttributedString release], _mutableAttributedString=nil;
        
    }
    _editable = editable;
    
}

+ (UIColor*)selectionColor {
    static UIColor *color = nil;
    if (color == nil) {
        color = [[UIColor colorWithRed:0.800f green:0.867f blue:0.929f alpha:1.0f] retain];    
    }    
    return color;
}

+ (UIColor*)caretColor {
    static UIColor *color = nil;
    if (color == nil) {
        color = [[UIColor colorWithRed:0.25 green:0.50 blue:1.0 alpha:1.0] retain];
    }
    return color;
}

+ (UIColor*)spellingSelectionColor {
    static UIColor *color = nil;
    if (color == nil) {
        color = [[UIColor colorWithRed:1.000f green:0.851f blue:0.851f alpha:1.0f] retain];
    }
    return color;
}


#pragma mark -
#pragma mark UITextInput methods

#pragma mark UITextInput - Replacing and Returning Text

- (NSString *)textInRange:(UITextRange *)range {
    IndexedRange *r = (IndexedRange *)range;
    return ([_attributedString.string substringWithRange:r.range]);
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
    
    IndexedRange *r = (IndexedRange *)range;

    NSRange selectedNSRange = self.selectedRange;
    if ((r.range.location + r.range.length) <= selectedNSRange.location) {
        selectedNSRange.location -= (r.range.length - text.length);
    } else {
        selectedNSRange = [self rangeIntersection:r.range withSecond:_selectedRange];
    }
    
    [_mutableAttributedString replaceCharactersInRange:r.range withString:text];        
    self.attributedString = _mutableAttributedString;
    self.selectedRange = selectedNSRange;
    
}


#pragma mark UITextInput - Working with Marked and Selected Text

- (UITextRange *)selectedTextRange {
    return [IndexedRange rangeWithNSRange:self.selectedRange];
}

- (void)setSelectedTextRange:(UITextRange *)range {
    IndexedRange *r = (IndexedRange *)range;
    self.selectedRange = r.range;
}

- (UITextRange *)markedTextRange {
    return [IndexedRange rangeWithNSRange:self.markedRange];    
}

- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange {
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;
    
    if (markedTextRange.location != NSNotFound) {
        if (!markedText)
            markedText = @"";
        
        [_mutableAttributedString replaceCharactersInRange:markedTextRange withString:markedText];
        markedTextRange.length = markedText.length;
        
    } else if (selectedNSRange.length > 0) {
        
        [_mutableAttributedString replaceCharactersInRange:selectedNSRange withString:markedText];
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
        
    } else {
        
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:markedText attributes:self.defaultAttributes];
        [_mutableAttributedString insertAttributedString:string atIndex:selectedNSRange.location];  
        [string release];
        
        markedTextRange.location = selectedNSRange.location;
        markedTextRange.length = markedText.length;
    }
    
    selectedNSRange = NSMakeRange(selectedRange.location + markedTextRange.location, selectedRange.length);
    
    self.attributedString = _attributedString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;    
    
}

- (void)unmarkText {
    
    NSRange markedTextRange = self.markedRange;
    
    if (markedTextRange.location == NSNotFound)
        return;
    
    markedTextRange.location = NSNotFound;
    self.markedRange = markedTextRange;   
    
}


#pragma mark UITextInput - Computing Text Ranges and Text Positions

- (UITextPosition*)beginningOfDocument {
    return [IndexedPosition positionWithIndex:0];
}

- (UITextPosition*)endOfDocument {
    return [IndexedPosition positionWithIndex:_attributedString.length];
}

- (UITextRange*)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition {

    IndexedPosition *from = (IndexedPosition *)fromPosition;
    IndexedPosition *to = (IndexedPosition *)toPosition;    
    NSRange range = NSMakeRange(MIN(from.index, to.index), ABS(to.index - from.index));
    return [IndexedRange rangeWithNSRange:range];    
    
}

- (UITextPosition*)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {

    IndexedPosition *pos = (IndexedPosition *)position;    
    NSInteger end = pos.index + offset;
	
    if (end > _attributedString.length || end < 0)
        return nil;
    
    return [IndexedPosition positionWithIndex:end];
}

- (UITextPosition*)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset {

    IndexedPosition *pos = (IndexedPosition *)position;
    NSInteger newPos = pos.index;
    
    switch (direction) {
        case UITextLayoutDirectionRight:
            newPos += offset;
            break;
        case UITextLayoutDirectionLeft:
            newPos -= offset;
            break;
        UITextLayoutDirectionUp:
        UITextLayoutDirectionDown:
            break;
    }
    	
    if (newPos < 0)
        newPos = 0;
    
    if (newPos > _attributedString.length)
        newPos = _attributedString.length;
    
    return [IndexedPosition positionWithIndex:newPos];
}


#pragma mark UITextInput - Evaluating Text Positions

- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other {
    IndexedPosition *pos = (IndexedPosition *)position;
    IndexedPosition *o = (IndexedPosition *)other;
    
    if (pos.index == o.index) {
        return NSOrderedSame;
    } if (pos.index < o.index) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition {
    IndexedPosition *f = (IndexedPosition *)from;
    IndexedPosition *t = (IndexedPosition *)toPosition;
    return (t.index - f.index);
}


#pragma mark UITextInput - Text Input Delegate and Text Input Tokenizer

- (id <UITextInputTokenizer>)tokenizer {
    return _tokenizer;
}


#pragma mark UITextInput - Text Layout, writing direction and position

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction {

    IndexedRange *r = (IndexedRange *)range;
    NSInteger pos = r.range.location;
    
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            pos = r.range.location;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:            
            pos = r.range.location + r.range.length;
            break;
    }
    
    return [IndexedPosition positionWithIndex:pos];        
}

- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction {

    IndexedPosition *pos = (IndexedPosition *)position;
    NSRange result = NSMakeRange(pos.index, 1);
    
    switch (direction) {
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionLeft:
            result = NSMakeRange(pos.index - 1, 1);
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:            
            result = NSMakeRange(pos.index, 1);
            break;
    }
    
    return [IndexedRange rangeWithNSRange:result];   
}

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction {
    return UITextWritingDirectionLeftToRight;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range {
    // only ltr supported for now.
}


#pragma mark UITextInput - Geometry

- (CGRect)firstRectForRange:(UITextRange *)range {
    
    IndexedRange *r = (IndexedRange *)range;    
    return [self firstRectForNSRange:r.range];   
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    
    IndexedPosition *pos = (IndexedPosition *)position;
	return [self caretRectForIndex:pos.index];    
}


#pragma mark UITextInput - Hit testing

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
    
    IndexedPosition *position = [IndexedPosition positionWithIndex:[self closestIndexToPoint:point]];
    return position;
    
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range {
	
    IndexedPosition *position = [IndexedPosition positionWithIndex:[self closestIndexToPoint:point]];
    return position;
    
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
	
    IndexedRange *range = [IndexedRange rangeWithNSRange:[self characterRangeAtPoint_:point]];
    return range;
    
}


#pragma mark UITextInput - Styling Information

- (NSDictionary*)textStylingAtPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction {
    // This sample assumes all text is single-styled, so this is easy.
    return [NSDictionary dictionaryWithObject:self.font forKey:UITextInputTextFontKey];
}


#pragma mark -
#pragma mark UIKeyInput methods

- (BOOL)hasText {
    return (_attributedString.length != 0);
}

- (void)insertText:(NSString *)text {
    
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;
    
    NSAttributedString *newString = [[NSAttributedString alloc] initWithString:text attributes:self.defaultAttributes];
    
    if (_correctionRange.location != NSNotFound && _correctionRange.length > 0){
        
        [_mutableAttributedString replaceCharactersInRange:self.correctionRange withAttributedString:newString];
        selectedNSRange.length = 0;
        selectedNSRange.location = (self.correctionRange.location+text.length);
        self.correctionRange = NSMakeRange(NSNotFound, 0);

    } else if (markedTextRange.location != NSNotFound) {
        
        [_mutableAttributedString replaceCharactersInRange:markedTextRange withAttributedString:newString];
        selectedNSRange.location = markedTextRange.location + text.length;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0); 
        
    } else if (selectedNSRange.length > 0) {
        
        [_mutableAttributedString replaceCharactersInRange:selectedNSRange withAttributedString:newString];
        selectedNSRange.length = 0;
        selectedNSRange.location = (selectedNSRange.location + text.length);
        
    } else {
        
        [_mutableAttributedString insertAttributedString:newString atIndex:selectedNSRange.location];        
        selectedNSRange.location += text.length;
        
    }
    
    [newString release];
    
    self.attributedString = _mutableAttributedString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange;  
    
    if (text.length > 1 || ([text isEqualToString:@" "] || [text isEqualToString:@"\n"])) {
        [self checkSpelling];
    }

}

- (void)deleteBackward  {
    
    NSRange selectedNSRange = self.selectedRange;
    NSRange markedTextRange = self.markedRange;
    
    
    if (_correctionRange.location != NSNotFound && _correctionRange.length > 0) {
        
        [_mutableAttributedString beginEditing];
        [_mutableAttributedString deleteCharactersInRange:self.correctionRange];
        [_mutableAttributedString endEditing];
        self.correctionRange = NSMakeRange(NSNotFound, 0);
        selectedNSRange.length = 0;

    } else if (markedTextRange.location != NSNotFound) {
        
        [_mutableAttributedString beginEditing];
        [_mutableAttributedString deleteCharactersInRange:selectedNSRange];
        [_mutableAttributedString endEditing];
        
        selectedNSRange.location = markedTextRange.location;
        selectedNSRange.length = 0;
        markedTextRange = NSMakeRange(NSNotFound, 0);
        
    } else if (selectedNSRange.length > 0) {
        
        [_mutableAttributedString beginEditing];
        [_mutableAttributedString deleteCharactersInRange:selectedNSRange];
        [_mutableAttributedString endEditing];
        
        selectedNSRange.length = 0;
        
    } else if (selectedNSRange.location > 0) {
        
        selectedNSRange.location--;
        selectedNSRange.length = 1;
        
        [_mutableAttributedString beginEditing];
        [_mutableAttributedString deleteCharactersInRange:selectedNSRange];
        [_mutableAttributedString endEditing];
        
        selectedNSRange.length = 0;
        
    }
    
    self.attributedString = _mutableAttributedString;
    self.markedRange = markedTextRange;
    self.selectedRange = selectedNSRange; 
    
}


#pragma mark -
#pragma mark SpellCheck 

- (void)insertCorrectionAttributesForRange:(NSRange)range {
    
    NSMutableAttributedString *string = [_attributedString mutableCopy];
    [string removeAttribute:(NSString*)kCTUnderlineStyleAttributeName range:range];
    self.attributedString = string;
    [string release];
    
}

- (void)removeCorrectionAttributesForRange:(NSRange)range {
    
    NSMutableAttributedString *string = [_attributedString mutableCopy];
    [string addAttributes:self.correctionAttributes range:range];
    self.attributedString = string;
    [string release];
    
}

- (void)checkSpellingForRange:(NSRange)range {
    
   range = [_textChecker rangeOfMisspelledWordInString:_attributedString.string range:NSMakeRange(0, _attributedString.length) startingAt:0 wrap:YES language:@"en_US"];
    
    if (range.location!=NSNotFound && range.length > 1) {
        
        NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:(int)(kCTUnderlineStyleThick|kCTUnderlinePatternDot)], kCTUnderlineStyleAttributeName, (id)[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0f].CGColor, kCTUnderlineColorAttributeName, nil];
        [_mutableAttributedString addAttributes:dictionary range:range];
        self.attributedString = _attributedString;
        [dictionary release];
        
    }
    
    
}

- (void)checkSpelling {
    
    NSInteger currentOffset = 0;
    NSRange currentRange = NSMakeRange(0, 0);
    NSString *theText = _attributedString.string;
    NSRange stringRange = NSMakeRange(0, theText.length-1);
    NSArray *guesses;
    BOOL done = NO;
    
    NSString *theLanguage = [[UITextChecker availableLanguages] objectAtIndex:0];
    if (!theLanguage)
        theLanguage = @"en_US";
    
    while (!done) {
        
        currentRange = [_textChecker rangeOfMisspelledWordInString:theText range:stringRange
                                                       startingAt:currentOffset wrap:NO language:theLanguage];
        if (currentRange.location == NSNotFound) {
            done = YES;
            continue;
        }
        guesses = [_textChecker guessesForWordRange:currentRange inString:theText
                                          language:theLanguage];
        
        
        if (guesses!=nil) {           
            [_mutableAttributedString addAttributes:self.correctionAttributes range:currentRange];
        }
        
        currentOffset = currentOffset + (currentRange.length-1);
        
    }
    
    if (![self.attributedString isEqualToAttributedString:_mutableAttributedString]) {
        self.attributedString = _mutableAttributedString;
    }

    
}


#pragma mark -
#pragma mark Gestures 

- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    
    if (gesture.state==UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
    
        BOOL _selection = (_selectionView!=nil);

        if (!_selection && _caretView!=nil) {
            [_caretView show];
        }
        
        if (_textWindow==nil) {
            
            EGOTextWindow *window = nil;
            
            for (EGOTextWindow *aWindow in [[UIApplication sharedApplication] windows]){
                if ([aWindow isKindOfClass:[EGOTextWindow class]]) {
                    window = aWindow;
                    window.hidden=NO;
                    window.frame = [[UIScreen mainScreen] bounds];
                    break;
                }
            }
            
            if (window==nil) {
                window = [[EGOTextWindow alloc] initWithFrame:self.window.frame];
                window.windowLevel = UIWindowLevelStatusBar;
                [window makeKeyAndVisible];
            }
            
            _textWindow=window;
            [_textWindow setType:_selection ? EGOWindowMagnify : EGOWindowLoupe];
        }
           
        CGPoint point = [gesture locationInView:self];
        point.y -= 20.0f;
        NSInteger index = [self closestIndexToPoint:point];
        
        if (index!=kCFNotFound) {
            if (_selection) {
                
                if (gesture.state == UIGestureRecognizerStateBegan) {
                    BOOL left = NO;
                    if (index < _selectedRange.location) {
                        left = YES;
                    } else if (index > _selectedRange.location+_selectedRange.length) {
                        left = NO;
                    } else {
                        
                        NSInteger leftDiff =  index - _selectedRange.location;
                        NSInteger rightDiff = (_selectedRange.location+_selectedRange.length)-index;
                        
                        left = (leftDiff < rightDiff);
                        
                    }
                    
                    _textWindow.selectionType = left ? EGOSelectionTypeLeft : EGOSelectionTypeRight;
                }
               
                CGRect rect = CGRectZero;
                if (_textWindow.selectionType==EGOSelectionTypeLeft) {
                  
                    NSInteger begin = MAX(0, index);
                    begin = MIN(_selectedRange.location+_selectedRange.length-1, begin);

                    NSInteger end = _selectedRange.location + _selectedRange.length;
                    end = MIN(_attributedString.string.length, end-begin);
                    
                    self.selectedRange = NSMakeRange(begin, end);
                    rect = [self caretRectForIndex:(self.selectedRange.location)];
                
                } else {
                    
                    NSInteger length = MIN(index-_selectedRange.location, _attributedString.string.length-_selectedRange.location);
                    length = MAX(1, length);
                    
                    self.selectedRange = NSMakeRange(self.selectedRange.location, length);
                    rect = [self caretRectForIndex:(self.selectedRange.location+length)];
                    
                }
                
                if (gesture.state == UIGestureRecognizerStateBegan) {
                    [_textWindow showFromView:_textContentView rect:[_textContentView convertRect:rect toView:_textWindow]];
                } else {
                    [_textWindow renderWithContentView:_textContentView fromRect:rect];
                }
                
            } else {
                
                CGPoint location = [gesture locationInView:_textWindow];
                CGRect rect = CGRectMake(location.x, location.y, _caretView.bounds.size.width, _caretView.bounds.size.height);
                
                self.selectedRange = NSMakeRange(index, 0);

                if (gesture.state == UIGestureRecognizerStateBegan) {
                
                    [_textWindow showFromView:_textContentView rect:rect];
               
                } else {
                    
                    [_textWindow renderWithContentView:_textContentView fromRect:rect];
                
                }
                
            }
        }
        
    } else {
        
        if (_caretView!=nil) {
            [_caretView delayBlink];
        }
        
        if ((_textWindow!=nil)) {
            [_textWindow hide:YES];
            _textWindow=nil;
        }
        
        if (self.selectedRange.length>0) {
            
            UIMenuController *controller = [UIMenuController sharedMenuController];
            [controller setTargetRect:_caretView.frame inView:_textContentView];
            [controller update];
            [controller setMenuVisible:YES animated:YES];
            
        }
        
    }
    
}


#pragma mark -
#pragma mark Touches


- (void)showMenu {
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setMenuItems:nil];
    [menuController setTargetRect:_caretView.frame inView:self];
    [menuController update];
    [menuController setMenuVisible:YES animated:YES];

}

- (void)showCorrectionMenu {
    
    if (_editing) {

        NSRange range = [self characterRangeAtIndex:self.selectedRange.location];
        NSLog(@"char at index : %i %i", range.location, range.length);
        if (range.location!=NSNotFound && range.length>0) {
            
            NSString *language = [[UITextChecker availableLanguages] objectAtIndex:0];
            if (!language)
                language = @"en_US";
            self.correctionRange = [_textChecker rangeOfMisspelledWordInString:_attributedString.string range:range startingAt:0 wrap:YES language:language];
            
        }
        
    }
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showMenu) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showCorrectionMenu) object:nil];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    if ([self isEditable] && ![self isFirstResponder]) {
        [self becomeFirstResponder];  
        return;
    }
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    
    self.correctionRange = NSMakeRange(NSNotFound, 0);
    if (self.selectedRange.length>0) {
        self.selectedRange = NSMakeRange(_selectedRange.location, 0);
    }
    
    if ([menuController isMenuVisible]) {
        [menuController setMenuVisible:NO animated:NO];
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    if (([touch tapCount] == 2)) {
                      
        NSRange range = [self characterRangeAtPoint_:[touch locationInView:_textContentView]];
        if (range.location!=NSNotFound && range.length>0) {
            
            self.selectedRange = range;

            if (![menuController isMenuVisible]) {
                [menuController setMenuItems:nil];
                [menuController setTargetRect:[self firstRectForNSRange:self.selectedRange] inView:self];
                [menuController update];
                [menuController setMenuVisible:YES animated:YES];
            }
            
        } 

    } else if ([touch tapCount] == 1) {
            
        [self.inputDelegate selectionWillChange:self];
        
        NSInteger index = [self closestWhiteSpaceIndexToPoint:[touch locationInView:self]];
        if (index==self.selectedRange.location) {
            [self performSelector:@selector(showMenu) withObject:nil afterDelay:0.3f];
        } else {
            [self performSelector:@selector(showCorrectionMenu) withObject:nil afterDelay:0.3f];
        }
        if (index!=kCFNotFound) {
            self.markedRange = NSMakeRange(NSNotFound, 0);
            self.selectedRange = NSMakeRange(index, 0);
        }
        [self.inputDelegate selectionDidChange:self];          

     
    }
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
}


#pragma mark -
#pragma mark UIResponder

- (BOOL)canBecomeFirstResponder {

    if ([self isEditable] && ([self.delegate respondsToSelector:@selector(textViewShouldBeginEditing:)])) {
        return [self.delegate textViewShouldBeginEditing:self];
    }
    
    return YES;
}

- (BOOL)becomeFirstResponder {

    if (([self.delegate respondsToSelector:@selector(textViewDidBeginEditing:)])) {
        [self.delegate textViewDidBeginEditing:self];
    }

    self.editing = YES;
    return [super becomeFirstResponder];
}

- (BOOL)canResignFirstResponder {
    
    if (([self.delegate respondsToSelector:@selector(textViewShouldEndEditing:)])) {
        return [self.delegate textViewShouldEndEditing:self];
    }
    
    return YES;
}

- (BOOL)resignFirstResponder {
    
    if (([self.delegate respondsToSelector:@selector(textViewDidEndEditing:)])) {
        [self.delegate textViewDidEndEditing:self];
    }
    
    self.editing = NO;	
	return [super resignFirstResponder];
    
}


#pragma mark -
#pragma mark Menu Actions

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    
    if (self.correctionRange.length>0) {
        
        if ([NSStringFromSelector(action) hasPrefix:@"spellCheckMenu"]) {
            return YES;
        }
        
        return NO;
    }
    
    if ((action==@selector(cut:)) || (action==@selector(delete:))) {
        return (_selectedRange.length>0 && _editing);
    } else if (action==@selector(copy:)) {
        return ((_selectedRange.length>0));
    } else if ((action == @selector(select:) || action == @selector(selectAll:))) {
        return (_selectedRange.length==0 && [self hasText]);
    } else if (action == @selector(paste:)) {
        return (_editing && [[UIPasteboard generalPasteboard] containsPasteboardTypes:[NSArray arrayWithObject:@"public.utf8-plain-text"]]);
    }

    return [super canPerformAction:action withSender:sender];
    
}

- (void)spellingCorrection:(UIMenuController*)sender {
    
    [self replaceRange:[IndexedRange rangeWithNSRange:self.correctionRange] withText:[self.menuItemActions objectForKey:NSStringFromSelector(_cmd)]];
    self.correctionRange = NSMakeRange(NSNotFound, 0);
    self.menuItemActions = nil;
    [sender setMenuItems:nil];
    
}

- (void)spellCheckMenuEmpty:(id)sender{

    self.correctionRange = NSMakeRange(NSNotFound, 0);
    
}

- (void)paste:(id)sender {
    
    NSString *pasteText = [[UIPasteboard generalPasteboard] valueForPasteboardType:@"public.utf8-plain-text"];
    
    if (pasteText!=nil) {
        
        NSMutableAttributedString *string = [self.attributedString mutableCopy];
        NSAttributedString *newString = [[NSAttributedString alloc] initWithString:pasteText attributes:self.defaultAttributes];
        [string insertAttributedString:newString atIndex:_selectedRange.location];
        [self setAttributedString:string];
        
        NSRange range = NSMakeRange(_selectedRange.location+[newString length], 0);
        self.selectedRange = range;
        
        [newString release];
        [string release];

    }
    
}

- (void)menuDidHide:(NSNotification*)notification {
    
    if (_selectionView) {
        UIMenuController *controller = [UIMenuController sharedMenuController];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller update];
            [controller setTargetRect:_selectionView.frame inView:self];
            [controller setMenuVisible:YES animated:YES];
        });
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIMenuControllerDidHideMenuNotification object:nil];
    
}

- (void)selectAll:(id)sender {
    
    NSString *string = [_attributedString string];
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.selectedRange = [_attributedString.string rangeOfString:trimmedString];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];

}

- (void)select:(id)sender {
        
    NSRange range = [self characterRangeAtPoint_:_caretView.center];
    self.selectedRange = range;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:) name:UIMenuControllerDidHideMenuNotification object:nil];

}

- (void)cut:(id)sender {
    
    NSString *string = [_attributedString.string substringWithRange:_selectedRange];
    [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
    
    NSMutableAttributedString *mutableString = [self.attributedString mutableCopy];
    [mutableString deleteCharactersInRange:_selectedRange];
    [self setAttributedString:mutableString];
    [mutableString release];
    
    self.selectedRange = NSMakeRange(_selectedRange.location, 0);
    
}

- (void)copy:(id)sender {
    
    NSString *string = [self.attributedString.string substringWithRange:_selectedRange];
    [[UIPasteboard generalPasteboard] setValue:string forPasteboardType:@"public.utf8-plain-text"];
    
}

- (void)delete:(id)sender {
    
    NSMutableAttributedString *string = [self.attributedString mutableCopy];
    [string deleteCharactersInRange:_selectedRange];
    [self setAttributedString:string];
    [string release];
    
    self.selectedRange = NSMakeRange(_selectedRange.location, 0);
    
}

- (void)replace:(id)sender {
    
    
}


#pragma mark -
#pragma mark Dealloc EGOTextView

- (void)dealloc {

    _textWindow=nil;
    self.font = nil;
    self.menuItemActions=nil;
    self.defaultAttributes=nil;
    self.correctionAttributes=nil;
    self.attributedString=nil;
    self.text=nil;
    [_caretView release];
    [super dealloc];
}

@end

#pragma mark -
#pragma mark IndexedPosition

@implementation IndexedPosition 
@synthesize index=_index;

+ (IndexedPosition *)positionWithIndex:(NSUInteger)index {
    IndexedPosition *pos = [[IndexedPosition alloc] init];
    pos.index = index;
    return [pos autorelease];
}

@end


#pragma mark -
#pragma mark IndexedRange 

@implementation IndexedRange 
@synthesize range=_range;

+ (IndexedRange *)rangeWithNSRange:(NSRange)theRange {
    if (theRange.location == NSNotFound)
        return nil;
    
    IndexedRange *range = [[IndexedRange alloc] init];
    range.range = theRange;
    return [range autorelease];
}

- (UITextPosition *)start {
    return [IndexedPosition positionWithIndex:self.range.location];
}

- (UITextPosition *)end {
	return [IndexedPosition positionWithIndex:(self.range.location + self.range.length)];
}

-(BOOL)isEmpty {
    return (self.range.length == 0);
}

@end


#pragma mark -
#pragma mark ContentView

@implementation EGOContentView

@synthesize delegate=_delegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        
        self.userInteractionEnabled = NO;
        self.layer.geometryFlipped = YES;
        self.backgroundColor = [UIColor whiteColor];
        
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    
    [_delegate drawContentInRect:rect];
    
}

- (void)dealloc {
    [super dealloc];
}

@end


#pragma mark -
#pragma mark CaretView

@implementation EGOCaretView

static const NSTimeInterval kInitialBlinkDelay = 0.7;
static const NSTimeInterval kBlinkRate = 0.5;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [EGOTextView caretColor];
    }    
    return self;
}

- (void)blink {
    self.hidden = !self.hidden;
}

- (void)show {
    
    self.hidden = NO;
    [_blinkTimer setFireDate:[NSDate distantFuture]];

}

- (void)didMoveToSuperview {
    self.hidden = NO;

    if (self.superview) {
        _blinkTimer = [[NSTimer scheduledTimerWithTimeInterval:kBlinkRate target:self selector:@selector(blink) userInfo:nil repeats:YES] retain];
        [self delayBlink];
    } else {
        [_blinkTimer invalidate];
        [_blinkTimer release];
        _blinkTimer = nil;        
    }
}

- (void)delayBlink {
    self.hidden = NO;
    [_blinkTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:kInitialBlinkDelay]];
}

- (void)dealloc {
    [_blinkTimer invalidate];
    [_blinkTimer release];
    [super dealloc];
}

@end


#pragma mark -
#pragma mark LoupeView

@implementation EGOLoupeView

- (id)init {
    if ((self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 127.0f, 127.0f)])) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [[UIImage imageNamed:@"loupe-lo.png"] drawInRect:rect];
    
    if ((_contentImage!=nil)) {
        
        CGContextSaveGState(ctx);
        CGContextClipToMask(ctx, rect, [UIImage imageNamed:@"loupe-mask.png"].CGImage);
        [_contentImage drawInRect:rect];        
        CGContextRestoreGState(ctx);
        
    }
    
    [[UIImage imageNamed:@"loupe-hi.png"] drawInRect:rect];
    
}

- (void)setContentImage:(UIImage *)image {
    
    [_contentImage release], _contentImage=nil;
    _contentImage = [image retain];
    [self setNeedsDisplay];

}

- (void)dealloc {
    [_contentImage release], _contentImage=nil;
    [super dealloc];
}

@end


#pragma mark -
#pragma mark EGOTextWindow

@implementation EGOTextWindow

@synthesize showing=_showing;
@synthesize selectionType=_selectionType;
@synthesize type=_type;

static const CGFloat kLoupeScale = 1.2f;
static const CGFloat kMagnifyScale = 1.0f;
static const NSTimeInterval kDefaultAnimationDuration = 0.15f;

- (id)initWithFrame:(CGRect)frame{    
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _type = EGOWindowLoupe;
    }
    return self;
}

- (NSInteger)selectionForRange:(NSRange)range {
    return range.location;
}

- (void)showFromView:(UIView*)view rect:(CGRect)rect {
        
    CGPoint pos = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
    
    if (!_showing) {
        
        if ((_view==nil)) {
            UIView *view;
            if (_type==EGOWindowLoupe) {
                view = [[EGOLoupeView alloc] init];
            } else {
                view = [[EGOMagnifyView alloc] init];
            }
            [self addSubview:view];
            _view=view;
            [view release];
        }
                        
        CGRect frame = _view.frame;
        frame.origin.x = floorf(pos.x - (_view.bounds.size.width/2));
        frame.origin.y = floorf(pos.y - _view.bounds.size.height);
        
        if (_type==EGOWindowMagnify) {
            
            frame.origin.y = MAX(frame.origin.y+8.0f, 0.0f);
            frame.origin.x += 2.0f;
            
        } else {
            
            frame.origin.y = MAX(frame.origin.y-10.0f, -40.0f);
            
        }
        
        CGRect originFrame = frame;
        frame.origin.y += frame.size.height/2;
        _view.frame = frame;
        _view.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
        _view.alpha = 0.01f;
        
        [UIView animateWithDuration:kDefaultAnimationDuration animations:^{
            
            _view.alpha = 1.0f;
            _view.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            _view.frame = originFrame;

        } completion:^(BOOL finished) {
            
            _showing=YES;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.0f*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self renderWithContentView:view fromRect:rect];
            });
            
            
        }];
        
    }
    
}

- (void)hide:(BOOL)animated {
    
    if ((_view!=nil)) {
        
        [UIView animateWithDuration:kDefaultAnimationDuration animations:^{
                        
            CGRect frame = _view.frame;
            CGPoint center = _view.center;
            frame.origin.x = floorf(center.x-(frame.size.width/2));
            frame.origin.y = center.y;
            _view.frame = frame;
            _view.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
            
        } completion:^(BOOL finished) {

            _showing=NO;
            [_view removeFromSuperview];
            _view=nil;
            self.hidden = YES;

        }];
        
    }
    
}

- (UIImage*)screenshotFromCaretFrame:(CGRect)rect inView:(UIView*)view scale:(BOOL)scale{
    
    CGRect offsetRect = [self convertRect:rect toView:view];
    offsetRect.origin.y += ((UIScrollView*)view.superview).contentOffset.y;
    offsetRect.origin.y -= _view.bounds.size.height+20.0f;
    offsetRect.origin.x -= (_view.bounds.size.width/2);
    
    CGFloat magnifyScale = 1.0f; 
    
    if (scale) {
        CGFloat max = 24.0f;
        magnifyScale = max/offsetRect.size.height;
        NSLog(@"max %f scale %f", max, magnifyScale);
    } else if (rect.size.height < 22.0f) {
        //magnifyScale = 22.0f/offsetRect.size.height;
        //NSLog(@"cale %f", magnifyScale);
    }

    UIGraphicsBeginImageContextWithOptions(_view.bounds.size, YES, [[UIScreen mainScreen] scale]);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:1.0f].CGColor);
    UIRectFill(CGContextGetClipBoundingBox(ctx));
    
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, view.bounds.size.height);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    CGContextConcatCTM(ctx, CGAffineTransformMakeScale(magnifyScale, magnifyScale));
    CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(-(offsetRect.origin.x), offsetRect.origin.y));

    [view.layer renderInContext:ctx];
  
    CGContextRestoreGState(ctx);
    
    CGContextConcatCTM(ctx, CGAffineTransformMakeScale(magnifyScale, magnifyScale));
    CGContextConcatCTM(ctx, CGAffineTransformMakeTranslation(-rect.origin.x*magnifyScale, rect.origin.y*magnifyScale));
    for (CALayer *layer in view.layer.sublayers){
        [layer renderInContext:ctx];
    }
    
    UIImage *aImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return aImage;
    
}

- (void)renderWithContentView:(UIView*)view fromRect:(CGRect)rect {

    CGPoint pos = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
    
    if (_showing && _view!=nil) {
        
        CGRect frame = _view.frame;
        frame.origin.x = floorf((pos.x - (_view.bounds.size.width/2)) + (rect.size.width/2));

        if (_type==EGOWindowMagnify) {
            frame.origin.y = MAX(frame.origin.y, 0.0f);
        } else {
            frame.origin.y = floorf(pos.y - _view.bounds.size.height);
            frame.origin.y = MAX(frame.origin.y-10.0f, -40.0f);
            rect = [self convertRect:rect toView:view];
        }
        _view.frame = frame;

        UIImage *image = [self screenshotFromCaretFrame:rect inView:view scale:(_type==EGOWindowMagnify)];
        [(EGOLoupeView*)_view setContentImage:image];
        
    }
    
}

- (void)dealloc {
    _view=nil;
    [super dealloc];
}

@end


#pragma mark -
#pragma mark MagnifyView

@implementation EGOMagnifyView

- (id)init {
    if ((self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 145.0f, 59.0f)])) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [[UIImage imageNamed:@"magnifier-ranged-lo.png"] drawInRect:rect];
    
    if ((_contentImage!=nil)) {
        
        CGContextSaveGState(ctx);
        CGContextClipToMask(ctx, rect, [UIImage imageNamed:@"magnifier-ranged-mask.png"].CGImage);
        [_contentImage drawInRect:rect];        
        CGContextRestoreGState(ctx);
        
    }
    
    [[UIImage imageNamed:@"magnifier-ranged-hi.png"] drawInRect:rect];
    
}

- (void)setContentImage:(UIImage *)image {
    
    [_contentImage release], _contentImage=nil;
    _contentImage = [image retain];
    [self setNeedsDisplay];
    
}

- (void)dealloc {
    [_contentImage release], _contentImage=nil;
    [super dealloc];
}

@end


#pragma mark -
#pragma mark SelectionView

@implementation EGOSelectionView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
       
        self.backgroundColor = [UIColor clearColor]; 
        self.userInteractionEnabled = NO;
        self.layer.geometryFlipped = YES;
    }
    return self;
}

- (void)setBeginCaret:(CGRect)begin endCaret:(CGRect)end {
    
    if(!self.superview) return;
    
    self.frame = CGRectMake(self.frame.origin.x, begin.origin.y, end.origin.x - begin.origin.x, CGRectGetMaxY(end)-begin.origin.y);   
    begin = [self.superview convertRect:begin toView:self];
    end = [self.superview convertRect:end toView:self];
    

    if (_leftCaret==nil) {
        UIView *view = [[UIView alloc] initWithFrame:begin];
        view.backgroundColor = [EGOTextView caretColor];
        [self addSubview:view]; 
        _leftCaret=[view retain];
        [view release];
    }
    
    if (_leftDot==nil) {
        UIImage *dotImage = [UIImage imageNamed:@"drag-dot.png"];
        UIImageView *view = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, dotImage.size.width, dotImage.size.height)];
        [view setImage:dotImage];
        [self addSubview:view];
        _leftDot = view;
        [view release];
    }
    
    CGFloat _dotShadowOffset = 5.0f;
    _leftCaret.frame = begin;
    _leftDot.frame = CGRectMake(floorf(_leftCaret.center.x - (_leftDot.bounds.size.width/2)), _leftCaret.frame.origin.y-(_leftDot.bounds.size.height-_dotShadowOffset), _leftDot.bounds.size.width, _leftDot.bounds.size.height);
    
    if (_rightCaret==nil) {
        UIView *view = [[UIView alloc] initWithFrame:end];
        view.backgroundColor = [EGOTextView caretColor];
        [self addSubview:view];
        _rightCaret = [view retain];
        [view release];
    }
    
    if (_rightDot==nil) {
        UIImage *dotImage = [UIImage imageNamed:@"drag-dot.png"];
        UIImageView *view = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, dotImage.size.width, dotImage.size.height)];
        [view setImage:dotImage];
        [self addSubview:view];
        _rightDot = view;
        [view release];
    }
    
    _rightCaret.frame = end;
    _rightDot.frame = CGRectMake(floorf(_rightCaret.center.x - (_rightDot.bounds.size.width/2)), CGRectGetMaxY(_rightCaret.frame), _rightDot.bounds.size.width, _rightDot.bounds.size.height);
    

}

- (void)dealloc {
    
   [_leftCaret release], _leftCaret=nil;
   [_rightCaret release], _rightCaret=nil;
    _rightDot=nil;
    _leftDot=nil;
    [super dealloc];
}

@end
