


import Foundation

class JWClient: NSObject {
	var packetCount = 0
	var deauthsSent = 0
	private(set) var macAddress: [CUnsignedChar] = []
	private(set) var bssid: [CUnsignedChar] = []
	var rssi: Float = 0.0
	var enabled = false
	
	init(mac: UnsafePointer<CUnsignedChar>?, bssid aBSSID: UnsafePointer<CUnsignedChar>?) {
		
		super.init()
		macAddress = [CUnsignedChar](repeating: 0, count: 6)
		bssid = [CUnsignedChar](repeating: 0, count: 6)
		packetCount = 0
		memcpy(&macAddress, mac, 6)
		memcpy(&bssid, aBSSID, 6)
		enabled = true
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		if !(object is JWClient) {
			return false
		}
		let client = object as? JWClient
		if memcmp(client!.bssid, bssid, 6) == 0 && memcmp(client!.macAddress, macAddress, 6) == 0 {
			return true
		}
		
		return false
	}
	
//	deinit {
//		free(&macAddress)
//		free(&bssid)
//	}
}
