#import "EJSharedOpenGLContext.h"
#import "EJCanvas/2D/EJCanvasShaders.h"


@implementation EJSharedOpenGLContext

+ (instancetype)instance {
    
    static EJSharedOpenGLContext *sharedInstance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


- (instancetype)init {
    self = [super init];
    
    if (self) {
        
        _glContext2D = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _glSharegroup = _glContext2D.sharegroup;
    }
    
    return self;
}


- (void)dealloc {
    
	[_programFlat release];
    _programFlat = nil;
	
    [_programTexture release];
    _programTexture = nil;
	
    [_programAlphaTexture release];
    _programAlphaTexture = nil;
	
    [_programPattern release];
    _programPattern = nil;
	
    [_programRadialGradient release];
    _programRadialGradient = nil;
	
    [_glContext2D release];
    _glContext2D = nil;
	
    [_vertexBuffer release];
    _vertexBuffer = nil;
    
    [_glSharegroup release];
    _glSharegroup = nil;
    
	[EAGLContext setCurrentContext:nil];
	[super dealloc];
}

- (NSMutableData *)vertexBuffer {
	if(!_vertexBuffer) {
		_vertexBuffer = [[NSMutableData alloc] initWithLength:EJ_OPENGL_VERTEX_BUFFER_SIZE];
	}
	return _vertexBuffer;
}


//
//#define EJ_GL_PROGRAM_GETTER(TYPE, NAME) \
//	- (TYPE *)program##NAME { \
//		if( !program##NAME ) { \
//			program##NAME = [[TYPE alloc] initWithVertexShader:EJShaderVertex fragmentShader:EJShader##NAME]; \
//		} \
//	return program##NAME; \
//	}
//
//EJ_GL_PROGRAM_GETTER(EJGLProgram2D, Flat);
//EJ_GL_PROGRAM_GETTER(EJGLProgram2D, Texture);
//EJ_GL_PROGRAM_GETTER(EJGLProgram2D, AlphaTexture);
//EJ_GL_PROGRAM_GETTER(EJGLProgram2D, Pattern);
//EJ_GL_PROGRAM_GETTER(EJGLProgram2DRadialGradient, RadialGradient);
//
//#undef EJ_GL_PROGRAM_GETTER

@end
