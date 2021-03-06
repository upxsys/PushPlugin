/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PushPlugin.h"

const uint8_t pingString[] = "ping\n";
const uint8_t pongString[] = "pong\n";

@implementation PushPlugin

@synthesize notificationMessage;
@synthesize isInline;

@synthesize callbackId;
@synthesize notificationCallbackId;
@synthesize callback;


- (void)unregister:(CDVInvokedUrlCommand*)command;
{
    self.callbackId = command.callbackId;
    
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    [self successWithMessage:@"unregistered"];
}



- (void)register:(CDVInvokedUrlCommand*)command;
{
    self.callbackId = command.callbackId;
    
    NSMutableDictionary* options = [command.arguments objectAtIndex:0];
    
    isInline = NO;
    self.callback = [options objectForKey:@"ecb"];
    
    id iOSConfiguration = [options objectForKey:@"iOSConfigurations"];
    
    
    NSLog(@"Push notifications - starting registration");
    if([self isVoipCapable] && [[iOSConfiguration objectForKey:@"AVNS"] boolValue]){
        NSLog(@"Push notifications - is Viop");
        [self registerForVoip:options];
    }else if([[iOSConfiguration objectForKey:@"APNS"] boolValue]){
        NSLog(@"Push notifications - is Push");
        [self registerForPush:options];
    }else{
        NSLog(@"Push notifications - none possible");
    }
    
    
    if (notificationMessage)            // if there is a pending startup notification
        [self notificationReceived];    // go ahead and process it
}

- (BOOL)isVoipCapable
{
    return floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_0;
}

- (void)registerForVoip:(NSMutableDictionary*) options
{
    NSLog(@"Push notifications - registering Viop - step 1/3");
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound) categories:nil]];
}

- (void)registerForPush:(NSMutableDictionary*) options
{
    NSLog(@"Push notifications - registering Push");
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    UIUserNotificationType UserNotificationTypes = UIUserNotificationTypeNone;
#endif
    UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeNone;
    
    id badgeArg = [options objectForKey:@"badge"];
    id soundArg = [options objectForKey:@"sound"];
    id alertArg = [options objectForKey:@"alert"];
    
    if ([badgeArg isKindOfClass:[NSString class]])
    {
        if ([badgeArg isEqualToString:@"true"]) {
            notificationTypes |= UIRemoteNotificationTypeBadge;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            UserNotificationTypes |= UIUserNotificationTypeBadge;
#endif
        }
    }
    else if ([badgeArg boolValue]) {
        notificationTypes |= UIRemoteNotificationTypeBadge;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        UserNotificationTypes |= UIUserNotificationTypeBadge;
#endif
    }
    
    if ([soundArg isKindOfClass:[NSString class]])
    {
        if ([soundArg isEqualToString:@"true"]) {
            notificationTypes |= UIRemoteNotificationTypeSound;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            UserNotificationTypes |= UIUserNotificationTypeSound;
#endif
        }
    }
    else if ([soundArg boolValue]) {
        notificationTypes |= UIRemoteNotificationTypeSound;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        UserNotificationTypes |= UIUserNotificationTypeSound;
#endif
    }
    
    if ([alertArg isKindOfClass:[NSString class]])
    {
        if ([alertArg isEqualToString:@"true"]) {
            notificationTypes |= UIRemoteNotificationTypeAlert;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            UserNotificationTypes |= UIUserNotificationTypeAlert;
#endif
        }
    }
    else if ([alertArg boolValue]) {
        notificationTypes |= UIRemoteNotificationTypeAlert;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        UserNotificationTypes |= UIUserNotificationTypeAlert;
#endif
    }
    
    notificationTypes |= UIRemoteNotificationTypeNewsstandContentAvailability;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    UserNotificationTypes |= UIUserNotificationActivationModeBackground;
#endif
    
    if (notificationTypes == UIRemoteNotificationTypeNone)
        NSLog(@"PushPlugin.register: Push notification type is set to none");
    
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    if ([[UIApplication sharedApplication]respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UserNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
    }
#else
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
#endif
    
    
}

/*
 - (void)isEnabled:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {
 UIRemoteNotificationType type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
 NSString *jsStatement = [NSString stringWithFormat:@"navigator.PushPlugin.isEnabled = %d;", type != UIRemoteNotificationTypeNone];
 NSLog(@"JSStatement %@",jsStatement);
 }
 */

- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    NSLog(@"Push notifications - APNS registred");
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    NSString *token = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<"withString:@""]
                        stringByReplacingOccurrencesOfString:@">" withString:@""]
                       stringByReplacingOccurrencesOfString: @" " withString: @""];
    [results setValue:token forKey:@"deviceToken"];
    
