//
//  ANAppDelegate.m
//  JamWiFi
//
//  Created by Alex Nichol on 7/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ANAppDelegate.h"
#import "ANListView.h"
#include <dlfcn.h>


@implementation ANAppDelegate

@synthesize window = _window;



- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
	[NSNotificationCenter.defaultCenter
	 		addObserver:self
	 		selector:@selector(applicationWillTerminate:)
	 		name:NSApplicationWillTerminateNotification object:nil];
	
	libHandle = dlopen("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Apple80211", RTLD_LAZY);
	_open = dlsym(libHandle, "Apple80211Open");
	bind = dlsym(libHandle, "Apple80211BindToInterface");
	scan = dlsym(libHandle, "Apple80211Scan");
	_close = dlsym(libHandle, "Apple80211Close");
	
    networkList = [ANListView.alloc initWithFrame:self.window.contentView.bounds];
    [self pushView:networkList direction:ANViewSlideDirectionForward];
    [CarbonAppProcess.currentProcess makeFrontmost];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	
	// Cleanup
	dlclose(libHandle);
	
	[NSApplication.sharedApplication terminate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)pushView:(NSView *)view direction:(ANViewSlideDirection)direction {
    if (animating) return;
    __weak typeof(self) weakSelf = self;
    NSRect oldDestFrame = activeView.bounds;
    if (direction == ANViewSlideDirectionForward)
        oldDestFrame.origin.x = -oldDestFrame.size.width;
    else
        oldDestFrame.origin.x = oldDestFrame.size.width;
		
    
    NSRect newSourceFrame = self.window.contentView.bounds;
    NSRect newDestFrame = self.window.contentView.bounds;
    
    if (direction == ANViewSlideDirectionForward)
        newSourceFrame.origin.x = newSourceFrame.size.width;
    else
        newSourceFrame.origin.x = -newSourceFrame.size.width;
	
    
    animating = YES;
    
    view.frame = newSourceFrame;
    [self.window.contentView addSubview:view];
    nextView = view;
    
    NSAnimationContext.currentContext.duration = 0.3;
    NSAnimationContext.currentContext.completionHandler = ^{ [weakSelf animationComplete]; };
    [NSAnimationContext beginGrouping];
    activeView.animator.frame = oldDestFrame;
    view.animator.frame = newDestFrame;
    [NSAnimationContext endGrouping];
}

- (void)animationComplete {
    [activeView removeFromSuperview];
    animating = NO;
    activeView = nextView;
    nextView = nil;
}

- (void)showNetworkList {
    [self pushView:networkList direction:ANViewSlideDirectionBackward];
}

@end
