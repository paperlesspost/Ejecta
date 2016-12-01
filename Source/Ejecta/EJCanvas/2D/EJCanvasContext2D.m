#import "EJCanvasContext2D.h"
#import "EJFont.h"
#import "EJJavaScriptView.h"

#import "EJCanvasPattern.h"
#import "EJCanvasGradient.h"

@implementation EJCanvasContext2D

const EJCompositeOperationFunc EJCompositeOperationFuncs[] = {
	[kEJCompositeOperationSourceOver] = {GL_ONE, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationLighter] = {GL_ONE, GL_ONE_MINUS_SRC_ALPHA, 0},
	[kEJCompositeOperationLighten] = {GL_ONE, GL_ONE_MINUS_SRC_ALPHA, 0},
	[kEJCompositeOperationDarker] = {GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationDarken] = {GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationDestinationOut] = {GL_ZERO, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationDestinationOver] = {GL_ONE_MINUS_DST_ALPHA, GL_ONE, 1},
	[kEJCompositeOperationSourceAtop] = {GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationXOR] = {GL_ONE_MINUS_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA, 1},
	[kEJCompositeOperationCopy] = {GL_ONE, GL_ZERO, 1},
	[kEJCompositeOperationSourceIn] = {GL_DST_ALPHA, GL_ZERO, 1},
	[kEJCompositeOperationDestinationIn] = {GL_ZERO, GL_SRC_ALPHA, 1},
	[kEJCompositeOperationSourceOut] = {GL_ONE_MINUS_DST_ALPHA, GL_ZERO, 1},
	[kEJCompositeOperationDestinationAtop] = {GL_ONE_MINUS_DST_ALPHA, GL_SRC_ALPHA, 1}
};


- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp width:(short)widthp height:(short)heightp {
    
    self = [super init];
    
    if (self) {
        
        [self setScriptView:scriptViewp];
        [self setSharedGLContext:scriptViewp.openGLContext];
        [self setGlContext:self.sharedGLContext.glContext2D];
        [self setVertexBuffer:self.sharedGLContext.vertexBuffer.mutableBytes];
        NSInteger bufferSize = self.sharedGLContext.vertexBuffer.length / sizeof(EJVertex);
        [self setVertexBufferSize:bufferSize];
        memset(stateStack, 0, sizeof(stateStack));
        [self setStateIndex:0];
        [self setState:&stateStack[_stateIndex]];
        self.state->globalAlpha = 1;
        self.state->globalCompositeOperation = kEJCompositeOperationSourceOver;
        self.state->transform = CGAffineTransformIdentity;
        self.state->lineWidth = 1;
        self.state->lineCap = kEJLineCapButt;
        self.state->lineJoin = kEJLineJoinMiter;
        self.state->miterLimit = 10;
        self.state->textBaseline = kEJTextBaselineAlphabetic;
        self.state->textAlign = kEJTextAlignStart;
        self.state->font = [[EJFontDescriptor descriptorWithName:@"Helvetica" size:10] retain];
        self.state->clipPath = nil;
        
        _bufferWidth = self.width = widthp;
        _bufferHeight = self.height = heightp;
        _path = [[EJPath alloc] init];
        _fontCache = [[EJFontCache instance] retain];
        _textureFilter = GL_LINEAR;
        
        self.msaaEnabled = NO;
        self.msaaSamples = 2;
        self.preserveDrawingBuffer = YES;
        
        _stencilMask = 0x1;
        
    }
    return self;
}

- (void)dealloc {
	// Make sure this rendering context is the current one, so all
	// OpenGL objects can be deleted properly.
	EAGLContext *oldContext = EAGLContext.currentContext;
	[EAGLContext setCurrentContext:self.glContext];
	
	[_fontCache release];
    _fontCache = nil;
    
    [_currentTexture release];
    _currentTexture = nil;
    
    [_path release];
    _path = nil;
    
    [_scriptView release];
    _scriptView = nil;
    
    [_currentProgram release];
    _currentProgram = nil;
    
    [_sharedGLContext release];
    _sharedGLContext = nil;
    
    
	// Release all fonts, clip paths and patterns from the stack
	for( int i = 0; i < _stateIndex + 1; i++ ) {
		[stateStack[i].font release];
		[stateStack[i].clipPath release];
		[stateStack[i].fillObject release];
		[stateStack[i].strokeObject release];
	}
	
	if( _viewFrameBuffer ) { glDeleteFramebuffers( 1, &_viewFrameBuffer); }
	if( _viewRenderBuffer ) { glDeleteRenderbuffers(1, &_viewRenderBuffer); }
	if( _msaaFrameBuffer ) {	glDeleteFramebuffers( 1, &_msaaFrameBuffer); }
	if( _msaaRenderBuffer ) { glDeleteRenderbuffers(1, &_msaaRenderBuffer); }
	if( _stencilBuffer ) { glDeleteRenderbuffers(1, &_stencilBuffer); }
	
	[_path release];
	[EAGLContext setCurrentContext:oldContext];
	
	[super dealloc];
}

