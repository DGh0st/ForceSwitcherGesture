@interface SBFluidSwitcherViewController : UIViewController // iOS 11 - 13
@end

@interface SBGrabberTongue : NSObject // iOS 9 - 13
-(id)initWithDelegate:(id)delegate edge:(UIRectEdge)edges type:(NSUInteger)type; // iOS 9 - 13
-(void)installInView:(id)view withColorStyle:(NSInteger)style; // iOS 9 - 13
-(void)invalidate; // iOS 9 - 13
@end

@interface SBFluidSwitcherGestureManager : NSObject <UIGestureRecognizerDelegate> // iOS 11 - 13
@property (nonatomic, retain) SBGrabberTongue *deckGrabberTongue; // iOS 11 - 13
@property (assign, nonatomic, weak) SBFluidSwitcherViewController *switcherViewController; // iOS 11 - 12
@property (assign, nonatomic, weak) SBFluidSwitcherViewController *mainSwitcherContentController; // iOS 13
@end

@interface UIGestureRecognizer (ForceSwitcherGesturePrivate) // iOS 3 - 13
-(void)_setRequiresSystemGesturesToFail:(BOOL)gesture; // iOS 7 - 13
@end

@interface SBCoverSheetPresentationManager : NSObject // iOS 11 - 13
+(instancetype)sharedInstance; // iOS 11 - 13
-(BOOL)hasBeenDismissedSinceKeybagLock; // iOS 11 - 13
@end

@interface SpringBoard : UIApplication // iOS 3 - 13
-(id)_accessibilityTopDisplay; // iOS 5 - 13
@end

@interface SBControlCenterController : UIViewController // iOS 7 - 13
+(instancetype)sharedInstance; // iOS 7 - 13
-(BOOL)isVisible; // iOS 7 - 13
@end

@interface SBUIChevronView : UIView // iOS 10 - 13
-(void)setState:(NSInteger)state animated:(BOOL)animated; // iOS 10 - 13
@end

static BOOL isEnabled = YES;
static BOOL isTopEdgeEnabled = YES;
static BOOL isSwipeDownChevronEnabled = YES;

static inline BOOL IsiOSAtleast(NSInteger major) {
    NSOperatingSystemVersion version;
    version.majorVersion = major;
    version.minorVersion = 0;
    version.patchVersion = 0;
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

static inline BOOL IsiOSVersion(NSInteger iOS) {
	return IsiOSAtleast(iOS) && !IsiOSAtleast(iOS + 1);
}

static inline NSUInteger GetGrabberType() {
	/*
	// TODO: Find types for each of the iOS version
	// Type for the grabber tongue needs to be unique
	NSDictionary<NSNumber *, NSNumber *> *iOSVersionToTypeMapping = @{
		@11 : @22, // iOS 11 - 22
		@12 : @21, // iOS 12 - 21
		@13 : @33 // iOS 13 - 33
		// @14 : @? // iOS 14 - ? TODO: Find the actual value
	};

	for (NSNumber *iOSVersion in iOSVersionToTypeMapping) {
		if (IsiOSVersion([iOSVersion unsignedIntegerValue]))
			return [iOSVersionToTypeMapping[iOSVersion] unsignedIntegerValue];
	}
	*/

	return 0x4e45564552; // ideally should never come here
}

static void UpdateSwitcherGrabberTongue(SBFluidSwitcherGestureManager *manager) {
	if (isEnabled) {
		if (manager.deckGrabberTongue == nil) {
			manager.deckGrabberTongue = [[%c(SBGrabberTongue) alloc] initWithDelegate:manager edge:UIRectEdgeBottom type:GetGrabberType()];
			SBFluidSwitcherViewController *fluidSwitcherViewController = nil;
			if ([manager respondsToSelector:@selector(mainSwitcherContentController)]) {
				fluidSwitcherViewController = manager.mainSwitcherContentController;
			} else if ([manager respondsToSelector:@selector(switcherViewController)]) {
				fluidSwitcherViewController = manager.switcherViewController;
			}
			[manager.deckGrabberTongue installInView:fluidSwitcherViewController.view withColorStyle:0];
		}
	} else {
		[manager.deckGrabberTongue invalidate];
		[manager.deckGrabberTongue release];
		manager.deckGrabberTongue = nil;
	}
}

%hook SBSystemGestureMetric
-(instancetype)initForType:(NSUInteger)type parentMetric:(id)metric {
	// TODO: Not needed if using existing system grabber type
	NSUInteger newType = (type == GetGrabberType() ? 0 : type);
	return %orig(newType, metric);
}
%end

%hook CCSControlCenterDefaults
-(NSUInteger)_defaultPresentationGesture {
	return (isEnabled && isTopEdgeEnabled) ? 1 : %orig();
}

-(NSUInteger)presentationGesture {
	return (isEnabled && isTopEdgeEnabled) ? 1 : %orig();
}
%end

%hook SBControlCenterController
-(UIRectEdge)presentingEdge {
	if (isEnabled) {
		if (isTopEdgeEnabled)
			return UIRectEdgeTop;
		return UIRectEdgeNone; // disable control center swipe up
	}
	return %orig();
}
%end

%hook CCUIOverlayStatusBarPresentationProvider
-(NSUInteger)headerMode {
	if (isEnabled && isTopEdgeEnabled) {
		if (isSwipeDownChevronEnabled)
			return 1;
		return 0; // disable chevron
	}
	return %orig();
}

-(BOOL)allowHotPocketDuringTransition {
	return (isEnabled && isTopEdgeEnabled && isSwipeDownChevronEnabled) || %orig();
}
%end

%hook CCUIHeaderPocketView
-(void)setChevronState:(NSUInteger)state {
	if (isEnabled && isTopEdgeEnabled && isSwipeDownChevronEnabled)
		[[self valueForKey:@"_headerChevronView"] setState:-state animated:NO];
	else
		%orig(state);
}

-(void)setBackgroundAlpha:(CGFloat)alpha {
	if (isEnabled && isTopEdgeEnabled && isSwipeDownChevronEnabled)
		alpha = 0.0;
	%orig(alpha);
}
%end

%hook SBFluidSwitcherGestureManager
-(id)initWithFluidSwitcherViewController:(id)fluidSwitcherViewController {
	self = %orig(fluidSwitcherViewController);
	if (self != nil && IsiOSVersion(11)) // iOS 11 sets the grabber inline instead of having a separate method
		UpdateSwitcherGrabberTongue(self);
	return self;
}

-(void)_updateSwitcherBottomEdgeGesturePresence {
	UpdateSwitcherGrabberTongue(self);
}

-(BOOL)_shouldBeginBottomEdgePanGesture:(id)gesture {
	id topDisplay = [(SpringBoard *)[UIApplication sharedApplication] _accessibilityTopDisplay];
	BOOL isPowerDownVisible = [topDisplay isKindOfClass:%c(SBPowerDownViewController)] || [topDisplay isKindOfClass:%c(SBPowerDownController)];
	BOOL isControlCenterVisible = [[%c(SBControlCenterController) sharedInstance] isVisible];
	BOOL isCoverSheetVisible = [topDisplay isKindOfClass:%c(CSCoverSheetViewController)] || ![[%c(SBCoverSheetPresentationManager) sharedInstance] hasBeenDismissedSinceKeybagLock];
	if (isEnabled && (isPowerDownVisible || isControlCenterVisible || isCoverSheetVisible))
		return NO;
	return %orig(gesture);
}
%end
