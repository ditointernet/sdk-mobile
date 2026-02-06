import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Linking,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';

import * as Device from 'expo-device';
import * as Notifications from 'expo-notifications';

import DitoSdk, { addNotificationClickListener } from '../src';

type InputFieldProps = {
  label: string;
  onChangeText: (value: string) => void;
  placeholder: string;
  value: string;
};

function InputField({
  label,
  onChangeText,
  placeholder,
  value,
}: InputFieldProps) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={styles.input}
        placeholder={placeholder}
        value={value}
        onChangeText={onChangeText}
      />
    </View>
  );
}

type SectionProps = {
  children: React.ReactNode;
  title: string;
};

function Section({ children, title }: SectionProps) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

type PushPermissionStatus =
  | 'undetermined'
  | 'denied'
  | 'granted'
  | 'unknown';

function mapPermissionStatus(
  status: Notifications.PermissionStatus,
): PushPermissionStatus {
  if (status === Notifications.PermissionStatus.GRANTED) return 'granted';
  if (status === Notifications.PermissionStatus.DENIED) return 'denied';
  if (status === Notifications.PermissionStatus.UNDETERMINED)
    return 'undetermined';
  return 'unknown';
}

export default function App() {
  const [status, setStatus] = useState('Not initialized');
  const [isInitialized, setIsInitialized] = useState(false);
  const [platformVersion, setPlatformVersion] = useState<string | null>(null);
  const [debugEnabled, setDebugEnabled] = useState(false);

  const [apiKey, setApiKey] = useState('');
  const [apiSecret, setApiSecret] = useState('');

  const [userId, setUserId] = useState('user123');
  const [userName, setUserName] = useState('John Doe');
  const [userEmail, setUserEmail] = useState('john@example.com');

  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [zip, setZip] = useState('');
  const [country, setCountry] = useState('');

  const [action, setAction] = useState('purchase');
  const [token, setToken] = useState('');
  const [pushPermission, setPushPermission] =
    useState<PushPermissionStatus>('undetermined');
  const [pushCount, setPushCount] = useState(0);
  const [pushTokenType, setPushTokenType] = useState<string | null>(null);

  const foregroundSubscription = useRef<Notifications.EventSubscription | null>(
    null,
  );
  const responseSubscription = useRef<Notifications.EventSubscription | null>(
    null,
  );

  const customData = useMemo(() => {
    const data: Record<string, string> = {};
    if (phone) data.phone = phone;
    if (address) data.address = address;
    if (city) data.city = city;
    if (state) data.state = state;
    if (zip) data.zip = zip;
    if (country) data.country = country;
    return data;
  }, [address, city, country, phone, state, zip]);

  useEffect(() => {
    Notifications.setNotificationHandler({
      handleNotification: async () => ({
        shouldPlaySound: true,
        shouldSetBadge: false,
        shouldShowAlert: true,
      }),
    });

    const setup = async () => {
      const settings = await Notifications.getPermissionsAsync();
      setPushPermission(mapPermissionStatus(settings.status));
    };

    setup().catch(() => {});

    foregroundSubscription.current =
      Notifications.addNotificationReceivedListener(() => {
        setPushCount((current) => current + 1);
      });

    const unsubscribe = addNotificationClickListener((event) => {
      if (!event.deeplink) return;
      Alert.alert('Deeplink', event.deeplink, [
        { text: 'Abrir', onPress: () => Linking.openURL(event.deeplink) },
        { text: 'OK' },
      ]);
    });

    responseSubscription.current =
      Notifications.addNotificationResponseReceivedListener(async (response) => {
        const data = response.notification.request.content.data as Record<string, unknown>;
        await DitoSdk.handleNotificationClick(data);
      });

    return () => {
      unsubscribe();
      foregroundSubscription.current?.remove();
      responseSubscription.current?.remove();
    };
  }, []);

  const handleInitialize = async () => {
    try {
      await DitoSdk.initialize({ apiKey, apiSecret });
      setStatus('Initialized successfully');
      setIsInitialized(true);
      Alert.alert('Success', 'SDK initialized successfully');
    } catch (error: any) {
      setStatus(`Initialization failed: ${error.message}`);
      Alert.alert('Error', error.message);
    }
  };

  const handleRequestPushPermission = async () => {
    try {
      const response = await Notifications.requestPermissionsAsync();
      setPushPermission(mapPermissionStatus(response.status));
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleLoadPushToken = async () => {
    if (!Device.isDevice) {
      Alert.alert('Error', 'Push token requires a physical device');
      return;
    }

    try {
      const settings = await Notifications.getPermissionsAsync();
      const mapped = mapPermissionStatus(settings.status);
      setPushPermission(mapped);

      if (mapped !== 'granted') {
        Alert.alert('Error', 'Push permission is not granted');
        return;
      }

      const tokenResponse = await Notifications.getDevicePushTokenAsync();
      const rawToken =
        typeof tokenResponse.data === 'string'
          ? tokenResponse.data
          : String(tokenResponse.data);
      setPushTokenType(tokenResponse.type);
      setToken(rawToken);
      Alert.alert('Success', 'Push token loaded');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleLoadPlatformVersion = async () => {
    try {
      const version = await DitoSdk.getPlatformVersion();
      setPlatformVersion(version);
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleToggleDebug = async (value: boolean) => {
    setDebugEnabled(value);
    try {
      await DitoSdk.setDebugMode(value);
    } catch (error: any) {
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
        customData: Object.keys(customData).length ? customData : undefined,
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
          platform: 'Expo',
          timestamp: new Date().toISOString(),
        },
      });
      Alert.alert('Success', 'Event tracked successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleRegisterToken = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    if (!token.trim()) {
      Alert.alert('Error', 'Token is required');
      return;
    }

    try {
      await DitoSdk.registerDeviceToken(token);
      Alert.alert('Success', 'Device token registered successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleUnregisterToken = async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Please initialize SDK first');
      return;
    }

    if (!token.trim()) {
      Alert.alert('Error', 'Token is required');
      return;
    }

    try {
      await DitoSdk.unregisterDeviceToken(token);
      Alert.alert('Success', 'Device token unregistered successfully');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.header}>
          <Text style={styles.title}>Dito SDK (Expo)</Text>
          <Text style={styles.subtitle}>Example application</Text>
        </View>

        <Section title="Status">
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Initialized</Text>
            <Text style={styles.statusValue}>
              {isInitialized ? 'Yes' : 'No'}
            </Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Status</Text>
            <Text style={styles.statusValue}>{status}</Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Platform</Text>
            <Text style={styles.statusValue}>
              {platformVersion ?? 'Not loaded'}
            </Text>
          </View>
          <View style={styles.rowActions}>
            <TouchableOpacity
              style={styles.secondaryButton}
              onPress={handleLoadPlatformVersion}
            >
              <Text style={styles.secondaryButtonText}>
                Get platform version
              </Text>
            </TouchableOpacity>
          </View>
          <View style={styles.switchRow}>
            <Text style={styles.statusLabel}>Debug mode</Text>
            <Switch
              value={debugEnabled}
              onValueChange={handleToggleDebug}
            />
          </View>
        </Section>

        <Section title="Initialize">
          <InputField
            label="API Key"
            placeholder="DITO_API_KEY"
            value={apiKey}
            onChangeText={setApiKey}
          />
          <InputField
            label="API Secret"
            placeholder="DITO_API_SECRET"
            value={apiSecret}
            onChangeText={setApiSecret}
          />
          <TouchableOpacity style={styles.primaryButton} onPress={handleInitialize}>
            <Text style={styles.primaryButtonText}>Initialize SDK</Text>
          </TouchableOpacity>
        </Section>

        <Section title="Identify user">
          <InputField
            label="User ID"
            placeholder="user123"
            value={userId}
            onChangeText={setUserId}
          />
          <InputField
            label="Name"
            placeholder="John Doe"
            value={userName}
            onChangeText={setUserName}
          />
          <InputField
            label="Email"
            placeholder="john@example.com"
            value={userEmail}
            onChangeText={setUserEmail}
          />

          <Text style={styles.subsectionTitle}>Custom data</Text>
          <InputField
            label="Phone"
            placeholder="(optional)"
            value={phone}
            onChangeText={setPhone}
          />
          <InputField
            label="Address"
            placeholder="(optional)"
            value={address}
            onChangeText={setAddress}
          />
          <InputField
            label="City"
            placeholder="(optional)"
            value={city}
            onChangeText={setCity}
          />
          <InputField
            label="State"
            placeholder="(optional)"
            value={state}
            onChangeText={setState}
          />
          <InputField
            label="Zip"
            placeholder="(optional)"
            value={zip}
            onChangeText={setZip}
          />
          <InputField
            label="Country"
            placeholder="(optional)"
            value={country}
            onChangeText={setCountry}
          />

          <TouchableOpacity style={styles.primaryButton} onPress={handleIdentify}>
            <Text style={styles.primaryButtonText}>Identify</Text>
          </TouchableOpacity>
        </Section>

        <Section title="Track event">
          <InputField
            label="Action"
            placeholder="purchase"
            value={action}
            onChangeText={setAction}
          />
          <TouchableOpacity style={styles.primaryButton} onPress={handleTrack}>
            <Text style={styles.primaryButtonText}>Track</Text>
          </TouchableOpacity>
        </Section>

        <Section title="Push token">
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Permission</Text>
            <Text style={styles.statusValue}>{pushPermission}</Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Foreground received</Text>
            <Text style={styles.statusValue}>{String(pushCount)}</Text>
          </View>
          <InputField
            label="Device push token"
            placeholder="Load token or paste here"
            value={token}
            onChangeText={setToken}
          />
          <View style={styles.rowActions}>
            <TouchableOpacity
              style={styles.secondaryButton}
              onPress={handleRequestPushPermission}
            >
              <Text style={styles.secondaryButtonText}>Request permission</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.secondaryButton}
              onPress={handleLoadPushToken}
            >
              <Text style={styles.secondaryButtonText}>
                Load token{pushTokenType ? ` (${pushTokenType})` : ''}
              </Text>
            </TouchableOpacity>
          </View>
          <View style={styles.rowActions}>
            <TouchableOpacity
              style={styles.secondaryButton}
              onPress={handleRegisterToken}
            >
              <Text style={styles.secondaryButtonText}>Register</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.dangerButton}
              onPress={handleUnregisterToken}
            >
              <Text style={styles.dangerButtonText}>Unregister</Text>
            </TouchableOpacity>
          </View>
        </Section>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0b1220',
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 48,
  },
  header: {
    marginBottom: 16,
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#121b2f',
  },
  title: {
    color: '#eaf1ff',
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    marginTop: 4,
    color: '#a9b7d5',
    fontSize: 14,
  },
  section: {
    marginTop: 14,
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#121b2f',
  },
  sectionTitle: {
    color: '#eaf1ff',
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 12,
  },
  subsectionTitle: {
    marginTop: 8,
    marginBottom: 10,
    color: '#a9b7d5',
    fontSize: 14,
    fontWeight: '600',
  },
  field: {
    marginBottom: 12,
  },
  label: {
    color: '#a9b7d5',
    fontSize: 12,
    marginBottom: 6,
  },
  input: {
    borderWidth: 1,
    borderColor: '#273553',
    backgroundColor: '#0b1220',
    color: '#eaf1ff',
    borderRadius: 12,
    padding: 12,
    fontSize: 16,
  },
  primaryButton: {
    backgroundColor: '#2563eb',
    padding: 14,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 8,
  },
  primaryButtonText: {
    color: '#eaf1ff',
    fontSize: 16,
    fontWeight: '700',
  },
  secondaryButton: {
    backgroundColor: '#1f2a44',
    padding: 12,
    borderRadius: 12,
    alignItems: 'center',
    flex: 1,
  },
  secondaryButtonText: {
    color: '#eaf1ff',
    fontSize: 14,
    fontWeight: '600',
  },
  dangerButton: {
    backgroundColor: '#7f1d1d',
    padding: 12,
    borderRadius: 12,
    alignItems: 'center',
    flex: 1,
  },
  dangerButtonText: {
    color: '#fee2e2',
    fontSize: 14,
    fontWeight: '700',
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  statusLabel: {
    color: '#a9b7d5',
    fontSize: 14,
    fontWeight: '600',
  },
  statusValue: {
    color: '#eaf1ff',
    fontSize: 14,
    fontWeight: '600',
    flexShrink: 1,
    marginLeft: 12,
    textAlign: 'right',
  },
  rowActions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 10,
  },
  switchRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
  },
});

