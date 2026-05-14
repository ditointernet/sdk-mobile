import {
  NativeEventEmitter,
  type EmitterSubscription,
} from 'react-native';

export interface DitoNotificationClick {
  deeplink: string;
  logId: string;
  notificationId: string;
  notificationName: string;
  reference: string;
  userId: string;
}

export type DitoNotificationClickListener = (
  event: DitoNotificationClick,
) => void;

const NOTIFICATION_CLICK_EVENT = 'DitoNotificationClick';
const NATIVE_MODULE_UNAVAILABLE_MESSAGE =
  'DitoSdkModule native module is not available. Make sure you have properly linked the native module.';

function createNotificationEventEmitter(): NativeEventEmitter {
  const { DitoSdkModule } = require('react-native').NativeModules;
  if (!DitoSdkModule) {
    throw new Error(NATIVE_MODULE_UNAVAILABLE_MESSAGE);
  }

  return new NativeEventEmitter(DitoSdkModule);
}

class DitoNotificationListener {
  static addNotificationClickListener(
    listener: DitoNotificationClickListener,
  ): EmitterSubscription {
    return createNotificationEventEmitter().addListener(
      NOTIFICATION_CLICK_EVENT,
      listener,
    );
  }
}

export { NOTIFICATION_CLICK_EVENT };
export default DitoNotificationListener;
