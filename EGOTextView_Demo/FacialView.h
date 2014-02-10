//
//  FacialView.h
//  KeyBoardTest
//
//  Created by wangqiulei on 11-8-16.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol facialViewDelegate

-(void)selectedFacialView:(NSString*)str;

@end


@interface FacialView : UIView {

   __weak id<facialViewDelegate>delegate;
	
}
@property(nonatomic,weak)id<facialViewDelegate>delegate;

-(void)loadFacialView:(int)page size:(CGSize)size;

@end