- (void)create {
	if(self.msaaEnabled) {
		glGenFramebuffers(1, &_msaaFrameBuffer);
		glGenRenderbuffers(1, &_msaaRenderBuffer);
	}
	
	glGenFramebuffers(1, &_viewFrameBuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _viewFrameBuffer);
	
	glGenRenderbuffers(1, &_viewRenderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderBuffer);
	
	glDisable(GL_CULL_FACE);
	glDisable(GL_DITHER);
	
	glEnable(GL_BLEND);
	glDepthFunc(GL_ALWAYS);
	
	[self resizeToWidth:self.width
                 height:self.height];
}

- (void)resizeToWidth:(short)newWidth height:(short)newHeight {
	// This function is a stub - Overwritten in both subclasses
	self.width = newWidth;
	self.height = newHeight;
	
	_bufferWidth = self.width;
	_bufferHeight = self.height;
	
	[self resetFramebuffer];
}

- (void)resetFramebuffer {
	// Delete stencil buffer if present; it will be re-created when needed
	if( _stencilBuffer ) {
		glDeleteRenderbuffers(1, &_stencilBuffer);
		_stencilBuffer = 0;
	}
	
	// Resize the MSAA buffer
	if(self.msaaEnabled && _msaaFrameBuffer && _msaaRenderBuffer ) {
		glBindFramebuffer(GL_FRAMEBUFFER, _msaaFrameBuffer);
		glBindRenderbuffer(GL_RENDERBUFFER, _msaaRenderBuffer);
		
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, self.msaaSamples, GL_RGBA8_OES, _bufferWidth, _bufferHeight);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _msaaRenderBuffer);
	}
	
	[self prepare];
	
	// Clear to transparent
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
	glClear(GL_COLOR_BUFFER_BIT);

    [self setNeedsPresenting:YES];
    
}

- (void)createStencilBufferOnce {
	if( _stencilBuffer ) { return; }
	
	glGenRenderbuffers(1, &_stencilBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _stencilBuffer);
	if(self.msaaEnabled) {
		glRenderbufferStorageMultisampleAPPLE(GL_RENDERBUFFER, self.msaaSamples, GL_DEPTH24_STENCIL8_OES, _bufferWidth, _bufferHeight);
	}
	else {
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, _bufferWidth, _bufferHeight);
	}
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _stencilBuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _stencilBuffer);
	
	glBindRenderbuffer(GL_RENDERBUFFER, self.msaaEnabled ? _msaaRenderBuffer : _viewRenderBuffer );
	
	glClear(GL_STENCIL_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	glEnable(GL_DEPTH_TEST);
}

- (void)bindVertexBuffer {	
	glEnableVertexAttribArray(kEJGLProgram2DAttributePos);
	glVertexAttribPointer(kEJGLProgram2DAttributePos, 2, GL_FLOAT, GL_FALSE,
		sizeof(EJVertex), (char *)self.vertexBuffer + offsetof(EJVertex, pos));
	
	glEnableVertexAttribArray(kEJGLProgram2DAttributeUV);
	glVertexAttribPointer(kEJGLProgram2DAttributeUV, 2, GL_FLOAT, GL_FALSE,
		sizeof(EJVertex), (char *)self.vertexBuffer + offsetof(EJVertex, uv));

	glEnableVertexAttribArray(kEJGLProgram2DAttributeColor);
	glVertexAttribPointer(kEJGLProgram2DAttributeColor, 4, GL_UNSIGNED_BYTE, GL_TRUE,
		sizeof(EJVertex), (char *)self.vertexBuffer + offsetof(EJVertex, color));
}

