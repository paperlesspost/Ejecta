// The base class each Canvas Context (2D or WebGL) is derived from, so it can
// be hosted by a Canvas.

#import <Foundation/Foundation.h>

@class EAGLContext;

@interface EJCanvasContext : NSObject

- (void)create;
- (void)flushBuffers;
- (void)prepare;

@property (nonatomic, assign) BOOL preserveDrawingBuffer;
@property (nonatomic, assign) BOOL needsPresenting;
@property (nonatomic, assign) BOOL msaaEnabled;
@property (nonatomic, assign) GLint msaaSamples;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, retain) EAGLContext *glContext;

@end
