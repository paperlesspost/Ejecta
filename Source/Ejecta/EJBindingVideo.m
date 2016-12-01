#import "EJBindingVideo.h"


@implementation EJBindingVideo

- (instancetype)initWithContext:(JSContextRef)ctx argc:(size_t)argc argv:(const JSValueRef [])argv {
    
    self = [super initWithContext:ctx
                             argc:argc
                             argv:argv];
    
    if (self) {
        
        _controller = [[AVPlayerViewController alloc] initWithNibName:nil bundle:nil];
        _controller.showsPlaybackControls = NO;
        AVPlayer *player = [[AVPlayer alloc] initWithPlayerItem:nil];
        [_controller setPlayer:player];
        [player release];

    }
    return self;
}

//Garbage collection in iOS???
- (void)prepareGarbageCollection {
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)dealloc {
    
    if (_controller.view.superview) {
        [_controller.view removeFromSuperview];
    }
    
	[_controller release];
    _controller = nil;
    
	[_path release];
    _path = nil;
    
	[super dealloc];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
	shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	return YES;
}

EJ_BIND_GET(duration, ctx) {
	return JSValueMakeNumber(ctx, _controller.player.currentItem.asset.duration.value);
}

EJ_BIND_GET(loop, ctx) {
	return JSValueMakeBoolean( ctx, _loop );
}

EJ_BIND_SET(loop, ctx, value) {
	_loop = JSValueToBoolean(ctx, value);
}

EJ_BIND_GET(controls, ctx) {
	return JSValueMakeBoolean( ctx, _controller.showsPlaybackControls);
}

EJ_BIND_SET(controls, ctx, value) {
	_controller.showsPlaybackControls = JSValueToNumberFast(ctx, value);
}

EJ_BIND_GET(currentTime, ctx) {
	return JSValueMakeNumber( ctx, _controller.player.currentItem.currentTime.value );
}

EJ_BIND_SET(currentTime, ctx, value) {
	[_controller.player seekToTime:CMTimeMakeWithSeconds(JSValueToNumberFast(ctx, value), 1)];
}

EJ_BIND_GET(src, ctx) {
	return _path ? NSStringToJSValue(ctx, _path) : NULL;
}

EJ_BIND_SET(src, ctx, value) {
    
	[NSNotificationCenter.defaultCenter removeObserver:self];

	[_path release];
	_path = nil;
    [self setPath:JSValueToNSString(ctx, value)];
	
    NSURL *url = [NSURL URLWithString:_path];
	
    if( !url.host ) {
		// No host? Assume we have a local file
		url = [NSURL fileURLWithPath:[scriptView pathForResource:_path]];
	}

	[_controller.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
	_controller.showsPlaybackControls = NO;

	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
	tapGesture.delegate = self;
	tapGesture.numberOfTapsRequired = 1;
	[_controller.view addGestureRecognizer:tapGesture];
	[tapGesture release];

	[NSNotificationCenter.defaultCenter addObserver:self
		selector:@selector(didFinish:)
		name:AVPlayerItemDidPlayToEndTimeNotification
		object:_controller.player.currentItem];

    
    dispatch_async(dispatch_get_main_queue(), ^{

        [self triggerEvent:@"canplaythrough"];
        [self triggerEvent:@"loadedmetadata"];
    });
}

- (void)didTap:(UIGestureRecognizer *)gestureRecognizer {
	[self triggerEvent:@"click"];
}

- (void)didFinish:(AVPlayerItem *)moviePlayer {
	if(_loop ) {
		[_controller.player seekToTime:kCMTimeZero];
	}
	else {
		[_controller.player pause];
		
        if (_controller.view.superview) {
            [_controller.view removeFromSuperview];
        }
		_ended = true;
		[self triggerEvent:@"ended"];
	}
}

EJ_BIND_GET(ended, ctx) {
	return JSValueMakeBoolean(ctx, _ended);
}

EJ_BIND_GET(paused, ctx) {
	return JSValueMakeBoolean(ctx, (_controller.player.rate == 0));
}

EJ_BIND_FUNCTION(play, ctx, argc, argv) {
	if(_controller.player.rate != 0 ) {
		// Already playing. Nothing to do here.
		return NULL;
	}

	_controller.view.frame = scriptView.bounds;
	[scriptView addSubview:_controller.view];
	[_controller.player play];

	return NULL;
}

EJ_BIND_FUNCTION(pause, ctx, argc, argv) {
	[_controller.player pause];
	[_controller.view removeFromSuperview];
	return NULL;
}

EJ_BIND_FUNCTION(load, ctx, argc, argv) {
	return NULL;
}

EJ_BIND_FUNCTION(canPlayType, ctx, argc, argv) {
	if( argc != 1 ) return NSStringToJSValue(ctx, @"");

	NSString *mime = JSValueToNSString(ctx, argv[0]);
	if( [mime hasPrefix:@"video/mp4"] ) {
		return NSStringToJSValue(ctx, @"probably");
	}
	return NSStringToJSValue(ctx, @"");
}

EJ_BIND_EVENT(canplaythrough);
EJ_BIND_EVENT(loadedmetadata);
EJ_BIND_EVENT(ended);
EJ_BIND_EVENT(click);

EJ_BIND_CONST(nodeName, "VIDEO");
EJ_BIND_CONST(tagName, "VIDEO");

@end
