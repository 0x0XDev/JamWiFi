


import Foundation
import CoreWLAN
import AppKit


class JWTrafficGatherer: NSView, ANWiFiSnifferDelegate, NSTableViewDelegate, NSTableViewDataSource {
	var sniffer: ANWiFiSniffer?
	var networks: [CWNetwork] = []
	var channels: [CWChannel] = []
	var channelIndex = 0
	var hopTimer: Timer?
	var allClients: [JWClient] = []
	var clientsTable: NSTableView?
	var clientsScrollView: NSScrollView?
	var backButton: NSButton?
	var continueButton: NSButton?
	
	var sortAscending = true
	var sortOrder = ""
	
	init(frame frameRect: NSRect, sniffer aSniffer: ANWiFiSniffer?, networks theNetworks: [CWNetwork]?) {
		super.init(frame: frameRect)
		configureUI()
		
		if let theNetworks = theNetworks {
			networks = theNetworks
		}
		sniffer = aSniffer
		allClients = []
		
		var mChannels: [CWChannel] = []
		for net in networks {
			if let wlanChannel = net.wlanChannel {
				if !mChannels.contains(wlanChannel) {
					mChannels.append(wlanChannel)
				}
			}
		}
		channels = mChannels
		channelIndex = -1
		hopChannel()
		hopTimer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(hopChannel), userInfo: nil, repeats: true)
		
