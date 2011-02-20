//
//  ANImageBitmapRep.m
//  ANImageBitmapRep
//
//  Created by Alex Nichol on 5/5/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ANImageBitmapRep.h"

#define DEGTORAD(x) (x * (M_PI / 180.0f))

static CGPoint locationForAngle (CGFloat angle, CGFloat hypotenuse) {
	// get the corner
	CGPoint p;
	p.x = cos(DEGTORAD(angle)) * hypotenuse;
	p.y = sin(DEGTORAD(angle)) * hypotenuse;
	return p;
}

@implementation ANImageBitmapRep

#pragma mark Initialization

+ (CGContextRef)CreateARGBBitmapContextWithSize:(CGSize)size {
	CGContextRef context = NULL;
    CGColorSpaceRef colorSpace;
    void * bitmapData;
    int bitmapByteCount;
    int bitmapBytesPerRow;
	
	// Get image width, height. We'll use the entire image.
    size_t pixelsWide = size.width;
    size_t pixelsHigh = size.height;
	
    bitmapBytesPerRow = (pixelsWide * 4);
    bitmapByteCount = (bitmapBytesPerRow * pixelsHigh);
	
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
	
	// allocate
    bitmapData = malloc(bitmapByteCount);
    if (bitmapData == NULL) {
		NSLog(@"Malloc failed which is too bad.  I was hoping to use this memory.");
		CGColorSpaceRelease(colorSpace);
		// even though CGContextRef technically is not a pointer,
		// it's typedef probably is and it is a scalar anyway.
        return NULL;
    }
	
    // Create the bitmap context. We are
	// setting up the image as an ARGB (0-255 per component)
	// 4-byte per/pixel.
    context = CGBitmapContextCreate (bitmapData,
									 pixelsWide,
									 pixelsHigh,
									 8,
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaPremultipliedFirst);
	if (context == NULL) {
		free (bitmapData);
		NSLog(@"Failed to create bitmap!");
    }
	
	CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));
	
    CGColorSpaceRelease(colorSpace);
	
    return context;	
}
+ (CGContextRef)CreateARGBBitmapContextWithImage:(CGImageRef)image {
	CGContextRef context = NULL;
    CGColorSpaceRef colorSpace;
    void * bitmapData;
    int bitmapByteCount;
    int bitmapBytesPerRow;
	
	// Get image width, height. We'll use the entire image.
    size_t pixelsWide = CGImageGetWidth(image);
    size_t pixelsHigh = CGImageGetHeight(image);
	
    bitmapBytesPerRow = (pixelsWide * 4);
    bitmapByteCount = (bitmapBytesPerRow * pixelsHigh);
	
    // Use the generic RGB color space.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
	
	// allocate
    bitmapData = malloc(bitmapByteCount);
    if (bitmapData == NULL) {
		NSLog(@"Malloc failed which is too bad.  I was hoping to use this memory.");
		CGColorSpaceRelease(colorSpace);
		// even though CGContextRef technically is not a pointer,
		// it's typedef probably is and it is a scalar anyway.
        return NULL;
    }
	
    // Create the bitmap context. We are
	// setting up the image as an ARGB (0-255 per component)
	// 4-byte per/pixel.
    context = CGBitmapContextCreate (bitmapData,
									 pixelsWide,
									 pixelsHigh,
									 8,      // bits per component
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaPremultipliedFirst);
	if (context == NULL) {
		free (bitmapData);
		NSLog(@"Failed to create bitmap!");
    }
	
	// draw the image on the context.
	// CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
	// CGContextScaleCTM(context, 1.0, -1.0);
	CGContextClearRect(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)));
	CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
	
    CGColorSpaceRelease(colorSpace);
	
    return context;	
}

- (id)initWithSize:(CGSize)sz {
	if (self = [super init]) {
		// load the image into the context
		ctx = [ANImageBitmapRep CreateARGBBitmapContextWithSize:sz];
		changed = YES;
		bitmapData = CGBitmapContextGetData(ctx);
	}
	return self;
}
- (id)initWithImage:(UIImage *)_img {
	if (self = [super init]) {
		// load the image into the context
		img = [_img CGImage];
		CGImageRetain(img);
		ctx = [ANImageBitmapRep CreateARGBBitmapContextWithImage:img];
		changed = NO;
		bitmapData = CGBitmapContextGetData(ctx);
	}
	return self;
}
+ (id)imageBitmapRepWithImage:(UIImage *)_img {
	return [[[ANImageBitmapRep alloc] initWithImage:_img] autorelease];
}
+ (id)imageBitmapRepNamed:(NSString *)_resourceName {
	// we wanna use an autorelease pool here
	// to make sure we don't retain
	// the UIImage imageNamed: image.
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	ANImageBitmapRep * rep = [[ANImageBitmapRep alloc] initWithImage:[UIImage imageNamed:_resourceName]];
	[pool drain];
	return [rep autorelease];
}

#pragma mark Getting Properties

