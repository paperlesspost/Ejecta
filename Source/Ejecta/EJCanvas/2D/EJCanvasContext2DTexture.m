#import "EJCanvasContext2DTexture.h"
#import "EJJavaScriptView.h"

@implementation EJCanvasContext2DTexture

- (void)dealloc {
	[texture release];
	[super dealloc];
}

- (void)resizeToWidth:(short)newWidth height:(short)newHeight {
	[self flushBuffers];
	
	self.bufferWidth = self.width = newWidth;
	self.bufferHeight = self.height = newHeight;
	
	NSLog(
		@"Creating Offscreen Canvas (2D): "
			@"size: %fx%f, "
			@"antialias: %@",
		self.width, self.height,
		(self.msaaEnabled ? [NSString stringWithFormat:@"yes (%d samples)", self.msaaSamples] : @"no")
	);
	
	// Release previous texture if any, create the new texture and set it as
	// the rendering target for this framebuffer
	[texture release];
	texture = [[EJTexture alloc] initAsRenderTargetWithWidth:newWidth height:newHeight
		fbo:self.viewFrameBuffer];
	
	glBindFramebuffer(GL_FRAMEBUFFER, self.viewFrameBuffer);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.textureId, 0);
	
	[self resetFramebuffer];
}

- (EJTexture *)texture {
	// If this texture Canvas uses MSAA, we need to resolve the MSAA first,
	// before we can use the texture for drawing.
	if(self.msaaEnabled && self.needsPresenting) {
		GLint boundFrameBuffer;
		glGetIntegerv( GL_FRAMEBUFFER_BINDING, &boundFrameBuffer );
		
		//Bind the MSAA and View frameBuffers and resolve
		glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, self.msaaFrameBuffer);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, self.viewFrameBuffer);
		glResolveMultisampleFramebufferAPPLE();
		
		glBindFramebuffer(GL_FRAMEBUFFER, boundFrameBuffer);
        [self setNeedsPresenting:NO];
	}
	
	// Special case where this canvas is drawn into itself - we have to use glReadPixels to get a texture
	if(self.scriptView.currentRenderingContext == self ) {
		return [self getImageDataSx:0 sy:0 sw:self.width sh:self.height].texture;
	}
	
	// Just use the framebuffer texture directly
	else {
		return texture;
	}
}

@end
