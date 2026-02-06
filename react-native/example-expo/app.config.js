import 'dotenv/config';

export default {
  name: 'Dito SDK Expo Example',
  slug: 'dito-sdk-expo-example',
  version: '1.0.0',
  platforms: ['ios', 'android'],
  plugins: [
    'expo-notifications',
    [
      '@ditointernet/dito-sdk',
      {
        apiKey: process.env.DITO_API_KEY ?? '',
        apiSecret: process.env.DITO_API_SECRET ?? '',
      },
    ],
  ],
};

