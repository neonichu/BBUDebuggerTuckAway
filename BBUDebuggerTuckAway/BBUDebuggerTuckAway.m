//
//  BBUDebuggerTuckAway.m
//  BBUDebuggerTuckAway
//
//  Created by Boris Bügling on 20.01.14.
//    Copyright (c) 2014 Boris Bügling. All rights reserved.
//

#import <NSObject+YOLO/NSObject+YOLO.h>
#import <objc/runtime.h>

#import "BBUDebuggerTuckAway.h"

static BBUDebuggerTuckAway *sharedPlugin;

@interface NSObject (ShutUpWarnings)

-(id)editorArea;
-(BOOL)showDebuggerArea;
-(void)toggleDebuggerVisibility:(id)arg;
-(NSArray*)workspaceWindowControllers;

@end

#pragma mark -

@implementation BBUDebuggerTuckAway

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        [self performSelector:@selector(swizzleDidChangeTextInSourceTextView) withObject:nil afterDelay:5.0];
    }
    return self;
}

- (void)swizzleDidChangeTextInSourceTextView
{
    [[objc_getClass("DVTSourceTextView") new] yl_swizzleSelector:@selector(didChangeText)
                                                       withBlock:^void(id sself) {
                                                           [self toggleDebuggersIfNeeded];
                                                           
                                                           [sself yl_performSelector:@selector(didChangeText)
                                                                       returnAddress:NULL
                                                                   argumentAddresses:NULL];
                                                       }];
}

- (void)toggleDebuggersIfNeeded
{
    for (NSWindowController *workspaceWindowController in [objc_getClass("IDEWorkspaceWindowController")
                                                           workspaceWindowControllers])
    {
        id editorArea = [workspaceWindowController editorArea];
        if ([editorArea showDebuggerArea]) {
            [editorArea toggleDebuggerVisibility:nil];
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
