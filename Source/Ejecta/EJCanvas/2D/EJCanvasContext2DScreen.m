#import <QuartzCore/QuartzCore.h>
#import "EJCanvasContext2DScreen.h"
#import "EJJavaScriptView.h"

@implementation EJCanvasContext2DScreen
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
		if(self.viewFrameBuffer) {
			[self resizeToWidth:self.width height:self.height];
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
		@"Creating ScreenCanvas (2D): "
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
		[self.scriptView addSubview:glview];
	}
	else {
		// Resize an existing view
		glview.frame = frame;
		glview.contentScaleFactor = contentScale;
		glview.layer.contentsScale = contentScale;
	}
	
	// Set up the renderbuffer
	glBindRenderbuffer(GL_RENDERBUFFER, self.viewRenderBuffer);
	[self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)glview.layer];
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.viewRenderBuffer);
	
	// The renderbuffer may be bigger than the requested size; make sure to store the real
	// renderbuffer size.
	GLint rbWidth, rbHeight;
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &rbWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &rbHeight);
	self.bufferWidth = rbWidth;
	self.bufferHeight = rbHeight;
	
	// Flip the screen - OpenGL has the origin in the bottom left corner. We want the top left.
    [self setUpsideDown:YES];
	[super resetFramebuffer];
}

- (void)finish {
	glFinish();
}

- (void)present {
	[self flushBuffers];
	
	if(!self.needsPresenting) { return; }
	
	if(self.msaaEnabled) {
		//Bind the MSAA and View frameBuffers and resolve
		glBindFramebuffer(GL_READ_FRAMEBUFFER_APPLE, self.msaaFrameBuffer);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER_APPLE, self.viewFrameBuffer);
		glResolveMultisampleFramebufferAPPLE();
		
		glBindRenderbuffer(GL_RENDERBUFFER, self.viewRenderBuffer);
		[self.glContext presentRenderbuffer:GL_RENDERBUFFER];
		glBindFramebuffer(GL_FRAMEBUFFER, self.msaaFrameBuffer);
	}
	else {
		[self.glContext presentRenderbuffer:GL_RENDERBUFFER];
	}
    [self setNeedsPresenting:NO];
}

- (EJTexture *)texture {
	// This context may not be the current one, but it has to be in order for
	// glReadPixels to succeed.
	EJCanvasContext *previousContext = self.scriptView.currentRenderingContext;
	self.scriptView.currentRenderingContext = self;
	
	EJTexture *texture = [self getImageDataSx:0 sy:0 sw:self.width sh:self.height].texture;
	
	self.scriptView.currentRenderingContext = previousContext;
	return texture;
}

@end
