#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import "EJTexture.h"
#import "EJConvertWebGL.h"

#import "EJSharedTextureCache.h"
#import "EJJavaScriptView.h"

#define PVR_TEXTURE_FLAG_TYPE_MASK 0xff

enum {
	kPVRTextureFlagTypePVRTC_2 = 24,
	kPVRTextureFlagTypePVRTC_4
};

typedef struct {
	uint32_t headerLength;
	uint32_t height;
	uint32_t width;
	uint32_t numMipmaps;
	uint32_t flags;
	uint32_t dataLength;
	uint32_t bpp;
	uint32_t bitmaskRed;
	uint32_t bitmaskGreen;
	uint32_t bitmaskBlue;
	uint32_t bitmaskAlpha;
	uint32_t pvrTag;
	uint32_t numSurfs;
} PVRTextureHeader;


@interface EJTexture ()

@property (nonatomic, assign, readwrite) BOOL cached;
@property (nonatomic, assign, readwrite) BOOL isCompressed;
@property (nonatomic, assign, readwrite) BOOL lazyLoaded;
@property (nonatomic, assign, readwrite) BOOL dimensionsKnown;
@property (nonatomic, assign, readwrite) CGFloat width, height;
@property (nonatomic, copy, readwrite) NSString *fullPath;
@property (nonatomic, retain, readwrite) EJTextureStorage *textureStorage;
@property (nonatomic, assign, readwrite) GLenum format;
@property (nonatomic, assign, readwrite) GLuint fbo;
@property (nonatomic, retain, readwrite) NSBlockOperation *loadCallback;
@property (nonatomic, assign, readwrite) BOOL isDynamic;
@property (nonatomic, retain, readwrite) NSMutableData *pixels;
@property (nonatomic, assign, readwrite) GLuint textureId;
@property (nonatomic, assign, readwrite) NSTimeInterval lastUsed;

@end



@implementation EJTexture


- (instancetype)initEmptyForWebGL {
	// For WebGL textures; this will not create a textureStorage
    self = [super init];
    
    if (self) {

        params[kEJTextureParamMinFilter] = GL_LINEAR;
        params[kEJTextureParamMagFilter] = GL_LINEAR;
        params[kEJTextureParamWrapS] = GL_REPEAT;
        params[kEJTextureParamWrapT] = GL_REPEAT;
    }
    return self;
    
}

- (instancetype)initWithPath:(NSString *)path {
	// For loading on the main thread (blocking)
    if ([NSThread isMainThread] == NO) {
        NSString *title = [NSString stringWithFormat:@"%@\n%s is not being called from the main thread.", NSStringFromClass([self class]), __PRETTY_FUNCTION__];
        NSAssert(NO, title);
        NSLog(@"%@", title);
    }
    
    self = [super init];
    
    if (self) {
        
        [self setFullPath:path];
        
        NSMutableData *pixels = [self loadPixelsFromPath:path];
        if( pixels ) {
            [self createWithPixels:pixels format:GL_RGBA];
        }
        
        [pixels release];
    }
    
    return self;
}

+ (instancetype)cachedTextureWithPath:(NSString *)path loadOnQueue:(NSOperationQueue *)queue callback:(NSOperation *)callback {
	// For loading on a background thread (non-blocking), but tries the cache first
	
	// Only try the cache if path is not a data URI
	BOOL isDataURI = [path hasPrefix:@"data:"];
	
	EJTexture *texture = !isDataURI
		? EJSharedTextureCache.instance.textures[path]
		: nil;
	
	if( texture ) {
		// We already have a texture, but it may hasn't finished loading yet. If
		// the texture's loadCallback is still present, add it as an dependency
		// for the current callback.
		
		if( texture->_loadCallback ) {
			[callback addDependency:texture->_loadCallback];
		}
		[NSOperationQueue.mainQueue addOperation:callback];
	}
	else {
		// Create a new texture and add it to the cache
		texture = [[EJTexture alloc] initWithPath:path loadOnQueue:queue callback:callback];
		
		if( !isDataURI ) {
			EJSharedTextureCache.instance.textures[path] = texture;
			texture->_cached = true;
		}
		[texture autorelease];
	}
	return texture;
}

