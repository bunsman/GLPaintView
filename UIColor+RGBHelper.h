//
//  UIColor+RGBHelper.h
//  GLPaintView
//
//  Created by Bunsman on 14-5-12.
//  Copyright (c) 2014年 T-Magic. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (RGBHelper)

- (NSArray *)getRGBAValues;
- (CGFloat)getRed;
- (CGFloat)getGreen;
- (CGFloat)getBlue;
- (CGFloat)getAlpha;

@end
