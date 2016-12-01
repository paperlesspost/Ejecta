// EJImageData contains the actual pixel data bytes in an NSMutableData.
// Accessing the .texture property will create a texture with those bytes.

#import <Foundation/Foundation.h>
#import "EJTexture.h"

@interface EJImageData : NSObject

- (instancetype)initWithWidth:(int)width height:(int)height pixels:(NSMutableData *)pixels;

@property (retain, nonatomic) EJTexture *texture;
@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;
@property (retain, nonatomic) NSMutableData *pixels;

@end
