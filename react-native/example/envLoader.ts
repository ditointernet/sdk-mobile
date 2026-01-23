import Config from 'react-native-config';

export const EnvLoader = {
  get: (key: string): string => {
    return Config[key] || '';
  },

  getOrEmpty: (key: string): string => {
    return Config[key] || '';
  }
};
