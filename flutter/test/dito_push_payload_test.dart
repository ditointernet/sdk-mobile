import 'dart:convert';

import 'package:dito_sdk/dito_notification_info.dart';
import 'package:dito_sdk/dito_notification_listener.dart';
import 'package:dito_sdk/dito_push_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payload como o channel-senders emite: `actions` e `custom_data` são strings JSON
/// dentro do data map, e o link de cada botão já vem resolvido para o OS do token.
const _actionsJson = '['
    '{"id":"comprar_agora","label":"Comprar agora","link":"https://loja.brand.com/promo"},'
    '{"id":"ver_promocao","label":"Ver promoção","link":"brandapp://promo"}'
    ']';

void main() {
  group('DitoPushPayload.fromData', () {
    test('extrai os três campos ricos de um payload completo', () {
      final payload = DitoPushPayload.fromData({
        'channel': 'DITO',
        'image': 'https://cdn.brand.com/promo.png',
        'actions': _actionsJson,
        'custom_data': '{"nivel_programa":"ouro","id_pedido":"12345"}',
      });

      expect(payload.image, 'https://cdn.brand.com/promo.png');
      expect(payload.actions, hasLength(2));
      expect(payload.actions.first.id, 'comprar_agora');
      expect(payload.actions.first.label, 'Comprar agora');
      expect(payload.actions.first.link, 'https://loja.brand.com/promo');
      expect(payload.actions.last.link, 'brandapp://promo');
      expect(payload.customData, {
        'nivel_programa': 'ouro',
        'id_pedido': '12345',
      });
      expect(payload.hasRichContent, isTrue);
    });

    test('push legado sem campos novos devolve payload vazio', () {
      final payload = DitoPushPayload.fromData({
        'channel': 'DITO',
        'title': 'Oi',
        'message': 'Tudo bem?',
        'data': '{"notification":"1","reference":"2"}',
      });

      expect(payload.image, isEmpty);
      expect(payload.actions, isEmpty);
      expect(payload.customData, isEmpty);
      expect(payload.hasRichContent, isFalse);
    });

    test('mapa nulo ou vazio não lança', () {
      expect(DitoPushPayload.fromData(null).hasRichContent, isFalse);
      expect(DitoPushPayload.fromData({}).hasRichContent, isFalse);
    });

    test('não confunde o blob legado data.data com nível aninhado', () {
      // `data.data` é uma string JSON, não um mapa. Se o parser a tratasse como
      // nível aninhado, procuraria as chaves ricas dentro dela e quebraria.
      final payload = DitoPushPayload.fromData({
        'data': jsonEncode({'image': 'https://nao-e-daqui.com/x.png'}),
      });

      expect(payload.image, isEmpty);
    });

    test('acha os campos num nível data aninhado de verdade', () {
      final payload = DitoPushPayload.fromData({
        'data': {'image': 'https://cdn.brand.com/promo.png'},
      });

      expect(payload.image, 'https://cdn.brand.com/promo.png');
    });

    group('parsing defensivo', () {
      test('JSON inválido em actions devolve lista vazia, sem lançar', () {
        final payload = DitoPushPayload.fromData({
          'actions': '[{"id":"quebrado",',
          'image': 'https://cdn.brand.com/promo.png',
        });

        expect(payload.actions, isEmpty);
        // O campo ruim não contamina os outros.
        expect(payload.image, 'https://cdn.brand.com/promo.png');
      });

      test('JSON inválido em custom_data devolve mapa vazio', () {
        final payload = DitoPushPayload.fromData({'custom_data': 'não é json'});
        expect(payload.customData, isEmpty);
      });

      test('corta em 2 botões, o teto do contrato', () {
        final payload = DitoPushPayload.fromData({
          'actions': jsonEncode([
            {'id': 'a', 'label': 'A', 'link': 'x'},
            {'id': 'b', 'label': 'B', 'link': 'y'},
            {'id': 'c', 'label': 'C', 'link': 'z'},
          ]),
        });

        expect(payload.actions.map((a) => a.id), ['a', 'b']);
      });

      test('descarta botão com id ou label vazio e deduplica por id', () {
        final payload = DitoPushPayload.fromData({
          'actions': jsonEncode([
            {'id': '', 'label': 'Sem id', 'link': 'x'},
            {'id': 'sem_label', 'label': '', 'link': 'y'},
            {'id': 'ok', 'label': 'Primeiro', 'link': 'z'},
            {'id': 'ok', 'label': 'Duplicado', 'link': 'w'},
          ]),
        });

        expect(payload.actions, hasLength(1));
        expect(payload.actions.single.label, 'Primeiro');
      });

      test('botão sem link é mantido com link vazio', () {
        // O SDK nativo faz o mesmo: o botão aparece e o toque cai no deeplink
        // da notificação, em vez do botão desaparecer sem explicação.
        final payload = DitoPushPayload.fromData({
          'actions': jsonEncode([
            {'id': 'ok', 'label': 'Sem link'},
          ]),
        });

        expect(payload.actions.single.link, isEmpty);
      });

      test('valor não-string em custom_data é convertido, não descartado', () {
        final payload = DitoPushPayload.fromData({
          'custom_data': {'pontos': 1500, 'ativo': true},
        });

        expect(payload.customData, {'pontos': '1500', 'ativo': 'true'});
      });

      test('aceita estrutura já decodificada em actions', () {
        final payload = DitoPushPayload.fromData({
          'actions': [
            {'id': 'ok', 'label': 'Pronto', 'link': 'x'},
          ],
        });

        expect(payload.actions.single.id, 'ok');
      });

      test('a lista de actions devolvida é imutável', () {
        final payload = DitoPushPayload.fromData({'actions': _actionsJson});
        expect(
          () => payload.actions.add(
            const DitoPushAction(id: 'x', label: 'X', link: 'y'),
          ),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('DitoNotificationClick.fromMap', () {
    test('lê o clique em botão com action e custom data', () {
      final click = DitoNotificationClick.fromMap({
        'deeplink': 'https://loja.brand.com/promo',
        'notificationId': '123',
        'reference': 'ref-1',
        'logId': 'log-1',
        'notificationName': 'Promo de julho',
        'userId': 'user-1',
        'actionId': 'comprar_agora',
        'actionLabel': 'Comprar agora',
        'customData': {'nivel_programa': 'ouro'},
      });

      expect(click.isActionClick, isTrue);
      expect(click.actionId, 'comprar_agora');
      expect(click.actionLabel, 'Comprar agora');
      expect(click.customData, {'nivel_programa': 'ouro'});
      expect(click.deeplink, 'https://loja.brand.com/promo');
    });

    test('clique no corpo não reporta action', () {
      final click = DitoNotificationClick.fromMap({
        'deeplink': 'brandapp://home',
        'notificationId': '123',
        'reference': 'ref-1',
        'logId': '',
        'notificationName': '',
        'userId': '',
      });

      expect(click.isActionClick, isFalse);
      expect(click.actionId, isEmpty);
      expect(click.customData, isEmpty);
    });

    test('evento de um plugin nativo antigo, sem as chaves novas, não quebra', () {
      final click = DitoNotificationClick.fromMap({
        'type': 'notification_click',
        'deeplink': 'brandapp://home',
      });

      expect(click.actionId, isEmpty);
      expect(click.actionLabel, isEmpty);
      expect(click.customData, isEmpty);
    });
  });

  group('DitoNotificationInfo.fromMap', () {
    test('lê imagem e custom data do inbox nativo', () {
      final info = DitoNotificationInfo.fromMap({
        'id': 'row-1',
        'notificationId': '123',
        'reference': 'ref-1',
        'title': 'Promo',
        'message': 'Aproveite',
        'link': 'brandapp://promo',
        'receivedAt': 1700000000000,
        'isRead': false,
        'image': 'https://cdn.brand.com/promo.png',
        'customData': {'nivel_programa': 'ouro'},
      });

      expect(info.image, 'https://cdn.brand.com/promo.png');
      expect(info.customData, {'nivel_programa': 'ouro'});
    });

    test('inbox de SDK nativo antigo, sem as chaves novas, não quebra', () {
      final info = DitoNotificationInfo.fromMap({
        'id': 'row-1',
        'notificationId': '123',
        'reference': 'ref-1',
        'title': 'Promo',
        'message': 'Aproveite',
        'link': '',
        'receivedAt': 1700000000000,
        'isRead': true,
      });

      expect(info.image, isEmpty);
      expect(info.customData, isEmpty);
    });

    test('customData que chega como string JSON também é aceito', () {
      // Blinda contra um SDK nativo que ainda devolva a string crua do payload.
      final info = DitoNotificationInfo.fromMap({
        'id': 'row-1',
        'notificationId': '123',
        'reference': 'ref-1',
        'title': '',
        'message': '',
        'link': '',
        'receivedAt': 0,
        'isRead': false,
        'customData': '{"nivel_programa":"ouro"}',
      });

      expect(info.customData, {'nivel_programa': 'ouro'});
    });
  });
}
