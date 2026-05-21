import React, { useState } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  Alert,
} from 'react-native';
import DitoSdk from '../src/index';

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
});
