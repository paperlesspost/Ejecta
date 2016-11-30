// This class exposes WebSockets to JavaScript. It's a wrapper around the
// excellent SocketRocket library, whose API is closely modeled after the w3c JS
// API. So this wrapper is pretty thin.


#import "EJBindingEventedBase.h"
#import "SRWebSocket.h"

typedef NS_ENUM(unsigned int, EJWebSocketBinaryType) {
	kEJWebSocketBinaryTypeBlob,
	kEJWebSocketBinaryTypeArrayBuffer
};

typedef NS_ENUM(unsigned int, EJWebSocketReadyState) {
	kEJWebSocketReadyStateConnecting = 0,
	kEJWebSocketReadyStateOpen = 1,
	kEJWebSocketReadyStateClosing = 2,
	kEJWebSocketReadyStateClosed = 3
};

@interface EJBindingWebSocket : EJBindingEventedBase <SRWebSocketDelegate> {
	EJWebSocketBinaryType binaryType;
	EJWebSocketReadyState readyState;
	NSString *url;
	SRWebSocket *socket;
}

@end
