#import "EJNonRetainingProxy.h"

@implementation EJNonRetainingProxy
+ (EJNonRetainingProxy *)proxyWithTarget:(id)target {
    EJNonRetainingProxy *proxy = [[self alloc] init];
    [proxy setTarget:target];
    [proxy autorelease];
    return proxy;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
	return [_target methodSignatureForSelector:sel];
}

- (BOOL)respondsToSelector:(SEL)sel {
    return [_target respondsToSelector:sel] || [super respondsToSelector:sel];
}

- (id)forwardingTargetForSelector:(SEL)sel {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if( [_target respondsToSelector:invocation.selector] ) {
        [invocation invokeWithTarget:_target];
	}
    else {
		[super forwardInvocation:invocation];
	}
}

- (void)dealloc {
    
    [_target release];
    _target = nil;
    [super dealloc];
}

@end
