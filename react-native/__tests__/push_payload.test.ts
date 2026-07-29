import {
  parsePushPayload,
  hasRichContent,
  MAX_PUSH_ACTIONS,
} from '../src/push_payload';

/**
 * Payload como o channel-senders emite: `actions` e `custom_data` são strings JSON dentro
 * do data map, e o link de cada botão já vem resolvido para o OS do token.
 */
const ACTIONS_JSON = JSON.stringify([
  {
    id: 'comprar_agora',
    label: 'Comprar agora',
    link: 'https://loja.brand.com/promo',
  },
  { id: 'ver_promocao', label: 'Ver promoção', link: 'brandapp://promo' },
]);

describe('parsePushPayload', () => {
  it('extrai os três campos ricos de um payload completo', () => {
    const payload = parsePushPayload({
      channel: 'DITO',
      image: 'https://cdn.brand.com/promo.png',
      actions: ACTIONS_JSON,
      custom_data: '{"nivel_programa":"ouro","id_pedido":"12345"}',
    });

    expect(payload.image).toBe('https://cdn.brand.com/promo.png');
    expect(payload.actions).toHaveLength(2);
    expect(payload.actions[0]).toEqual({
      id: 'comprar_agora',
      label: 'Comprar agora',
      link: 'https://loja.brand.com/promo',
    });
    expect(payload.actions[1]?.link).toBe('brandapp://promo');
    expect(payload.customData).toEqual({
      nivel_programa: 'ouro',
      id_pedido: '12345',
    });
    expect(hasRichContent(payload)).toBe(true);
  });

  it('push legado sem campos novos devolve payload vazio', () => {
    const payload = parsePushPayload({
      channel: 'DITO',
      title: 'Oi',
      data: '{"notification":"1","reference":"2"}',
    });

    expect(payload.image).toBe('');
    expect(payload.actions).toEqual([]);
    expect(payload.customData).toEqual({});
    expect(hasRichContent(payload)).toBe(false);
  });

  it('não lança com entrada nula, undefined ou vazia', () => {
    expect(hasRichContent(parsePushPayload(null))).toBe(false);
    expect(hasRichContent(parsePushPayload(undefined))).toBe(false);
    expect(hasRichContent(parsePushPayload({}))).toBe(false);
  });

  it('não confunde o blob legado data.data com nível aninhado', () => {
    // `data.data` é uma string JSON, não um objeto. Se o parser a tratasse como
    // nível aninhado, procuraria as chaves ricas dentro dela.
    const payload = parsePushPayload({
      data: JSON.stringify({ image: 'https://nao-e-daqui.com/x.png' }),
    });

    expect(payload.image).toBe('');
  });

  it('acha os campos num nível data aninhado de verdade', () => {
    const payload = parsePushPayload({
      data: { image: 'https://cdn.brand.com/promo.png' },
    });

    expect(payload.image).toBe('https://cdn.brand.com/promo.png');
  });

  describe('parsing defensivo', () => {
    it('JSON inválido em actions devolve lista vazia e não contamina os outros campos', () => {
      const payload = parsePushPayload({
        actions: '[{"id":"quebrado",',
        image: 'https://cdn.brand.com/promo.png',
      });

      expect(payload.actions).toEqual([]);
      expect(payload.image).toBe('https://cdn.brand.com/promo.png');
    });

    it('JSON inválido em custom_data devolve objeto vazio', () => {
      expect(parsePushPayload({ custom_data: 'não é json' }).customData).toEqual(
        {},
      );
    });

    it(`corta em ${MAX_PUSH_ACTIONS} botões, o teto do contrato`, () => {
      const payload = parsePushPayload({
        actions: JSON.stringify([
          { id: 'a', label: 'A', link: 'x' },
          { id: 'b', label: 'B', link: 'y' },
          { id: 'c', label: 'C', link: 'z' },
        ]),
      });

      expect(payload.actions.map((a) => a.id)).toEqual(['a', 'b']);
    });

    it('descarta botão com id ou label vazio e deduplica por id', () => {
      const payload = parsePushPayload({
        actions: JSON.stringify([
          { id: '', label: 'Sem id', link: 'x' },
          { id: 'sem_label', label: '', link: 'y' },
          { id: 'ok', label: 'Primeiro', link: 'z' },
          { id: 'ok', label: 'Duplicado', link: 'w' },
        ]),
      });

      expect(payload.actions).toHaveLength(1);
      expect(payload.actions[0]?.label).toBe('Primeiro');
    });

    it('botão sem link é mantido com link vazio', () => {
      const payload = parsePushPayload({
        actions: JSON.stringify([{ id: 'ok', label: 'Sem link' }]),
      });

      expect(payload.actions[0]?.link).toBe('');
    });

    it('valor não-string em custom_data é convertido, não descartado', () => {
      const payload = parsePushPayload({
        custom_data: { pontos: 1500, ativo: true },
      });

      expect(payload.customData).toEqual({ pontos: '1500', ativo: 'true' });
    });

    it('aceita estrutura já decodificada em actions', () => {
      const payload = parsePushPayload({
        actions: [{ id: 'ok', label: 'Pronto', link: 'x' }],
      });

      expect(payload.actions[0]?.id).toBe('ok');
    });
  });
});
