// Subclass of EJGLProgramm2D for the radial gradient fragment shader, because
// this shader has two special uniforms that describe the gradient.

#import "EJGLProgram2D.h"

@interface EJGLProgram2DRadialGradient : EJGLProgram2D

@property (nonatomic, assign) GLuint inner;
@property (nonatomic, assign) GLuint diff;

@end