- (instancetype)initWithPath:(NSString *)path loadOnQueue:(NSOperationQueue *)queue callback:(NSOperation *)callback {
	// For loading on a background thread (non-blocking)
	// This will defer loading for local images
    self = [super init];
    
    if (self) {
        
        [self setFullPath:path];
        
        BOOL isURL = [path hasPrefix:@"http:"] || [path hasPrefix:@"https:"];
        BOOL isDataURI = !isURL && [path hasPrefix:@"data:"];
        
        // Neither a URL nor a data URI? We can lazy load the texture. Just add the callback
        // to the load queue and return
        if(!isURL && !isDataURI) {
            // Only set the lazy loading flag if the file exists, so we know it can, at least potentially,
            // be loaded
            _lazyLoaded = [NSFileManager.defaultManager fileExistsAtPath:_fullPath];
            _format = GL_RGBA;
            [NSOperationQueue.mainQueue addOperation:callback];
            return self;
        }
        
        _loadCallback = [[NSBlockOperation alloc] init];
        
        // Load the image file in a background thread
        //we don't know if queue argument can be owned by
        // self, so we should cast self to avoid the retain
        // cycle anyway.
        
        EJTexture * __unsafe_unretained weakSelf = self;
        
        [queue addOperationWithBlock:^{
            
            EJTexture * strongSelf = weakSelf;
            
            NSMutableData *pixels = [strongSelf loadPixelsFromPath:path];
            
            // Upload the pixel data in the main thread, otherwise the GLContext gets confused.
            // We could use a sharegroup here, but it turned out quite buggy and has little
            // benefits - the main bottleneck is loading the image file.
            [strongSelf.loadCallback addExecutionBlock:^{
                if( pixels ) {
                    [strongSelf createWithPixels:pixels format:GL_RGBA];
                }
                [strongSelf.loadCallback release];
                strongSelf.loadCallback = nil;
            }];
            
            [callback addDependency:_loadCallback];
            
            [NSOperationQueue.mainQueue addOperation:_loadCallback];
            [NSOperationQueue.mainQueue addOperation:callback];
        }];
        
        
    }
    
    return self;
}

- (instancetype)initWithWidth:(int)widthp height:(int)heightp {
	// Create an empty RGBA texture
	return [self initWithWidth:widthp height:heightp format:GL_RGBA];
}

- (instancetype)initWithWidth:(int)widthp height:(int)heightp format:(GLenum)formatp {
	// Create an empty texture
    
    self = [super init];
    
    if (self) {
        
        self.width = widthp;
        _height = heightp;
        _dimensionsKnown = YES;
        [self createWithPixels:NULL format:formatp];
    }
    
    return self;
}

- (instancetype)initWithWidth:(int)widthp height:(int)heightp pixels:(NSData *)pixels {
	// Creates a texture with the given pixels
    
    self = [super init];
    
    if (self) {
        
        self.width = widthp;
        _height = heightp;
        _dimensionsKnown = YES;
        [self createWithPixels:pixels format:GL_RGBA];
    }
    
    return self;
}

- (instancetype)initAsRenderTargetWithWidth:(int)widthp height:(int)heightp fbo:(GLuint)fbop {
    
    self = [super init];
    
    if (self) {

        _fbo = fbop;
    }
    
    return self;
}

- (instancetype)initWithUIImage:(UIImage *)image {
    
    self = [super init];
    
    if (self) {

        NSMutableData *pixels = [self loadPixelsFromUIImage:image];
        if( pixels ) {
            [self createWithPixels:pixels format:GL_RGBA];
        }
        
        [pixels release];
    }
    
    return self;
}

- (void)dealloc {
	if(_cached) {
		[EJSharedTextureCache.instance.textures removeObjectForKey:_fullPath];
	}
    
	[_loadCallback release];
    _loadCallback = nil;
    
	[_fullPath release];
    _fullPath = nil;
    
	[_textureStorage release];
    _textureStorage = nil;
	
    [super dealloc];
}

- (void)maybeReleaseStorage {
	// Releases the texture storage if it can be easily reloaded from
	// a local file
	if(_lazyLoaded && _textureStorage ) {
	
		// Make sure this isnt' the currently bound texture
		GLint boundTexture = 0;
		glGetIntegerv(GL_TEXTURE_BINDING_2D, &boundTexture);
		if( boundTexture != _textureStorage.textureId ) {
			[_textureStorage release];
			_textureStorage = nil;
		}
	}
}

