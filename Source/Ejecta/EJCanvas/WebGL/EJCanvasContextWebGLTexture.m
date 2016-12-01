#import "EJCanvasContextWebGLTexture.h"

@implementation EJCanvasContextWebGLTexture

- (void)dealloc {
	[texture release];
	[super dealloc];
}

- (void)resizeToWidth:(short)newWidth height:(short)newHeight {
	[self flushBuffers];
	
	bufferWidth = self.width = newWidth;
	bufferHeight = self.height = newHeight;
	
	NSLog(
		@"Creating Offscreen Canvas (WebGL): size: %fx%f, antialias: %@",
		self.width, self.height,
		(self.msaaEnabled ? [NSString stringWithFormat:@"yes (%d samples)", self.msaaSamples] : @"no")
	);
	
	GLint previousFrameBuffer;
	GLint previousRenderBuffer;
	glGetIntegerv( GL_FRAMEBUFFER_BINDING, &previousFrameBuffer );
	glGetIntegerv( GL_RENDERBUFFER_BINDING, &previousRenderBuffer );
	
	glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
	
	// Release previous texture if any, create the new texture and set it as
	// the rendering target for this framebuffer
	[texture release];
	texture = [[EJTexture alloc] initAsRenderTargetWithWidth:newWidth height:newHeight fbo:viewFrameBuffer];
	texture.drawFlippedY = true;
	
	glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.textureId, 0);
	
	[self resizeAuxiliaryBuffers];
	
	// Clear
	glViewport(0, 0, self.width, self.height);
	[self clear];
	
	// Reset to the previously bound frame and renderbuffers
	[self bindFramebuffer:previousFrameBuffer toTarget:GL_FRAMEBUFFER];
	[self bindRenderbuffer:previousRenderBuffer toTarget:GL_RENDERBUFFER];
}

- (EJTexture *)texture {
	// If this texture Canvas uses MSAA, we need to resolve the MSAA first,
	// before we can use the texture for drawing.
	if(self.msaaEnabled && self.needsPresenting) {
		GLint previousFrameBuffer;
		glGetIntegerv( GL_FRAMEBUFFER_BINDING, &previousFrameBuffer );
		
		//Bind the MSAA and View frameBuffers and resolve
		glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, msaaFrameBuffer);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, viewFrameBuffer);
		glResolveMultisampleFramebufferAPPLE();
		
		glBindFramebuffer(GL_FRAMEBUFFER, previousFrameBuffer);
        [self setNeedsPresenting:NO];
    }
	
	return texture;
}

@end
