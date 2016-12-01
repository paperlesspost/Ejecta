#import "EJTimer.h"
#import "EJJavaScriptView.h"


@implementation EJTimerCollection


- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp {
	
    self = [super init];
    
    if (self) {
        [self setScriptView:scriptViewp];
        _timers = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return self;
}

- (void)dealloc {
    [_scriptView release];
    _scriptView = nil;
    [_timers release];
    _timers = nil;
	[super dealloc];
}

- (NSInteger)scheduleCallback:(JSObjectRef)callback interval:(NSTimeInterval)interval repeat:(BOOL)repeat {
	_lastId++;
	
	EJTimer *timer = [[[EJTimer alloc] initWithScriptView:_scriptView callback:callback interval:interval repeat:repeat] autorelease];
    _timers[@(_lastId)] = timer;
    
    return _lastId;
}

- (void)cancelId:(NSInteger)timerId {
    [_timers removeObjectForKey:@(timerId)];
}

- (void)update {	
	for( NSNumber *timerId in _timers.allKeys) {
        
        EJTimer *timer = _timers[timerId];
        [timer check];
		
		if(timer.active == NO) {
			[_timers removeObjectForKey:timerId];
		}
	}
}

@end



@interface EJTimer()
@property (nonatomic, retain) NSDate *target;
@end


@implementation EJTimer

- (instancetype)initWithScriptView:(EJJavaScriptView *)scriptViewp
	callback:(JSObjectRef)callbackp
	interval:(NSTimeInterval)intervalp
	repeat:(BOOL)repeatp
{
    self = [super init];
    
    if (self) {
        
        [self setScriptView:scriptViewp];
        _active = YES;
        _interval = intervalp;
        _repeat = repeatp;
        
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:_interval];
        [self setTarget:date];
        [date release];
        
        _callback = callbackp;
        JSValueProtect(_scriptView.jsGlobalContext, _callback);
    }
    return self;
}

- (void)dealloc {
    
    [_target release];
    _target = nil;
    [_scriptView release];
    _scriptView = nil;
    
	JSValueUnprotectSafe(_scriptView.jsGlobalContext, _callback);
	
    [super dealloc];
}

- (void)check {
    
	if([self isActive] && [_target timeIntervalSinceNow] <= 0 ) {
		
        [_scriptView invokeCallback:_callback
                         thisObject:NULL
                               argc:0
                               argv:NULL];
		
		if(_repeat) {
            [self setTarget:nil];
            _target = [NSDate dateWithTimeIntervalSinceNow:_interval];
        }
		else {
			_active = false;
		}
	}
}


@end
