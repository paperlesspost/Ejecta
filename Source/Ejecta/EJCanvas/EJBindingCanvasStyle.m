#import "EJBindingCanvasStyle.h"
#import "EJBindingCanvas.h"

@implementation EJBindingCanvasStyle

#define EJ_BIND_PX_STYLE(NAME, TARGET) \
	EJ_BIND_GET(NAME, ctx) { \
		return NSStringToJSValue(ctx, [NSString stringWithFormat:@"%fpx", TARGET]);\
	} \
	\
	EJ_BIND_SET(NAME, ctx, value) { \
		if( JSValueIsNumber(ctx, value) ) { \
			TARGET = JSValueToNumberFast(ctx, value); \
			return; \
		} \
		NSString *valueString = JSValueToNSString(ctx, value); \
		if( valueString.length > 0 ) { \
			float NAME; \
			sscanf( valueString.UTF8String, "%fpx", &NAME); \
			TARGET = NAME; \
		} \
		else { \
			TARGET = 0; \
		} \
	}

	EJ_BIND_PX_STYLE(width, _binding.styleWidth);
	EJ_BIND_PX_STYLE(height, _binding.styleHeight);
	EJ_BIND_PX_STYLE(left, _binding.styleLeft);
	EJ_BIND_PX_STYLE(top, _binding.styleTop);

#undef EJ_BIND_PX_STYLE

EJ_BIND_ENUM(imageRendering, _binding.imageRendering,
	"auto",			// kEJCanvasImageRenderingAuto,
	"crisp-edges",	// kEJCanvasImageRenderingCrispEdges,
	"pixelated"		// kEJCanvasImageRenderingPixelated
);

@end
