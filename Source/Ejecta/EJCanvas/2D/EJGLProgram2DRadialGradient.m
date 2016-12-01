#import "EJGLProgram2DRadialGradient.h"

@implementation EJGLProgram2DRadialGradient

- (void)getUniforms {
	[super getUniforms];
	
	_inner = glGetUniformLocation(self.program, "inner");
	_diff = glGetUniformLocation(self.program, "diff");
}

@end
