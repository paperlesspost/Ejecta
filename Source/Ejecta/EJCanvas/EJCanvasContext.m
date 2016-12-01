#import "EJCanvasContext.h"

@implementation EJCanvasContext

- (void)create {}
- (void)flushBuffers {}
- (void)prepare {}

- (void)dealloc {
    
    [_glContext release];
    _glContext = nil;
    
    [super dealloc];
}

@end
