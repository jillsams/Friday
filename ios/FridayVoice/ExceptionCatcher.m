#import "ExceptionCatcher.h"

BOOL FVTry(void (^block)(void), NSError **error) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:exception.name ?: @"NSException"
                                         code:0
                                     userInfo:@{
                NSLocalizedDescriptionKey:
                    exception.reason ?: @"Audio setup failed."
            }];
        }
        return NO;
    }
}
