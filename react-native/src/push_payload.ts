/**
 * Botão de ação de uma notificação rica.
 *
 * O backend já resolve o `link` para o sistema operacional do device, então cada botão
 * carrega exatamente um destino — não existe par android/ios aqui.
 */
export interface DitoPushAction {
  /** Identificador do botão (`^[a-z0-9_]{1,32}$`), único dentro do push. */
  id: string;
  /** Texto exibido no botão (até 25 caracteres). */
  label: string;
  /** URL ou deeplink aberto ao tocar no botão. */
  link: string;
}

/** Campos ricos de um push da Dito, extraídos do data map do FCM. */
export interface DitoPushPayload {
  /** URL da imagem (`data.image`); vazio quando a campanha não tem imagem. */
  image: string;
  /** Botões declarados em `data.actions`, no máximo `MAX_PUSH_ACTIONS`. */
  actions: DitoPushAction[];
  /** `data.custom_data`, com as variáveis já substituídas pelo backend. */
  customData: Record<string, string>;
}

/** O contrato garante no máximo 2 botões; o excedente é descartado. */
export const MAX_PUSH_ACTIONS = 2;

const EMPTY_PAYLOAD: DitoPushPayload = Object.freeze({
  image: '',
  actions: Object.freeze([]) as unknown as DitoPushAction[],
  customData: Object.freeze({}) as Record<string, string>,
});

/**
 * Extrai imagem, botões e custom data de um data map de push.
 *
 * O uso normal é dentro do handler de mensagem da biblioteca de FCM do app:
 *
 * ```typescript
 * messaging().onMessage(async (message) => {
 *   const payload = parsePushPayload(message.data);
 *   if (hasRichContent(payload)) {
 *     console.log('imagem=', payload.image, 'botões=', payload.actions.length);
 *   }
 * });
 * ```
 *
 * O parsing é deliberadamente leniente: `actions` e `custom_data` viajam como strings
 * JSON dentro do data map, e um payload malformado devolve o campo vazio em vez de
 * lançar — mesma postura dos parsers nativos, porque derrubar o handler de push por
 * causa de um campo opcional é pior que ignorá-lo.
 */
export function parsePushPayload(
  data?: Record<string, unknown> | null,
): DitoPushPayload {
  if (!data || typeof data !== 'object') {
    return EMPTY_PAYLOAD;
  }

  return {
    image: readString(data, 'image'),
    actions: parseActions(readRaw(data, 'actions')),
    customData: parseCustomData(readRaw(data, 'custom_data')),
  };
}

/** True quando o push traz pelo menos um dos três campos ricos. */
export function hasRichContent(payload: DitoPushPayload): boolean {
  return (
    payload.image.length > 0 ||
    payload.actions.length > 0 ||
    Object.keys(payload.customData).length > 0
  );
}

/**
 * Procura `key` no mapa e, se não achar, dentro de um `data` aninhado.
 *
 * O blob legado `data.data` é uma **string** JSON, não um objeto, então a checagem de
 * tipo garante que ele nunca é confundido com o nível aninhado.
 */
function readRaw(data: Record<string, unknown>, key: string): unknown {
  const direct = data[key];
  if (direct !== undefined && direct !== null) {
    return direct;
  }
  const nested = data.data;
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    return (nested as Record<string, unknown>)[key];
  }
  return undefined;
}

function readString(data: Record<string, unknown>, key: string): string {
  const value = readRaw(data, key);
  return typeof value === 'string' ? value.trim() : '';
}

function parseActions(raw: unknown): DitoPushAction[] {
  const decoded = decode(raw);
  if (!Array.isArray(decoded)) {
    return [];
  }

  const actions: DitoPushAction[] = [];
  const seen = new Set<string>();
  for (const item of decoded) {
    if (actions.length >= MAX_PUSH_ACTIONS) {
      break;
    }
    if (!item || typeof item !== 'object') {
      continue;
    }
    const entry = item as Record<string, unknown>;
    const id = stringField(entry, 'id');
    const label = stringField(entry, 'label');
    if (!id || !label || seen.has(id)) {
      continue;
    }
    seen.add(id);
    actions.push({ id, label, link: stringField(entry, 'link') });
  }
  return actions;
}

function parseCustomData(raw: unknown): Record<string, string> {
  const decoded = decode(raw);
  if (!decoded || typeof decoded !== 'object' || Array.isArray(decoded)) {
    return {};
  }

  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(decoded as Record<string, unknown>)) {
    const name = key.trim();
    if (!name || value === null || value === undefined) {
      continue;
    }
    result[name] = typeof value === 'string' ? value : String(value);
  }
  return result;
}

/**
 * Aceita tanto a string JSON que o backend emite quanto uma estrutura já decodificada,
 * porque bibliotecas de FCM diferentes entregam o data map de formas diferentes.
 */
function decode(raw: unknown): unknown {
  if (raw === null || raw === undefined) {
    return undefined;
  }
  if (typeof raw === 'object') {
    return raw;
  }
  if (typeof raw !== 'string') {
    return undefined;
  }
  const text = raw.trim();
  if (!text) {
    return undefined;
  }
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

function stringField(entry: Record<string, unknown>, key: string): string {
  const value = entry[key];
  if (value === null || value === undefined) {
    return '';
  }
  return String(value).trim();
}