- (void)prepare {
	// Bind the frameBuffer and vertexBuffer array
	glBindFramebuffer(GL_FRAMEBUFFER, self.msaaEnabled ? self.msaaFrameBuffer : self.viewFrameBuffer );
	glBindRenderbuffer(GL_RENDERBUFFER, self.msaaEnabled ? self.msaaRenderBuffer : self.viewRenderBuffer );
	
	glViewport(0, 0, self.bufferWidth, self.bufferHeight);
	
	EJCompositeOperation op = self.state->globalCompositeOperation;
	glBlendFunc( EJCompositeOperationFuncs[op].source, EJCompositeOperationFuncs[op].destination );
	_currentTexture = nil;
	_currentProgram = nil;
	
	[self bindVertexBuffer];
	
	if(_stencilBuffer) {
		glEnable(GL_DEPTH_TEST);
	}
	else {
		glDisable(GL_DEPTH_TEST);
	}
	
	if( _state->clipPath ) {
		glDepthFunc(GL_EQUAL);
	}
	else {
		glDepthFunc(GL_ALWAYS);
	}
	
    [self setNeedsPresenting:YES];
}

- (void)setWidth:(CGFloat)newWidth {
    
    if(newWidth == self.width) {
        // Same width as before? Just clear the canvas, as per the spec
        [self flushBuffers];
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }
    
    self.width = newWidth;
    
    [self resizeToWidth:newWidth height:self.height];
}

- (void)setHeight:(CGFloat)newHeight {
    
    if(newHeight == self.height) {
        // Same height as before? Just clear the canvas, as per the spec
        [self flushBuffers];
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }
    
    self.height = newHeight;
    
    [self resizeToWidth:self.width
                 height:newHeight];
}

- (void)setTexture:(EJTexture *)newTexture {
	if( _currentTexture == newTexture ) { return; }
	
	[self flushBuffers];
	
	_currentTexture = newTexture;
	[_currentTexture bindWithFilter:_textureFilter];
}

- (void)setProgram:(EJGLProgram2D *)newProgram {
	if( _currentProgram == newProgram ) { return; }
	
	[self flushBuffers];
	_currentProgram = newProgram;
	
	glUseProgram(_currentProgram.program);
	glUniform2f(_currentProgram.screen, self.width, self.height * (_upsideDown ? -1 : 1));
}

- (void)pushTriX1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2
	x3:(float)x3 y3:(float)y3
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	if( _vertexBufferIndex >= _vertexBufferSize - 3 ) {
		[self flushBuffers];
	}
	
	EJVector2 d1 = { x1, y1 };
	EJVector2 d2 = { x2, y2 };
	EJVector2 d3 = { x3, y3 };
	
	if( !CGAffineTransformIsIdentity(transform) ) {
		d1 = EJVector2ApplyTransform( d1, transform );
		d2 = EJVector2ApplyTransform( d2, transform );
		d3 = EJVector2ApplyTransform( d3, transform );
	}
	
	EJVertex *vb = &_vertexBuffer[_vertexBufferIndex];
	vb[0] = (EJVertex) { d1, {0, 0}, color };
	vb[1] = (EJVertex) { d2, {0, 0}, color };
	vb[2] = (EJVertex) { d3, {0, 0}, color };
	
	_vertexBufferIndex += 3;
}

- (void)pushQuadV1:(EJVector2)v1 v2:(EJVector2)v2 v3:(EJVector2)v3 v4:(EJVector2)v4
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	if( _vertexBufferIndex >= _vertexBufferSize - 6 ) {
		[self flushBuffers];
	}
	
	if( !CGAffineTransformIsIdentity(transform) ) {
		v1 = EJVector2ApplyTransform( v1, transform );
		v2 = EJVector2ApplyTransform( v2, transform );
		v3 = EJVector2ApplyTransform( v3, transform );
		v4 = EJVector2ApplyTransform( v4, transform );
	}
	
	EJVertex *vb = &_vertexBuffer[_vertexBufferIndex];
	vb[0] = (EJVertex) { v1, {0, 0}, color };
	vb[1] = (EJVertex) { v2, {0, 0}, color };
	vb[2] = (EJVertex) { v3, {0, 0}, color };
	vb[3] = (EJVertex) { v2, {0, 0}, color };
	vb[4] = (EJVertex) { v3, {0, 0}, color };
	vb[5] = (EJVertex) { v4, {0, 0}, color };
	
	_vertexBufferIndex += 6;
}

