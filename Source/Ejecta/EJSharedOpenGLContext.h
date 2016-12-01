// The Shared OpenGL Context provides compiled shaders and the main vertex
// buffer to all Canvas2D Contexts. With this, an offscreen Canvas2D does not
// have to recompile its own shaders or allocate its own buffer again. All
// Canvas2D contexts can also share the same underlying EAGLContext, which
// makes switching between canvases pretty fast.

// In contrast, WebGL Contexts do not use this class. Each WebGL Context will
// create its own EAGLContext so it can manage all the OpenGL state itself.

#import <Foundation/Foundation.h>
#import "EJGLProgram2D.h"
#import "EJGLProgram2DRadialGradient.h"

#define EJ_OPENGL_VERTEX_BUFFER_SIZE (32 * 1024) // 32kb

@interface EJSharedOpenGLContext : NSObject

+ (EJSharedOpenGLContext *)instance;

@property (nonatomic, retain) EJGLProgram2D *programFlat;
@property (nonatomic, retain) EJGLProgram2D *programTexture;
@property (nonatomic, retain) EJGLProgram2D *programAlphaTexture;
@property (nonatomic, retain) EJGLProgram2D *programPattern;
@property (nonatomic, retain) EJGLProgram2DRadialGradient *programRadialGradient;

@property (nonatomic, retain) EAGLContext *glContext2D;
@property (nonatomic, retain) EAGLSharegroup *glSharegroup;
@property (nonatomic, retain) NSMutableData *vertexBuffer;

@end
