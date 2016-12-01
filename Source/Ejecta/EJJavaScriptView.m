#import "EJJavaScriptView.h"
#import "EJTimer.h"
#import "EJBindingBase.h"
#import "EJClassLoader.h"
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>


// Block function callbacks
JSValueRef EJBlockFunctionCallAsFunction(
	JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argc, const JSValueRef argv[], JSValueRef* exception
) {
	JSValueRef (^block)(JSContextRef ctx, size_t argc, const JSValueRef argv[]) = JSObjectGetPrivate(function);
	JSValueRef ret = block(ctx, argc, argv);
	return ret ? ret : JSValueMakeUndefined(ctx);
}

void EJBlockFunctionFinalize(JSObjectRef object) {
	JSValueRef (^block)(JSContextRef ctx, size_t argc, const JSValueRef argv[]) = JSObjectGetPrivate(object);
	[block release];
}


#pragma mark -
#pragma mark Ejecta view Implementation

@implementation EJJavaScriptView


- (instancetype)initWithFrame:(CGRect)frame {
	return [self initWithFrame:frame appFolder:EJECTA_DEFAULT_APP_FOLDER];
}

- (instancetype)initWithFrame:(CGRect)frame appFolder:(NSString *)folder {
    
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setupWithAppFolder:folder];
    }
    
    return self;
}

-(void)awakeFromNib {
    [self setupWithAppFolder:EJECTA_DEFAULT_APP_FOLDER];
    [super awakeFromNib];
}