- (void)pushRectX:(float)x y:(float)y w:(float)w h:(float)h
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	if( _vertexBufferIndex >= _vertexBufferSize - 6 ) {
		[self flushBuffers];
	}
		
	EJVector2 d11 = {x, y};
	EJVector2 d21 = {x+w, y};
	EJVector2 d12 = {x, y+h};
	EJVector2 d22 = {x+w, y+h};
	
	if( !CGAffineTransformIsIdentity(transform) ) {
		d11 = EJVector2ApplyTransform( d11, transform );
		d21 = EJVector2ApplyTransform( d21, transform );
		d12 = EJVector2ApplyTransform( d12, transform );
		d22 = EJVector2ApplyTransform( d22, transform );
	}
	
	EJVertex *vb = &_vertexBuffer[_vertexBufferIndex];
	vb[0] = (EJVertex) { d11, {0, 0}, color };	// top left
	vb[1] = (EJVertex) { d21, {0, 0}, color };	// top right
	vb[2] = (EJVertex) { d12, {0, 0}, color };	// bottom left
		
	vb[3] = (EJVertex) { d21, {0, 0}, color };	// top right
	vb[4] = (EJVertex) { d12, {0, 0}, color };	// bottom left
	vb[5] = (EJVertex) { d22, {0, 0}, color };	// bottom right
	
	_vertexBufferIndex += 6;
}

- (void)pushFilledRectX:(float)x y:(float)y w:(float)w h:(float)h
	fillable:(NSObject<EJFillable> *)fillable
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	if( [fillable isKindOfClass:EJCanvasPattern.class] ) {
		EJCanvasPattern *pattern = (EJCanvasPattern *)fillable;
		[self pushPatternedRectX:x y:y w:w h:h pattern:pattern color:color withTransform:transform];
	}
	else if( [fillable isKindOfClass:EJCanvasGradient.class] ) {
		EJCanvasGradient *gradient = (EJCanvasGradient *)fillable;
		[self pushGradientRectX:x y:y w:w h:h gradient:gradient color:color withTransform:transform];
	}
}

- (void)pushGradientRectX:(float)x y:(float)y w:(float)w h:(float)h
	gradient:(EJCanvasGradient *)gradient
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{	
	if( gradient.type == kEJCanvasGradientTypeLinear ) {
		// Local positions inside the quad
		EJVector2 p1 = {(gradient.p1.x-x)/w, (gradient.p1.y-y)/h};
		EJVector2 p2 = {(gradient.p2.x-x)/w, (gradient.p2.y-y)/h};
		
		// Calculate the slope of (p1,p2) and the line orthogonal to it
		float aspect = w/h;
		EJVector2 slope = EJVector2Sub(p2, p1);
		EJVector2 ortho = {slope.y/aspect, -slope.x*aspect};
		
		// Calculate the intersection points of the slope (starting at p1)
		// and the orthogonal starting at each corner of the quad - these
		// points are the final texture coordinates.
		float d = 1/(slope.y * ortho.x - slope.x * ortho.y);
		
		EJVector2
			ot = {ortho.x * d, ortho.y * d},
			st = {slope.x * d, slope.y * d};
		
		EJVector2
			a11 = {ot.x * -p1.y, st.x * -p1.y},
			a12 = {ot.y * p1.x, st.y * p1.x},
			a21 = {ot.x * (1 - p1.y), st.x * (1 - p1.y)},
			a22 = {ot.y * (p1.x - 1), st.y * (p1.x - 1)};
			
		EJVector2
			t11 = {a11.x + a12.x, a11.y + a12.y},
			t21 = {a11.x + a22.x, a11.y + a22.y},
			t12 = {a21.x + a12.x, a21.y + a12.y},
			t22 = {a21.x + a22.x, a21.y + a22.y};
		
		[self setProgram:_sharedGLContext.programTexture];
		[self setTexture:gradient.texture];
		if( _vertexBufferIndex >= _vertexBufferSize - 6 ) {
			[self flushBuffers];
		}
		
		// Vertex coordinates
		EJVector2 d11 = {x, y};
		EJVector2 d21 = {x+w, y};
		EJVector2 d12 = {x, y+h};
		EJVector2 d22 = {x+w, y+h};
		
		if( !CGAffineTransformIsIdentity(transform) ) {
			d11 = EJVector2ApplyTransform( d11, transform );
			d21 = EJVector2ApplyTransform( d21, transform );
			d12 = EJVector2ApplyTransform( d12, transform );
			d22 = EJVector2ApplyTransform( d22, transform );
		}

		EJVertex *vb = &_vertexBuffer[_vertexBufferIndex];
		vb[0] = (EJVertex) { d11, t11, color };	// top left
		vb[1] = (EJVertex) { d21, t21, color };	// top right
		vb[2] = (EJVertex) { d12, t12, color };	// bottom left
			
		vb[3] = (EJVertex) { d21, t21, color };	// top right
		vb[4] = (EJVertex) { d12, t12, color };	// bottom left
		vb[5] = (EJVertex) { d22, t22, color };	// bottom right
		
		_vertexBufferIndex += 6;
	}
	
	else if( gradient.type == kEJCanvasGradientTypeRadial ) {
		[self flushBuffers];
				
		EJGLProgram2DRadialGradient *gradientProgram = _sharedGLContext.programRadialGradient;
		[self setProgram:gradientProgram];
		
		glUniform3f(gradientProgram.inner, gradient.p1.x, gradient.p1.y, gradient.r1);
		EJVector2 dp = EJVector2Sub(gradient.p2, gradient.p1);
		float dr = gradient.r2 - gradient.r1;
		glUniform3f(gradientProgram.diff, dp.x, dp.y, dr);
		
		[self setTexture:gradient.texture];
		[self pushTexturedRectX:x y:y w:w h:h tx:x ty:y tw:w th:h color:color withTransform:transform];
	}
}

