//
//  AppDelegate+notification.m
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "AppDelegate+notification.h"
#import "PushPlugin.h"
#import <objc/runtime.h>

static char launchNotificationKey;

@implementation AppDelegate (notification)

- (id) getCommandInstance:(NSString*)className
{
    return [self.viewController getCommandInstance:className];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    Method original, swizzled;
    
    original = class_getInstanceMethod(self, @selector(init));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(original, swizzled);
}

- (AppDelegate *)swizzled_init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createNotificationChecker:)
                                                 name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
    
    // This actually calls the original init method over in AppDelegate. Equivilent to calling super
    // on an overrided method, this is not recursive, although it appears that way. neat huh?
    return [self swizzled_init];
}

-(void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type{
    
    //print out the VoIP token. We will use this to test the nofications.
    NSLog(@"Push notifications - AVNS registred");
    PushPlugin *pushHandler = [self getCommandInstance:@"PushPlugin"];
    [pushHandler didRegisterWithToken: credentials.token.description andWithANSType:@"AVNS"];
    
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *) notificationSettings{
    
    NSLog(@"Push notifications - registering Viop - step 2/3");
    //register for voip notifications
    PKPushRegistry *voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    voipRegistry.delegate = self;
    voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    NSLog(@"Push notifications - registering Viop - step 3/3");
    
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
{
    
    [self didReceiveMessage:payload.dictionaryPayload];
    
    UIApplication *application = [UIApplication sharedApplication];
    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)]) {
        appState = application.applicationState;
    }
    
    if (appState == UIApplicationStateBackground) {
        id p = [payload.dictionaryPayload objectForKey:@"aps"];
        NSString *message = [p objectForKey:@"alert"];
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertBody = message;
        localNotification.applicationIconBadgeNumber = 1;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
}


// This code will be called immediately after application:didFinishLaunchingWithOptions:. We need
// to process notifications in cold-start situations
- (void)createNotificationChecker:(NSNotification *)notification
{
    if (notification)
    {
        NSDictionary *launchOptions = [notification userInfo];
        if (launchOptions)
            self.launchNotification = [launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    PushPlugin *pushHandler = [self getCommandInstance:@"PushPlugin"];
    [pushHandler didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    PushPlugin *pushHandler = [self getCommandInstance:@"PushPlugin"];
    [pushHandler didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSLog(@"didReceiveNotification");
    [self didReceiveMessage:userInfo];
    completionHandler(UIBackgroundFetchResultNewData);
    
    
}


- (void)didReceiveMessage:(NSDictionary *)message{
    [self markMessageAsReceived:message];
    
    UIApplication *application = [UIApplication sharedApplication];
    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)]) {
        appState = application.applicationState;
    }
    
    if (appState == UIApplicationStateActive) {
        PushPlugin *pushHandler = [self getCommandInstance:@"PushPlugin"];
        pushHandler.notificationMessage = message;
        pushHandler.isInline = YES;
        [pushHandler notificationReceived];
    } else {
        //save it for later
        self.launchNotification = message;
    }
    
}

- (void)markMessageAsReceived:(NSDictionary *)message
{
    @try {
        //Marking as received
        
        NSString *jsonString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle]
                                                                   pathForResource: @"www/static/config" ofType: @"json"] encoding:NSUTF8StringEncoding error:nil];
        NSError* errorConfig = nil;
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        id conf = [NSJSONSerialization JSONObjectWithData:data options:0 error:&errorConfig];
        if(errorConfig){
            NSLog(@"Marking as received - Error when parsing config: %@",errorConfig.localizedDescription);
        }else{
            id upx = [conf objectForKey:@"upx"];
            NSString *server = [upx objectForKey:@"server"];
            NSString *account = [upx objectForKey:@"account"];
            
            id extra = [message objectForKey:@"extra"];
            NSString *receiverHash = [extra objectForKey:@"receiver_hash"];
            NSString *messageId = [extra objectForKey:@"message_id"];
            
            NSString *urlString = [NSString stringWithFormat:@"%@?action=markPushMessageReceived&api=plain&account=%@&receiver_hash=%@&message_id=%@", server, account, receiverHash, messageId];
            
            NSURL *url = [NSURL URLWithString:urlString];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            NSURLResponse* response;
            NSError* callError = nil;
            
            //Capturing server response
            NSData* result = [NSURLConnection sendSynchronousRequest:request  returningResponse:&response error:&callError];
            if(callError){
                NSLog(@"Marking as received - Error when calling server: %@",callError.localizedDescription);
            }else{
                NSString *responseString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
                NSLog(@"Push message with message_id=%@ and hash=%@ marked as received with response=%@", messageId, receiverHash, responseString);
                
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Marking as received - Exception: %@", exception.name);
    }
    @finally {
        
    }
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    NSLog(@"active");
    
    //zero badge
    application.applicationIconBadgeNumber = 0;
    
    if (self.launchNotification) {
        PushPlugin *pushHandler = [self getCommandInstance:@"PushPlugin"];
        
        pushHandler.notificationMessage = self.launchNotification;
        self.launchNotification = nil;
        [pushHandler performSelectorOnMainThread:@selector(notificationReceived) withObject:pushHandler waitUntilDone:NO];
    }
}

// The accessors use an Associative Reference since you can't define a iVar in a category
// http://developer.apple.com/library/ios/#documentation/cocoa/conceptual/objectivec/Chapters/ocAssociativeReferences.html
- (NSMutableArray *)launchNotification
{
    return objc_getAssociatedObject(self, &launchNotificationKey);
}

- (void)setLaunchNotification:(NSDictionary *)aDictionary
{
    objc_setAssociatedObject(self, &launchNotificationKey, aDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dealloc
{
    self.launchNotification = nil; // clear the association and release the object
}

@end
