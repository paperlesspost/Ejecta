// The Texture Cache simply provides a Dictionary where textures can register
// and unregister themselfs. The `releaseStoragesOlderThan` method simply walks
// through this dictionary and asks each Texture to release their Storage, if
// possible.

// The Texture Cache also (lazily) provides tables for (un-)premultiplying
// pixel data. It's a bit of an odd choice to have this in this class, but it
// works nicely, since an instance of this class is global.

#import <Foundation/Foundation.h>

@interface EJSharedTextureCache : NSObject

+ (EJSharedTextureCache *)instance;
- (void)releaseStoragesOlderThan:(NSTimeInterval)seconds;

@property (nonatomic, readonly) NSMutableDictionary *textures;
@property (nonatomic, readonly) NSMutableData *premultiplyTable;
@property (nonatomic, readonly) NSMutableData *unPremultiplyTable;

@end
