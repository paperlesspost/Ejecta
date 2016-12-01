// The Texture class is used for everything that provides pixel data in some way
// and should be drawable to a Context. The most obvious use case is as the
// pixel data of an Image element. However, Canvas elements themselfs may need
// to be drawn to other Canvases and thus create a Texture of their contents on
// the fly.

// EJTexture is also extensively used in 2D Contexts for Fonts, Gradients,
// Patterns and ImageData.

// A lot of work goes into making sure that Textures can be shared between
// different 2D and WebGL contexts and keeping track of mutability. The actual
// Texture Data is held in a separate EJTextureStorage class, so that 2D and
// WebGL textures can share the same data, but have different binding
// attributes. This also allows us to release and reload the texture's pixel
// data on demand while keeping the Texture itself around.

// All textures are represented with premultiplied alpha in memory. However,
// ImageData objects for 2D Canvases expect the raw pixel data to be
// unpremultiplied, so this class provides some static methods to premultiply
// and unpremultiply raw pixel data.

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "EJTextureStorage.h"

@interface EJTexture : NSObject <NSCopying> {
    EJTextureParams params;
}

@property (nonatomic, readonly) BOOL cached;
@property (nonatomic, assign) BOOL drawFlippedY;
@property (nonatomic, readonly) BOOL isCompressed;
@property (nonatomic, readonly) BOOL lazyLoaded;
@property (nonatomic, readonly) BOOL dimensionsKnown;
@property (nonatomic, readonly) CGFloat width, height;
@property (nonatomic, readonly) NSString *fullPath;
@property (nonatomic, readonly) EJTextureStorage *textureStorage;
@property (nonatomic, readonly) GLenum format;
@property (nonatomic, readonly) GLuint fbo;
@property (nonatomic, readonly) NSBlockOperation *loadCallback;
@property (nonatomic, readonly) BOOL isDynamic;
@property (nonatomic, readonly) NSMutableData *pixels;
@property (nonatomic, readonly) GLuint textureId;
@property (nonatomic, readonly) NSTimeInterval lastUsed;


- (instancetype)initEmptyForWebGL;
- (instancetype)initWithPath:(NSString *)path;
+ (id)cachedTextureWithPath:(NSString *)path loadOnQueue:(NSOperationQueue *)queue callback:(NSOperation *)callback;
- (instancetype)initWithPath:(NSString *)path loadOnQueue:(NSOperationQueue *)queue callback:(NSOperation *)callback;

- (instancetype)initWithWidth:(int)widthp height:(int)heightp;
- (instancetype)initWithWidth:(int)widthp height:(int)heightp format:(GLenum) format;
- (instancetype)initWithWidth:(int)widthp height:(int)heightp pixels:(NSData *)pixels;
- (instancetype)initAsRenderTargetWithWidth:(int)widthp height:(int)heightp fbo:(GLuint)fbo;
- (instancetype)initWithUIImage:(UIImage *)image;

- (void)maybeReleaseStorage;

- (void)ensureMutableKeepPixels:(BOOL)keepPixels forTarget:(GLenum)target;

- (void)createWithTexture:(EJTexture *)other;
- (void)createWithPixels:(NSData *)pixels format:(GLenum)format;
- (void)createWithPixels:(NSData *)pixels format:(GLenum)formatp target:(GLenum)target;
- (void)uploadCompressedPixels:(NSData *)pixels target:(GLenum)target;
- (void)updateWithPixels:(NSData *)pixels atX:(int)x y:(int)y width:(int)subWidth height:(int)subHeight;

- (NSMutableData *)loadPixelsFromPath:(NSString *)path;
- (NSMutableData *)loadPixelsFromUIImage:(UIImage *)image;

- (GLint)getParam:(GLenum)pname;
- (void)setParam:(GLenum)pname param:(GLenum)param;

- (void)bindWithFilter:(GLenum)filter;
- (void)bindToTarget:(GLenum)target;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) UIImage *image;
+ (UIImage *)imageWithPixels:(NSData *)pixels width:(CGFloat)width height:(CGFloat)height;

+ (void)premultiplyPixels:(const GLubyte *)inPixels to:(GLubyte *)outPixels byteLength:(NSInteger)byteLength format:(GLenum)format;
+ (void)unPremultiplyPixels:(const GLubyte *)inPixels to:(GLubyte *)outPixels byteLength:(NSInteger)byteLength format:(GLenum)format;
+ (void)flipPixelsY:(GLubyte *)pixels bytesPerRow:(GLuint)bytesPerRow rows:(GLuint)rows;



@end
