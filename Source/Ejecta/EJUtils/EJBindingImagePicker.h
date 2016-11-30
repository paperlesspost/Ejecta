// The Image Picker is one of the few classes that have no direct counterpart
// in the browser. It allows Ejecta to load an image from camera roll or a new
// photo.

// The image is returned as EJBindingImage instance to JavaScript and can be
// directly drawn onto a Canvas or loaded as a WebGL texture.

#import "EJBindingBase.h"

#define EJ_PICKER_TYPE_FULLSCREEN 1
#define EJ_PICKER_TYPE_POPUP      2

typedef NS_ENUM(unsigned int, EJImagePickerType) {
	kEJImagePickerTypeFullscreen,
	kEJImagePickerTypePopup
};

@interface EJBindingImagePicker : EJBindingBase <UIImagePickerControllerDelegate, UIPopoverControllerDelegate, UINavigationControllerDelegate> {
	JSObjectRef callback;
	UIImagePickerController *picker;
	NSString *imgFormat;
	float jpgCompression;
	EJImagePickerType pickerType;
	float maxJsWidth, maxJsHeight;
	float maxTexWidth, maxTexHeight;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)successCallback:(JSValueRef[])params;
- (void)errorCallback:(NSString *)message;
- (void)closePicker:(JSContextRef)ctx;
- (UIImage *)reduceImageSize:(UIImage *)image;

+ (BOOL)isSourceTypeAvailable:(NSString *) sourceType;

@end
