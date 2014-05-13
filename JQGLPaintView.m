//
//  JQGLPaintView.m
//  GLPaintView
//
//  Created by Bunsman on 14-5-9.
//  Copyright (c) 2014年 T-Magic. All rights reserved.
//

#import "JQGLPaintView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "UIColor+RGBHelper.h"



@interface JQGLPaintView () {
    EAGLContext *glContext;
	GLuint viewRenderbuffer, viewFramebuffer;
//    GLuint depthRenderbuffer;
	
    GLuint textures[4];
    //	GLuint	brushTexture;
    
    CGPoint preLoc;
    CGPoint currentLoc;
    
    GLfloat lastSetRed;
    GLfloat lastSetGreen;
    GLfloat lastSetBlue;
    
    GLfloat preDrawSpeed;
}

@end


@implementation JQGLPaintView

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _eraserModeOn = NO;
        
        _brushOpacity = 1.0f;
        _brushPixelStep = 4.f;
        preDrawSpeed = 0;
        
//        _saturation = 1.0f;
//        _luminosity = 0.75f;
        
        //set up layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = NO;
        // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        //set up context
        glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        //if there are many instance of JQGLPaintView, it must to reset [EAGLContext setCurrentContext:glContext]
        if (!glContext || ![EAGLContext setCurrentContext:glContext]) {
            return nil;
        }
        
        [self setupOpenGLStatus];
        _brushSize = 20;
        glPointSize(_brushSize);
        
        [self setupTextures];
        _brushType = -1;
        [self setBrushType:0];
        
		// Make sure to start with a cleared buffer
        [self clearCanvas];
        [self clearBuffers];
        
        [self setBrushColor:[UIColor blackColor]];
    }
    return self;
}

#pragma mark - Setter

- (void)setEraserModeOn:(BOOL)eraserModeOn
{
    if (_eraserModeOn != eraserModeOn) {
        _eraserModeOn = eraserModeOn;
        
        [EAGLContext setCurrentContext:glContext];
        if (_eraserModeOn) {
            [self enableEraseMode];
        }
        else
        {
            [self disableEraseMode];
        }
    }
}

- (void)setBrushType:(BrushTextureId)textureId
{
    if (_brushType != textureId) {
        glBindTexture(GL_TEXTURE_2D, textures[textureId]);
        _brushType = textureId;
    }
}

- (void)setBrushSize:(GLfloat)size
{
    if (_brushSize != size) {
        _brushSize = size;
        glPointSize(_brushSize);
    }
}

- (void)setBrushColor:(UIColor *)color
{
    [self disableEraseMode];
    
    [EAGLContext setCurrentContext:glContext];
    
    lastSetRed = [color getRed];
	lastSetBlue = [color getBlue];
	lastSetGreen = [color getGreen];
	// Set the brush color using premultiplied alpha values
	glColor4f(lastSetRed	* _brushOpacity,
			  lastSetGreen  * _brushOpacity,
			  lastSetBlue	* _brushOpacity,
			  _brushOpacity);
}

#pragma mark - Setup

