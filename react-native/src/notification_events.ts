import { parsePushPayload } from './push_payload';

/** Nome do evento emitido pelos módulos nativos no `RCTDeviceEventEmitter`. */
export const NOTIFICATION_CLICK_EVENT = 'dito_notification_click';

/**
 * Interação do usuário com uma notificação da Dito.
 *
 * Cobre os dois caminhos de clique — o toque no corpo da notificação e o toque em um
 * botão de ação — e é o único lugar onde o JavaScript consegue distinguir os dois.
 */
export interface DitoNotificationClick {
  /**
   * Destino a abrir para esta interação.
   *
   * Em um toque em botão já é o link do próprio botão, resolvido para o sistema
   * operacional do device pelo backend; em um toque no corpo é o deeplink da
   * notificação. Não é preciso escolher entre destinos aqui.
   */
  deeplink: string;
  notificationId: string;
  reference: string;
  logId: string;
  notificationName: string;
  userId: string;
  /** Id do botão tocado; vazio quando o clique foi no corpo da notificação. */
  actionId: string;
  /** Label do botão tocado; vazio quando o clique foi no corpo da notificação. */
  actionLabel: string;
  /** Custom data da campanha, com as variáveis já substituídas pelo backend. */
  customData: Record<string, string>;
}

/** Notificação guardada no inbox local da SDK. */
export interface DitoNotificationInfo {
  id: string;
  notificationId: string;
  reference: string;
  title: string;
  message: string;
  link: string;
  receivedAt: Date;
  isRead: boolean;
  /** URL da imagem do push; vazio quando a campanha não tem imagem. */
  image: string;
  /** Custom data da campanha já decodificada; vazia quando não há custom data. */
  customData: Record<string, string>;
}

/** True quando o clique veio de um botão de ação, não do corpo da notificação. */
export function isActionClick(click: DitoNotificationClick): boolean {
  return click.actionId.length > 0;
}

/**
 * Converte o mapa que o módulo nativo emite em [DitoNotificationClick].
 *
 * O parsing é tolerante de propósito: o evento atravessa a bridge como JSON solto e um
 * campo ausente vira string vazia em vez de derrubar o listener do app.
 */
export function parseNotificationClick(raw: unknown): DitoNotificationClick {
  const map = asRecord(raw);
  return {
    deeplink: readString(map, 'deeplink'),
    notificationId: readString(map, 'notificationId'),
    reference: readString(map, 'reference'),
    logId: readString(map, 'logId'),
    notificationName: readString(map, 'notificationName'),
    userId: readString(map, 'userId'),
    actionId: readString(map, 'actionId'),
    actionLabel: readString(map, 'actionLabel'),
    customData: readCustomDataField(map.customData),
  };
}

/**
 * Converte um registro do inbox nativo em [DitoNotificationInfo].
 *
 * `receivedAt` chega como epoch em milissegundos nas duas plataformas — o Android guarda
 * um `Long` e o iOS converte o `Date` antes de emitir.
 */
export function parseNotificationInfo(raw: unknown): DitoNotificationInfo {
  const map = asRecord(raw);
  return {
    id: readString(map, 'id'),
    notificationId: readString(map, 'notificationId'),
    reference: readString(map, 'reference'),
    title: readString(map, 'title'),
    message: readString(map, 'message'),
    link: readString(map, 'link'),
    receivedAt: new Date(readNumber(map, 'receivedAt')),
    isRead: map.isRead === true,
    image: readString(map, 'image'),
    customData: readCustomDataField(map.customData),
  };
}

/**
 * Normaliza o `customData` que chega da bridge nativa.
 *
 * Os dois módulos entregam um mapa pronto, mas o parser também aceita a string JSON
 * crua: um SDK nativo mais antigo que este pacote ainda devolve a string, e nesse caso
 * o parser de push rico já sabe decodificá-la.
 */
export function readCustomDataField(raw: unknown): Record<string, string> {
  if (raw === null || raw === undefined) {
    return {};
  }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    const result: Record<string, string> = {};
    for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
      const name = key.trim();
      if (!name || value === null || value === undefined) {
        continue;
      }
      result[name] = typeof value === 'string' ? value : String(value);
    }
    return result;
  }
  return parsePushPayload({ custom_data: raw }).customData;
}

function asRecord(raw: unknown): Record<string, unknown> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {};
  }
  return raw as Record<string, unknown>;
}

function readString(map: Record<string, unknown>, key: string): string {
  const value = map[key];
  if (value === null || value === undefined) {
    return '';
  }
  return typeof value === 'string' ? value : String(value);
}

function readNumber(map: Record<string, unknown>, key: string): number {
  const value = map[key];
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}
