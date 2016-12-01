#import "EJBindingBase.h"
#import "EJClassLoader.h"
#import <objc/runtime.h>


@implementation EJBindingBase

- (instancetype)initWithContext:(JSContextRef)ctxp argc:(size_t)argc argv:(const JSValueRef [])argv {
	if( self = [super init] ) {
	}
	return self;
}

#pragma mark -
#pragma mark - Setter / Getter

- (void)setScriptView:(EJJavaScriptView *)newValue {
    
    if (scriptView != newValue) {
        if (newValue) {
            [scriptView release];
            scriptView = [newValue retain];
        }
    }
}

- (EJJavaScriptView *)scriptView {
    
    if (!scriptView) {
        scriptView = [[EJJavaScriptView alloc] initWithFrame:CGRectZero];
    }
    
    return scriptView;
}

#pragma mark -


- (void)createWithJSObject:(JSObjectRef)obj scriptView:(EJJavaScriptView *)view {
	_jsObject = obj;
    [self setScriptView:view];
}

- (void)prepareGarbageCollection {
	// Called in EJBindingBaseFinalize before sending 'release'.
	// Cancel loading callbacks and the like here.
}

+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	instance:(EJBindingBase *)instance
{
	// Create JSObject with the JSClass for this ObjC-Class
	EJLoadedJSClass *class = [scriptView.classLoader getJSClass:self];
	JSObjectRef obj = JSObjectMake( ctx, class.jsClass, NULL );
	
	// Attach all constant values to the object. Doing this on instantiation is a bit slower
	// than just having the callbacks in the StaticProperties, but it makes access to them
	// much faster because we never have to leave JS land. This is especially important for
	// the CanvasContextWebGL which has A LOT of const values.
	NSDictionary *constantValues = class.constantValues;
	
	for( NSString* key in constantValues ) {
		NSObject *value = constantValues[key];
		JSValueRef jsValue = [value isKindOfClass:NSString.class]
			? NSStringToJSValue(ctx, (NSString *)value)
			: JSValueMakeNumber(ctx, ((NSNumber *)value).doubleValue);
			
		JSStringRef name = JSStringCreateWithCFString((CFStringRef)key);
		JSObjectSetProperty(
			ctx, obj, name, jsValue,
			kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontDelete, NULL
		);
		JSStringRelease(name);
	}
	
	// The JSObject retains the instance; it will be released by EJBindingBaseFinalize
	JSObjectSetPrivate( obj, (void *)[instance retain] );
	[instance createWithJSObject:obj scriptView:scriptView];
	
	return obj;
}

void EJBindingBaseFinalize(JSObjectRef object) {
	EJBindingBase *instance = (EJBindingBase *)JSObjectGetPrivate(object);
	[instance prepareGarbageCollection];
	[instance release];
}


@end
