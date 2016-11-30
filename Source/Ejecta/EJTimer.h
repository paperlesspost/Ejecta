// EJTimer and EJTimerCollection provide the backbone of Ejecta's  setInterval()
// and setTimeout() functions in JavaScript.

// The EJJavaScriptView manages an instance of EJTimerCollection and provides
// methods for installing and deleting timers.

// The EJTimerCollection's update method checks all timers and calls their
// JavaScript callback if they are due.

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>


@class EJJavaScriptView;

@interface EJTimerCollection : NSObject {
	NSMutableDictionary *timers;
	int lastId;
	EJJavaScriptView *scriptView;
}

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptView;
- (int)scheduleCallback:(JSObjectRef)callback interval:(NSTimeInterval)interval repeat:(BOOL)repeat;
- (void)cancelId:(int)timerId;
- (void)update;

@end



@interface EJTimer : NSObject {
	NSTimeInterval interval;
	JSObjectRef callback;
	BOOL active, repeat;
	EJJavaScriptView *scriptView;
}

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp
	callback:(JSObjectRef)callbackp
	interval:(NSTimeInterval)intervalp
	repeat:(BOOL)repeatp;
- (void)check;

@property (readonly) BOOL active;

@end
