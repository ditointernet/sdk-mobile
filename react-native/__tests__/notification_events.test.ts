import {
  isActionClick,
  parseNotificationClick,
  parseNotificationInfo,
  readCustomDataField,
} from '../src/notification_events';

describe('parseNotificationClick', () => {
  it('reads every field the native modules emit', () => {
    const click = parseNotificationClick({
      deeplink: 'myapp://order/42',
      notificationId: 'notif-1',
      reference: 'ref-1',
      logId: 'log-1',
      notificationName: 'campanha de julho',
      userId: 'user-1',
      actionId: 'track_order',
      actionLabel: 'Rastrear',
      customData: { order_id: '42' },
    });

    expect(click).toEqual({
      deeplink: 'myapp://order/42',
      notificationId: 'notif-1',
      reference: 'ref-1',
      logId: 'log-1',
      notificationName: 'campanha de julho',
      userId: 'user-1',
      actionId: 'track_order',
      actionLabel: 'Rastrear',
      customData: { order_id: '42' },
    });
  });

  it('fills missing fields with empty values instead of throwing', () => {
    // O clique que nasce na notificação nativa não carrega log_id nem notification_name:
    // o PendingIntent do botão não transporta esses campos.
    const click = parseNotificationClick({
      deeplink: 'myapp://home',
      notificationId: 'notif-1',
      reference: 'ref-1',
    });

    expect(click.logId).toBe('');
    expect(click.notificationName).toBe('');
    expect(click.userId).toBe('');
    expect(click.actionId).toBe('');
    expect(click.customData).toEqual({});
  });

  it('survives a null or non-object event', () => {
    expect(parseNotificationClick(null).deeplink).toBe('');
    expect(parseNotificationClick('nope').notificationId).toBe('');
    expect(parseNotificationClick([1, 2]).reference).toBe('');
  });

  it('accepts customData as the raw JSON string an older native SDK returns', () => {
    const click = parseNotificationClick({
      customData: '{"order_id":"42","tier":"gold"}',
    });

    expect(click.customData).toEqual({ order_id: '42', tier: 'gold' });
  });
});

describe('isActionClick', () => {
  it('is true only when a button was tapped', () => {
    const body = parseNotificationClick({ deeplink: 'myapp://home' });
    const button = parseNotificationClick({
      deeplink: 'myapp://order/42',
      actionId: 'track_order',
      actionLabel: 'Rastrear',
    });

    expect(isActionClick(body)).toBe(false);
    expect(isActionClick(button)).toBe(true);
  });
});

describe('parseNotificationInfo', () => {
  it('turns the epoch millis both platforms emit into a Date', () => {
    const info = parseNotificationInfo({
      id: 'row-1',
      notificationId: 'notif-1',
      reference: 'ref-1',
      title: 'Seu pedido chegou',
      message: 'Confira os detalhes',
      link: 'myapp://order/42',
      receivedAt: 1753747200000,
      isRead: true,
      image: 'https://cdn.dito.com.br/push/hero.png',
      customData: { order_id: '42' },
    });

    expect(info.receivedAt.getTime()).toBe(1753747200000);
    expect(info.isRead).toBe(true);
    expect(info.image).toBe('https://cdn.dito.com.br/push/hero.png');
    expect(info.customData).toEqual({ order_id: '42' });
  });

  it('defaults isRead to false for anything that is not exactly true', () => {
    expect(parseNotificationInfo({ isRead: 0 }).isRead).toBe(false);
    expect(parseNotificationInfo({ isRead: 'true' }).isRead).toBe(false);
    expect(parseNotificationInfo({}).isRead).toBe(false);
  });

  it('falls back to the epoch when receivedAt is missing or unusable', () => {
    expect(parseNotificationInfo({}).receivedAt.getTime()).toBe(0);
    expect(parseNotificationInfo({ receivedAt: 'abc' }).receivedAt.getTime()).toBe(0);
    // A bridge do React entrega número; uma string numérica ainda é aceita.
    expect(parseNotificationInfo({ receivedAt: '1753747200000' }).receivedAt.getTime()).toBe(
      1753747200000,
    );
  });
});

describe('readCustomDataField', () => {
  it('stringifies non-string values so the map type holds', () => {
    expect(readCustomDataField({ points: 1500, vip: true })).toEqual({
      points: '1500',
      vip: 'true',
    });
  });

  it('drops null values and blank keys', () => {
    expect(readCustomDataField({ a: null, '  ': 'x', b: 'y' })).toEqual({ b: 'y' });
  });

  it('returns an empty map for anything it cannot read', () => {
    expect(readCustomDataField(null)).toEqual({});
    expect(readCustomDataField(undefined)).toEqual({});
    expect(readCustomDataField('not json')).toEqual({});
    expect(readCustomDataField(42)).toEqual({});
  });
});
