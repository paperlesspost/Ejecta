// Instead of the indices that OpenGL returns for its create* functions, WebGL
// returns an object for each created object. This ensures that textures,
// buffers and shaders that are not currently bound can be correctly garbage
// collected.

// This files provides thin binding wrappers for each type of these OpenGL
// indices.

#import "EJBindingBase.h"
#import "EJBindingCanvasContextWebGL.h"
#import "EJTexture.h"

@interface EJBindingWebGLObject : EJBindingBase {
	GLuint index;
	EJBindingCanvasContextWebGL *webglContext;
}
- (instancetype)initWithWebGLContext:(EJBindingCanvasContextWebGL *)webglContext index:(GLuint)index;
- (void)invalidate;
+ (GLint)indexFromJSValue:(JSValueRef)value;
+ (EJBindingWebGLObject *)webGLObjectFromJSValue:(JSValueRef)value;
+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	webglContext:(EJBindingCanvasContextWebGL *)webglContext
	index:(GLuint)index;
@end


@interface EJBindingWebGLBuffer : EJBindingWebGLObject
@end


@interface EJBindingWebGLProgram : EJBindingWebGLObject
@end


@interface EJBindingWebGLShader : EJBindingWebGLObject
@end


@interface EJBindingWebGLTexture : EJBindingWebGLObject {
	EJTexture *texture;
}
+ (EJTexture *)textureFromJSValue:(JSValueRef)value;
+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	webglContext:(EJBindingCanvasContextWebGL *)webglContext;
@end


@interface EJBindingWebGLUniformLocation : EJBindingWebGLObject
@end


@interface EJBindingWebGLRenderbuffer : EJBindingWebGLObject
@end


@interface EJBindingWebGLFramebuffer : EJBindingWebGLObject
@end

@interface EJBindingWebGLVertexArrayObjectOES : EJBindingWebGLObject
@end

@interface EJBindingWebGLActiveInfo : EJBindingBase {
	GLint size;
	GLenum type;
	NSString *name;
}
- (instancetype)initWithSize:(GLint)sizep type:(GLenum)typep name:(NSString *)namep;
+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	size:(GLint)sizep type:(GLenum)typep name:(NSString *)namep;
@end


@interface EJBindingWebGLShaderPrecisionFormat : EJBindingBase {
	GLint rangeMin;
	GLint rangeMax;
	GLint precision;
}
- (instancetype)initWithRangeMin:(GLint)rangeMin rangeMax:(GLint)rangeMax precision:(GLint)precision;
+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	rangeMin:(GLint)rangeMin rangeMax:(GLint)rangeMax precision:(GLint)precision;
@end


@interface EJBindingWebGLContextAttributes : EJBindingBase
@end
