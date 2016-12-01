// EJTimer and EJTimerCollection provide the backbone of Ejecta's  setInterval()
// and setTimeout() functions in JavaScript.

// The EJJavaScriptView manages an instance of EJTimerCollection and provides
// methods for installing and deleting timers.

// The EJTimerCollection's update method checks all timers and calls their
// JavaScript callback if they are due.

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class EJJavaScriptView;

@interface EJTimerCollection : NSObject

@property (nonatomic, retain) NSMutableDictionary *timers;
@property (nonatomic, assign) NSInteger lastId;
@property (nonatomic, retain) EJJavaScriptView *scriptView;

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptView;
- (NSInteger)scheduleCallback:(JSObjectRef)callback interval:(NSTimeInterval)interval repeat:(BOOL)repeat;
- (void)cancelId:(NSInteger)timerId;
- (void)update;

@end


@interface EJTimer : NSObject

@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, assign) JSObjectRef callback;
@property (nonatomic, assign) BOOL repeat;
@property (nonatomic, retain) EJJavaScriptView *scriptView;
@property (nonatomic, readonly, getter=isActive) BOOL active;

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp
	callback:(JSObjectRef)callbackp
	interval:(NSTimeInterval)intervalp
	repeat:(BOOL)repeatp;

- (void)check;



@end
