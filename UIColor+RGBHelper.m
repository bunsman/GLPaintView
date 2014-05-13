//
//  UIColor+RGBHelper.m
//  GLPaintView
//
//  Created by Bunsman on 14-5-12.
//  Copyright (c) 2014年 T-Magic. All rights reserved.
//

#import "UIColor+RGBHelper.h"

@implementation UIColor (RGBHelper)

- (NSArray *)getRGBAValues
{
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    size_t componentsCount = CGColorGetNumberOfComponents(self.CGColor);
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    
    if(componentsCount == 2) {
        red     = components[0];//grayscale
        green   = components[0];
        blue    = components[0];
        alpha   = components[1];//alpha
    }
    else {
        red     = components[0];
        green   = components[1];
        blue    = components[2];
        alpha   = components[3];
    }
    
    return [NSArray arrayWithObjects:[NSNumber numberWithFloat:red], [NSNumber numberWithFloat:green],
            [NSNumber numberWithFloat:blue], [NSNumber numberWithFloat:alpha], nil];
}

- (CGFloat)getRed
{
    CGFloat red = 0.0;
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    
    red = components[0];
    
    return red;
}

- (CGFloat)getGreen
{
    CGFloat green = 0.0;
    size_t componentsCount = CGColorGetNumberOfComponents(self.CGColor);
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    
    if(componentsCount == 2) {
        green   = components[0];
    }
    else {
        green   = components[1];
    }
    
    return green;
}

- (CGFloat)getBlue
{
    CGFloat blue = 0.0;
    size_t componentsCount = CGColorGetNumberOfComponents(self.CGColor);
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    
    if(componentsCount == 2) {
        blue    = components[0];
    }
    else {
        blue    = components[2];
    }
    
    return blue;
}

- (CGFloat)getAlpha
{
    CGFloat alpha = 0.0;
    size_t componentsCount = CGColorGetNumberOfComponents(self.CGColor);
    const CGFloat *components = CGColorGetComponents(self.CGColor);
    
    if(componentsCount == 2) {
        alpha   = components[1];//alpha
    }
    else {
        alpha   = components[3];
    }
    
    return alpha;
}

@end
