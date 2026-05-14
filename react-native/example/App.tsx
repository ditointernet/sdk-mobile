import React, { useEffect, useState } from 'react';
import {
  Alert,
  FlatList,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import DitoSdk, {
  type DitoNotificationClick,
  type DitoNotificationInfo,
  type DitoNotificationOptions,
} from '../src/index';

function parseOptionalInteger(value: string): number | undefined {
  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }

  const parsed = Number.parseInt(trimmed, 10);
  return Number.isNaN(parsed) ? undefined : parsed;
}

export default function App() {
  const [status, setStatus] = useState('Not initialized');
  const [isInitialized, setIsInitialized] = useState(false);
  const [apiKey, setApiKey] = useState('your-api-key');
  const [apiSecret, setApiSecret] = useState('your-api-secret');
  const [userId, setUserId] = useState('user123');
  const [userName, setUserName] = useState('John Doe');
  const [userEmail, setUserEmail] = useState('john@example.com');
  const [action, setAction] = useState('purchase');
  const [token, setToken] = useState('fcm-device-token');
  const [smallIconResId, setSmallIconResId] = useState('');
  const [largeIconResId, setLargeIconResId] = useState('');
  const [soundResourceName, setSoundResourceName] = useState('');
  const [badgeEnabled, setBadgeEnabled] = useState(true);
  const [accentColor, setAccentColor] = useState('');
  const [deeplink, setDeeplink] = useState('dito-example://notification');
  const [lastNotificationClick, setLastNotificationClick] = useState('No notification click received');
  const [notifications, setNotifications] = useState<DitoNotificationInfo[]>([]);

  const loadNotifications = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    try {
      const items = await DitoSdk.getNotifications();
      setNotifications(items);
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  useEffect(() => {
    const subscription = DitoSdk.addNotificationClickListener(
      (event: DitoNotificationClick) => {
        const value =
          event.deeplink ||
          event.notificationName ||
          event.notificationId ||
          'Notification click received';
        setLastNotificationClick(value);
        Alert.alert('Notification click', value);
      },
    );

    return () => subscription.remove();
  }, []);

  const handleMarkAsRead = async (id: string) => {
    try {
      await DitoSdk.markNotificationAsRead(id);
      await loadNotifications();
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleInitialize = async () => {
    try {
      await DitoSdk.initialize({
        apiKey,
        apiSecret,
      });
      setStatus('Initialized successfully');
      setIsInitialized(true);
      Alert.alert('Success', 'SDK initialized successfully');
    } catch (error: any) {
      setStatus(`Initialization failed: ${error.message}`);
      Alert.alert('Error', error.message);
    }
  };

  const handleIdentify = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    try {
      await DitoSdk.identify({
        id: userId,
        name: userName || undefined,
        email: userEmail || undefined,
        customData: {
          source: 'example_app',
          timestamp: new Date().toISOString(),
        },
      });
      Alert.alert('Success', 'User identified successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleTrack = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    try {
      await DitoSdk.track({
        action,
        data: {
          timestamp: new Date().toISOString(),
          platform: 'React Native',
        },
      });
      Alert.alert('Success', 'Event tracked successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleSetNotificationOptions = async () => {
    const options: DitoNotificationOptions = {
      accentColor: parseOptionalInteger(accentColor),
      badgeEnabled,
      largeIconResId: parseOptionalInteger(largeIconResId),
      smallIconResId: parseOptionalInteger(smallIconResId),
      soundResourceName: soundResourceName || undefined,
    };
    try {
      await DitoSdk.setNotificationOptions(options);
      Alert.alert('Success', 'Notification Options aplicadas');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleNotificationClick = async () => {
    try {
      const handled = await DitoSdk.handleNotificationClick({
        deeplink,
        link: deeplink,
        notification: 'example-notification-id',
        notification_name: 'Example notification',
      });
      setLastNotificationClick(
        handled ? deeplink : 'Notification click was not handled',
      );
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleRegisterToken = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    try {
      await DitoSdk.registerDeviceToken(token);
      Alert.alert('Success', 'Device token registered successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.section}>
          <Text style={styles.title}>Dito SDK Example</Text>
          <View style={styles.statusCard}>
            <Text style={styles.statusLabel}>Status:</Text>
            <Text style={styles.statusValue}>{status}</Text>
            <Text style={styles.statusLabel}>Initialized:</Text>
            <Text style={styles.statusValue}>{isInitialized ? 'Yes' : 'No'}</Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Initialize SDK</Text>
          <TextInput
            style={styles.input}
            placeholder="API Key"
            value={apiKey}
            onChangeText={setApiKey}
          />
          <TextInput
            style={styles.input}
            placeholder="API Secret"
            value={apiSecret}
            onChangeText={setApiSecret}
            secureTextEntry
          />
          <TouchableOpacity style={styles.button} onPress={handleInitialize}>
            <Text style={styles.buttonText}>Initialize</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Identify User</Text>
          <TextInput
            style={styles.input}
            placeholder="User ID"
            value={userId}
            onChangeText={setUserId}
          />
          <TextInput
            style={styles.input}
            placeholder="Name (optional)"
            value={userName}
            onChangeText={setUserName}
          />
          <TextInput
            style={styles.input}
            placeholder="Email (optional)"
            value={userEmail}
            onChangeText={setUserEmail}
            keyboardType="email-address"
          />
          <TouchableOpacity style={styles.button} onPress={handleIdentify}>
            <Text style={styles.buttonText}>Identify User</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Track Event</Text>
          <TextInput
            style={styles.input}
            placeholder="Action"
            value={action}
            onChangeText={setAction}
          />
          <TouchableOpacity style={styles.button} onPress={handleTrack}>
            <Text style={styles.buttonText}>Track Event</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Register Device Token</Text>
          <TextInput
            style={styles.input}
            placeholder="FCM Device Token"
            value={token}
            onChangeText={setToken}
          />
          <TouchableOpacity style={styles.button} onPress={handleRegisterToken}>
            <Text style={styles.buttonText}>Register Token</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notification Click / Deeplink</Text>
          <Text style={styles.statusValue}>{lastNotificationClick}</Text>
          <TextInput
            style={styles.input}
            placeholder="Deeplink"
            value={deeplink}
            onChangeText={setDeeplink}
          />
          <TouchableOpacity style={styles.button} onPress={handleNotificationClick}>
            <Text style={styles.buttonText}>Handle Notification Click</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notification Options</Text>
          <TextInput
            style={styles.input}
            placeholder="Small Icon Res ID (Android, number)"
            value={smallIconResId}
            onChangeText={setSmallIconResId}
            keyboardType="numeric"
          />
          <TextInput
            style={styles.input}
            placeholder="Large Icon Res ID (Android, number)"
            value={largeIconResId}
            onChangeText={setLargeIconResId}
            keyboardType="numeric"
          />
          <TextInput
            style={styles.input}
            placeholder="Sound Resource Name"
            value={soundResourceName}
            onChangeText={setSoundResourceName}
          />
          <TextInput
            style={styles.input}
            placeholder="Accent Color (Android color int)"
            value={accentColor}
            onChangeText={setAccentColor}
            keyboardType="numeric"
          />
          <TouchableOpacity
            style={[styles.button, styles.secondaryButton]}
            onPress={() => setBadgeEnabled(value => !value)}
          >
            <Text style={styles.buttonText}>
              Badge Enabled: {badgeEnabled ? 'Yes' : 'No'}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={handleSetNotificationOptions}>
            <Text style={styles.buttonText}>Aplicar Notification Options</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Notification Inbox</Text>
          <TouchableOpacity style={[styles.button, styles.reloadButton]} onPress={loadNotifications}>
            <Text style={styles.buttonText}>Recarregar inbox</Text>
          </TouchableOpacity>
          {notifications.length === 0 ? (
            <Text style={styles.emptyText}>Nenhuma notificação salva</Text>
          ) : (
            <FlatList
              data={notifications}
              keyExtractor={item => item.id}
              scrollEnabled={false}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.notificationCard}
                  onPress={() => handleMarkAsRead(item.id)}
                >
                  <View style={styles.notificationHeader}>
                    <Text style={styles.notificationTitle}>{item.title}</Text>
                    {!item.isRead && (
                      <Text style={styles.unreadBadge}>● Não lida</Text>
                    )}
                  </View>
                  <Text style={styles.notificationMessage}>{item.message}</Text>
                  <Text style={styles.notificationDate}>
                    {new Date(item.receivedAt).toLocaleString()}
                  </Text>
                </TouchableOpacity>
              )}
            />
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    padding: 16,
  },
  section: {
    marginBottom: 24,
    backgroundColor: '#fff',
    padding: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 16,
    textAlign: 'center',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  statusCard: {
    backgroundColor: '#f0f0f0',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  statusLabel: {
    fontSize: 14,
    fontWeight: '600',
    marginTop: 4,
  },
  statusValue: {
    fontSize: 14,
    color: '#666',
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
    fontSize: 16,
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  reloadButton: {
    marginBottom: 12,
  },
  secondaryButton: {
    backgroundColor: '#5856D6',
    marginBottom: 12,
  },
  emptyText: {
    color: '#999',
    textAlign: 'center',
    marginTop: 8,
    fontSize: 14,
  },
  notificationCard: {
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e0e0e0',
    marginTop: 8,
    padding: 12,
  },
  notificationHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  notificationTitle: {
    flex: 1,
    fontSize: 15,
    fontWeight: '600',
  },
  unreadBadge: {
    color: '#e53935',
    fontSize: 12,
    fontWeight: '700',
    marginLeft: 8,
  },
  notificationMessage: {
    color: '#444',
    fontSize: 14,
    marginBottom: 4,
  },
  notificationDate: {
    color: '#999',
    fontSize: 12,
  },
});
