const {
  withAndroidManifest,
  withInfoPlist,
} = require('@expo/config-plugins');

function upsertUsesPermission(manifest, permission) {
  const permissions = manifest['uses-permission'] ?? [];

  const alreadyExists = permissions.some(
    (item) => item?.$?.['android:name'] === permission,
  );

  if (!alreadyExists) {
    permissions.push({ $: { 'android:name': permission } });
  }

  manifest['uses-permission'] = permissions;
}

function upsertMetaData(application, name, value) {
  const metaData = application['meta-data'] ?? [];

  const existing = metaData.find((item) => item?.$?.['android:name'] === name);
  if (existing) {
    existing.$['android:value'] = value;
    application['meta-data'] = metaData;
    return;
  }

  metaData.push({ $: { 'android:name': name, 'android:value': value } });
  application['meta-data'] = metaData;
}

function withDitoAndroid(config, props) {
  return withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults;
    const manifest = androidManifest.manifest ?? {};
    const application = manifest.application?.[0];

    if (application) {
      upsertMetaData(application, 'br.com.dito.API_KEY', props.apiKey);
      upsertMetaData(application, 'br.com.dito.API_SECRET', props.apiSecret);
    }

    upsertUsesPermission(manifest, 'android.permission.INTERNET');
    upsertUsesPermission(manifest, 'android.permission.POST_NOTIFICATIONS');

    androidManifest.manifest = manifest;
    config.modResults = androidManifest;
    return config;
  });
}

function withDitoIOS(config) {
  return withInfoPlist(config, (config) => {
    const modes = config.modResults.UIBackgroundModes ?? [];
    if (!modes.includes('remote-notification')) {
      config.modResults.UIBackgroundModes = [...modes, 'remote-notification'];
    }
    return config;
  });
}

module.exports = function withDitoSdk(config, props) {
  if (
    !props ||
    typeof props.apiKey !== 'string' ||
    typeof props.apiSecret !== 'string' ||
    props.apiKey.length === 0 ||
    props.apiSecret.length === 0
  ) {
    return config;
  }

  config = withDitoAndroid(config, props);
  config = withDitoIOS(config);
  return config;
};

