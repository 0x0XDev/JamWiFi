//
//  HelperFunc.m
//  JamWiFi
//
//  Created by Leonardos Jr. on 20.07.19.
//

#import "HelperFunc.h"

void runAlert(NSString*title, NSString*message) {
	NSRunAlertPanel(title, message, @"OK", nil, nil);
}
