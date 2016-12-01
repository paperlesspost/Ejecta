#import "EJTextureStorage.h"

@interface EJTextureStorage ()

@property (nonatomic, readwrite) GLuint textureId;
@property (nonatomic, readwrite) BOOL immutable;
@property (nonatomic, readwrite) NSTimeInterval lastBound;

@end

@implementation EJTextureStorage


- (instancetype)init {
	if( self = [super init] ) {
		glGenTextures(1, &_textureId);
        [self setImmutable:NO];
	}
	return self;
}

- (instancetype)initImmutable {
	if( self = [super init] ) {
		glGenTextures(1, &_textureId);
        [self setImmutable:NO];
	}
	return self;
}

- (void)dealloc {
	if(_textureId) {
		glDeleteTextures(1, &_textureId);
	}
	[super dealloc];
}

- (void)bindToTarget:(GLenum)target withParams:(EJTextureParam *)newParams {
	glBindTexture(target, _textureId);
	
	// Check if we have to set a param
	if(params[kEJTextureParamMinFilter] != newParams[kEJTextureParamMinFilter]) {
		params[kEJTextureParamMinFilter] = newParams[kEJTextureParamMinFilter];
		glTexParameteri(target, GL_TEXTURE_MIN_FILTER, params[kEJTextureParamMinFilter]);
	}
	if(params[kEJTextureParamMagFilter] != newParams[kEJTextureParamMagFilter]) {
		params[kEJTextureParamMagFilter] = newParams[kEJTextureParamMagFilter];
		glTexParameteri(target, GL_TEXTURE_MAG_FILTER, params[kEJTextureParamMagFilter]);
	}
	if(params[kEJTextureParamWrapS] != newParams[kEJTextureParamWrapS]) {
		params[kEJTextureParamWrapS] = newParams[kEJTextureParamWrapS];
		glTexParameteri(target, GL_TEXTURE_WRAP_S, params[kEJTextureParamWrapS]);
	}
	if(params[kEJTextureParamWrapT] != newParams[kEJTextureParamWrapT]) {
		params[kEJTextureParamWrapT] = newParams[kEJTextureParamWrapT];
		glTexParameteri(target, GL_TEXTURE_WRAP_T, params[kEJTextureParamWrapT]);
	}
	
	_lastBound = NSProcessInfo.processInfo.systemUptime;
}

@end

