// This class implements the XMLHttpRequest API quite closely to the w3c spec.
// Notably absent is the ability to load binary data as Blob. Luckily, Blobs
// are stupid anyway and ArrayBuffers nicely fill the gap.

#import "EJBindingEventedBase.h"

typedef NS_ENUM(unsigned int, EJHttpRequestType) {
	kEJHttpRequestTypeString,
	kEJHttpRequestTypeArrayBuffer,
	kEJHttpRequestTypeBlob,
	kEJHttpRequestTypeDocument,
	kEJHttpRequestTypeJSON,
	kEJHttpRequestTypeText
};

typedef NS_ENUM(unsigned int, EJHttpRequestState) {
	kEJHttpRequestStateUnsent = 0,
	kEJHttpRequestStateOpened = 1,
	kEJHttpRequestStateHeadersReceived = 2,
	kEJHttpRequestStateLoading = 3,
	kEJHttpRequestStateDone = 4,
};

@interface EJBindingHttpRequest : EJBindingEventedBase <NSURLSessionDelegate> {
	EJHttpRequestType type;
	NSString *method;
	NSString *url;
	BOOL async;
	NSString *user;
	NSString *password;
	int timeout;
	NSMutableDictionary *requestHeaders;
	NSStringEncoding defaultEncoding;
	
	EJHttpRequestState state;	
	NSURLSession *session;
	NSURLResponse *response;
	NSMutableData *responseBody;
}

- (void)clearConnection;
- (void)clearRequest;
@property (NS_NONATOMIC_IOSONLY, getter=getResponseText, readonly, copy) NSString *responseText;

@end