- (void)ensureMutableKeepPixels:(BOOL)keepPixels forTarget:(GLenum)target {

	// If we have a TextureStorage but it's not mutable (i.e. created by Canvas2D) and
	// we're not the only owner of it, we have to create a new TextureStorage.
	// FIXME: If the texture is compressed, we simply ignore this check and use the compressed
	// TextureStorage
    
    /** 
     We can't use retainCount as a check here, Apple docs state that
     checking the retain count of an object does not guarantee its lifetime.
     */
    
	if(_textureStorage && _textureStorage.immutable && !_isCompressed) {
	
		// Keep pixel data of the old TextureStorage when creating the new?
		if(keepPixels) {
			if(self.pixels) {
				[self createWithPixels:self.pixels format:GL_RGBA target:target];
			}
		}
		else {
			[_textureStorage release];
			_textureStorage = NULL;
		}
	}
	
	if(!_textureStorage ) {
		_textureStorage = [[EJTextureStorage alloc] init];
	}
}

- (NSTimeInterval)lastUsed {
	return _textureStorage.lastBound;
}

// When accessing the .textureId, .width or .height we need to
// ensure that lazyLoaded textures are actually loaded by now.

#define EJ_ENSURE_LAZY_LOADED_STORAGE() \
	if( !_textureStorage && _lazyLoaded ) { \
		NSMutableData *pixels = [self loadPixelsFromPath:_fullPath]; \
		if( pixels ) { \
			[self createWithPixels:pixels format:GL_RGBA]; \
		} \
	}

- (GLuint)textureId {
	EJ_ENSURE_LAZY_LOADED_STORAGE();
	return _textureStorage.textureId;
}

- (BOOL)isDynamic {
	return !!_fbo;
}

- (CGFloat)width {
	if(_dimensionsKnown ) {
		return _width;
	}
	EJ_ENSURE_LAZY_LOADED_STORAGE();
	return _width;
}

- (CGFloat)height {
	if(_dimensionsKnown ) {
		return _height;
	}
	EJ_ENSURE_LAZY_LOADED_STORAGE();
	return _height;
}

- (instancetype)copyWithZone:(NSZone *)zone {
	
    EJTexture *copy = [[EJTexture allocWithZone:zone] init];
	
	// This retains the textureStorage object and sets the associated properties
	[copy createWithTexture:self];
	
	// Copy texture parameters not handled by createWithTexture
	memcpy(copy->params, params, sizeof(EJTextureParams));
	copy->_isCompressed = _isCompressed;
	
	if(self.isDynamic && !_isCompressed) {
		// We want a static copy. So if this texture is used by an FBO, we have to
		// re-create the texture from pixels again
		[copy createWithPixels:self.pixels format:_format];
	}

	return copy;
}

- (void)createWithTexture:(EJTexture *)other {
	
    [_textureStorage release];
    _textureStorage = nil;
    
    [_fullPath release];
    _fullPath = nil;
    
	_format = other->_format;
	_fullPath = [other->_fullPath copy];
	
	_width = other.width;
	_height = other.height;
	_isCompressed = other->_isCompressed;
	_lazyLoaded = other->_lazyLoaded;
	_dimensionsKnown = other.dimensionsKnown;
	
    /** 
     Do we want to call retain here?  Should we implement
     copy on the EJTextureStorage class?  Do we want a
     copy of the texture storage, or use the same one?.
     */
	_textureStorage = [other->_textureStorage retain];
}

- (void)createWithPixels:(NSData *)pixels format:(GLenum)formatp {
	[self createWithPixels:pixels format:formatp target:GL_TEXTURE_2D];
}

- (void)createWithPixels:(NSData *)pixels format:(GLenum)formatp target:(GLenum)target {
	// Release previous texture if we had one
	if(_textureStorage) {
		[_textureStorage release];
		_textureStorage = nil;
	}
	
	// Set the default texture params for Canvas2D
	params[kEJTextureParamMinFilter] = GL_LINEAR;
	params[kEJTextureParamMagFilter] = GL_LINEAR;
	params[kEJTextureParamWrapS] = GL_CLAMP_TO_EDGE;
	params[kEJTextureParamWrapT] = GL_CLAMP_TO_EDGE;

	GLint maxTextureSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
	
	if(self.width > maxTextureSize || self.height > maxTextureSize ) {
		NSLog(@"Warning: Image %@ larger than MAX_TEXTURE_SIZE (%d)", _fullPath ? _fullPath : @"[Dynamic]", maxTextureSize);
		return;
	}
	_format = formatp;
	
	GLint boundTexture = 0;
	GLenum bindingName = (target == GL_TEXTURE_2D)
		? GL_TEXTURE_BINDING_2D
		: GL_TEXTURE_BINDING_CUBE_MAP;
	glGetIntegerv(bindingName, &boundTexture);
	
	if(_isCompressed) {
		[self uploadCompressedPixels:pixels target:target];
	}
	else {
		_textureStorage = [[EJTextureStorage alloc] initImmutable];
		[_textureStorage bindToTarget:target withParams:params];
		glTexImage2D(target, 0, _format, self.width, self.height, 0, _format, GL_UNSIGNED_BYTE, pixels.bytes);
	}
	
	glBindTexture(target, boundTexture);
}

