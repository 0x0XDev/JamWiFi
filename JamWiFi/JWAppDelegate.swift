


import Cocoa

enum ANViewSlideDirection : Int {
	case forward
	case backward
}

//Apple Private Framework
typealias openFunc = @convention(c) (UnsafeMutableRawPointer?) -> CInt
typealias bindFunc = @convention(c) (UnsafeMutableRawPointer?, String) -> CInt
typealias scanFunc = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, NSDictionary) -> CInt
typealias associateFunc = @convention(c) (UnsafeMutableRawPointer?, NSDictionary, NSString) -> CInt
typealias closeFunc = @convention(c) (UnsafeMutableRawPointer?) -> CInt
typealias errStrFunc = @convention(c) (CInt) -> UnsafePointer<CChar>



//let Apple80211Open: ((UnsafeMutableRawPointer?) -> Int)? = nil
//let Apple80211BindToInterface: ((UnsafeMutableRawPointer?, String?) -> Int)? = nil

//void *airportHandle;
//int (*Apple80211Open)(void *);
//int (*Apple80211BindToInterface)(void *, NSString *);
//int (*Apple80211Close)(void *);
//int (*Apple80211Info)(void , NSDictionary*);
//int (*Apple80211Associate)(void , NSDictionary, void *);
//int (*Apple80211Scan)(void , NSArray *, void *);

internal func ErrorInfo(errorCode: Int) {
	runAlert("Error", "Error Code: \(errorCode)")
}

var _open: openFunc?
var _bind: bindFunc?
var _scan: scanFunc?
var _associate: associateFunc?
var _close: closeFunc?
var _errStr: errStrFunc?

//@NSApplicationMain
class JWAppDelegate: NSObject, NSApplicationDelegate {

	@IBOutlet weak var window: NSWindow!
	
	var activeView: NSView?
	var nextView: NSView?
	var animating = false
	var networkList: JWListView?


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		print("JWDelegate: Launch Complete.")
		
		// Change Apple Defaults for `scan_merge`
		if UserDefaults.standard.dictionary(forKey: "USER_SCAN_OPTIONS") == nil {
			UserDefaults.standard.set(["SCAN_MERGE":kCFBooleanFalse], forKey: "USER_SCAN_OPTIONS")
		}
	
		
		if let handle = dlopen(nil, RTLD_LAZY) {
		//if let handle = dlopen("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Apple80211", RTLD_LAZY) {
			if let open = dlsym(handle, "Apple80211Open") {
				_open = unsafeBitCast(open, to: openFunc.self)
			} else { ErrorInfo(errorCode: 6) }
			if let bind = dlsym(handle, "Apple80211BindToInterface") {
				_bind = unsafeBitCast(bind, to: bindFunc.self)
			} else { ErrorInfo(errorCode: 7) }
			if let scan = dlsym(handle, "Apple80211Scan") {
				_scan = unsafeBitCast(scan, to: scanFunc.self)
			} else { ErrorInfo(errorCode: 8) }
			if let associate = dlsym(handle, "Apple80211Associate") {
				_associate = unsafeBitCast(associate, to: associateFunc.self)
			} else { ErrorInfo(errorCode: 9) }
			if let close = dlsym(handle, "Apple80211Close") {
				_close = unsafeBitCast(close, to: closeFunc.self)
			} else { ErrorInfo(errorCode: 10) }
			if let errStr = dlsym(handle, "Apple80211ErrToStr") {
				_errStr = unsafeBitCast(errStr, to: errStrFunc.self)
			} else { ErrorInfo(errorCode: 11) }
			dlclose(handle)
		} else { ErrorInfo(errorCode: 5) }
		
		window.isMovableByWindowBackground = true
		networkList = JWListView(frame: window.contentView?.bounds ?? NSRect.null)
		push(networkList, direction: .forward)
		CarbonAppProcess.current().makeFrontmost()
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ theApplication: NSApplication) -> Bool {
		return true
	}
	
	func push(_ view: NSView?, direction: ANViewSlideDirection) {
		if animating {
			return
		}
		weak var weakSelf = self
		var oldDestFrame = activeView?.bounds
		if direction == .forward {
			let width = 0 - (oldDestFrame?.size.width ?? 0)
			oldDestFrame?.origin.x = width
		} else {
			let width = oldDestFrame!.size.width
			oldDestFrame?.origin.x = width
		}
		
		
		var newSourceFrame = window.contentView?.bounds
		let newDestFrame = window.contentView?.bounds
		
		if direction == .forward {
			let width = newSourceFrame!.size.width
			newSourceFrame?.origin.x = width
		} else {
			let width = 0 - (newSourceFrame?.size.width ?? 0)
			newSourceFrame?.origin.x = width
		}
		
		
		animating = true
		
		view?.frame = newSourceFrame!
		if let view = view {
			window.contentView?.addSubview(view)
		}
		nextView = view
		
		NSAnimationContext.current.duration = 0.3
		NSAnimationContext.current.completionHandler = {
			weakSelf?.animationComplete()
		}
		NSAnimationContext.beginGrouping()
		activeView?.animator().frame = oldDestFrame!
		view?.animator().frame = newDestFrame!
		NSAnimationContext.endGrouping()
	}
	
	func animationComplete() {
		activeView?.removeFromSuperview()
		animating = false
		activeView = nextView
		nextView = nil
	}
	
	func showNetworkList() {
		push(networkList, direction: .backward)
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	@IBAction func preferencesPressed(_ sender: Any) {
		JWPreferences.shared.show()
	}
	
}

