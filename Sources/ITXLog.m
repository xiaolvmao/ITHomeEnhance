#import "ITXLog.h"

static const NSUInteger kITXLogCapacity = 400;
static NSMutableArray<NSString *> *sLines;
static NSLock *sLock;
static NSString *sLogPath;

static void ITXLogSetup(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sLines = [NSMutableArray array];
        sLock = [NSLock new];
        NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        sLogPath = [dir stringByAppendingPathComponent:@"ITHomeEnhance.log"];
    });
}

void ITXLog(NSString *format, ...) {
    ITXLogSetup();
    va_list args;
    va_start(args, format);
    NSString *body = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@] %@", [fmt stringFromDate:[NSDate date]], body];

    NSLog(@"[ITHomeEnhance] %@", body);

    [sLock lock];
    [sLines insertObject:line atIndex:0];
    if (sLines.count > kITXLogCapacity) {
        [sLines removeLastObject];
    }
    NSString *path = sLogPath;
    [sLock unlock];

    if (path) {
        static NSDateFormatter *fileFmt = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            fileFmt = [[NSDateFormatter alloc] init];
            fileFmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        });
        NSString *row = [NSString stringWithFormat:@"%@ %@\n", [fileFmt stringFromDate:[NSDate date]], body];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        @try {
            if (!fh) {
                [row writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            } else {
                [fh seekToEndOfFile];
                [fh writeData:[row dataUsingEncoding:NSUTF8StringEncoding]];
                [fh closeFile];
            }
        } @catch (__unused NSException *e) {
        }
    }
}

NSArray<NSString *> *ITXLogLines(void) {
    ITXLogSetup();
    [sLock lock];
    NSArray *copy = [sLines copy];
    [sLock unlock];
    return copy;
}

void ITXLogClear(void) {
    ITXLogSetup();
    [sLock lock];
    [sLines removeAllObjects];
    [sLock unlock];
    [[NSFileManager defaultManager] removeItemAtPath:sLogPath error:nil];
}
