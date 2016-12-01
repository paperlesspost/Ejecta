#import "EJSharedOpenALManager.h"

@implementation EJSharedOpenALManager

static EJSharedOpenALManager *sharedOpenALManager;

+ (EJSharedOpenALManager *)instance {
	if( !sharedOpenALManager ) {
		sharedOpenALManager = [[EJSharedOpenALManager new] autorelease];
	}
    return sharedOpenALManager;
}

- (void)beginInterruption {
	alcMakeContextCurrent(NULL);
}

- (void)endInterruption {
	if (_context) {
		alcMakeContextCurrent(_context);
		alcProcessContext(_context);
	}
}

- (NSMutableDictionary*)buffers {
	if( !_buffers ) {
		// Create a non-retaining Dictionary to hold the cached buffers
		_buffers = (NSMutableDictionary*)CFDictionaryCreateMutable(NULL, 8, &kCFCopyStringDictionaryKeyCallBacks, NULL);
		
		// Create the OpenAL device when .buffers is first accessed
		_device = alcOpenDevice(NULL);
		if( _device ) {
			_context = alcCreateContext( _device, NULL );
			alcMakeContextCurrent( _context );
		}
	}
	
	return _buffers;
}

- (void)dealloc {
	sharedOpenALManager = nil;
	[_buffers release];
	
	if( _context ) { alcDestroyContext( _context ); }
	if( _device ) { alcCloseDevice( _device ); }
	[super dealloc];
}

@end