- (void)bindTexture:(UIImage *)image withId:(GLuint)textureId
{
    CGImageRef textureImageRef;
    GLubyte    *textureData;
    size_t     width, height;
    
    CGContextRef textureContext;
    
    // Create a texture from an image
    // First create a UIImage object from the data in a image file, and then extract the Core Graphics image
    textureImageRef = image.CGImage;
    // Get the width and height of the image
    width = CGImageGetWidth(textureImageRef);
    height = CGImageGetHeight(textureImageRef);
    
    // Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
    // you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
    
    // Make sure the image exists
    if (image) {
        // Allocate  memory needed for the bitmap context
        // MARK: should use contentScale?
        textureData = (GLubyte *)calloc(width * height * 4, sizeof(GLubyte));
        // Use  the bitmatp creation function provided by the Core Graphics framework.
        textureContext = CGBitmapContextCreate(textureData, width, height, 8, width * 4, CGImageGetColorSpace(textureImageRef), (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        // After you create the context, you can draw the  image to the context.
        CGContextDrawImage(textureContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), textureImageRef);
        // You don't need the context at this point, so you need to release it to avoid memory leaks.
        CGContextRelease(textureContext);
        
        //生成一次。多次生成卡顿，并引起其他的问题
//        // Use OpenGL ES to generate a name for the texture.
//        glGenTextures(1, &textureId);
        // Bind the texture name.
        glBindTexture(GL_TEXTURE_2D, textureId);
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        // Specify a 2D texture image, providing the a pointer to the image data in memory
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
        // Release  the image data; it's no longer needed
        free(textureData);
    }
}

- (void)setupTextures
{
    //如果需要绑定新纹理，那么需要先执行glDeleteTextures
    //因为先前调用glGenTextures产生的纹理索引集不会由后面调用的glGenTextures得到，除非他们首先被glDeleteTextures删除。
    // Use OpenGL ES to generate a name for the texture. 第一个参数是纹理数量，第二参数是纹理索引数组
    glGenTextures(5, &textures[0]);
    
    for (int i = 0; i < 5; i++) {
        [self bindTexture:[UIImage imageNamed:[NSString stringWithFormat:@"brush0%d", i]]
                   withId:textures[i]];
    }
}

- (void)setupOpenGLStatus
{
    // Set the view's scale factor
//    self.contentScaleFactor = 2.0;
    
    // Setup OpenGL states
    glMatrixMode(GL_PROJECTION);
    CGRect frame = self.bounds;
    CGFloat scale = self.contentScaleFactor;
    // Setup the view port in Pixels
    
    glOrthof(0, frame.size.width * scale, 0, frame.size.height * scale, -1, 1);
    glViewport(0, 0, frame.size.width * scale, frame.size.height * scale);
    glMatrixMode(GL_MODELVIEW);
    
    glDisable(GL_DITHER);
    glEnable(GL_TEXTURE_2D);
    glEnableClientState(GL_VERTEX_ARRAY);
    
    glEnable(GL_BLEND);
    // Set a blending function appropriate for premultiplied alpha pixel data
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glEnable(GL_POINT_SPRITE_OES);
    glTexEnvf(GL_POINT_SPRITE_OES, GL_COORD_REPLACE_OES, GL_TRUE);
}

#pragma mark - OpenGL Status

- (void)enableEraseMode
{
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
    
    // Set the brush color using premultiplied alpha values
	glColor4f(lastSetRed	* _brushOpacity,
			  lastSetGreen  * _brushOpacity,
			  lastSetBlue	* _brushOpacity,
			  0);
}

-(void)disableEraseMode
{
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glColor4f(lastSetRed	* _brushOpacity,
			  lastSetGreen  * _brushOpacity,
			  lastSetBlue	* _brushOpacity,
			  _brushOpacity);
}

- (void)clearCanvas
{
    [EAGLContext setCurrentContext:glContext];
    
	// Clear the buffer
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// Display the buffer
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)clearBuffers
{
    GLsizei bufferStorageWidth = 0;
    GLsizei bufferStorageHeight = 0;
    
    // Clean up any buffers we have allocated.
    glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
//	glDeleteRenderbuffersOES(1, &depthRenderbuffer);
//    depthRenderbuffer = 0;
    
    // Generate IDs for a framebuffer object and a color renderbuffer
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[glContext renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(id<EAGLDrawable>)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &bufferStorageWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &bufferStorageHeight);
	
//	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
//	glGenRenderbuffersOES(1, &depthRenderbuffer);
//	glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
//	glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, bufferStorageWidth, bufferStorageHeight);
//	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
	}
}

#pragma mark - Drawing

- (void)layoutSubviews
{
	[EAGLContext setCurrentContext:glContext];
    [self clearBuffers];
}