- (void)pushPatternedRectX:(float)x y:(float)y w:(float)w h:(float)h
	pattern:(EJCanvasPattern *)pattern
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	EJTexture *texture = pattern.texture;
	float
		tw = texture.width,
		th = texture.height,
		pw = w,
		ph = h;
		
	if( !(pattern.repeat & kEJCanvasPatternRepeatX) ) {
		pw = MIN(tw - x, w);
	}
	if( !(pattern.repeat & kEJCanvasPatternRepeatY) ) {
		ph = MIN(th - y, h);
	}

	if( pw > 0 && ph > 0 ) { // We may have to skip entirely
		[self setProgram:_sharedGLContext.programPattern];
		[self setTexture:texture];
		
		[self pushTexturedRectX:x y:y w:pw h:ph tx:x/tw ty:y/th tw:pw/tw th:ph/th
			color:color withTransform:transform];
	}
	
	if( pw < w || ph < h ) {
		// Draw clearing rect for the stencil buffer if we didn't fill everything with
		// the pattern image - happens when not repeating in both directions
		[self setProgram:_sharedGLContext.programFlat];
		EJColorRGBA transparentBlack = {.hex = 0x00000000};
		[self pushRectX:x y:y w:w h:h color:transparentBlack withTransform:transform];
	}
}

- (void)pushTexturedRectX:(float)x y:(float)y w:(float)w h:(float)h
	tx:(float)tx ty:(float)ty tw:(float)tw th:(float)th
	color:(EJColorRGBA)color
	withTransform:(CGAffineTransform)transform
{
	if( _vertexBufferIndex >= _vertexBufferSize - 6 ) {
		[self flushBuffers];
	}
	
	// Textures from offscreen WebGL contexts have to be draw upside down.
	// They're actually right-side up in memory, but everything else has
	// flipped y
	if( _currentTexture.drawFlippedY ) {
		ty = 1 - ty;
		th *= -1;
	}
	
	EJVector2 d11 = {x, y};
	EJVector2 d21 = {x+w, y};
	EJVector2 d12 = {x, y+h};
	EJVector2 d22 = {x+w, y+h};
	
	if( !CGAffineTransformIsIdentity(transform) ) {
		d11 = EJVector2ApplyTransform( d11, transform );
		d21 = EJVector2ApplyTransform( d21, transform );
		d12 = EJVector2ApplyTransform( d12, transform );
		d22 = EJVector2ApplyTransform( d22, transform );
	}

	EJVertex *vb = &_vertexBuffer[_vertexBufferIndex];
	vb[0] = (EJVertex) { d11, {tx, ty}, color };	// top left
	vb[1] = (EJVertex) { d21, {tx+tw, ty}, color };	// top right
	vb[2] = (EJVertex) { d12, {tx, ty+th}, color };	// bottom left
		
	vb[3] = (EJVertex) { d21, {tx+tw, ty}, color };	// top right
	vb[4] = (EJVertex) { d12, {tx, ty+th}, color };	// bottom left
	vb[5] = (EJVertex) { d22, {tx+tw, ty+th}, color };	// bottom right
	
	_vertexBufferIndex += 6;
}