- (void)uploadCompressedPixels:(NSData *)pixels target:(GLenum)target {
	PVRTextureHeader *header = (PVRTextureHeader *) pixels.bytes;
	
    uint32_t formatFlags = header->flags & PVR_TEXTURE_FLAG_TYPE_MASK;
	
	GLenum internalFormat;
	uint32_t bpp;
	
	if( formatFlags == kPVRTextureFlagTypePVRTC_4 ) {
		internalFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
		bpp = 4;
	}
	else if( formatFlags == kPVRTextureFlagTypePVRTC_2 ) {
		internalFormat = GL_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG;
		bpp = 2;
	}
	else {
		NSLog(@"Warning: PVRTC Compressed Image %@ neither 2 nor 4 bits per pixel", _fullPath);
		return;
	}
	
	
	// Create texture storage
	if( header->numMipmaps > 0 ) {
		params[kEJTextureParamMinFilter] = GL_LINEAR_MIPMAP_LINEAR;
	}
	
	_textureStorage = [[EJTextureStorage alloc] initImmutable];
	[_textureStorage bindToTarget:target withParams:params];
	
	// Upload all mip levels
	int mipWidth = self.width,
		mipHeight = self.height;
	
	
	uint8_t *bytes = ((uint8_t *)pixels.bytes) + header->headerLength;
	
	for( GLint mip = 0; mip < header->numMipmaps+1; mip++ ) {
		uint32_t widthBlocks = MAX(mipWidth / (16/bpp), 2);
		uint32_t heightBlocks = MAX(mipHeight / 4, 2);
		uint32_t size = widthBlocks * heightBlocks * 8;
		
		glCompressedTexImage2D(GL_TEXTURE_2D, mip, internalFormat, mipWidth, mipHeight, 0, size, bytes);
		bytes += size;

		mipWidth = MAX(mipWidth >> 1, 1);
		mipHeight = MAX(mipHeight >> 1, 1);
	}
}

- (void)updateWithPixels:(NSData *)pixels atX:(GLint)sx y:(GLint)sy width:(GLint)sw height:(GLint)sh {
	int boundTexture = 0;
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &boundTexture);
	
	glBindTexture(GL_TEXTURE_2D, _textureStorage.textureId);
	glTexSubImage2D(GL_TEXTURE_2D, 0, sx, sy, sw, sh, _format, GL_UNSIGNED_BYTE, pixels.bytes);
	
	glBindTexture(GL_TEXTURE_2D, boundTexture);
}

- (NSMutableData *)pixels {
	EJ_ENSURE_LAZY_LOADED_STORAGE();
	
	GLint boundFrameBuffer;
	GLuint tempFramebuffer;
	glGetIntegerv( GL_FRAMEBUFFER_BINDING, &boundFrameBuffer );
	
	// If this texture doesn't have an FBO (i.e. its not used as the backing store
	// for an offscreen canvas2d), we have to create a new, temporary framebuffer
	// containing the texture. We can then read the pixel data using glReadPixels
	// as usual
	if(!_fbo) {
		glGenFramebuffers(1, &tempFramebuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, tempFramebuffer);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _textureStorage.textureId, 0);
	}
	else {
		glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
	}
	
	int size = self.width * self.height * EJGetBytesPerPixel(GL_UNSIGNED_BYTE, _format);
	NSMutableData *data = [NSMutableData dataWithLength:size];
	glReadPixels(0, 0, self.width, self.height, _format, GL_UNSIGNED_BYTE, data.mutableBytes);
	
	glBindFramebuffer(GL_FRAMEBUFFER, boundFrameBuffer);
	
	
	if(!_fbo) {
		glDeleteFramebuffers(1, &tempFramebuffer);
	}
	
	return data;
}

