//
//  ANTrafficGatherer.m
//  JamWiFi
//
//  Created by Alex Nichol on 7/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ANTrafficGatherer.h"
#import "ANAppDelegate.h"
#import "ANClientKiller.h"

@implementation ANTrafficGatherer

- (id)initWithFrame:(NSRect)frameRect sniffer:(ANWiFiSniffer *)aSniffer networks:(NSArray *)theNetworks {
    if ((self = [super initWithFrame:frameRect])) {
        [self configureUI];
        
        networks = theNetworks;
        sniffer = aSniffer;
        allClients = [[NSMutableArray alloc] init];
        
        NSMutableArray * mChannels = [[NSMutableArray alloc] init];
        for (CWNetwork * net in networks) {
            if (![mChannels containsObject:net.wlanChannel]) {
                [mChannels addObject:net.wlanChannel];
            }
        }
        channels = [mChannels copy];
        channelIndex = -1;
        [self hopChannel];
        hopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(hopChannel) userInfo:nil repeats:YES];
        
        sniffer.delegate = self;
        [sniffer start];
    }
    return self;
}

- (void)configureUI {
    NSRect frame = self.frame;
    clientsScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 52, frame.size.width - 20, frame.size.height - 62)];
    clientsTable = [[NSTableView alloc] initWithFrame:[[clientsScrollView contentView] bounds]];
    backButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, 100, 24)];
    continueButton = [[NSButton alloc] initWithFrame:NSMakeRect(frame.size.width - 110, 10, 100, 24)];
	
	backButton.bezelStyle = NSRoundedBezelStyle;
	backButton.title = @"Back";
    backButton.font = [NSFont systemFontOfSize:13];
    backButton.target = self;
    backButton.action = @selector(backButton:);
    
    continueButton.bezelStyle = NSRoundedBezelStyle;
    continueButton.title = @"Do It!";
	continueButton.font = [NSFont systemFontOfSize:13];
	continueButton.target = self;
	continueButton.action = @selector(continueButton:);
    
    NSTableColumn * checkedColumn = [[NSTableColumn alloc] initWithIdentifier:@"enabled"];
	checkedColumn.headerCell.stringValue = @"Jam";
	checkedColumn.width = 30;
	checkedColumn.editable = YES;
    [clientsTable addTableColumn:checkedColumn];
    
    NSTableColumn * stationColumn = [[NSTableColumn alloc] initWithIdentifier:@"device"];
	stationColumn.headerCell.stringValue = @"Device";
	stationColumn.width = 120;
	stationColumn.editable = NO;
    [clientsTable addTableColumn:stationColumn];
    
    NSTableColumn * bssidColumn = [[NSTableColumn alloc] initWithIdentifier:@"bssid"];
	bssidColumn.headerCell.stringValue = @"BSSID";
	bssidColumn.width = 120;
	bssidColumn.editable = NO;
    [clientsTable addTableColumn:bssidColumn];
    
    NSTableColumn * packetsColumn = [[NSTableColumn alloc] initWithIdentifier:@"count"];
	packetsColumn.headerCell.stringValue = @"Packets";
	packetsColumn.width = 120;
	packetsColumn.editable = NO;
    [clientsTable addTableColumn:packetsColumn];
    
    NSTableColumn * rssiColumn = [[NSTableColumn alloc] initWithIdentifier:@"rssi"];
	rssiColumn.headerCell.stringValue = @"RSSI";
	rssiColumn.width = 70;
	rssiColumn.editable = NO;
    [clientsTable addTableColumn:rssiColumn];
    
    [clientsScrollView setDocumentView:clientsTable];
    [clientsScrollView setBorderType:NSBezelBorder];
    [clientsScrollView setHasVerticalScroller:YES];
    [clientsScrollView setHasHorizontalScroller:YES];
    [clientsScrollView setAutohidesScrollers:NO];
    
    clientsTable.dataSource = self;
    clientsTable.delegate = self;
    clientsTable.allowsMultipleSelection = YES;
    
    [self addSubview:clientsScrollView];
    [self addSubview:continueButton];
    [self addSubview:backButton];
    
    [self setAutoresizesSubviews:YES];
    [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [clientsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [continueButton setAutoresizingMask:(NSViewMinXMargin)];
}

- (void)backButton:(id)sender {
    [sniffer stop];
	sniffer.delegate = nil;
    sniffer = nil;
    [(ANAppDelegate *)[NSApp delegate] showNetworkList];
}

- (void)continueButton:(id)sender {
    ANClientKiller *killer = [[ANClientKiller alloc] initWithFrame:self.bounds sniffer:sniffer networks:networks clients:allClients];
    [(ANAppDelegate *)[NSApp delegate] pushView:killer direction:ANViewSlideDirectionForward];
}

#pragma mark - Table View -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return allClients.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ANClient * client = [allClients objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:@"station"]) {
        return MACToString(client.macAddress);
    } else if ([[tableColumn identifier] isEqualToString:@"bssid"]) {
        return MACToString(client.bssid);
    } else if ([[tableColumn identifier] isEqualToString:@"count"]) {
        return [NSNumber numberWithInt:client.packetCount];
    } else if ([[tableColumn identifier] isEqualToString:@"enabled"]) {
        return [NSNumber numberWithBool:client.enabled];
    } else if ([[tableColumn identifier] isEqualToString:@"rssi"]) {
        return [NSNumber numberWithFloat:client.rssi];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    ANClient * client = [allClients objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:@"enabled"]) {
        client.enabled = [object boolValue];
    }
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([[tableColumn identifier] isEqualToString:@"enabled"]) {
        NSButtonCell * cell = [NSButtonCell new];
        cell.buttonType = NSSwitchButton;
        cell.title = @"";
        return cell;
    }
    return nil;
}

