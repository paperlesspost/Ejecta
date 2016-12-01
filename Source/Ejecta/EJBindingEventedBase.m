#import "EJBindingEventedBase.h"
#import "EJJavaScriptView.h"

@implementation EJBindingEventedBase

- (instancetype)initWithContext:(JSContextRef)ctxp argc:(size_t)argc argv:(const JSValueRef [])argv {
    
    self = [super initWithContext:ctxp
                             argc:argc
                             argv:argv];
    
    if (self) {
        
        _eventListeners = [[NSMutableDictionary alloc] initWithCapacity:0];
        _onCallbacks = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    
    return self;
}

- (void)dealloc {
	JSContextRef ctx = scriptView.jsGlobalContext;
	
	// Unprotect all event callbacks
	for( NSString *type	in _eventListeners) {
		NSArray *listeners = _eventListeners[type];
		for( NSValue *callbackValue in listeners ) {
			JSValueUnprotectSafe(ctx, callbackValue.pointerValue);
		}
	}
	[_eventListeners release];
    _eventListeners = nil;
	
	// Unprotect all event callbacks
	for( NSString *type in _onCallbacks ) {
		NSValue *callbackValue = _onCallbacks[type];
		JSValueUnprotectSafe(ctx, callbackValue.pointerValue);
	}
	[_onCallbacks release];
    _onCallbacks = nil;
	
	[super dealloc];
}

- (JSValueRef)getCallbackWithType:(NSString *)type ctx:(JSContextRef)ctx {
	NSValue *listener = _onCallbacks[type];
	return listener ? listener.pointerValue : JSValueMakeNull(ctx);
}

- (void)setCallbackWithType:(NSString *)type ctx:(JSContextRef)ctx callback:(JSValueRef)callbackValue {
	// Remove old event listener?
	JSValueRef oldCallback = [self getCallbackWithType:type ctx:ctx];
	if( oldCallback && !JSValueIsNull(ctx, oldCallback) ) {
		JSValueUnprotectSafe(ctx, oldCallback);
		[_onCallbacks removeObjectForKey:type];
	}
	
	JSObjectRef callback = JSValueToObject(ctx, callbackValue, NULL);
	if( callback && JSObjectIsFunction(ctx, callback) ) {
		JSValueProtect(ctx, callback);
		_onCallbacks[type] = [NSValue valueWithPointer:callback];
	}
}

EJ_BIND_FUNCTION(addEventListener, ctx, argc, argv) {
	if( argc < 2 ) { return NULL; }
	
	NSString *type = JSValueToNSString( ctx, argv[0] );
	JSObjectRef callback = JSValueToObject(ctx, argv[1], NULL);
	JSValueProtect(ctx, callback);
	NSValue *callbackValue = [NSValue valueWithPointer:callback];
	
	NSMutableArray *listeners = NULL;
	if( (listeners = _eventListeners[type]) ) {
		[listeners addObject:callbackValue];
	}
	else {
		_eventListeners[type] = [NSMutableArray arrayWithObject:callbackValue];
	}
	return NULL;
}

EJ_BIND_FUNCTION(removeEventListener, ctx, argc, argv) {
	if( argc < 2 ) { return NULL; }
	
	NSString *type = JSValueToNSString( ctx, argv[0] );

	NSMutableArray *listeners = NULL;
	if( (listeners = _eventListeners[type]) ) {
		JSObjectRef callback = JSValueToObject(ctx, argv[1], NULL);
		for( int i = 0; i < listeners.count; i++ ) {
			if( JSValueIsStrictEqual(ctx, callback, [listeners[i] pointerValue]) ) {
				JSValueUnprotect(ctx, [listeners[i] pointerValue]);
				[listeners removeObjectAtIndex:i];
				return NULL;
			}
		}
	}
	return NULL;
}

- (void)triggerEvent:(NSString *)type argc:(int)argc argv:(JSValueRef[])argv {
	NSArray *listeners = _eventListeners[type];
	if( listeners ) {
		for( NSValue *callback in listeners ) {
			[scriptView invokeCallback:callback.pointerValue thisObject:jsObject argc:argc argv:argv];
		}
	}
	
	NSValue *callback = _onCallbacks[type];
	if( callback ) {
		[scriptView invokeCallback:callback.pointerValue thisObject:jsObject argc:argc argv:argv];
	}
}

- (void)triggerEvent:(NSString *)type {
	[self triggerEvent:type properties:nil];
}

- (void)triggerEvent:(NSString *)type properties:(JSEventProperty[])properties {
	NSArray *listeners = _eventListeners[type];
	NSValue *onCallback = _onCallbacks[type];
	
	// Check if we have any listeners before constructing the event object
	if( !(listeners && listeners.count) && !onCallback ) {
		return;
	}
	
	// Build the event object
	JSObjectRef jsEvent = [EJBindingEvent createJSObjectWithContext:scriptView.jsGlobalContext
		scriptView:scriptView type:type target:jsObject];
	
	// Attach all additional properties, if any
	if( properties ) {
		for( int i = 0; properties[i].name; i++ ) {
			JSStringRef name = JSStringCreateWithUTF8CString(properties[i].name);
			JSValueRef value = properties[i].value;
			JSObjectSetProperty(scriptView.jsGlobalContext, jsEvent, name, value, kJSPropertyAttributeReadOnly, NULL);
			JSStringRelease(name);
		}
	}
	
	
	JSValueRef params[] = { jsEvent };
	if( listeners ) {
		for( NSValue *callback in listeners ) {
			[scriptView invokeCallback:callback.pointerValue thisObject:jsObject argc:1 argv:params];
		}
	}
	
	if( onCallback ) {
		[scriptView invokeCallback:onCallback.pointerValue thisObject:jsObject argc:1 argv:params];
	}
}

@end


@implementation EJBindingEvent

+ (JSObjectRef)createJSObjectWithContext:(JSContextRef)ctx
	scriptView:(EJJavaScriptView *)scriptView
	type:(NSString *)type
	target:(JSObjectRef)target
{
	EJBindingEvent *event = [[self alloc] initWithContext:ctx argc:0 argv:NULL];
	JSValueProtect(ctx, target);
    
    [event setJsTarget:target];
    [event setType:type];
    
	JSValueRef jsTimestamp = JSValueMakeNumber(ctx, NSProcessInfo.processInfo.systemUptime * 1000.0);
	JSValueProtect(ctx, jsTimestamp);
    
    [event setJsTimestamp:jsTimestamp];
    
	JSObjectRef jsEvent = [self createJSObjectWithContext:ctx scriptView:scriptView instance:event];
	[event release];
	return jsEvent;
}

- (void)dealloc {
	[_type release];
    _type = nil;
    
	JSValueUnprotectSafe(scriptView.jsGlobalContext, _jsTarget);
	JSValueUnprotectSafe(scriptView.jsGlobalContext, _jsTimestamp);
	
	[super dealloc];
}

EJ_BIND_GET(target, ctx) { return _jsTarget; }
EJ_BIND_GET(currentTarget, ctx) { return _jsTarget; }
EJ_BIND_GET(type, ctx) { return NSStringToJSValue(ctx, _type); }
EJ_BIND_GET(timestamp, ctx) { return _jsTimestamp; }

EJ_BIND_FUNCTION(preventDefault, ctx, argc, argv){ return NULL; }
EJ_BIND_FUNCTION(stopPropagation, ctx, argc, argv){ return NULL; }

@end