- (NSMutableData *)loadPixelsFromPath:(NSString *)path {
	BOOL isURL = [path hasPrefix:@"http:"] || [path hasPrefix:@"https:"];
	BOOL isDataURI = !isURL && [path hasPrefix:@"data:"];
	
	NSMutableData *pixels;
	if( isDataURI || isURL ) {
		// Load directly from a Data URI string or an URL
		UIImage *tmpImage = [[UIImage alloc] initWithData:
			[NSData dataWithContentsOfURL:[NSURL URLWithString:path]]];
		
		if( !tmpImage ) {
			if( isDataURI ) {
				NSLog(@"Error Loading image from Data URI.");
			}
			if( isURL ) {
				NSLog(@"Error Loading image from URL: %@", path);
			}
			return NULL;
		}
		pixels = [self loadPixelsFromUIImage:tmpImage];
		[tmpImage release];
	}
	
	else if( [path.pathExtension isEqualToString:@"pvr"] ) {
		// Compressed PVRTC? Only load raw data bytes
		pixels = [NSMutableData dataWithContentsOfFile:path];
		if( !pixels ) {
			NSLog(@"Error Loading image %@ - not found.", path);
			return NULL;
		}
		PVRTextureHeader *header = (PVRTextureHeader *)pixels.bytes;
		_width = header->width;
		_height = header->height;
		_dimensionsKnown = true;
		_isCompressed = true;
	}
	
	else {
		// Use UIImage for PNG, JPG and everything else
		UIImage *tmpImage = [[UIImage alloc] initWithContentsOfFile:path];
		
		if( !tmpImage ) {
			NSLog(@"Error Loading image %@ - not found.", path);
			return NULL;
		}
		
		pixels = [self loadPixelsFromUIImage:tmpImage];
		[tmpImage release];
	}
	
	return pixels;
}

- (NSMutableData *)loadPixelsFromUIImage:(UIImage *)image {
	CGImageRef cgImage = image.CGImage;
	
	_width = CGImageGetWidth(cgImage);
	_height = CGImageGetHeight(cgImage);
	_dimensionsKnown = true;
	
	NSMutableData *pixels = [NSMutableData dataWithLength:self.width * self.height * 4];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pixels.mutableBytes, self.width, self.height, 8, self.width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
	CGContextDrawImage(context, CGRectMake(0.0, 0.0, self.width, self.height), cgImage);
	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);
	
	return pixels;
}

- (GLint)getParam:(GLenum)pname {
	if(pname == GL_TEXTURE_MIN_FILTER) return params[kEJTextureParamMinFilter];
	if(pname == GL_TEXTURE_MAG_FILTER) return params[kEJTextureParamMagFilter];
	if(pname == GL_TEXTURE_WRAP_S) return params[kEJTextureParamWrapS];
	if(pname == GL_TEXTURE_WRAP_T) return params[kEJTextureParamWrapT];
	return 0;
}

- (void)setParam:(GLenum)pname param:(GLenum)param {
	if(pname == GL_TEXTURE_MIN_FILTER) params[kEJTextureParamMinFilter] = param;
	else if(pname == GL_TEXTURE_MAG_FILTER) params[kEJTextureParamMagFilter] = param;
	else if(pname == GL_TEXTURE_WRAP_S) params[kEJTextureParamWrapS] = param;
	else if(pname == GL_TEXTURE_WRAP_T) params[kEJTextureParamWrapT] = param;
}

- (void)bindWithFilter:(GLenum)filter {
	params[kEJTextureParamMinFilter] = filter;
	params[kEJTextureParamMagFilter] = filter;
	[_textureStorage bindToTarget:GL_TEXTURE_2D withParams:params];
}

- (void)bindToTarget:(GLenum)target {
	EJ_ENSURE_LAZY_LOADED_STORAGE();
	[_textureStorage bindToTarget:target withParams:params];
}

- (UIImage *)image {
	return [EJTexture imageWithPixels:self.pixels width:self.width height:self.height];
}