- (CGSize)size {
	return CGSizeMake(CGBitmapContextGetWidth(ctx), CGBitmapContextGetHeight(ctx));
}

- (CGContextRef)graphicsContext {
	return ctx;
}
- (CGImageRef)CGImage {
	if (!changed) {
		// their job to release it
		return CGImageRetain(img);
	} else {
		CGImageRelease(img);
		img = CGBitmapContextCreateImage(ctx);
		changed = NO;
		return CGImageRetain(img);
	}
}
- (UIImage *)image {
	CGImageRef _img = [self CGImage];
	CGImageRelease(_img);
	// I don't know how UIImage deals with these things.
	return [UIImage imageWithCGImage:_img];
}

- (void)getPixel:(CGFloat *)pxl atX:(int)x y:(int)y {
	CGSize s = [self size];
	unsigned char * c = (unsigned char *)&bitmapData[((y * (int)(s.width))+x) * 4];
	// convert from ARGB to RGBA
	float alpha = ((float)c[0]) / 255.0f;
	pxl[0] = ((float)((float)(int)(c[1])) / 255.0f) / alpha;
	pxl[1] = ((float)((float)c[2]) / 255.0f) / alpha;
	pxl[2] = ((float)((float)c[3]) / 255.0f) / alpha;
	pxl[3] = ((float)(c[0]) / 255.0f);
	
	if (pxl[0] > 1) pxl[0] = 1;
	if (pxl[1] > 1) pxl[1] = 1;
	if (pxl[2] > 1) pxl[2] = 1;
	if (pxl[3] > 1) pxl[3] = 1;
}

- (void)get255Pixel:(char *)pxl atX:(int)x y:(int)y {
	CGSize s = [self size];
	changed = YES;
	unsigned char * c = (unsigned char *)&bitmapData[((y * (int)(s.width))+x) * 4];
	pxl[1] = c[0];
	pxl[2] = c[1];
	pxl[3] = c[2];
	pxl[0] = c[3];
}

#pragma mark Setting Properties

- (void)setNeedsUpdate {
	changed = YES;
}

- (void)setSize:(CGSize)_size {
	CGSize size = CGSizeMake(round(_size.width), round(_size.height));
	CGImageRef _img = [self CGImage];
	
	CGContextRef _ctx = [ANImageBitmapRep CreateARGBBitmapContextWithSize:size];
	CGContextRelease(ctx);
	free(bitmapData);
	// image will still be retained.
	
	ctx = _ctx;
	bitmapData = CGBitmapContextGetData(_ctx);
	
	CGContextClearRect(ctx, CGRectMake(0, 0, size.width, size.height));
	CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), _img);
	
	CGImageRelease(_img);
	
	changed = YES;
}

- (void)setBrightness:(float)percent {
	if (percent > 1) {
		int width, height;
		CGSize s = [self size];
		width = (int)(s.width);
		height = (int)(s.height);
		int bytes = width * height * 4;
		for (int i = 0; i < bytes; i++) {
			if (i % 4 != 0) {
				int c = (int)((float)((unsigned char)(bitmapData[i])) * percent);
				if (c > 255) c = 255;
				bitmapData[i] = (char)(c);
			}
		}
	}
	CGSize s = [self size];
	CGContextSaveGState(ctx);
	CGContextSetFillColorWithColor(ctx, [[UIColor colorWithRed:0 green:0 blue:0 alpha:(1.0 - percent)] CGColor]);
	CGContextFillRect(ctx, CGRectMake(0, 0, s.width, s.height));
	CGContextRestoreGState(ctx);
}
- (void)setQuality:(float)percent {
	CGSize s = [self size];
	CGSize back = [self size];
	s.width *= percent;
	s.height *= percent;
	[self setSize:s];
	[self setSize:back];
}

- (void)setPixel:(CGFloat *)pxl atX:(int)x y:(int)y {
	CGSize s = [self size];
	changed = YES;
	float alpha = pxl[3];
	unsigned char * c = (unsigned char *)&bitmapData[((y * (int)(s.width))+x) * 4];
	// convert from ARGB to RGBA
	int i1 = (int)((float)(pxl[3]) * 255.0f);
	int i2 = (int)((float)(pxl[0]) * 255.0f * alpha);
	int i3 = (int)((float)(pxl[1]) * 255.0f * alpha);
	int i4 = (int)((float)(pxl[2]) * 255.0f * alpha);
	
	if (i1 < 0) i1 = 0; else if (i1 > 255) i1 = 255;
	if (i2 < 0) i2 = 0; else if (i2 > 255) i2 = 255;
	if (i3 < 0) i3 = 0; else if (i3 > 255) i3 = 255;
	if (i4 < 0) i4 = 0; else if (i4 > 255) i4 = 255;
	
	c[0] = (char)(i1);
	c[1] = (char)(i2);
	c[2] = (char)(i3);
	c[3] = (char)(i4);
}


