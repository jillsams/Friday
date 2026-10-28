#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`. If it raises an NSException (AVAudioEngine tap APIs do this),
/// returns NO and fills `error` instead of crashing the app.
BOOL FVTry(void (^block)(void), NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END
