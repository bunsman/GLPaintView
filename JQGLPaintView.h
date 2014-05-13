//
//  JQGLPaintView.h
//  GLPaintView
//
//  Created by Bunsman on 14-5-9.
//  Copyright (c) 2014年 T-Magic. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(GLuint, BrushTextureId) {
    BrushTextureId0,
    BrushTextureId1,
    BrushTextureId2,
    BrushTextureId3,
    BrushTextureId4,
};


@interface JQGLPaintView : UIView

@property (nonatomic, assign) BOOL eraserModeOn;

//Brush
@property (nonatomic, assign) GLfloat brushOpacity;     //笔刷不透明度
@property (nonatomic, assign) GLfloat brushPixelStep;   //笔刷绘制间隔
@property (nonatomic, assign) GLfloat brushSize;        //笔刷大小
@property (nonatomic, assign) BrushTextureId brushType; //笔刷纹理

//HSL
//@property (nonatomic, assign) GLfloat saturation;       //色饱和度
//@property (nonatomic, assign) GLfloat luminosity;       //光度

- (void)clearCanvas;
- (void)setBrushColor:(UIColor *)color;

- (UIImage*)glToUIImage; // upsideDown image from gl
- (UIImage*)imageRepresentation;

@end