#if !TARGET_IPHONE_SIMULATOR
    // Get Bundle Info for Remote Registration (handy if you have more than one app)
    [results setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"] forKey:@"appName"];
    [results setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"appVersion"];
    
    // Check what Notifications the user has turned on.  We registered for all three, but they may have manually disabled some or all of them.
    NSUInteger rntypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    
    // Set the defaults to disabled unless we find otherwise...
    NSString *pushBadge = @"disabled";
    NSString *pushAlert = @"disabled";
    NSString *pushSound = @"disabled";
    
    // Check what Registered Types are turned on. This is a bit tricky since if two are enabled, and one is off, it will return a number 2... not telling you which
    // one is actually disabled. So we are literally checking to see if rnTypes matches what is turned on, instead of by number. The "tricky" part is that the
    // single notification types will only match if they are the ONLY one enabled.  Likewise, when we are checking for a pair of notifications, it will only be
    // true if those two notifications are on.  This is why the code is written this way
    if(rntypes & UIRemoteNotificationTypeBadge){
        pushBadge = @"enabled";
    }
    if(rntypes & UIRemoteNotificationTypeAlert) {
        pushAlert = @"enabled";
    }
    if(rntypes & UIRemoteNotificationTypeSound) {
        pushSound = @"enabled";
    }
    
    [results setValue:pushBadge forKey:@"pushBadge"];
    [results setValue:pushAlert forKey:@"pushAlert"];
    [results setValue:pushSound forKey:@"pushSound"];
    
    // Get the users Device Model, Display Name, Token & Version Number
    UIDevice *dev = [UIDevice currentDevice];
    [results setValue:dev.name forKey:@"deviceName"];
    [results setValue:dev.model forKey:@"deviceModel"];
    [results setValue:dev.systemVersion forKey:@"deviceSystemVersion"];
    
    [self didRegisterWithToken:[deviceToken description] andWithANSType:@"APNS"];
#endif
}

- (void) didRegisterWithToken:(NSString *)token andWithANSType:(NSString *) ANSType
{
    NSLog(@"Push notifications - Token is: %@", token);
    NSString *tokenFormatted = [[[token stringByReplacingOccurrencesOfString:@"<"withString:@""]
                                 stringByReplacingOccurrencesOfString:@">" withString:@""]
                                stringByReplacingOccurrencesOfString: @" " withString: @""];
    
    [self successWithMessage:[NSString stringWithFormat:@"%@,%@", tokenFormatted, ANSType]];
}

- (void)didFailToRegisterForRemotseNotificationsWithError:(NSError *)error
{
    [self failWithMessage:@"" withError:error];
}

- (void)notificationReceived {
    NSLog(@"Notification received");
    
    if (notificationMessage && self.callback)
    {
        NSMutableString *jsonStr = [NSMutableString stringWithString:@"{"];
        
        [self parseDictionary:notificationMessage intoJSON:jsonStr];
        
        if (isInline)
        {
            [jsonStr appendFormat:@"foreground:\"%d\"", 1];
            isInline = NO;
        }
        else
            [jsonStr appendFormat:@"foreground:\"%d\"", 0];
        
        [jsonStr appendString:@"}"];
        
        NSLog(@"Msg: %@", jsonStr);
        
        NSString * jsCallBack = [NSString stringWithFormat:@"%@(%@);", self.callback, jsonStr];
       
        if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
            // Cordova-iOS pre-4
            [self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsCallBack waitUntilDone:NO];
        } else {
            // Cordova-iOS 4+
            [self.webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsCallBack waitUntilDone:NO];
        }
        
        
        self.notificationMessage = nil;
    }
}