		sniffer?.delegate = self
		sniffer?.start()
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		//fatalError("init(coder:) has not been implemented")
	}
	
	func configureUI() {
		let frame = self.frame
		clientsScrollView = NSScrollView(frame: NSRect(x: 10, y: 52, width: frame.size.width - 20, height: frame.size.height - 62))
		clientsTable = NSTableView(frame: clientsScrollView?.contentView.bounds ?? NSRect.zero)
		backButton = NSButton(frame: NSRect(x: 10, y: 10, width: 100, height: 24))
		continueButton = NSButton(frame: NSRect(x: frame.size.width - 110, y: 10, width: 100, height: 24))
		
		backButton?.bezelStyle = .rounded
		backButton?.title = "Back"
		backButton?.font = .systemFont(ofSize: 13)
		backButton?.target = self
		backButton?.action = #selector(backButton(_:))
		
		continueButton?.bezelStyle = .rounded
		continueButton?.title = "Do It!"
		continueButton?.font = .systemFont(ofSize: 13)
		continueButton?.target = self
		continueButton?.action = #selector(continueButton(_:))
		
		let checkedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
		checkedColumn.headerCell.stringValue = "Jam"
		checkedColumn.width = 30
		checkedColumn.isEditable = true
		checkedColumn.sortDescriptorPrototype = NSSortDescriptor(key: checkedColumn.identifier.rawValue, ascending: true)
		clientsTable?.addTableColumn(checkedColumn)
		
		let deviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
		deviceColumn.headerCell.stringValue = "Device"
		deviceColumn.width = 120
		deviceColumn.isEditable = false
		deviceColumn.sortDescriptorPrototype = NSSortDescriptor(key: deviceColumn.identifier.rawValue, ascending: true)
		clientsTable?.addTableColumn(deviceColumn)
		
		let bssidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bssid"))
		bssidColumn.headerCell.stringValue = "BSSID (Access Point)"
		bssidColumn.width = 120
		bssidColumn.isEditable = false
		bssidColumn.sortDescriptorPrototype = NSSortDescriptor(key: bssidColumn.identifier.rawValue, ascending: true)
		clientsTable?.addTableColumn(bssidColumn)
		
		let packetsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("count"))
		packetsColumn.headerCell.stringValue = "Packets"
		packetsColumn.width = 120
		packetsColumn.isEditable = false
		packetsColumn.sortDescriptorPrototype = NSSortDescriptor(key: packetsColumn.identifier.rawValue, ascending: true)
		clientsTable?.addTableColumn(packetsColumn)
		
		let rssiColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rssi"))
		rssiColumn.headerCell.stringValue = "RSSI"
		rssiColumn.width = 70
		rssiColumn.isEditable = false
		rssiColumn.sortDescriptorPrototype = NSSortDescriptor(key: rssiColumn.identifier.rawValue, ascending: true)
		clientsTable?.addTableColumn(rssiColumn)
		
		clientsScrollView?.documentView = clientsTable
		clientsScrollView?.borderType = .bezelBorder
		clientsScrollView?.hasVerticalScroller = true
		clientsScrollView?.hasHorizontalScroller = true
		clientsScrollView?.autohidesScrollers = false
		
		clientsTable?.dataSource = self
		clientsTable?.delegate = self
		clientsTable?.allowsMultipleSelection = true
		
		if let _ = clientsScrollView { addSubview(clientsScrollView!) }
		if let _ = continueButton { addSubview(continueButton!) }
		if let _ = backButton { addSubview(backButton!) }
		
		autoresizesSubviews = true
		autoresizingMask = [.width, .height]
		clientsScrollView?.autoresizingMask = [.width, .height]
		continueButton?.autoresizingMask = .minXMargin
	}
	
	@objc func backButton(_ sender: Any?) {
		sniffer?.stop()
		sniffer?.delegate = nil
		sniffer = nil
		(NSApp.delegate as? JWAppDelegate)?.showNetworkList()
	}
	
	@objc func continueButton(_ sender: Any?) {
		let killer = JWClientKiller(frame: bounds, sniffer: sniffer, networks: networks, clients: allClients)
		(NSApp.delegate as? JWAppDelegate)?.push(killer, direction: .forward)
	}
	
	// MARK: - Table View -
	func numberOfRows(in tableView: NSTableView) -> Int {
		return allClients.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let client = allClients[row]
		if tableColumn?.identifier.rawValue == "device" {
			return MACToString(client.macAddress)
		} else if tableColumn?.identifier.rawValue == "bssid" {
			return MACToString(client.bssid)
		} else if tableColumn?.identifier.rawValue == "count" {
			return NSNumber(value: client.packetCount)
		} else if tableColumn?.identifier.rawValue == "enabled" {
			return NSNumber(value: client.enabled)
		} else if tableColumn?.identifier.rawValue == "rssi" {
			return NSNumber(value: client.rssi)
		}
		return nil
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		let client = allClients[row]
		if tableColumn?.identifier.rawValue == "enabled" {
			client.enabled = (object as? NSNumber)?.boolValue ?? false
		}
	}

	func tableView(_ tableView: NSTableView, dataCellFor tableColumn: NSTableColumn?, row: Int) -> NSCell? {
		if tableColumn?.identifier.rawValue == "enabled" {
			let cell = NSButtonCell()
			cell.setButtonType(.switch)
			cell.title = ""
			return cell
		}
		return nil
	}
	
	// MARK: - WiFi -
	func includesBSSID(_ bssid: UnsafePointer<UInt8>?) -> Bool {
		for network in networks {
			if (MACToString(bssid) == network.bssid) {
				return true
			}
		}
		return false
	}
	
	@objc func hopChannel() {
		channelIndex += 1
		if channelIndex >= channels.count {
			channelIndex = 0
		}
		sniffer?.setChannel(channels[channelIndex])
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		
		guard let sortDescriptor = tableView.sortDescriptors.first else {
		   return
		 }
		
		sortAscending = sortDescriptor.ascending
		sortOrder = sortDescriptor.key!
		sortNetworks()
		clientsTable?.reloadData()
	}
	
	@inline(__always) func sortNetworks() {
		if sortOrder == "" { return }
		
		let order: ComparisonResult = sortAscending ? .orderedAscending : .orderedDescending

		switch sortOrder {
			case "enabled": allClients.sort { $0.enabled.description.localizedStandardCompare($1.enabled.description) == order}; break
			case "device": allClients.sort { MACToString($0.macAddress).localizedStandardCompare(MACToString($1.macAddress)) == order}; break
			case "bssid": allClients.sort { MACToString($0.bssid).localizedStandardCompare(MACToString($1.bssid)) == order}; break
			case "count": allClients.sort { String($0.packetCount).localizedStandardCompare(String($1.packetCount)) == order}; break
			case "rssi": allClients.sort { String($0.rssi).localizedStandardCompare(String($1.rssi)) == order}; break
			default: break
		}
		
	}
	
	// MARK: WiFi Sniffer
	func wifiSnifferFailed(toOpenInterface sniffer: ANWiFiSniffer?) {
		runAlert("Interface Error", "Failed to open sniffer interface.")
	}
	
	func wifiSniffer(_ sniffer: ANWiFiSniffer?, failedWithError error: Error?) {
		runAlert("Sniff Error", "Got a sniff error. Please try again.")
	}
	
	func wifiSniffer(_ sniffer: ANWiFiSniffer?, gotPacket packet: AN80211Packet?) {
		var hasClient = false
		var client = [CUnsignedChar](repeating: 0, count: 6)
		var bssid = [CUnsignedChar](repeating: 0, count: 6)
		if packet?.dataFCS() != packet?.calculateFCS() {
			return
		}
		if packet?.macHeader().pointee.frame_control.from_ds == 0 && packet?.macHeader().pointee.frame_control.to_ds == 1 {
			bssid = withUnsafeBytes(of: packet?.macHeader().pointee.mac1) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			if !includesBSSID(bssid) {
				return
			}
			client = withUnsafeBytes(of: packet?.macHeader().pointee.mac2) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			hasClient = true
		} else if packet?.macHeader().pointee.frame_control.from_ds == 0 && packet?.macHeader().pointee.frame_control.to_ds == 0 {
			bssid = withUnsafeBytes(of: packet?.macHeader().pointee.mac3) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			if !includesBSSID(bssid) {
				return
			}
			
			if memcmp(withUnsafeBytes(of: packet?.macHeader().pointee.mac2){$0.baseAddress!}, withUnsafeBytes(of: packet?.macHeader().pointee.mac3){$0.baseAddress!}, 6) != 0 {
				client = withUnsafeBytes(of: packet?.macHeader().pointee.mac2) {
					Array($0.bindMemory(to: CUnsignedChar.self))
				}
				hasClient = true
			}
		} else if packet?.macHeader().pointee.frame_control.from_ds == 1 && packet?.macHeader().pointee.frame_control.to_ds == 0 {
			bssid = withUnsafeBytes(of: packet?.macHeader().pointee.mac2) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			if !includesBSSID(bssid) {
				return
			}
			client = withUnsafeBytes(of: packet?.macHeader().pointee.mac1) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			hasClient = true
		}
		if client[0] == 0x33 && client[1] == 0x33 {
			hasClient = false
		}
		if client[0] == 0x01 && client[1] == 0x00 {
			hasClient = false
		}
		if client[0] == 0xff && client[1] == 0xff {
			hasClient = false
		}
		if hasClient {
			let clientObj = JWClient(mac: client, bssid: bssid)
			if !allClients.contains(clientObj) {
				allClients.append(clientObj)
			} else {
				guard let index = allClients.firstIndex(of: clientObj) else {return}
				let origClient = allClients[index]
				origClient.packetCount += 1
				origClient.rssi = Float(packet!.rssi)
			}
			sortNetworks()
			clientsTable?.reloadData()
		}
	}
	
}
