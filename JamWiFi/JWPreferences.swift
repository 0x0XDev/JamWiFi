


import Cocoa




class JWPreferences: NSViewController {
	
	static let shared = JWPreferences()
	
	fileprivate lazy var window: NSWindow = {
		let window = NSWindow(contentViewController: self)

		window.title = "JamWiFi Preferences"
        window.center()
		window.isMovableByWindowBackground = true
		window.styleMask = [.titled,.unifiedTitleAndToolbar]
		window.titlebarAppearsTransparent = true
		
		return window
	}()
	
	fileprivate let bssTypes = ["IBSS - Independent Basic Service Set (Ad-hoc)","BSS - Basic Service Set","Both"]
	fileprivate let scanTypes = ["Active","Passive","Fast (Cached)"]
	
	fileprivate var tempPrefs: [String:Any] = [:]
	
	internal func show() {
		NSApp.runModal(for: window)
	}
	
	override func loadView() {
		tempPrefs = UserDefaults.standard.dictionary(forKey: "USER_SCAN_OPTIONS") ?? [:]
		
		view = NSView(frame: NSMakeRect(0, 0, 500, 200))
		
		let scanningLabel = NSTextField(labelWithAttributedString: NSAttributedString(string: "Scanning Options", attributes: [.font:NSFont.boldSystemFont(ofSize: 13)]))
		scanningLabel.frame.origin = CGPoint(x: 15, y: view.frame.height-scanningLabel.frame.height-20)
		
		let mergeOption = NSButton(checkboxWithTitle: "Merge Networks with same SSIDs and different BSSIDs", target: self, action: #selector(mergeClicked))
		mergeOption.frame.origin = CGPoint(x: scanningLabel.frame.origin.x, y: scanningLabel.frame.origin.y-mergeOption.frame.height-10)
		mergeOption.refusesFirstResponder = true
		mergeOption.state = tempPrefs["SCAN_MERGE"] == nil || (tempPrefs["SCAN_MERGE"] as! CFBoolean) == kCFBooleanTrue ? .on : .off
		
		let includeP2P = NSButton(checkboxWithTitle: "Include Peer-to-Peer (awdl0) Networks", target: self, action: #selector(includeP2PClicked))
		includeP2P.frame.origin = CGPoint(x: mergeOption.frame.origin.x, y: mergeOption.frame.origin.y-includeP2P.frame.height-5)
		includeP2P.refusesFirstResponder = true
		includeP2P.state = tempPrefs["SCAN_P2P"] == nil || (tempPrefs["SCAN_P2P"] as! CFBoolean) == kCFBooleanFalse ? .off : .on
		
		let includeClosed = NSButton(checkboxWithTitle: "Include Closed Networks", target: self, action: #selector(includeClosedClicked))
		includeClosed.frame.origin = CGPoint(x: includeP2P.frame.origin.x, y: includeP2P.frame.origin.y-includeClosed.frame.height-5)
		includeClosed.refusesFirstResponder = true
		includeClosed.state = tempPrefs["SCAN_CLOSED_NETWORKS"] == nil || (tempPrefs["SCAN_CLOSED_NETWORKS"] as! CFBoolean) == kCFBooleanFalse ? .off : .on
		
		let bssTypeLabel = NSTextField(labelWithString: "BSS Type")
		bssTypeLabel.frame.origin = CGPoint(x: includeClosed.frame.origin.x, y: includeClosed.frame.origin.y-bssTypeLabel.frame.height-10)
		
		let bssType = NSPopUpButton(frame: NSMakeRect(bssTypeLabel.frame.origin.x+bssTypeLabel.frame.width+12, bssTypeLabel.frame.origin.y-4, 130, 20), pullsDown: false)
		bssType.addItems(withTitles: bssTypes)
		bssType.refusesFirstResponder = true
		bssType.target = self
		bssType.action = #selector(bssTypeSelected)
		bssType.selectItem(at: tempPrefs["SCAN_BSS_TYPE"] == nil ? 2 : tempPrefs["SCAN_BSS_TYPE"] as! Int - 1)
		
		let scanTypeLabel = NSTextField(labelWithString: "Scan Type")
		scanTypeLabel.frame.origin = CGPoint(x: bssTypeLabel.frame.origin.x, y: bssTypeLabel.frame.origin.y-scanTypeLabel.frame.height-10)
		
		let scanType = NSPopUpButton(frame: NSMakeRect(bssType.frame.origin.x, scanTypeLabel.frame.origin.y-4, 130, 20), pullsDown: false)
		scanType.addItems(withTitles: scanTypes)
		scanType.refusesFirstResponder = true
		scanType.target = self
		scanType.action = #selector(scanTypeSelected)
		scanType.selectItem(at: tempPrefs["SCAN_TYPE"] == nil ? 0 : tempPrefs["SCAN_TYPE"] as! Int - 1)
		
		let discardButton = NSButton(title: "Discard", target: self, action: #selector(discard))
		discardButton.frame.origin = CGPoint(x: view.frame.width-discardButton.frame.width-10, y: 10)
		discardButton.refusesFirstResponder = true
		
		let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
		saveButton.frame.origin = CGPoint(x: discardButton.frame.origin.x - saveButton.frame.width+5, y: 10)
		saveButton.refusesFirstResponder = true
		
		view.addSubview(scanningLabel)
		view.addSubview(mergeOption)
		view.addSubview(includeP2P)
		view.addSubview(includeClosed)
		view.addSubview(bssTypeLabel)
		view.addSubview(bssType)
		view.addSubview(scanTypeLabel)
		view.addSubview(scanType)
		
		view.addSubview(discardButton)
		view.addSubview(saveButton)
	}
	
	@objc fileprivate func mergeClicked(sender: NSButton) {
		tempPrefs["SCAN_MERGE"] = sender.state.rawValue == 0 ? kCFBooleanFalse : kCFBooleanTrue
	}
	@objc fileprivate func includeP2PClicked(sender: NSButton) {
		tempPrefs["SCAN_P2P"] = sender.state.rawValue == 0 ? kCFBooleanFalse : kCFBooleanTrue
	}
	@objc fileprivate func includeClosedClicked(sender: NSButton) {
		tempPrefs["SCAN_CLOSED_NETWORKS"] = sender.state.rawValue == 0 ? kCFBooleanFalse : kCFBooleanTrue
	}
	@objc fileprivate func bssTypeSelected(sender: NSPopUpButton) {
		tempPrefs["SCAN_BSS_TYPE"] = sender.indexOfSelectedItem + 1
	}
	@objc fileprivate func scanTypeSelected(sender: NSPopUpButton) {
		tempPrefs["SCAN_TYPE"] = sender.indexOfSelectedItem + 1
	}
	
	@objc fileprivate func save() {
		UserDefaults.standard.set(tempPrefs, forKey: "USER_SCAN_OPTIONS")
		UserDefaults.standard.synchronize()
		hide()
	}
	@objc fileprivate func discard() {
		tempPrefs = [:]
		hide()
	}
	fileprivate func hide() {
		NSApp.stopModal()
		window.orderOut(nil)
	}
}
