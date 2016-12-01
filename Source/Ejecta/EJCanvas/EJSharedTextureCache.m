#import "EJSharedTextureCache.h"
#import "EJTexture.h"

@interface EJSharedTextureCache ()

@property (nonatomic, readwrite) NSMutableDictionary *textures;
@property (nonatomic, readwrite) NSMutableData *premultiplyTable;
@property (nonatomic, readwrite) NSMutableData *unPremultiplyTable;

@end


@implementation EJSharedTextureCache

+ (EJSharedTextureCache *)instance {

    static EJSharedTextureCache *sharedTextureCache = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedTextureCache = [[self alloc] init];
    });
    
    return sharedTextureCache;
}

- (instancetype)init {
	if( self = [super init] ) {
		// Create a non-retaining Dictionary to hold the cached textures
		_textures = (NSMutableDictionary *)CFDictionaryCreateMutable(NULL, 8, &kCFCopyStringDictionaryKeyCallBacks, NULL);
	}
	return self;
}

- (void)releaseStoragesOlderThan:(NSTimeInterval)seconds {
	NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
	for(NSString *key in _textures.allKeys) {
		EJTexture *texture = _textures[key];
		if( now - texture.lastUsed > seconds ) {
			[texture maybeReleaseStorage];
		}
	}
}

- (void)dealloc {
	
    [_textures release];
    _textures = nil;
    
    [self.premultiplyTable release];
    _premultiplyTable = nil;
    
    [self.unPremultiplyTable release];
    _unPremultiplyTable = nil;
    
    [super dealloc];
}


// Lookup tables for fast [un]premultiplied alpha color values
// From https://bugzilla.mozilla.org/show_bug.cgi?id=662130

- (NSMutableData *)premultiplyTable {
	if(!_premultiplyTable) {
		_premultiplyTable = [[NSMutableData alloc] initWithLength:256*256];
		
		unsigned char *data = [_premultiplyTable mutableBytes];
		for( int a = 0; a <= 255; a++ ) {
			for( int c = 0; c <= 255; c++ ) {
				data[a*256+c] = (a * c + 254) / 255;
			}
		}
	}
	
	return _premultiplyTable;
}

- (NSMutableData *)unPremultiplyTable {
	if(!_unPremultiplyTable) {
		_unPremultiplyTable = [[NSMutableData alloc] initWithLength:256*256];
		
		unsigned char *data = [_unPremultiplyTable mutableBytes];
		// a == 0 case
		for( int c = 0; c <= 255; c++ ) {
			data[c] = c;
		}

		for( int a = 1; a <= 255; a++ ) {
			for( int c = 0; c <= 255; c++ ) {
				data[a*256+c] = (c * 255) / a;
			}
		}
	}
	
	return _unPremultiplyTable;
}



@end