// reentrant method to drill down and surface all sub-dictionaries' key/value pairs into the top level json
-(void)parseDictionary:(NSDictionary *)inDictionary intoJSON:(NSMutableString *)jsonString
{
    NSArray         *keys = [inDictionary allKeys];
    NSString        *key;
    
    for (key in keys)
    {
        id thisObject = [inDictionary objectForKey:key];
        
        if ([thisObject isKindOfClass:[NSDictionary class]])
            [self parseDictionary:thisObject intoJSON:jsonString];
        else if ([thisObject isKindOfClass:[NSString class]])
            [jsonString appendFormat:@"\"%@\":\"%@\",",
             key,
             [[[[inDictionary objectForKey:key]
                stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
               stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
              stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]];
        else {
            [jsonString appendFormat:@"\"%@\":\"%@\",", key, [inDictionary objectForKey:key]];
        }
    }
}

- (void)setApplicationIconBadgeNumber:(CDVInvokedUrlCommand *)command {
    
    self.callbackId = command.callbackId;
    
    NSMutableDictionary* options = [command.arguments objectAtIndex:0];
    int badge = [[options objectForKey:@"badge"] intValue] ?: 0;
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badge];
    
    [self successWithMessage:[NSString stringWithFormat:@"app badge count set to %d", badge]];
}
-(void)successWithMessage:(NSString *)message
{
    NSLog(@"Push notifications - Successful");
    if (self.callbackId != nil)
    {
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
        [self.commandDelegate sendPluginResult:commandResult callbackId:self.callbackId];
    }
}

-(void)failWithMessage:(NSString *)message withError:(NSError *)error
{
    NSLog(@"Push notifications - Failed");
    NSString        *errorMessage = (error) ? [NSString stringWithFormat:@"%@ - %@", message, [error localizedDescription]] : message;
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
    
    [self.commandDelegate sendPluginResult:commandResult callbackId:self.callbackId];
}

- (void)addEvent:(NSString *)event
{
    [self.communicationLog appendFormat:@"%@\n", event];
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive)
    {
        NSLog(@"App is active. New event: %@", event);
    }
    else
    {
        NSLog(@"App is backgrounded. New event: %@", event);
    }
}

- (void)connectToVOIPServer:(NSString *)server andPort:(NSString *) port{
    if (!self.inputStream)
    {
        // 1
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)(server), [port intValue], &readStream, &writeStream);
        
        // 2
        self.sentPing = NO;
        self.communicationLog = [[NSMutableString alloc] init];
        self.inputStream = (__bridge_transfer NSInputStream *)readStream;
        self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;
        [self.inputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
        
        // 3
        [self.inputStream setDelegate:self];
        [self.outputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        // 4
        [self.inputStream open];
        [self.outputStream open];
        
        // 5
        [[UIApplication sharedApplication] setKeepAliveTimeout:600 handler:^{
            if (self.outputStream)
            {
                [self.outputStream write:pingString maxLength:strlen((char*)pingString)];
                [self addEvent:@"Ping sent"];
            }
        }];
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventNone:
            // do nothing.
            break;
            
        case NSStreamEventEndEncountered:
            [self addEvent:@"Connection Closed"];
            break;
            
        case NSStreamEventErrorOccurred:
            [self addEvent:[NSString stringWithFormat:@"Had error: %@", aStream.streamError]];
            break;
            
        case NSStreamEventHasBytesAvailable:
            if (aStream == self.inputStream)
            {
                uint8_t buffer[1024];
                NSInteger bytesRead = [self.inputStream read:buffer maxLength:1024];
                NSString *stringRead = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
                stringRead = [stringRead stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                
                [self addEvent:[NSString stringWithFormat:@"Received: %@", stringRead]];
                
                if ([stringRead isEqualToString:@"notify"])
                {
                    UILocalNotification *notification = [[UILocalNotification alloc] init];
                    notification.alertBody = @"New VOIP call";
                    notification.alertAction = @"Answer";
                    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                }
                else if ([stringRead isEqualToString:@"ping"])
                {
                    [self.outputStream write:pongString maxLength:strlen((char*)pongString)];
                }
            }
            break;
            
        case NSStreamEventHasSpaceAvailable:
            if (aStream == self.outputStream && !self.sentPing)
            {
                self.sentPing = YES;
                if (aStream == self.outputStream)
                {
                    [self.outputStream write:pingString maxLength:strlen((char*)pingString)];
                    [self addEvent:@"Ping sent"];
                }
            }
            break;
            
        case NSStreamEventOpenCompleted:
            if (aStream == self.inputStream)
            {
                [self addEvent:@"Connection Opened"];
            }
            break;
            
        default:
            break;
    }
}


@end