#define UseDrawSpeedFactor 0
#if UseDrawSpeedFactor
const GLfloat kFilteringFactor = 0.1f;
#endif

// Drawings a line onscreen based on where the user touches
- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    static GLfloat*     vertexBuffer = NULL;
    static NSUInteger   vertexMax    = 64;
    NSUInteger          vertexCount  = 0, count, i;
    
    [EAGLContext setCurrentContext:glContext];
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    // Allocate vertex array buffer
    if(vertexBuffer == NULL)
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    
    // Add points to the buffer so there are drawing points every X pixels
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / _brushPixelStep), 1);

#if UseDrawSpeedFactor
    float drawSpeed = sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y));
    if (drawSpeed < preDrawSpeed/2) {
        drawSpeed = preDrawSpeed/2;
    }
    preDrawSpeed = drawSpeed;
    
    GLfloat sizex;
    switch (_brushType) {
        case 0:
        case 1:
            sizex = 35 * scale -(drawSpeed/0.55>35?35:drawSpeed/0.55);
            break;
        case 2:
            sizex = 40 * scale -(drawSpeed/0.5>40?40:drawSpeed/0.5);
            break;
        default:
            sizex = _brushSize;
            break;
    }
    glPointSize(sizex);
#endif
    
    for(i = 0; i < count; ++i) {
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Render the vertex array
    glVertexPointer(2, GL_FLOAT, 0, vertexBuffer);
    glDrawArrays(GL_POINTS, 0, (GLsizei)vertexCount);
    
    // Display the buffer
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [glContext presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (UIImage*)glToUIImage
{
    [EAGLContext setCurrentContext:glContext];
    
	int imageWidth = CGRectGetWidth([self bounds]) * self.contentScaleFactor;
	int imageHeight = CGRectGetHeight([self bounds]) * self.contentScaleFactor;
	
	//image buffer for export
	NSInteger myDataLength = imageWidth * imageHeight * 4;
	
	// allocate array and read pixels into it.
	GLubyte *tempImagebuffer = (GLubyte *) malloc(myDataLength);
    
    glReadPixels(0, 0, imageWidth, imageHeight, GL_RGBA, GL_UNSIGNED_BYTE, tempImagebuffer);
	
	// make data provider with data.
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, tempImagebuffer, myDataLength, NULL);
	
	// prep the ingredients
	int bitsPerComponent = 8;
	int bitsPerPixel = 32;
	int bytesPerRow = 4 * imageWidth;
	CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
	CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
	
	// make the cgimage
	CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    
	// then make the uiimage from that
	UIImage *myImage =  [UIImage imageWithCGImage:imageRef] ;
	
	CGDataProviderRelease(provider);
	CGImageRelease(imageRef);
	CGColorSpaceRelease(colorSpaceRef);
    
    return myImage;
}

//CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
- (UIImage *)upsidedownGLImage:(UIImage *)image
{
    // calculate the size of the rotated view's containing box for our drawing space
    CGSize rotatedSize = CGSizeMake(image.size.width, image.size.height);
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    // Rotate the image context
//    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, 1.0);
    CGContextDrawImage(bitmap, CGRectMake(-image.size.width / 2, -image.size.height / 2, image.size.width, image.size.height), [image CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (UIImage*)imageRepresentation
{
    UIImage *outputImage = [self glToUIImage];
	outputImage = [self upsidedownGLImage:outputImage];
    
	return outputImage;
}

#pragma mark - Touches

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	CGRect bounds = [self bounds];
    UITouch *touch = [touches anyObject];
    
	// Convert touch point from UIView referential to OpenGL one (upside-down flip)
    currentLoc = [touch locationInView:self];
    currentLoc.y = bounds.size.height - currentLoc.y;
    preLoc = [touch previousLocationInView:self];
    preLoc.y = bounds.size.height - preLoc.y;
    
	// Render the stroke
	[self renderLineFromPoint:preLoc toPoint:currentLoc];
}

@end
