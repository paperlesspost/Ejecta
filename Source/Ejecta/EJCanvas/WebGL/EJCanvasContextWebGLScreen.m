#import "EJCanvasContextWebGLScreen.h"
#import "EJJavaScriptView.h"
#import "EJTexture.h"

@implementation EJCanvasContextWebGLScreen
@synthesize style;
@synthesize view = glview;

- (void)dealloc {
	[glview removeFromSuperview];
	[glview release];
	[super dealloc];
}

- (void)setStyle:(CGRect)newStyle {
	if(
		(style.size.width ? style.size.width : self.width) != newStyle.size.width ||
		(style.size.height ? style.size.height : self.height) != newStyle.size.height
	) {
		// Must resize
		style = newStyle;
		
		// Only resize if we already have a viewFrameBuffer. Otherwise the style
		// will be honored in the 'create' call.
		if( viewFrameBuffer ) {
			[self resizeToWidth:self.width
                         height:self.height];
		}
	}
	else {
		// Just reposition
		style = newStyle;
		if( glview ) {
			glview.frame = self.frame;
		}
	}
}

- (CGRect)frame {
	// Returns the view frame with the current style. If the style's witdth/height
	// is zero, the canvas width/height is used
	return CGRectMake(
		style.origin.x,
		style.origin.y,
		(style.size.width ? style.size.width : self.width),
		(style.size.height ? style.size.height : self.height)
	);
}

- (void)resizeToWidth:(short)newWidth height:(short)newHeight {
	[self flushBuffers];
	
	self.width = newWidth;
	self.height = newHeight;
	
	CGRect frame = self.frame;
	float contentScale = MAX(self.width/frame.size.width, self.height/frame.size.height);
	
	NSLog(
		@"Creating ScreenCanvas (WebGL): "
			@"size: %fx%f, "
			@"style: %.0fx%.0f, "
			@"antialias: %@, preserveDrawingBuffer: %@",
		self.width, self.height,
		frame.size.width, frame.size.height,
		(self.msaaEnabled ? [NSString stringWithFormat:@"yes (%d samples)", self.msaaSamples] : @"no"),
		(self.preserveDrawingBuffer ? @"yes" : @"no")
	);
	
	if( !glview ) {
		// Create the OpenGL UIView with final screen size and content scaling (retina)
		glview = [[EAGLView alloc] initWithFrame:frame contentScale:contentScale retainedBacking:self.preserveDrawingBuffer];
		
		// Append the OpenGL view to Ejecta's main view
		[scriptView addSubview:glview];
	}
	else {
		// Resize an existing view
		glview.frame = frame;
		glview.contentScaleFactor = contentScale;
		glview.layer.contentsScale = contentScale;
	}
	
	// Get the previously bound frame- and renderbuffers. If none are
	// bound yet use the default buffers.
	GLint previousFrameBuffer;
	glGetIntegerv( GL_FRAMEBUFFER_BINDING, &previousFrameBuffer );
	if (!previousFrameBuffer) {
		previousFrameBuffer = EJ_WEBGL_DEFAULT_FRAMEBUFFER;
	}
	
	GLint previousRenderBuffer;
	glGetIntegerv( GL_RENDERBUFFER_BINDING, &previousRenderBuffer );
	if (!previousRenderBuffer) {
		previousRenderBuffer = EJ_WEBGL_DEFAULT_RENDERBUFFER;
	}
	
	glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
	
	// Set up the renderbuffer and some initial OpenGL properties
	[self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)glview.layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderBuffer);
	
	// The renderbuffer may be bigger than the requested size; make sure to store the real
	// renderbuffer size.
	GLint rbWidth, rbHeight;
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &rbWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &rbHeight);
	bufferWidth = rbWidth;
	bufferHeight = rbHeight;
	

	[self resizeAuxiliaryBuffers];
	
	// Clear
	glViewport(0, 0, self.width, self.height);
	[self clear];
	
	
	// Reset to the previously bound frame and renderbuffers
	[self bindFramebuffer:previousFrameBuffer toTarget:GL_FRAMEBUFFER];
	[self bindRenderbuffer:previousRenderBuffer toTarget:GL_RENDERBUFFER];
}

- (void)finish {
	glFinish();
}

- (void)present {
	if(!self.needsPresenting) { return; }
	
	if(self.msaaEnabled) {
		//Bind the MSAA and View frameBuffers and resolve
		glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, msaaFrameBuffer);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, viewFrameBuffer);
		glResolveMultisampleFramebufferAPPLE();
		
		glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
		[self.glContext presentRenderbuffer:GL_RENDERBUFFER];
		glBindFramebuffer(GL_FRAMEBUFFER, msaaFrameBuffer);
	}
	else {
		[self.glContext presentRenderbuffer:GL_RENDERBUFFER];
	}
	
	if(self.preserveDrawingBuffer) {
		glClear(GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	}
	else {
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	}
    [self setNeedsPresenting:NO];
}

- (EJTexture *)texture {
	EJCanvasContext *previousContext = scriptView.currentRenderingContext;
	scriptView.currentRenderingContext = self;

	NSMutableData *pixels = [NSMutableData dataWithLength:bufferWidth * bufferHeight * 4 * sizeof(GLubyte)];
	glReadPixels(0, 0, bufferWidth, bufferHeight, GL_RGBA, GL_UNSIGNED_BYTE, pixels.mutableBytes);
	
	[EJTexture flipPixelsY:pixels.mutableBytes bytesPerRow:bufferWidth * 4 rows:bufferHeight];
	EJTexture *texture = [[[EJTexture alloc] initWithWidth:bufferWidth height:bufferHeight pixels:pixels] autorelease];

	scriptView.currentRenderingContext = previousContext;
	return texture;
}

@end
