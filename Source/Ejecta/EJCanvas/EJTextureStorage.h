// This class holds the actual OpenGL textureId and allows binding it with
// certain parameters.

// EJTextureStorage also keeps track of the time when the texture was last,
// bound so that old, unused textures can be detected and evicted from the
// cache.

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

typedef NS_ENUM(unsigned int, EJTextureParam) {
	kEJTextureParamMinFilter,
	kEJTextureParamMagFilter,
	kEJTextureParamWrapS,
	kEJTextureParamWrapT,
	kEJTextureParamLast
};

typedef EJTextureParam EJTextureParams[kEJTextureParamLast];


@interface EJTextureStorage : NSObject {
    
    EJTextureParams params;
}

@property (readonly, nonatomic) GLuint textureId;
@property (readonly, nonatomic) BOOL immutable;
@property (readonly, nonatomic) NSTimeInterval lastBound;

- (instancetype)initImmutable;
- (void)bindToTarget:(GLenum)target withParams:(EJTextureParam *)newParams;



@end
