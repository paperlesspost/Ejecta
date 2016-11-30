// A wrapper class around OpenGL's shader compilation, used for compiling
// shaders for Canvas2D.

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "EJCanvas2DTypes.h"

enum {
	kEJGLProgram2DAttributePos,
	kEJGLProgram2DAttributeUV,
	kEJGLProgram2DAttributeColor,
};

@interface EJGLProgram2D : NSObject {
	GLuint program;
	GLuint screen;
}

- (instancetype)initWithVertexShader:(const char *)vertexShaderSource fragmentShader:(const char *)fragmentShaderSource;
- (void)bindAttributeLocations;
- (void)getUniforms;

+ (GLint)compileShaderSource:(const char *)source type:(GLenum)type;
+ (void)linkProgram:(GLuint)program;

@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) GLuint screen;

@end
