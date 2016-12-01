#import "EJBindingImage.h"
#import "EJJavaScriptView.h"
#import "EJNonRetainingProxy.h"
#import "EJTexture.h"


@interface EJBindingImage ()

@property (nonatomic, retain, readwrite) EJTexture *texture;

@end


@implementation EJBindingImage



- (void)beginLoad {
	// This will begin loading the texture in a background thread and will call the
	// JavaScript onload callback when done
    [self setLoading:YES];
    
	// Protect this image object from garbage collection, as its callback function
	// may be the only thing holding on to it
	JSValueProtect(scriptView.jsGlobalContext, jsObject);
	
	NSString *fullPath;

	// If path is a Data URI or remote URL we don't want to prepend resource paths
	if([_path hasPrefix:@"data:"] ) {
		NSLog(@"Loading Image from Data URI");
		fullPath = _path;
	}
	else if( [_path hasPrefix:@"http:"] || [_path hasPrefix:@"https:"] ) {
		NSLog(@"Loading Image from URL: %@", _path);
		fullPath = _path;
	}
	else {
		NSLog(@"Loading Image (lazy): %@", _path);
		fullPath = [scriptView pathForResource:_path];
	}
	
	// Use a non-retaining proxy for the callback operation and take care that the
	// loadCallback is always cancelled when dealloc'ing
	_loadCallback = [[NSInvocationOperation alloc]
		initWithTarget:[EJNonRetainingProxy proxyWithTarget:self]
		selector:@selector(endLoad) object:nil];
	
	_texture = [[EJTexture cachedTextureWithPath:fullPath
		loadOnQueue:scriptView.backgroundQueue callback:_loadCallback] retain];
}

- (void)prepareGarbageCollection {
	[_loadCallback cancel];
	_loadCallback = nil;
}

- (void)dealloc {
	[_loadCallback cancel];
    _loadCallback = nil;
	
	[_texture release];
    _texture = nil;
    
	[_path release];
    _path = nil;
    
    [super dealloc];
}

- (void)endLoad {
    [self setLoading:NO];
    _loadCallback = nil;
	
	if(_texture.lazyLoaded || _texture.textureId ) {
		[self triggerEvent:@"load"];
	}
	else {
		[self triggerEvent:@"error"];
	}
	
	JSValueUnprotect(scriptView.jsGlobalContext, jsObject);
}

- (void)setTexture:(EJTexture *)texturep path:(NSString *)pathp {
	
    [self setTexture:texturep];
    [self setPath:pathp];
}

EJ_BIND_GET(src, ctx ) {
	return NSStringToJSValue(ctx, _path ? _path : @"");
}

EJ_BIND_SET(src, ctx, value) {
	// If the texture is still loading, do nothing to avoid confusion
	// This will break some edge cases; FIXME
	if(_loading) { return; }
	
	NSString *newPath = JSValueToNSString( ctx, value );
	
	// Same as the old path? Nothing to do here
	if([_path isEqualToString:newPath]) { return; }
	
	
	// Release the old path and texture?
	if(_path) {
		[_path release];
		_path = nil;
	}
	
	if(_texture) {
		[_texture release];
		_texture = nil;
	}
	
	if( !JSValueIsNull(ctx, value) && newPath.length ) {
        [self setPath:newPath];
        [self beginLoad];
	}
}

EJ_BIND_GET(width, ctx ) {
	return JSValueMakeNumber( ctx, _texture.width );
}

EJ_BIND_GET(height, ctx ) {
	return JSValueMakeNumber( ctx, _texture.height );
}

EJ_BIND_GET(complete, ctx ) {
	return JSValueMakeBoolean(ctx, (_texture && (_texture.lazyLoaded || _texture.textureId)) );
}

EJ_BIND_EVENT(load);
EJ_BIND_EVENT(error);

EJ_BIND_CONST(nodeName, "IMG");
EJ_BIND_CONST(tagName, "IMG");

@end