-(void)setupWithAppFolder:(NSString*)folder {
    _oldSize = self.frame.size;
    
    [self setAppFolder:folder];
    [self setPaused:NO];
    [self setExitOnMenuPress:YES];

    // CADisplayLink (and NSNotificationCenter?) retains it's target, but this
    // is causing a retain loop - we can't completely release the scriptView
    // from the outside.
    // So we're using a "weak proxy" that doesn't retain the scriptView; we can
    // then just invalidate the CADisplayLink in our dealloc and be done with it.
    _proxy = [EJNonRetainingProxy proxyWithTarget:self];
    [self setPauseOnEnterBackground:YES];

    // Limit all background operations (image & sound loading) to one thread
    _backgroundQueue = [[NSOperationQueue alloc] init];
    _backgroundQueue.name = @"com.ejecta.EJJavaScriptView.queue";
    _backgroundQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;

    _timers = [[EJTimerCollection alloc] initWithScriptView:self];
    
    _displayLink = [CADisplayLink displayLinkWithTarget:_proxy selector:@selector(run:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    // Create the global JS context in its own group, so it can be released properly
    _jsGlobalContext = JSGlobalContextCreateInGroup(NULL, NULL);
    jsUndefined = JSValueMakeUndefined(_jsGlobalContext);
    JSValueProtect(_jsGlobalContext, jsUndefined);

    // Attach all native class constructors to 'Ejecta'
    _classLoader = [[EJClassLoader alloc] initWithScriptView:self name:@"Ejecta"];
	
    
    // Retain the caches here, so even if they're currently unused in JavaScript,
    // they will persist until the last scriptView is released
    [self setTextureCache:[EJSharedTextureCache instance]];
    [self setOpenALManager:[EJSharedOpenALManager instance]];
    [self setOpenGLContext:[EJSharedOpenGLContext instance]];
    
    
    // Create the OpenGL context for Canvas2D
    [self setGlCurrentContext:_openGLContext.glContext2D];
    [EAGLContext setCurrentContext:_glCurrentContext];

    //Load the Ejecta.js from this bundle, rather than the main bundle
    NSString *path = [NSString stringWithFormat:@"%@/%@", [NSBundle bundleForClass:[EJJavaScriptView class]].resourcePath, @"Ejecta.js"];;
    
    NSString *script = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding error:NULL];
    
    [self evaluateScript:script sourceURL:path];
}

- (void)dealloc {
	// Wait until all background operations are finished. If we would just release the
	// backgroundQueue it would cancel running operations (such as texture loading) and
	// could keep some dependencies dangling
	[_backgroundQueue waitUntilAllOperationsAreFinished];
	[_backgroundQueue release];
    _backgroundQueue = nil;
    
    
	// Careful, order is important! The JS context has to be released first; it will release
	// the canvas objects which still need the openGLContext to be present, to release
	// textures etc.
	// Set 'jsGlobalContext' to null before releasing it, because it may be referenced by
	// bound objects' dealloc method
	JSValueUnprotect(_jsGlobalContext, jsUndefined);
	JSGlobalContextRef ctxref = _jsGlobalContext;
	_jsGlobalContext = NULL;
	JSGlobalContextRelease(ctxref);

	// Remove from notification center
    [self setPauseOnEnterBackground:NO];

	// Remove from display link
	[_displayLink invalidate];
	[_displayLink release];
    _displayLink = nil;
    
	[_textureCache release];
    _textureCache = nil;
    
	[_openALManager release];
    _openALManager = nil;
    
    [_classLoader release];
    _classLoader = nil;
    
	if(_jsBlockFunctionClass) {
		JSClassRelease(_jsBlockFunctionClass);
	}
	[_screenRenderingContext finish];
	[_screenRenderingContext release];
	[_currentRenderingContext release];

	[_openGLContext release];
    _openGLContext = nil;
    
    [_appFolder release];
    _appFolder = nil;
    
    _windowEventsDelegate = nil;
    _touchDelegate = nil;
    _deviceMotionDelegate = nil;
    _screenRenderingContext = nil;
    
    [_glCurrentContext release];
    _glCurrentContext = nil;
    
    [_currentRenderingContext release];
    _currentRenderingContext = nil;
    
    _proxy = nil;
    
    
    
    [super dealloc];
}

- (BOOL)pauseOnEnterBackground {
    return pauseOnEnterBackground;
}

- (void)setPauseOnEnterBackground:(BOOL)pauses {
	NSArray *pauseN = @[
		UIApplicationWillResignActiveNotification,
		UIApplicationDidEnterBackgroundNotification,
		UIApplicationWillTerminateNotification
	];
	NSArray *resumeN = @[
		UIApplicationWillEnterForegroundNotification,
		UIApplicationDidBecomeActiveNotification
	];

	if (pauses) {
		[self observeKeyPaths:pauseN selector:@selector(pause)];
		[self observeKeyPaths:resumeN selector:@selector(resume)];
	}
	else {
		[self removeObserverForKeyPaths:pauseN];
		[self removeObserverForKeyPaths:resumeN];
	}
    
    [self setPauseOnEnterBackground:pauses];
}

- (void)removeObserverForKeyPaths:(NSArray*)keyPaths {
	NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
	for( NSString *name in keyPaths ) {
        if (_proxy) {
         
            [nc removeObserver:_proxy name:name object:nil];
        }
	}
}

- (void)observeKeyPaths:(NSArray*)keyPaths selector:(SEL)selector {
	NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
	for( NSString *name in keyPaths ) {
        
        if (_proxy) {
         
            [nc addObserver:_proxy selector:selector name:name object:nil];
        }
	}
}

- (void)layoutSubviews {
	[super layoutSubviews];

	// Check if we did resize
	CGSize newSize = self.bounds.size;
	if( newSize.width != _oldSize.width || newSize.height != _oldSize.height ) {
		[_windowEventsDelegate resize];
		_oldSize = newSize;
	}
}


#pragma mark -
#pragma mark Script loading and execution

- (NSString *)pathForResource:(NSString *)path {
	char specialPathName[16];
	if( sscanf(path.UTF8String, "${%15[^}]", specialPathName) ) {
		NSString *searchPath = nil;
		if( strcmp(specialPathName, "Documents") == 0 ) {
			searchPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
		}
		else if( strcmp(specialPathName, "Library") == 0 ) {
			searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
		}
		else if( strcmp(specialPathName, "Caches") == 0 ) {
			searchPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
		}
		else if( strcmp(specialPathName, "tmp") == 0 ) {
			searchPath = NSTemporaryDirectory();
		}

		if( searchPath ) {
			return [searchPath stringByAppendingPathComponent:[path substringFromIndex:strlen(specialPathName)+3]];
		}
	}

	return [NSString stringWithFormat:@"%@/%@%@", NSBundle.mainBundle.resourcePath, _appFolder, path];
}

- (void)loadScriptAtPath:(NSString *)path {
	NSString *script = [NSString stringWithContentsOfFile:[self pathForResource:path]
		encoding:NSUTF8StringEncoding error:NULL];

	[self evaluateScript:script sourceURL:path];
}

- (JSValueRef)evaluateScript:(NSString *)script {
	return [self evaluateScript:script sourceURL:NULL];
}

- (JSValueRef)evaluateScript:(NSString *)script sourceURL:(NSString *)sourceURL {
	if(script.length == 0) {
		NSLog(
			@"Error: The script %@ does not exist or appears to be empty.",
			sourceURL ? sourceURL : @"[Anonymous]"
		);
		return NULL;
	}

	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
	JSStringRef sourceURLJS = NULL;
    
	if( sourceURL.length > 0 ) {
		sourceURLJS = JSStringCreateWithCFString((CFStringRef)sourceURL);
	}

	JSValueRef exception = NULL;
	JSValueRef ret = JSEvaluateScript(_jsGlobalContext, scriptJS, NULL, sourceURLJS, 0, &exception );
	[self logException:exception ctx:_jsGlobalContext];

	JSStringRelease( scriptJS );

	if ( sourceURLJS ) {
		JSStringRelease( sourceURLJS );
	}
	return ret;
}

- (JSValueRef)loadModuleWithId:(NSString *)moduleId module:(JSValueRef)module exports:(JSValueRef)exports {
	NSString *path = [moduleId stringByAppendingString:@".js"];
	NSString *script = [NSString stringWithContentsOfFile:[self pathForResource:path]
		encoding:NSUTF8StringEncoding error:NULL];

	if( !script ) {
		NSLog(@"Error: Can't Find Module %@", moduleId );
		return NULL;
	}

	NSLog(@"Loading Module: %@", moduleId );

	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
	JSStringRef pathJS = JSStringCreateWithCFString((CFStringRef)path);
	JSStringRef parameterNames[] = {
		JSStringCreateWithUTF8CString("module"),
		JSStringCreateWithUTF8CString("exports"),
	};

	JSValueRef exception = NULL;
	JSObjectRef func = JSObjectMakeFunction(_jsGlobalContext, NULL, 2, parameterNames, scriptJS, pathJS, 0, &exception );

	JSStringRelease( scriptJS );
	JSStringRelease( pathJS );
	JSStringRelease(parameterNames[0]);
	JSStringRelease(parameterNames[1]);

	if( exception ) {
		[self logException:exception ctx:_jsGlobalContext];
		return NULL;
	}

	JSValueRef params[] = { module, exports };
	return [self invokeCallback:func thisObject:NULL argc:2 argv:params];
}

- (JSValueRef)invokeCallback:(JSObjectRef)callback thisObject:(JSObjectRef)thisObject argc:(size_t)argc argv:(const JSValueRef [])argv {
	if( !_jsGlobalContext ) { return NULL; } // May already have been released

	JSValueRef exception = NULL;
	JSValueRef result = JSObjectCallAsFunction(_jsGlobalContext, callback, thisObject, argc, argv, &exception );
	[self logException:exception ctx:_jsGlobalContext];
	return result;
}

- (void)logException:(JSValueRef)exception ctx:(JSContextRef)ctxp {
	if( !exception ) { return; }

	JSStringRef jsLinePropertyName = JSStringCreateWithUTF8CString("line");
	JSStringRef jsFilePropertyName = JSStringCreateWithUTF8CString("sourceURL");
    JSStringRef jsStackPropertyName = JSStringCreateWithUTF8CString("stack");

	JSObjectRef exObject = JSValueToObject( ctxp, exception, NULL );
	JSValueRef line = JSObjectGetProperty( ctxp, exObject, jsLinePropertyName, NULL );
	JSValueRef file = JSObjectGetProperty( ctxp, exObject, jsFilePropertyName, NULL );
    JSValueRef stack = JSObjectGetProperty( ctxp, exObject, jsStackPropertyName, NULL );

	NSLog(
		@"%@ at line %@ in %@, stack: %@",
		JSValueToNSString( ctxp, exception ),
		JSValueToNSString( ctxp, line ),
		JSValueToNSString( ctxp, file ),
          JSValueToNSString( ctxp, stack )
	);

	JSStringRelease( jsLinePropertyName );
	JSStringRelease( jsFilePropertyName );
    JSStringRelease( jsStackPropertyName );
}

- (JSValueRef)jsValueForPath:(NSString *)objectPath {
	JSValueRef obj = JSContextGetGlobalObject(_jsGlobalContext);

	NSArray *pathComponents = [objectPath componentsSeparatedByString:@"."];
	for( NSString *p in pathComponents) {
		JSStringRef name = JSStringCreateWithCFString((CFStringRef)p);
        JSValueRef exception = NULL;
		obj = JSObjectGetProperty(_jsGlobalContext, (JSObjectRef)obj, name, &exception);
        JSStringRelease(name);
        if( exception != NULL) {
            NSLog(@"Exception caught getting value component \"%@\" in \"%@\"", p, objectPath);
            [self logException:exception ctx:_jsGlobalContext];
            return NULL;
        }else if(obj==jsUndefined){
            NSLog(@"Undefined value component \"%@\" in \"%@\"", p, objectPath);
            return NULL;
        }

		if( !obj ) { break; }
	}
	return obj;
}

- (JSObjectRef)createFunctionWithBlock:(JSValueRef (^)(JSContextRef ctx, size_t argc, const JSValueRef argv[]))block {
	if(!_jsBlockFunctionClass) {
		JSClassDefinition blockFunctionClassDef = kJSClassDefinitionEmpty;
		blockFunctionClassDef.callAsFunction = EJBlockFunctionCallAsFunction;
		blockFunctionClassDef.finalize = EJBlockFunctionFinalize;
		_jsBlockFunctionClass = JSClassCreate(&blockFunctionClassDef);
	}
	
	return JSObjectMake(_jsGlobalContext, _jsBlockFunctionClass, (void *)Block_copy(block) );
}


#pragma mark -
#pragma mark Run loop

- (void)run:(CADisplayLink *)sender {
	if(self.isPaused) { return; }
	
	// Check for lost gl context before invoking any JS calls
	if(_glCurrentContext && EAGLContext.currentContext != _glCurrentContext) {
        [EAGLContext setCurrentContext:_glCurrentContext];
	}
	
	// We rather poll for device motion updates at the beginning of each frame instead of
	// spamming out updates that will never be seen.
	[_deviceMotionDelegate triggerDeviceMotionEvents];

	// Check all timers
	[_timers update];

	// Redraw the canvas
    [self setCurrentRenderingContext:_screenRenderingContext];
	[_screenRenderingContext present];
}


- (void)pause {
	if(self.isPaused) { return; }

	[_windowEventsDelegate pause];
	[_displayLink removeFromRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
	[_screenRenderingContext finish];

	[AVAudioSession.sharedInstance setActive:NO error:NULL];
	[_openALManager beginInterruption];
	
	[self setPaused:YES];
}

- (void)resume {
	if(!self.isPaused) { return; }

	[_windowEventsDelegate resume];
	[EAGLContext setCurrentContext:_glCurrentContext];
	[_displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];

	[AVAudioSession.sharedInstance setActive:YES error:NULL];
	[_openALManager endInterruption];
	
    [self setPaused:NO];
}

- (void)clearCaches {
	JSGarbageCollect(_jsGlobalContext);

	// Release all texture storages that haven't been bound in
	// the last 5 seconds
	[_textureCache releaseStoragesOlderThan:5];
}

- (void)setCurrentRenderingContext:(EJCanvasContext *)renderingContext {
	
    if(renderingContext != _currentRenderingContext ) {
		[_currentRenderingContext flushBuffers];

        if (_currentRenderingContext) {
            [_currentRenderingContext release];
            _currentRenderingContext = nil;
        }
        
		// Switch GL Context if different
		if( renderingContext && renderingContext.glContext != _glCurrentContext ) {
			glFlush();
			_glCurrentContext = renderingContext.glContext;
			[EAGLContext setCurrentContext:_glCurrentContext];
		}

		[renderingContext prepare];
        
        //Since we are overriding the setter here, we call
        //retain on the new object since we are assigning the
        //the direct variable
        _currentRenderingContext = [renderingContext retain];
	}
}


#pragma mark -
#pragma mark Touch handlers

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	
    if (_touchDelegate && [_touchDelegate respondsToSelector:@selector(triggerEvent:timestamp:all:changed:remaining:)]) {
        
        [_touchDelegate triggerEvent:@"touchstart"
                           timestamp:event.timestamp
                                 all:event.allTouches
                             changed:touches
                           remaining:event.allTouches];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	
    NSMutableSet *remaining = [event.allTouches mutableCopy];
	[remaining minusSet:touches];
	
    if (_touchDelegate && [_touchDelegate respondsToSelector:@selector(triggerEvent:timestamp:all:changed:remaining:)]) {
    
        [_touchDelegate triggerEvent:@"touchend"
                           timestamp:event.timestamp
                                 all:event.allTouches
                             changed:touches
                           remaining:remaining];
    }
    
	[remaining release];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[self touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	
    if (_touchDelegate && [_touchDelegate respondsToSelector:@selector(triggerEvent:timestamp:all:changed:remaining:)]) {
     
        [_touchDelegate triggerEvent:@"touchmove"
                           timestamp:event.timestamp
                                 all:event.allTouches
                             changed:touches
                           remaining:event.allTouches];
        
    }
}

-(void)pressesBegan:(NSSet*)presses withEvent:(UIPressesEvent *)event {
	if(_exitOnMenuPress && ((UIPress *)presses.anyObject).type == UIPressTypeMenu ) {
		return [super pressesBegan:presses withEvent:event];
	}
}

-(void)pressesEnded:(NSSet*)presses withEvent:(UIPressesEvent *)event {
	if(_exitOnMenuPress && ((UIPress *)presses.anyObject).type == UIPressTypeMenu ) {
		return [super pressesEnded:presses withEvent:event];
	}
}


#pragma mark -
#pragma mark Timers

- (JSValueRef)createTimer:(JSContextRef)ctxp argc:(size_t)argc argv:(const JSValueRef [])argv repeat:(BOOL)repeat {
	if(
		argc != 2 ||
		!JSValueIsObject(ctxp, argv[0]) ||
		!JSValueIsNumber(_jsGlobalContext, argv[1])
	) {
		return NULL;
	}

	JSObjectRef func = JSValueToObject(ctxp, argv[0], NULL);
	float interval = JSValueToNumberFast(ctxp, argv[1])/1000;

	// Make sure short intervals (< 18ms) run each frame
	if( interval < 0.018 ) {
		interval = 0;
	}

	NSInteger timerId = [_timers scheduleCallback:func interval:interval repeat:repeat];
	return JSValueMakeNumber( ctxp, timerId );
}

- (JSValueRef)deleteTimer:(JSContextRef)ctxp argc:(size_t)argc argv:(const JSValueRef [])argv {
	if( argc != 1 || !JSValueIsNumber(ctxp, argv[0]) ) return NULL;

	[_timers cancelId:JSValueToNumberFast(ctxp, argv[0])];
	return NULL;
}


@end
