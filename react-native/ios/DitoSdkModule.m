#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

// A superclasse declarada aqui tem que ser a mesma da classe Swift. O módulo passou a
// herdar de RCTEventEmitter para emitir o evento de clique em notificação, e é dela que
// vêm os `addListener:`/`removeListeners:` que o NativeEventEmitter do JavaScript chama —
// não precisam ser redeclarados abaixo.
@interface RCT_EXTERN_MODULE(DitoSdkModule, RCTEventEmitter)

RCT_EXTERN_METHOD(initialize:(NSString *)apiKey
                  apiSecret:(NSString *)apiSecret
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(identify:(NSString *)id
                  name:(NSString *)name
                  email:(NSString *)email
                  customData:(NSDictionary *)customData
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(track:(NSString *)action
                  data:(NSDictionary *)data
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(registerDeviceToken:(NSString *)token
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(unregisterDeviceToken:(NSString *)token
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getInitialNotificationClick:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getNotifications:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(markNotificationAsRead:(NSString *)id
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
