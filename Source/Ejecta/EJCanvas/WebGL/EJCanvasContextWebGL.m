#import "EJCanvasContextWebGL.h"
#import "EJJavaScriptView.h"

@implementation EJCanvasContextWebGL

- (BOOL)needsPresenting { return self.needsPresenting; }
- (void)setNeedsPresenting:(BOOL)needsPresentingp { self.needsPresenting = needsPresentingp; }

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp width:(short)widthp height:(short)heightp {
	if( self = [super init] ) {
        
        [self setScriptView:scriptViewp];
        
		// Flush the previous context - if any - before creating a new one
		if( [EAGLContext currentContext] ) {
			glFlush();
		}
		
		self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
			sharegroup:self.scriptView.openGLContext.glSharegroup];
		
		bufferWidth = self.width = widthp;
		bufferHeight = self.height = heightp;
		
		self.msaaEnabled = NO;
		self.msaaSamples = 2;
		self.preserveDrawingBuffer = NO;
	}
	return self;
}

- (void)resizeToWidth:(short)newWidth height:(short)newHeight {
	// This function is a stub - Overwritten in both subclasses
	bufferWidth = self.width = newWidth;
	bufferHeight = self.height = newHeight;
}

- (void)resizeAuxiliaryBuffers {
	// Resize the MSAA buffer, if enabled
	if(self.msaaEnabled && msaaFrameBuffer && msaaRenderBuffer ) {
		glBindFramebuffer(GL_FRAMEBUFFER, msaaFrameBuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, msaaRenderBuffer);
		
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, self.msaaSamples, GL_RGBA8_OES, bufferWidth, bufferHeight);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, msaaRenderBuffer);
	}
	
	// Resize the depth and stencil buffer
	glBindRenderbuffer(GL_RENDERBUFFER, depthStencilBuffer);
	if(self.msaaEnabled) {
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, self.msaaSamples, GL_DEPTH24_STENCIL8_OES, bufferWidth, bufferHeight);
	}
	else {
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, bufferWidth, bufferHeight);
	}
	
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthStencilBuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, depthStencilBuffer);
    [self setNeedsPresenting:YES];
}

- (void)create {
	if(self.msaaEnabled) {
		glGenFramebuffers(1, &msaaFrameBuffer);
		glGenRenderbuffers(1, &msaaRenderBuffer);
	}
	
	// Create the frame- and renderbuffers
	glGenFramebuffers(1, &viewFrameBuffer);	
	glGenRenderbuffers(1, &viewRenderBuffer);
	glGenRenderbuffers(1, &depthStencilBuffer);
	
	[self resizeToWidth:self.width
                 height:self.height];
}

- (void)dealloc {
	// Make sure this rendering context is the current one, so all
	// OpenGL objects can be deleted properly. Remember the currently bound
	// Context, but only if it's not the context to be deleted
	EAGLContext *oldContext = [EAGLContext currentContext];
	if( oldContext == self.glContext ) { oldContext = NULL; }
	[EAGLContext setCurrentContext:self.glContext];
	
	if( viewFrameBuffer ) { glDeleteFramebuffers( 1, &viewFrameBuffer); }
	if( viewRenderBuffer ) { glDeleteRenderbuffers(1, &viewRenderBuffer); }
	if( msaaFrameBuffer ) {	glDeleteFramebuffers( 1, &msaaFrameBuffer); }
	if( msaaRenderBuffer ) { glDeleteRenderbuffers(1, &msaaRenderBuffer); }
	if( depthStencilBuffer ) { glDeleteRenderbuffers(1, &depthStencilBuffer); }
	
    [self.glContext release];
	
	[EAGLContext setCurrentContext:oldContext];
	[super dealloc];
}

- (void)prepare {
	// Bind to the frame/render buffer last bound on this context
	glBindFramebuffer(GL_FRAMEBUFFER, boundFrameBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, boundRenderBuffer);
	
	// Re-bind textures; they may have been changed in a different context
	GLint boundTexture2D;
	glGetIntegerv(GL_TEXTURE_BINDING_2D, &boundTexture2D);
	if( boundTexture2D ) { glBindTexture(GL_TEXTURE_2D, boundTexture2D); }
	
	GLint boundTextureCube;
	glGetIntegerv(GL_TEXTURE_BINDING_CUBE_MAP, &boundTextureCube);
	if( boundTextureCube ) { glBindTexture(GL_TEXTURE_CUBE_MAP, boundTextureCube); }
    [self setNeedsPresenting:YES];
}

- (void)clear {
	GLfloat c[4];
	glGetFloatv(GL_COLOR_CLEAR_VALUE, c);
	
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	
	glClearColor(c[0], c[1], c[2], c[3]);
}

- (void)bindFramebuffer:(GLint)framebuffer toTarget:(GLuint)target {
	if( framebuffer == EJ_WEBGL_DEFAULT_FRAMEBUFFER ) {
		framebuffer = self.msaaEnabled ? msaaFrameBuffer : viewFrameBuffer;
		[self bindRenderbuffer:EJ_WEBGL_DEFAULT_RENDERBUFFER toTarget:GL_RENDERBUFFER];
	}
	glBindFramebuffer(target, framebuffer);
	boundFrameBuffer = framebuffer;
}

- (void)bindRenderbuffer:(GLint)renderbuffer toTarget:(GLuint)target {
	if( renderbuffer == EJ_WEBGL_DEFAULT_RENDERBUFFER ) {
		renderbuffer = self.msaaEnabled ? msaaRenderBuffer : viewRenderBuffer;
	}
	glBindRenderbuffer(target, renderbuffer);
	boundRenderBuffer = renderbuffer;
}

- (void)setWidth:(CGFloat)newWidth {
	if( newWidth == self.width ) {
		// Same width as before? Just clear the canvas, as per the spec
		[self clear];
		return;
	}
	[self resizeToWidth:newWidth height:self.height];
}

- (void)setHeight:(CGFloat)newHeight {
	if( newHeight == self.height ) {
		// Same height as before? Just clear the canvas, as per the spec
		[self clear];
		return;
	}
	[self resizeToWidth:self.width height:newHeight];
}

@end
