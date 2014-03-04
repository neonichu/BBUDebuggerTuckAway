//
//  BBUDebuggerTuckAway.m
//  BBUDebuggerTuckAway
//
//  Created by Boris Bügling on 20.01.14.
//    Copyright (c) 2014 Boris Bügling. All rights reserved.
//

#import <objc/runtime.h>

#import "BBUDebuggerTuckAway.h"
#import "NSObject+YOLO.h"

#define kBBUDebuggerTuckAwayEnabledStatus @"kBBUDebuggerTuckAwayEnabledStatus"

static BBUDebuggerTuckAway *sharedPlugin;

@interface NSObject (ShutUpWarnings)

-(id)editorArea;
-(BOOL)showDebuggerArea;
-(void)toggleDebuggerVisibility:(id)arg;
-(NSArray*)workspaceWindowControllers;

@end

@interface BBUDebuggerTuckAway ()

@property (nonatomic, strong) NSMenuItem *toggleMenuItem;

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
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kBBUDebuggerTuckAwayEnabledStatus] == nil) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBBUDebuggerTuckAwayEnabledStatus];
        }
        
        [self initMenu];
    }
    return self;
}

- (void)initMenu
{
    NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    
    if (viewMenuItem) {
        [[viewMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
       _toggleMenuItem = [[NSMenuItem alloc] initWithTitle:[self titleForMenuItem]
                                                    action:@selector(toggleEnabledStatus)
                                             keyEquivalent:@""];
        
        [_toggleMenuItem setTarget:self];
        [[viewMenuItem submenu] addItem:_toggleMenuItem];
    }

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
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];

    if (status) {
        for (NSWindowController *workspaceWindowController in [objc_getClass("IDEWorkspaceWindowController")
                                                               workspaceWindowControllers])
        {
            id editorArea = [workspaceWindowController editorArea];
            if ([editorArea showDebuggerArea]) {
                [editorArea toggleDebuggerVisibility:nil];
            }
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Menu item stuffs

- (NSString *)titleForMenuItem
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    
    if (status) {
        return @"Disable Debug Window Auto Hide";
    }
    
    return @"Enable Debug Window Auto Hide";
}

- (void)toggleEnabledStatus
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    [[NSUserDefaults standardUserDefaults] setBool:!status forKey:kBBUDebuggerTuckAwayEnabledStatus];
    
    [_toggleMenuItem setTitle:[self titleForMenuItem]];
}

@end
