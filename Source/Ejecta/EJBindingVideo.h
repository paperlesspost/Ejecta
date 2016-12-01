// EJBindingVideo provides a bare-bones implementation of the <Video> element.
// This can only be used to display MP4 or MOV files as fullscreen video.

// The implemenation does NOT provide any functions to read individual video
// frames, draw them into a Canvas or use them as a Texture for WebGL.

#import "EJBindingEventedBase.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVkit.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVAsset.h>


@interface EJBindingVideo : EJBindingEventedBase <UIGestureRecognizerDelegate>

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL ended;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, retain) AVPlayerViewController *controller;


@end
