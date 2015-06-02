//
//  BBUDebuggerTuckAway.m
//  BBUDebuggerTuckAway
//
//  Created by Boris Bügling on 20.01.14.
//    Copyright (c) 2014 Boris Bügling. All rights reserved.
//

#import <objc/runtime.h>

#import "Aspects.h"
#import "BBUDebuggerTuckAway.h"

#define kBBUDebuggerTuckAwayEnabledStatus @"kBBUDebuggerTuckAwayEnabledStatus"
#define kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus @"kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus"

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
@property (nonatomic, strong) NSMenuItem *hideWhenDebugging;

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
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus] == nil) {
          [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];
        }
      
        [[NSUserDefaults standardUserDefaults] synchronize];
      
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self initMenu];
        }];
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
      
        NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"Hide When Typing In Editor"];
        _toggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Enabled" action:@selector(toggleEnabledStatus) keyEquivalent:@""];
        _hideWhenDebugging = [[NSMenuItem alloc] initWithTitle:@"Hide When Debbuging" action:@selector(toggleHideWhenDebuggingStatus) keyEquivalent:@""];
      
        _toggleMenuItem.target = self;
        _hideWhenDebugging.target = self;
      
        [submenu addItem:_toggleMenuItem];
        [submenu addItem:_hideWhenDebugging];

        [[debugMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"Hide When Typing In Editor"
                                                    action:NULL
                                             keyEquivalent:@""];
        [menuItem setSubmenu:submenu];

        [[debugMenuItem submenu] addItem:menuItem];
        
      [self changeMenuItemState:_toggleMenuItem forKey:kBBUDebuggerTuckAwayEnabledStatus];
      [self changeMenuItemState:_hideWhenDebugging forKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];
    }

}

- (void)swizzleDebuggerSession
{
    [objc_getClass("IDELaunchSession") bbudebugger_aspect_hookSelector:@selector(_didStart) withOptions:AspectPositionBefore usingBlock:^(id<BBUDebugger_AspectInfo> info) {
        if ([info.instance supportsDebugSession]) {
            self.debugging = YES;
        }
    } error:nil];
    
    [objc_getClass("IDELaunchSession") bbudebugger_aspect_hookSelector:@selector(_willExpire) withOptions:AspectPositionBefore usingBlock:^(id<BBUDebugger_AspectInfo> info) {
        if ([info.instance supportsDebugSession]) {
            self.debugging = NO;
        }
    } error:nil];
}

- (void)swizzleDidChangeTextInSourceTextView
{
    [objc_getClass("DVTSourceTextView") bbudebugger_aspect_hookSelector:@selector(didChangeText) withOptions:AspectPositionBefore usingBlock:^(id<BBUDebugger_AspectInfo> info) {
        [self toggleDebuggersIfNeeded];
    } error:nil];
}

- (void)toggleDebuggersIfNeeded
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    BOOL hideWhenDebugging = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];

  
    if (status && (hideWhenDebugging || !self.debugging)) {
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

- (void)changeMenuItemState:(NSMenuItem *)menuItem forKey:(NSString *)key
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    [menuItem setState:(status ? NSOnState : NSOffState)];
}

- (void)toggleEnabledStatus
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledStatus];
    [[NSUserDefaults standardUserDefaults] setBool:!status forKey:kBBUDebuggerTuckAwayEnabledStatus];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self changeMenuItemState:_toggleMenuItem forKey:kBBUDebuggerTuckAwayEnabledStatus];
}

- (void)toggleHideWhenDebuggingStatus
{
    BOOL status = [[NSUserDefaults standardUserDefaults] boolForKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];
    status = !status;
    
    [[NSUserDefaults standardUserDefaults] setBool:status forKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self changeMenuItemState:_hideWhenDebugging forKey:kBBUDebuggerTuckAwayEnabledHideWhenDebuggingStatus];
}

@end
