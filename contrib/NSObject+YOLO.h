#import <Foundation/Foundation.h>

@interface NSObject (YOLO)

-(void)yl_performSelector:(SEL)aSelector returnAddress:(void *)result argumentAddresses:(void *)arg1, ...;
-(void)yl_swizzleSelector:(SEL)originalSelector withBlock:(id)block;

@end
