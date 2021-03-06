// The protocol that all Audio Source types have to conform with in order to
// be used as the source for an EJBindingAudio element.

#import <UIKit/UIKit.h>

@protocol EJAudioSourceDelegate;
@protocol EJAudioSource

- (instancetype)initWithPath:(NSString *)path;
- (void)play;
- (void)pause;
- (void)setLooping:(BOOL)loop;
- (void)setVolume:(float)volume;
- (void)setPlaybackRate:(float)playbackRate;

@property (nonatomic) float duration;
@property (nonatomic) float currentTime;
@property (nonatomic, assign) NSObject<EJAudioSourceDelegate> *delegate;

@end

@protocol EJAudioSourceDelegate
- (void)sourceDidFinishPlaying:(NSObject<EJAudioSource> *)source;
@end