#pragma mark - WiFi -

- (BOOL)includesBSSID:(const unsigned char *)bssid {
    for (CWNetwork * network in networks) {
		if ([MACToString(bssid) isEqualToString:network.bssid]) {
			return YES;
		}
    }
    return NO;
}

- (void)hopChannel {
    channelIndex += 1;
    if (channelIndex >= channels.count) {
        channelIndex = 0;
    }
    [sniffer setChannel:[channels objectAtIndex:channelIndex]];
}

#pragma mark WiFi Sniffer

- (void)wifiSnifferFailedToOpenInterface:(ANWiFiSniffer *)sniffer {
    NSRunAlertPanel(@"Interface Error", @"Failed to open sniffer interface.", @"OK", nil, nil);
}

- (void)wifiSniffer:(ANWiFiSniffer *)sniffer failedWithError:(NSError *)error {
    NSRunAlertPanel(@"Sniff Error", @"Got a sniff error. Please try again.", @"OK", nil, nil);
}

- (void)wifiSniffer:(ANWiFiSniffer *)sniffer gotPacket:(AN80211Packet *)packet {
    BOOL hasClient = NO;
    unsigned char client[6];
    unsigned char bssid[6];
    if ([packet dataFCS] != [packet calculateFCS]) return;
    if (packet.macHeader->frame_control.from_ds == 0 && packet.macHeader->frame_control.to_ds == 1) {
        memcpy(bssid, packet.macHeader->mac1, 6);
        if (![self includesBSSID:bssid]) return;
        memcpy(client, packet.macHeader->mac2, 6);
        hasClient = YES;
    } else if (packet.macHeader->frame_control.from_ds == 0 && packet.macHeader->frame_control.to_ds == 0) {
        memcpy(bssid, packet.macHeader->mac3, 6);
        if (![self includesBSSID:bssid]) return;
        if (memcmp(packet.macHeader->mac2, packet.macHeader->mac3, 6) != 0) {
            memcpy(client, packet.macHeader->mac2, 6);
            hasClient = YES;
        }
    } else if (packet.macHeader->frame_control.from_ds == 1 && packet.macHeader->frame_control.to_ds == 0) {
        memcpy(bssid, packet.macHeader->mac2, 6);
        if (![self includesBSSID:bssid]) return;
        memcpy(client, packet.macHeader->mac1, 6);
        hasClient = YES;
    }
    if (client[0] == 0x33 && client[1] == 0x33) hasClient = NO;
    if (client[0] == 0x01 && client[1] == 0x00) hasClient = NO;
    if (client[0] == 0xFF && client[1] == 0xFF) hasClient = NO;
    if (hasClient) {
        ANClient * clientObj = [[ANClient alloc] initWithMac:client bssid:bssid];
        if (![allClients containsObject:clientObj]) {
            [allClients addObject:clientObj];
        } else {
            ANClient * origClient = [allClients objectAtIndex:[allClients indexOfObject:clientObj]];
            origClient.packetCount += 1;
            origClient.rssi = (float)packet.rssi;
        }
        [clientsTable reloadData];
    }
}

@end
