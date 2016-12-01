// EJConvert.h provides various functions to convert native values and objects
// to and from JavaScript values and objects. These functions are used
// throughout all of Ejecta.

// JSValueToNSString() and NSStringToJSValue() convert native Obj-C to and from
// JSValueRefs.

// JSValueToNumberFast() provides a faster implementation of JSCs built-in
// JSValueToNumber() function at expense of no error checking - i.e. strings
// will silently convert to 0 instead of throwing an exception. Ejecta makes
// heavy use of this function to provide a fast(er) Canvas and WebGL Context.

// NSObjectToJSValue() and JSValueToNSObject() converts between complex object
// hierachies. It supports Arrays, Objects (as NSDictionary), Strings, Bools,
// Numbers and Date instances.

// JSValueGetTypedArrayPtr() gets the data pointer and byte length from a
// Typed Array or Array Buffer. 

#import <Foundation/Foundation.h>
#import "JavaScriptCore/JavaScriptCore.h"


/**
 Converting a JSValue to NSString

 @param ctx the Javascript context
 @param v the Javascript value
 @return an instance of NSString
 */
NSString *JSValueToNSString( JSContextRef ctx, JSValueRef v );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param string <#string description#>
 @return <#return value description#>
 */
JSValueRef NSStringToJSValue( JSContextRef ctx, NSString *string );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param v <#v description#>
 @return <#return value description#>
 */
double JSValueToNumberFast( JSContextRef ctx, JSValueRef v );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param v <#v description#>
 */
void JSValueUnprotectSafe( JSContextRef ctx, JSValueRef v );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param obj <#obj description#>
 @return <#return value description#>
 */
JSValueRef NSObjectToJSValue( JSContextRef ctx, NSObject *obj );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param value <#value description#>
 @return <#return value description#>
 */
NSObject *JSValueToNSObject( JSContextRef ctx, JSValueRef value );

/**
 <#Description#>

 @param ctx <#ctx description#>
 @param value <#value description#>
 @param length <#length description#>
 @return <#return value description#>
 */
void *JSValueGetTypedArrayPtr( JSContextRef ctx, JSValueRef value, size_t *length );

/**
 <#Description#>

 @param v <#v description#>
 @return <#return value description#>
 */
static inline void *JSValueGetPrivate(JSValueRef v) {
	// On 64bit systems we can not safely call JSObjectGetPrivate with any
	// JSValueRef. Doing so with immediate values (numbers, null, bool,
	// undefined) will crash the app. So we check for these first.

	#if __LP64__
		return !((int64_t)v & 0xffff000000000002ll)
			? JSObjectGetPrivate((JSObjectRef)v)
			: NULL;
	#else
		return JSObjectGetPrivate((JSObjectRef)v);
	#endif
}
