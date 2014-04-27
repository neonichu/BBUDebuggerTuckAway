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

-(void)_didStart;
-(void)_willExpire;
-(id)editorArea;
-(BOOL)showDebuggerArea;
-(BOOL)supportsDebugSession;
-(void)toggleDebuggerVisibility:(id)arg;
-(NSArray*)workspaceWindowControllers;

@end

@interface BBUDebuggerTuckAway ()

@property (nonatomic, assign) BOOL debugging;
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
        [self performSelector:@selector(swizzleDebuggerSession) withObject:nil afterDelay:5.0];
        
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
    NSMenuItem *debugMenuItem = nil;
    
    if (viewMenuItem) {
        debugMenuItem = [[viewMenuItem submenu] itemWithTitle:@"Debug Area"];
    }
    
    if (debugMenuItem) {
        [[debugMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
       _toggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide When Typing In Editor"
                                                    action:@selector(toggleEnabledStatus)
                                             keyEquivalent:@""];
        
        [_toggleMenuItem setTarget:self];
        [[debugMenuItem submenu] addItem:_toggleMenuItem];
        
        [self changeMenuItemState];
    }

}

- (void)swizzleDebuggerSession
{
    [[objc_getClass("IDELaunchSession") new] yl_swizzleSelector:@selector(_didStart) withBlock:^void(id sself) {
        if ([sself supportsDebugSession]) {
            self.debugging = YES;
        }

        [sself yl_performSelector:@selector(_didStart)
                    returnAddress:NULL
                argumentAddresses:NULL];
    }];

    [[objc_getClass("IDELaunchSession") new] yl_swizzleSelector:@selector(_willExpire) withBlock:^void(id sself) {
        if ([sself supportsDebugSession]) {
            self.debugging = NO;
        }

        [sself yl_performSelector:@selector(_willExpire)
                    returnAddress:NULL
                argumentAddresses:NULL];
    }];
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

    if (status && !self.debugging) {
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

- (void)changeMenuItemState
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    
    NSCellStateValue state = NSOffState;
    if (status) {
        state = NSOnState;
    }
    
    [_toggleMenuItem setState:state];
}

- (void)toggleEnabledStatus
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    [[NSUserDefaults standardUserDefaults] setBool:!status forKey:kBBUDebuggerTuckAwayEnabledStatus];
    
    [self changeMenuItemState];
}

@end