- (void)flushBuffers {
	if(_vertexBufferIndex == 0 ) { return; }
	
    
	glDrawArrays(GL_TRIANGLES, 0, _vertexBufferIndex);
    [self setNeedsPresenting:YES];
	_vertexBufferIndex = 0;
}

- (BOOL)imageSmoothingEnabled {
	return (_textureFilter == GL_LINEAR);
}

- (void)setImageSmoothingEnabled:(BOOL)enabled {
	[self setTexture:NULL]; // force rebind for next texture
	_textureFilter = (enabled ? GL_LINEAR : GL_NEAREST);
}

- (void)setGlobalCompositeOperation:(EJCompositeOperation)op {
	[self flushBuffers];
	glBlendFunc( EJCompositeOperationFuncs[op].source, EJCompositeOperationFuncs[op].destination );
	_state->globalCompositeOperation = op;
}

- (EJCompositeOperation)globalCompositeOperation {
	return _state->globalCompositeOperation;
}

- (void)setFont:(EJFontDescriptor *)font {
	[_state->font release];
	_state->font = [font retain];
}

- (EJFontDescriptor *)font {
	return _state->font;
}

- (void)setFillObject:(NSObject<EJFillable> *)fillObject {
	[_state->fillObject release];
	_state->fillObject = [fillObject retain];
}

- (NSObject<EJFillable> *)fillObject {
	return _state->fillObject;
}

- (void)setStrokeObject:(NSObject<EJFillable> *)strokeObject {
	[_state->strokeObject release];
	_state->strokeObject = [strokeObject retain];
}

- (NSObject<EJFillable> *)strokeObject {
	return _state->strokeObject;
}


- (void)save {
	if( _stateIndex == EJ_CANVAS_STATE_STACK_SIZE-1 ) {
		NSLog(@"Warning: EJ_CANVAS_STATE_STACK_SIZE (%d) reached", EJ_CANVAS_STATE_STACK_SIZE);
		return;
	}
	
	stateStack[_stateIndex+1] = stateStack[_stateIndex];
	_stateIndex++;
	_state = &stateStack[_stateIndex];
	[_state->font retain];
	[_state->fillObject retain];
	[_state->strokeObject retain];
	[_state->clipPath retain];
}

- (void)restore {
	if( _stateIndex == 0 ) {	return; }
	
	EJCompositeOperation oldCompositeOp = _state->globalCompositeOperation;
	EJPath *oldClipPath = _state->clipPath;
	
	// Clean up current state
	[_state->font release];
	[_state->fillObject release];
	[_state->strokeObject release];

	if( _state->clipPath && _state->clipPath != stateStack[_stateIndex-1].clipPath ) {
		[self resetClip];
	}
	[_state->clipPath release];
	
	// Load state from stack
	_stateIndex--;
	_state = &stateStack[_stateIndex];
	
	_path.transform = _state->transform;
	
	// Set Composite op, if different
	if( _state->globalCompositeOperation != oldCompositeOp ) {
		self.globalCompositeOperation = _state->globalCompositeOperation;
	}
	
	// Render clip path, if present and different
	if( _state->clipPath && _state->clipPath != oldClipPath ) {
		[self setProgram:_sharedGLContext.programFlat];
		[_state->clipPath drawPolygonsToContext:self fillRule:_state->clipPath.fillRule target:kEJPathPolygonTargetDepth];
	}
}

- (void)rotate:(float)angle {
	_state->transform = CGAffineTransformRotate( _state->transform, angle );
	_path.transform = _state->transform;
}

- (void)translateX:(float)x y:(float)y {
	_state->transform = CGAffineTransformTranslate( _state->transform, x, y );
	_path.transform = _state->transform;
}

