// Provides the Image Element to JavaScript. An Image instance has the `.src`
// path of the image, a `width` and `height` and a loading callback. The actual
// pixel data of the image is provided by EJTexture.

#import "EJBindingEventedBase.h"
#import "EJTexture.h"
#import "EJDrawable.h"

@interface EJBindingImage : EJBindingEventedBase <EJDrawable>

@property (nonatomic, retain) EJTexture *texture;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSOperation *loadCallback;

- (void)setTexture:(EJTexture *)texturep path:(NSString *)pathp;

@end
