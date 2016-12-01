// The OpenALManager keeps track of the global OpenAL context and holds a
// dictionary of all active buffers.

#import <Foundation/Foundation.h>

#import <OpenAL/al.h>
#import <OpenAL/alc.h>

@interface EJSharedOpenALManager : NSObject

+ (EJSharedOpenALManager *)instance;
- (void)beginInterruption;
- (void)endInterruption;

@property (nonatomic, assign) ALCcontext *context;
@property (nonatomic, assign) ALCdevice *device;
@property (retain, nonatomic) NSMutableDictionary *buffers;

@end
