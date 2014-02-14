#import <objc/runtime.h>

#import "NSObject+YOLO.h"

SEL yl_aliasForSelector(SEL originalSelector) {
	return NSSelectorFromString([NSString stringWithFormat:@"yl_%s", 
		[NSStringFromSelector(originalSelector) cStringUsingEncoding:NSUTF8StringEncoding]]);
}

static BOOL Swizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    
    if (class_addMethod(c, orig,
                        method_getImplementation(newMethod),
                        method_getTypeEncoding(newMethod))) {
        IMP imp = class_replaceMethod(c, new,
        				method_getImplementation(origMethod),
                        method_getTypeEncoding(origMethod));
    	return imp != NULL;
    }
    
    method_exchangeImplementations(origMethod, newMethod);
    return YES;
}

@implementation NSObject (YOLO)

-(void)yl_logErrorForSelector:(SEL)originalSelector {
	NSLog(@"Could not swizzle %@ on %@.", NSStringFromSelector(originalSelector), NSStringFromClass(self.class));
}

// From: https://gist.github.com/bsneed/507344
- (void)yl_performSelector:(SEL)aSelector returnAddress:(void *)result argumentAddresses:(void *)arg1, ...
{
	aSelector = yl_aliasForSelector(aSelector);

	va_list args;
	va_start(args, arg1);
	
	if([self respondsToSelector:aSelector])
	{
		NSMethodSignature *methodSig = [[self class] instanceMethodSignatureForSelector:aSelector];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: methodSig];
		[invocation setTarget:self];
		[invocation setSelector:aSelector];
		if (arg1)
			[invocation setArgument:arg1 atIndex:2];
		const char* argType;
		for (int i = 3; i < [methodSig numberOfArguments]; i++)
		{
            // From: https://github.com/nst/nsarray-functional/blob/master/NSInvocation+Functional.m
            argType = [methodSig getArgumentTypeAtIndex:i];
            
            if(!strcmp(argType, @encode(id))) {
                void* arg = va_arg(args, void*);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(SEL))) {
                SEL arg = va_arg(args, SEL);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(Class))) {
                Class arg = va_arg(args, Class);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(char))) {
                char arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(unsigned char))) {
                unsigned char arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(int))) {
                int arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(bool))) {
                bool arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(BOOL))) {
                BOOL arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(short))) {
                short arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(unichar))) {
                unichar arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(float))) {
                float arg = va_arg(args, double);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(double))) {
                double arg = va_arg(args, double);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(long))) {
                long arg = va_arg(args, long);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(long long))) {
                long long arg = va_arg(args, long long);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(unsigned int))) {
                unsigned int arg = va_arg(args, unsigned int);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(unsigned long))) {
                unsigned long arg = va_arg(args, unsigned long);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(unsigned long long))) {
                unsigned long long arg = va_arg(args, unsigned long long);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(char*))) {
                char* arg = va_arg(args, char*);
                [invocation setArgument:&arg atIndex:i];
            } else if(!strcmp(argType, @encode(void*))) {
                void* arg = va_arg(args, void*);
                [invocation setArgument:&arg atIndex:i];
            } else if (!strncmp(argType, "^{", 2)) { // Pointer to a struct
                void* arg = va_arg(args, void*);
                [invocation setArgument:&arg atIndex:i];
            } else {
                NSAssert1(NO, @"-- Unhandled type: %s", argType);
            }
		}
		[invocation invoke];	
		if (result)
			[invocation getReturnValue:result];
	}
	
	va_end(args);
}

-(void)yl_swizzleSelector:(SEL)originalSelector withBlock:(id)block {
	Method m = class_getInstanceMethod(self.class, originalSelector);
	IMP imp = imp_implementationWithBlock(block);

	SEL newSelector = yl_aliasForSelector(originalSelector);

	if (!class_addMethod(self.class, newSelector, imp, method_getTypeEncoding(m))) {
		[self yl_logErrorForSelector:originalSelector];
		return;
	}

	if (!Swizzle(self.class, originalSelector, newSelector)) {
		[self yl_logErrorForSelector:originalSelector];
	}
}

@end