- (void)scaleX:(float)x y:(float)y {
	_state->transform = CGAffineTransformScale( _state->transform, x, y );
	_path.transform = _state->transform;
}

- (void)transformM11:(float)m11 m12:(float)m12 m21:(float)m21 m22:(float)m22 dx:(float)dx dy:(float)dy {
	CGAffineTransform t = CGAffineTransformMake( m11, m12, m21, m22, dx, dy );
	_state->transform = CGAffineTransformConcat( t, _state->transform );
	_path.transform = _state->transform;
}

- (void)setTransformM11:(float)m11 m12:(float)m12 m21:(float)m21 m22:(float)m22 dx:(float)dx dy:(float)dy {
	_state->transform = CGAffineTransformMake( m11, m12, m21, m22, dx, dy );
	_path.transform = _state->transform;
}

- (void)drawImage:(EJTexture *)texture sx:(float)sx sy:(float)sy sw:(float)sw sh:(float)sh dx:(float)dx dy:(float)dy dw:(float)dw dh:(float)dh {
	
	float tw = texture.width;
	float th = texture.height;
	
	[self setProgram:_sharedGLContext.programTexture];
	[self setTexture:texture];
	[self pushTexturedRectX:dx y:dy w:dw h:dh tx:sx/tw ty:sy/th tw:sw/tw th:sh/th
		color:EJCanvasBlendWhiteColor(_state) withTransform:_state->transform];
}

- (void)fillRectX:(float)x y:(float)y w:(float)w h:(float)h {
	if( _state->fillObject ) {
		[self pushFilledRectX:x y:y w:w h:h fillable:_state->fillObject
			color:EJCanvasBlendWhiteColor(_state) withTransform:_state->transform];
	}
	else {
		[self setProgram:_sharedGLContext.programFlat];
		
		EJColorRGBA cc = EJCanvasBlendFillColor(_state);
		[self pushRectX:x y:y w:w h:h
			color:cc withTransform:_state->transform];
	}
}

- (void)strokeRectX:(float)x y:(float)y w:(float)w h:(float)h {
	// strokeRect should not affect the current path, so we create
	// a new, tempPath instead.
	EJPath *tempPath = [EJPath new];
	tempPath.transform = _state->transform;
	
	[tempPath moveToX:x y:y];
	[tempPath lineToX:x+w y:y];
	[tempPath lineToX:x+w y:y+h];
	[tempPath lineToX:x y:y+h];
	[tempPath close];
	
	[self setProgram:_sharedGLContext.programFlat];
	[tempPath drawLinesToContext:self];
	[tempPath release];
}

- (void)clearRectX:(float)x y:(float)y w:(float)w h:(float)h {
	[self setProgram:_sharedGLContext.programFlat];
	
	EJCompositeOperation oldOp = _state->globalCompositeOperation;
	self.globalCompositeOperation = kEJCompositeOperationDestinationOut;
	
	static EJColorRGBA white = {.hex = 0xffffffff};
	[self pushRectX:x y:y w:w h:h color:white withTransform:_state->transform];
	
	self.globalCompositeOperation = oldOp;
}

- (EJImageData*)getImageDataSx:(short)sx sy:(short)sy sw:(short)sw sh:(short)sh {
	
	[self flushBuffers];
	
	if( _upsideDown ) {
		sy = _bufferHeight-sy-sh;
	}
	
	NSMutableData *pixels = [NSMutableData dataWithLength:sw * sh * 4 * sizeof(GLubyte)];
	glReadPixels(sx, sy, sw, sh, GL_RGBA, GL_UNSIGNED_BYTE, pixels.mutableBytes);
	
	if( _upsideDown ) {
		[EJTexture flipPixelsY:pixels.mutableBytes bytesPerRow:sw*4 rows:sh];
	}
	
	return [[[EJImageData alloc] initWithWidth:sw height:sh pixels:pixels] autorelease];
}

