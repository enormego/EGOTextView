//
//  EGOTextView.h
//  EGOTextView_Demo
//
//  Created by Devin Doty on 4/18/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

@class EGOTextView;
@protocol EGOTextViewDelegate <NSObject, UIScrollViewDelegate>
@optional

- (BOOL)textViewShouldBeginEditing:(EGOTextView *)textView;
- (BOOL)textViewShouldEndEditing:(EGOTextView *)textView;

- (void)textViewDidBeginEditing:(EGOTextView *)textView;
- (void)textViewDidEndEditing:(EGOTextView *)textView;

- (BOOL)textView:(EGOTextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewDidChange:(EGOTextView *)textView;

- (void)textViewDidChangeSelection:(EGOTextView *)textView;

@end

@class EGOCaretView, EGOContentView, EGOTextWindow, EGOMagnifyView, EGOSelectionView;
@interface EGOTextView : UIScrollView <UITextInputTraits, UITextInput> {
@private
    NSAttributedString  *_attributedString;
    UIFont              *_font; 
    BOOL                _editing;
    BOOL                _editable; 
    BOOL                _spellCheck;
    
    NSRange             _markedRange; 
    NSRange             _selectedRange;
    NSRange             _correctionRange;

    CTFramesetterRef    _framesetter;
    CTFrameRef          _frame;
    UILongPressGestureRecognizer *_longPress;
    
    EGOContentView      *_textContentView;
    EGOTextWindow       *_textWindow;
    EGOCaretView        *_caretView;
    EGOSelectionView    *_selectionView;
    
}

@property(nonatomic,assign) id <EGOTextViewDelegate> delegate;
@property(nonatomic,copy) NSAttributedString *attributedString;
@property(nonatomic,retain) UIFont *font; // ignored when attributedString is not nil
@property(nonatomic,getter=isEditing) BOOL editing; //default NO
@property(nonatomic,getter=isEditable) BOOL editable; //default YES
@property(nonatomic) NSRange selectedRange;
@property(nonatomic) NSRange markedRange;

- (BOOL)hasText;
- (void)setText:(NSString*)text; // creates an attributed string with default attributes

@end