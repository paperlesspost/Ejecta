// The CanvasPattern is a simple wrapper around EJTexture. Actual rendering of a
// pattern is handled in EJCanvasContext2D by the pushPatternedRect method.

#import <Foundation/Foundation.h>
#import "EJTexture.h"
#import "EJCanvasContext2D.h"

typedef NS_OPTIONS(unsigned int, EJCanvasPatternRepeat) {
	kEJCanvasPatternNoRepeat = 0,
	kEJCanvasPatternRepeatX = 1,
	kEJCanvasPatternRepeatY = 2,
	kEJCanvasPatternRepeat = 1 | 2
};

@interface EJCanvasPattern : NSObject <EJFillable> {
	EJTexture *texture;
	EJCanvasPatternRepeat repeat;
}

- (instancetype)initWithTexture:(EJTexture *)texturep repeat:(EJCanvasPatternRepeat)repeatp;

@property (readonly, nonatomic) EJTexture *texture;
@property (readonly, nonatomic) EJCanvasPatternRepeat repeat;

@end