- (void)putImageData:(EJImageData*)imageData dx:(float)dx dy:(float)dy {
	EJTexture *texture = imageData.texture;
	[self setProgram:_sharedGLContext.programTexture];
	[self setTexture:texture];
	
	short tw = texture.width;
	short th = texture.height;
	
	static EJColorRGBA white = {.hex = 0xffffffff};
	
	EJCompositeOperation oldOp = _state->globalCompositeOperation;
	self.globalCompositeOperation = kEJCompositeOperationCopy;
	
	[self pushTexturedRectX:dx y:dy w:tw h:th tx:0 ty:0 tw:1 th:1 color:white withTransform:CGAffineTransformIdentity];
	[self flushBuffers];
	
	self.globalCompositeOperation = oldOp;
}

- (void)beginPath {
	[_path reset];
}

- (void)closePath {
	[_path close];
}

- (void)fill:(EJPathFillRule)fillRule {
	[self setProgram:_sharedGLContext.programFlat];
	[_path drawPolygonsToContext:self fillRule:fillRule target:kEJPathPolygonTargetColor];
}

- (void)stroke {
	[self setProgram:_sharedGLContext.programFlat];
	[_path drawLinesToContext:self];
}

- (void)moveToX:(float)x y:(float)y {
	[_path moveToX:x y:y];
}

- (void)lineToX:(float)x y:(float)y {
	[_path lineToX:x y:y];
}

- (void)bezierCurveToCpx1:(float)cpx1 cpy1:(float)cpy1 cpx2:(float)cpx2 cpy2:(float)cpy2 x:(float)x y:(float)y {
	float scale = CGAffineTransformGetScale( _state->transform );
	[_path bezierCurveToCpx1:cpx1 cpy1:cpy1 cpx2:cpx2 cpy2:cpy2 x:x y:y scale:scale];
}

- (void)quadraticCurveToCpx:(float)cpx cpy:(float)cpy x:(float)x y:(float)y {
	float scale = CGAffineTransformGetScale( _state->transform );
	[_path quadraticCurveToCpx:cpx cpy:cpy x:x y:y scale:scale];
}

- (void)rectX:(float)x y:(float)y w:(float)w h:(float)h {
	[_path moveToX:x y:y];
	[_path lineToX:x+w y:y];
	[_path lineToX:x+w y:y+h];
	[_path lineToX:x y:y+h];
	[_path close];
}

- (void)arcToX1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 radius:(float)radius {
	[_path arcToX1:x1 y1:y1 x2:x2 y2:y2 radius:radius];
}

- (void)arcX:(float)x y:(float)y radius:(float)radius
	startAngle:(float)startAngle endAngle:(float)endAngle
	antiClockwise:(BOOL)antiClockwise
{
	[_path arcX:x y:y radius:radius startAngle:startAngle endAngle:endAngle antiClockwise:antiClockwise];
}

- (void)fillText:(NSString *)text x:(float)x y:(float)y {
	float scale = CGAffineTransformGetScale( _state->transform );
	EJFont *font = [[EJFontCache instance] fontWithDescriptor:_state->font contentScale:scale];
	
	[self setProgram:_sharedGLContext.programAlphaTexture];
	[font drawString:text toContext:self x:x y:y];
}

- (void)strokeText:(NSString *)text x:(float)x y:(float)y {
	float scale = CGAffineTransformGetScale( _state->transform );
	EJFont *font = [[EJFontCache instance] outlineFontWithDescriptor:_state->font lineWidth:_state->lineWidth contentScale:scale];
	
	[self setProgram:_sharedGLContext.programAlphaTexture];
	[font drawString:text toContext:self x:x y:y];
}

- (EJTextMetrics)measureText:(NSString *)text {
	float scale = CGAffineTransformGetScale( _state->transform );
	EJFont *font = [[EJFontCache instance] fontWithDescriptor:_state->font contentScale:scale];
	return [font measureString:text forContext:self];
}

- (void)clip:(EJPathFillRule)fillRule {
	[self flushBuffers];
	[_state->clipPath release];
	_state->clipPath = nil;
	
	_state->clipPath = _path.copy;
	[self setProgram:_sharedGLContext.programFlat];
	[_state->clipPath drawPolygonsToContext:self fillRule:fillRule target:kEJPathPolygonTargetDepth];
}

- (void)resetClip {
	if( _state->clipPath ) {
		[self flushBuffers];
		[_state->clipPath release];
		_state->clipPath = nil;
		
		glDepthMask(GL_TRUE);
		glClear(GL_DEPTH_BUFFER_BIT);
		glDepthMask(GL_FALSE);
		glDepthFunc(GL_ALWAYS);
	}
}

@end
