//
//  AppDelegate+notification.h
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "AppDelegate.h"
#import <PushKit/PushKit.h>

@interface AppDelegate (notification)
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;
- (void)applicationDidBecomeActive:(UIApplication *)application;
- (id) getCommandInstance:(NSString*)className;

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(NSString *)type;
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type;
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type;
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *) notificationSettings;


@property (nonatomic, retain) NSDictionary	*launchNotification;

@end