+ (UIImage *)imageWithPixels:(NSData *)pixels width:(CGFloat)width height:(CGFloat)height {
	UIImage *newImage = nil;
	
	int nrOfColorComponents = 4; // RGBA
	int bitsPerColorComponent = 8;
	BOOL interpolateAndSmoothPixels = NO;
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
	CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;

	CGDataProviderRef dataProviderRef;
	CGColorSpaceRef colorSpaceRef;
	CGImageRef imageRef;

	@try {
		dataProviderRef = CGDataProviderCreateWithData(NULL, pixels.bytes, pixels.length, nil);
		colorSpaceRef = CGColorSpaceCreateDeviceRGB();
		imageRef = CGImageCreate(
			width, height,
			bitsPerColorComponent, bitsPerColorComponent * nrOfColorComponents, width * nrOfColorComponents,
			colorSpaceRef, bitmapInfo, dataProviderRef, NULL, interpolateAndSmoothPixels, renderingIntent
		);
		newImage = [[UIImage alloc] initWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationUp];
	}
	@finally {
		CGDataProviderRelease(dataProviderRef);
		CGColorSpaceRelease(colorSpaceRef);
		CGImageRelease(imageRef);
	}

	return newImage;
}

+ (void)premultiplyPixels:(const GLubyte *)inPixels to:(GLubyte *)outPixels byteLength:(NSInteger)byteLength format:(GLenum)format {
	const GLubyte *premultiplyTable = EJSharedTextureCache.instance.premultiplyTable.bytes;
	
	if( format == GL_RGBA ) {
		for( int i = 0; i < byteLength; i += 4 ) {
			unsigned short a = inPixels[i+3] * 256;
			outPixels[i+0] = premultiplyTable[ a + inPixels[i+0] ];
			outPixels[i+1] = premultiplyTable[ a + inPixels[i+1] ];
			outPixels[i+2] = premultiplyTable[ a + inPixels[i+2] ];
			outPixels[i+3] = inPixels[i+3];
		}
	}
	else if ( format == GL_LUMINANCE_ALPHA ) {		
		for( int i = 0; i < byteLength; i += 2 ) {
			unsigned short a = inPixels[i+1] * 256;
			outPixels[i+0] = premultiplyTable[ a + inPixels[i+0] ];
			outPixels[i+1] = inPixels[i+1];
		}
	}
}

+ (void)unPremultiplyPixels:(const GLubyte *)inPixels to:(GLubyte *)outPixels byteLength:(NSInteger)byteLength format:(GLenum)format {
	const GLubyte *unPremultiplyTable = EJSharedTextureCache.instance.unPremultiplyTable.bytes;
	
	if( format == GL_RGBA ) {
		for( int i = 0; i < byteLength; i += 4 ) {
			unsigned short a = inPixels[i+3] * 256;
			outPixels[i+0] = unPremultiplyTable[ a + inPixels[i+0] ];
			outPixels[i+1] = unPremultiplyTable[ a + inPixels[i+1] ];
			outPixels[i+2] = unPremultiplyTable[ a + inPixels[i+2] ];
			outPixels[i+3] = inPixels[i+3];
		}
	}
	else if ( format == GL_LUMINANCE_ALPHA ) {		
		for( int i = 0; i < byteLength; i += 2 ) {
			unsigned short a = inPixels[i+1] * 256;
			outPixels[i+0] = unPremultiplyTable[ a + inPixels[i+0] ];
			outPixels[i+1] = inPixels[i+1];
		}
	}
}

+ (void)flipPixelsY:(GLubyte *)pixels bytesPerRow:(GLuint)bytesPerRow rows:(GLuint)rows {
	if( !pixels ) { return; }
	
	GLuint middle = rows/2;
	GLuint intsPerRow = bytesPerRow / sizeof(GLuint);
	GLuint remainingBytes = bytesPerRow - intsPerRow * sizeof(GLuint);
	
	for( GLuint rowTop = 0, rowBottom = rows-1; rowTop < middle; rowTop++, rowBottom-- ) {
		
		// Swap bytes in packs of sizeof(GLuint) bytes
		GLuint *iTop = (GLuint *)(pixels + rowTop * bytesPerRow);
		GLuint *iBottom = (GLuint *)(pixels + rowBottom * bytesPerRow);
		
		GLuint itmp;
		GLint n = intsPerRow;
		do {
			itmp = *iTop;
			*iTop++ = *iBottom;
			*iBottom++ = itmp;
		} while(--n > 0);
		
		// Swap the remaining bytes
		GLubyte *bTop = (GLubyte *)iTop;
		GLubyte *bBottom = (GLubyte *)iBottom;
		
		GLubyte btmp;
		switch( remainingBytes ) {
			case 3: btmp = *bTop; *bTop++ = *bBottom; *bBottom++ = btmp;
			case 2: btmp = *bTop; *bTop++ = *bBottom; *bBottom++ = btmp;
			case 1: btmp = *bTop; *bTop = *bBottom; *bBottom = btmp;
		}
	}
}


@end