- (void)set255Pixel:(char *)pxl atX:(int)x y:(int)y {
	CGSize s = [self size];
	changed = YES;
	unsigned char * c = (unsigned char *)&bitmapData[((y * (int)(s.width))+x) * 4];
	c[1] = pxl[0];
	c[2] = pxl[1];
	c[3] = pxl[2];
	c[0] = pxl[3];
}

#pragma mark Drawing

- (void)drawInRect:(CGRect)r {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (!context) {
		NSLog(@"Cannot draw yet.");
		return;
	}
	
	CGImageRef image = [self CGImage];
	
	CGContextSaveGState(context);
	CGContextTranslateCTM(context, 0, CGBitmapContextGetHeight(context));
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextDrawImage(context, CGRectMake(r.origin.x, 
										   (CGBitmapContextGetHeight(context) - r.origin.y) - r.size.height,
										   r.size.width, r.size.height),
					   image);
	CGContextRestoreGState(context);
	
	CGImageRelease(image);
}



#pragma mark Newbie Features

- (ANImageBitmapRep *)cropWithFrame:(CGRect)nRect {
	ANImageBitmapRep * irep = [[ANImageBitmapRep alloc] initWithSize:nRect.size];
	CGRect r;
	r.size = [self size];
	r.origin.x = -(nRect.origin.x);
	r.origin.y = -(r.size.height - (nRect.origin.y + nRect.size.height));
	CGContextRef _ctx = [irep graphicsContext];
	CGImageRef mImg = [self CGImage];
	CGContextDrawImage(_ctx, r, mImg);
	CGImageRelease(mImg);
	[irep setNeedsUpdate];
	return [irep autorelease];
}

- (ANImageBitmapRep *)rotate:(float)degrees {
	// rotate the image
	CGSize size = self.size;
	CGSize newSize;
	
	// calculate new size
	CGFloat hypotenuse;
	hypotenuse = sqrt(pow(size.width / 2.0, 2) + pow(size.height / 2.0, 2));
	
	CGPoint minP = CGPointMake(10000, 10000);
	CGPoint maxP = CGPointMake(-10000, -10000);
	for (float deg = 45.0; deg < 360.0; deg += 90.0) {
		CGPoint p1 = locationForAngle(deg + degrees, hypotenuse);
		if (p1.x < minP.x) minP.x = p1.x;
		if (p1.x > maxP.x) maxP.x = p1.x;
		if (p1.y < minP.y) minP.y = p1.y;
		if (p1.y > maxP.y) maxP.y = p1.y;
	}
	
	newSize.width = maxP.x - minP.x;
	newSize.height = maxP.y - minP.y;
	
	hypotenuse = sqrt((pow(newSize.width / 2.0, 2) + pow(newSize.height / 2.0, 2)));
	CGPoint newCenter;
	newCenter.x = cos(DEGTORAD((degrees + 45.0))) * hypotenuse;
	newCenter.y = sin(DEGTORAD((degrees + 45.0))) * hypotenuse;
	CGPoint offsetCenter;
	offsetCenter.x = (newSize.width / 2.0) - newCenter.x;
	offsetCenter.y = (newSize.height / 2.0) - newCenter.y;
	
	ANImageBitmapRep * newBitmap = [[ANImageBitmapRep alloc] initWithSize:newSize];
	
	CGContextRef context = [newBitmap graphicsContext];
	CGContextSaveGState(context);
	CGContextTranslateCTM(context, round(offsetCenter.x), round(offsetCenter.y));
	
	CGContextRotateCTM(context, DEGTORAD(degrees));
	CGRect drawRect;
	drawRect.size = size;
	drawRect.origin.x = round((newSize.width / 2) - (size.width / 2));
	drawRect.origin.y = round((newSize.height / 2) - (size.height / 2));
	CGContextDrawImage(context, drawRect, [self CGImage]);
	CGImageRelease(img);
	CGContextRestoreGState(context);

	[newBitmap setNeedsUpdate];
	
	return [newBitmap autorelease];
}

- (void)invertColors {
	ANImageBitmapRep * rep = self;
	CGSize s = [rep size];
	
	for (int y = 0; y < s.height; y++) {
		for (int x = 0; x < s.width; x++) {
			unsigned char * c = (unsigned char *)&bitmapData[((y * (int)(s.width))+x) * 4];
			c[1] = 255 - c[1];
			c[2] = 255 - c[2];
			c[3] = 255 - c[3];
		}
	}
	
	changed = YES;
}

- (void)dealloc {
	CGImageRelease(img);
	CGContextRelease(ctx);
	free(bitmapData);
	[super dealloc];
}
@end

@implementation UIImage (ANImageBitmapRep)

- (ANImageBitmapRep *)imageBitmapRep {
	return [[[ANImageBitmapRep alloc] initWithImage:self] autorelease];
}

- (UIImage *)scaleToSize:(CGSize)sz {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	ANImageBitmapRep * irep = [self imageBitmapRep];
	[irep setSize:sz];
	UIImage * img = [[irep image] retain];
	[pool drain];
	return [img autorelease];
}

@end
