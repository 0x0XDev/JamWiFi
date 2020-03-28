


import Cocoa
import CoreWLAN

class JWListView: NSView, NSTableViewDelegate, NSTableViewDataSource {
	var interfaceName = ""
	var networks: [CWNetwork] = []
	var scanButton: NSButton?
	var joinButton: NSButton?
	var disassociateButton: NSButton?
	var jamButton: NSButton?
	var progressIndicator: NSProgressIndicator?
	var networksScrollView: NSScrollView?
	var networksTable: NSTableView?
	
	var sortAscending = true
	var sortOrder = ""
	
	
	override init(frame: NSRect) {
		super.init(frame: frame)
		
		networksScrollView = NSScrollView(frame: NSRect(x: 10, y: 52, width: frame.size.width - 20, height: frame.size.height - 62))
		networksTable = NSTableView(frame: networksScrollView?.contentView.bounds ?? NSRect.zero)
		disassociateButton = NSButton(frame: NSRect(x: 10, y: 10, width: 100, height: 24))
		joinButton = NSButton(frame: NSRect(x: 110, y: 10, width: 100, height: 24))
		scanButton = NSButton(frame: NSRect(x: 210, y: 10, width: 100, height: 24))
		progressIndicator = NSProgressIndicator(frame: NSRect(x: 325, y: 14, width: 16, height: 16))
		jamButton = NSButton(frame: NSRect(x: frame.size.width - 110, y: 10, width: 100, height: 24))
		
		progressIndicator?.controlSize = .small
		progressIndicator?.style = .spinning
		progressIndicator?.isDisplayedWhenStopped = false
		
		scanButton?.bezelStyle = .rounded
		scanButton?.title = "Scan"
		scanButton?.target = self
		scanButton?.action = #selector(scanButton(_:))
		scanButton?.font = NSFont.systemFont(ofSize: 13)
		
		scanButton?.bezelStyle = .rounded
		scanButton?.title = "Scan"
		scanButton?.target = self
		scanButton?.action = #selector(scanButton(_:))
		scanButton?.font = NSFont.systemFont(ofSize: 13)
		
		joinButton?.bezelStyle = .rounded
		joinButton?.title = "Join"
		joinButton?.target = self
		joinButton?.action = #selector(joinButton(_:))
		joinButton?.font = NSFont.systemFont(ofSize: 13)
		joinButton?.isEnabled = false
		
		disassociateButton?.bezelStyle = .rounded
		disassociateButton?.title = "Deauth"
		disassociateButton?.target = self
		disassociateButton?.action = #selector(disassociateButton(_:))
		disassociateButton?.font = NSFont.systemFont(ofSize: 13)
		
		jamButton?.bezelStyle = .rounded
		jamButton?.title = "Monitor"
		jamButton?.target = self
		jamButton?.action = #selector(jamButton(_:))
		jamButton?.font = NSFont.systemFont(ofSize: 13)
		jamButton?.isEnabled = false
		
		
		let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channel"))
		channelColumn.headerCell.stringValue = "CH"
		channelColumn.width = 40
		channelColumn.isEditable = true
		channelColumn.sortDescriptorPrototype = NSSortDescriptor(key: channelColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(channelColumn)
		
		let essidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("essid"))
		essidColumn.headerCell.stringValue = "ESSID"
		essidColumn.width = 170
		essidColumn.isEditable = true
		essidColumn.sortDescriptorPrototype = NSSortDescriptor(key: essidColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(essidColumn)
		
		let bssidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bssid"))
		bssidColumn.headerCell.stringValue = "BSSID"
		bssidColumn.width = 120
		bssidColumn.isEditable = true
		bssidColumn.sortDescriptorPrototype = NSSortDescriptor(key: bssidColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(bssidColumn)
		
		let encColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enc"))
		encColumn.headerCell.stringValue = "Security"
		encColumn.width = 160
		encColumn.isEditable = true
		encColumn.sortDescriptorPrototype = NSSortDescriptor(key: encColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(encColumn)
		
		let rssiColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rssi"))
		rssiColumn.headerCell.stringValue = "RSSI"
		rssiColumn.width = 40
		rssiColumn.isEditable = true
		rssiColumn.sortDescriptorPrototype = NSSortDescriptor(key: rssiColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(rssiColumn)
		
		let channelBandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channelBand"))
		channelBandColumn.headerCell.stringValue = "CH-Band"
		channelBandColumn.width = 60
		channelBandColumn.isEditable = true
		channelBandColumn.sortDescriptorPrototype = NSSortDescriptor(key: channelBandColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(channelBandColumn)
		
		networksScrollView?.documentView = networksTable
		networksScrollView?.borderType = .bezelBorder
		networksScrollView?.hasVerticalScroller = true
		networksScrollView?.hasHorizontalScroller = true
		networksScrollView?.autohidesScrollers = false
		networksScrollView?.hasHorizontalScroller = false

		networksTable?.dataSource = self
		networksTable?.delegate = self
		networksTable?.allowsMultipleSelection = true
		networksTable?.refusesFirstResponder = true
		
		if let _ = networksScrollView { addSubview(networksScrollView!) }
		if let _ = scanButton { addSubview(scanButton!) }
		if let _ = joinButton { addSubview(joinButton!) }
		if let _ = disassociateButton { addSubview(disassociateButton!) }
		if let _ = progressIndicator { addSubview(progressIndicator!) }
		if let _ = jamButton { addSubview(jamButton!) }
		
		autoresizesSubviews = true
		autoresizingMask = [.width, .height]
		networksScrollView?.autoresizingMask = [.width, .height]
		jamButton?.autoresizingMask = .minXMargin
	
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		//fatalError("init(coder:) has not been implemented")
	}
	
	@objc func scanButton(_ sender: Any?) {
		
		progressIndicator?.startAnimation(self)
		scanButton?.isEnabled = false
		scanInBackground()
	}
	
	@objc func sheetOkPressed(_ sender: Any?) {
		self.window?.endSheet((sender as! NSView).window!, returnCode: .OK)
	}
	@objc func sheetCancelPressed(_ sender: Any?) {
		self.window?.endSheet((sender as! NSView).window!, returnCode: .cancel)
	}
	
	@objc func joinButton(_ sender: Any?) {
		
		progressIndicator?.startAnimation(self)
		joinButton?.isEnabled = false
		let network: CWNetwork = self.networks[(networksTable?.selectedRowIndexes.first)!]
		var password = ""
		let done: ((Bool)->()) = {run in
			if run {
				self.interfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
				var airportHandle: UnsafeMutableRawPointer?
				
				_ = _open!(&airportHandle)
				_ = _bind!(airportHandle, self.interfaceName)
				let result = _associate!(airportHandle, network.value(forKey: "_scanRecord") as! NSDictionary, password as NSString)
				
				if result == 0 {
					print("success")
				} else {
					print("fail: \(String(cString: _errStr!(result)))")
				}
				
				_ = _close!(airportHandle)
			}
			DispatchQueue.main.async {
				self.progressIndicator?.stopAnimation(self)
				self.joinButton?.isEnabled = true
			}
		}
		
		if network.supportsSecurity(.none) == false {
			
			let sheetWindow = NSWindow(contentRect: NSMakeRect(0, 0, 300, 100), styleMask: [.docModalWindow,.titled], backing: .buffered, defer: false)

			let label = NSTextField(labelWithString: "Enter Password:")
			label.frame = NSMakeRect(13, sheetWindow.frame.height-label.frame.height-12, label.frame.width, label.frame.height)
			
			let passwordField = NSTextField(frame: NSRect(x: label.frame.origin.x+2, y: 38, width: 270, height: 24))
			passwordField.placeholderString = "Password"
			passwordField.target = self
			passwordField.action = #selector(sheetOkPressed(_:))
	
			let cancelButton = NSButton(frame: NSRect(x: sheetWindow.frame.width-70-6, y: 5, width: 70, height: 24))
			let okButton = NSButton(frame: NSRect(x: cancelButton.frame.origin.x-70, y: 5, width: 70, height: 24))
			
			cancelButton.bezelStyle = .rounded
			cancelButton.title = "Cancel"
			cancelButton.target = self
			cancelButton.action = #selector(sheetCancelPressed(_:))

			okButton.bezelStyle = .rounded
			okButton.title = "Try"
			okButton.target = self
			okButton.action = #selector(sheetOkPressed(_:))
			okButton.isHighlighted = true

			sheetWindow.contentView?.addSubview(label)
			sheetWindow.contentView?.addSubview(passwordField)
			
			sheetWindow.contentView?.addSubview(okButton)
			sheetWindow.contentView?.addSubview(cancelButton)
			
			self.window?.beginSheet(sheetWindow, completionHandler: { (response) in
				password = passwordField.stringValue
				DispatchQueue.global(qos: .userInitiated).async { done(response == .OK) }
			})
		} else {
			DispatchQueue.global(qos: .userInitiated).async { done(true) }
		}
	}
	
	@objc func disassociateButton(_ sender: Any?) {
		CWWiFiClient.shared().interface()!.disassociate()
	}
	
	@objc func jamButton(_ sender: Any?) {
		var theNetworks: [CWNetwork] = []
		
		
		for idx in networksTable?.selectedRowIndexes ?? [] {
			theNetworks.append(self.networks[idx])
		}
		let sniffer = ANWiFiSniffer(interfaceName: interfaceName)
		let gatherer = JWTrafficGatherer(frame: bounds, sniffer: sniffer, networks: theNetworks)
		(NSApp.delegate as? JWAppDelegate)?.push(gatherer, direction: .forward)
	}
	
	func scanInBackground() {
		let queue = DispatchQueue.global(qos: .default)
		weak var weakSelf = self
		queue.async(execute: {
			self.interfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
			var airportHandle: UnsafeMutableRawPointer?
			var foundNets: UnsafeMutableRawPointer?
			
			let scanParams: NSDictionary = UserDefaults.standard.dictionary(forKey: "USER_SCAN_OPTIONS") as NSDictionary? ?? NSDictionary()
				
			_ = _open!(&airportHandle)
			_ = _bind!(airportHandle, self.interfaceName)
			let result = _scan!(airportHandle, &foundNets, scanParams)
			

			if foundNets == nil {
				print("wifi scan error: \(String(cString: _errStr!(result)))")
				
				// Cleanup
				_ = _close!(airportHandle)
				
				weakSelf?.performSelector(onMainThread: #selector(self.handleScanError), with: nil, waitUntilDone: false)
			} else {
				
				var networks: [CWNetwork] = []
	
				for dict in unsafeBitCast(foundNets, to: NSArray.self) {
					let network = CWNetwork()
					network.setValue(dict, forKey: "_scanRecord")
					networks.append(network)
				}
				
				// Cleanup
				_ = _close!(airportHandle)
				
				weakSelf?.performSelector(onMainThread: #selector(self.handleScanSuccess(_:)), with: networks, waitUntilDone: false)
			}
		})
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return networks.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let network = networks[row]
		
		if tableColumn?.identifier.rawValue == "channelBand" {
			let chBand =  network.wlanChannel?.channelBand
			return chBand! == .bandUnknown ? "?" : (chBand! == .band2GHz ? "2.4 GHz":"5.0 Ghz")
		} else if tableColumn?.identifier.rawValue == "channel" {
			return NSNumber(value: network.wlanChannel?.channelNumber ?? 0)
		} else if tableColumn?.identifier.rawValue == "essid" {
			return network.ssid ?? "<Hidden>"
		} else if tableColumn?.identifier.rawValue == "bssid" {
			return network.bssid
		} else if tableColumn?.identifier.rawValue == "enc" {
			return securityTypeString(network)
		} else if tableColumn?.identifier.rawValue == "rssi" {
			return NSNumber(value: network.rssiValue).description
		}
		return nil
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		return
	}
	func tableViewSelectionDidChange(_ notification: Notification) {
		jamButton?.isEnabled = networksTable?.selectedRowIndexes.count ?? 0 > 0 ? true : false
		joinButton?.isEnabled = networksTable?.selectedRowIndexes.count ?? 0 == 1 ? true : false
	}
	
	func securityTypeString(_ network: CWNetwork?) -> String {
		var securityArray: [String] = []
		if network?.supportsSecurity(.none) ?? false {
			return "Open"
		}
		if network?.supportsSecurity(.WEP) ?? false {
			securityArray.append("WEP")
		}
		if network?.supportsSecurity(.dynamicWEP) ?? false {
			securityArray.append("Dynamic WEP")
		}
		if network?.supportsSecurity(.wpaPersonal) ?? false {
			securityArray.append("WPA (P)")
		}
		if network?.supportsSecurity(.wpa2Personal) ?? false {
			securityArray.append("WPA2 (P)")
		}
		if network?.supportsSecurity(.wpaEnterprise) ?? false {
			securityArray.append("WPA (E)")
		}
		if network?.supportsSecurity(.wpa2Enterprise) ?? false {
			securityArray.append("WPA2 (E)")
		}
		if network?.supportsSecurity(.unknown) ?? false {
			securityArray.append("Unknown")
		}
		
		if securityArray.count == 0 {
			return "?"
		} else {
			return securityArray.joined(separator: " / ")
		}
		
	}
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		
		guard let sortDescriptor = tableView.sortDescriptors.first else {
		   return
		 }
		
		sortAscending = sortDescriptor.ascending
		sortOrder = sortDescriptor.key!
		sortNetworks()
		networksTable?.reloadData()
	}
	
	func sortNetworks() {
		if sortOrder == "" { return }
		
		let order: ComparisonResult = sortAscending ? .orderedAscending : .orderedDescending
		
		switch sortOrder {
			case "channelBand": networks.sort { String($0.wlanChannel!.channelBand.rawValue).localizedStandardCompare(String($1.wlanChannel!.channelBand.rawValue)) == order}; break
			case "channel": networks.sort { String($0.wlanChannel!.channelNumber).localizedStandardCompare(String($1.wlanChannel!.channelNumber)) == order}; break
			case "essid": networks.sort { ($0.ssid ?? "<Hidden>").localizedStandardCompare($1.ssid ?? "<Hidden>") == order}; break
			case "bssid": networks.sort { $0.bssid?.localizedStandardCompare($1.bssid!) == order}; break
			case "enc": networks.sort { securityTypeString($0).localizedStandardCompare(securityTypeString($1)) == order}; break
			case "rssi": networks.sort { String($0.rssiValue).localizedStandardCompare(String($1.rssiValue)) == order}; break
			default: break
		}
		
	}
	
	// MARK: - Private -
	@objc private func handleScanError() {
		progressIndicator?.stopAnimation(self)
		scanButton?.isEnabled = true
		runAlert("Scan Failed", "A network scan could not be completed at this time.")
	}
	
	@objc private func handleScanSuccess(_ theNetworks: [CWNetwork]?) {
		var newNetworks = theNetworks
		outerLoop: for network in networks {
			for newNetwork in newNetworks ?? [] {
				if isNetworkEqual(network, newNetwork) { continue outerLoop }
			}
			newNetworks?.append(network)
		}
		
		progressIndicator?.stopAnimation(self)
		scanButton?.isEnabled = true
		networks = newNetworks ?? networks
		
		sortNetworks()
		networksTable?.reloadData()
	}
	
	fileprivate func isNetworkEqual(_ network1: CWNetwork, _ network2: CWNetwork) -> Bool {
		if network1.ssid == network2.ssid &&
			network1.bssid == network2.bssid &&
			network1.wlanChannel?.isEqual(to: network2.wlanChannel) ?? false {
			return true
		}
		return false
	}

}

