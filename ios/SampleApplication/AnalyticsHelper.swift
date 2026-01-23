//
//  AnalyticsHelper.swift
//  Sample
//
//  Created by Copilot on 05/11/25.
//

import Foundation
import FirebaseAnalytics

/// Helper class para facilitar o uso do Firebase Analytics
class AnalyticsHelper {

    // MARK: - Screen View Events

    /// Registra visualização de tela
    /// - Parameters:
    ///   - screenName: Nome da tela visualizada
    ///   - screenClass: Classe da tela (opcional)
    static func logScreenView(screenName: String, screenClass: String? = nil) {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]

        if let screenClass = screenClass {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }

        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
        print("📊 Analytics: Screen View - \(screenName)")
    }

    // MARK: - User Actions

    /// Registra ação do usuário
    /// - Parameters:
    ///   - action: Nome da ação
    ///   - category: Categoria da ação (ex: "button", "form", "navigation")
    ///   - label: Label adicional (opcional)
    ///   - value: Valor numérico (opcional)
    static func logUserAction(action: String,
                             category: String,
                             label: String? = nil,
                             value: Int? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "category": category
        ]

        if let label = label {
            parameters["label"] = label
        }

        if let value = value {
            parameters["value"] = value
        }

        Analytics.logEvent("user_action", parameters: parameters)
        print("📊 Analytics: User Action - \(action) (\(category))")
    }

    // MARK: - E-commerce Events

    /// Registra visualização de produto
    /// - Parameters:
    ///   - productId: ID do produto
    ///   - productName: Nome do produto
    ///   - category: Categoria do produto
    ///   - price: Preço do produto
    static func logProductView(productId: String,
                              productName: String,
                              category: String? = nil,
                              price: Double? = nil) {
        var parameters: [String: Any] = [
            AnalyticsParameterItemID: productId,
            AnalyticsParameterItemName: productName
        ]

        if let category = category {
            parameters[AnalyticsParameterItemCategory] = category
        }

        if let price = price {
            parameters[AnalyticsParameterPrice] = price
        }

        Analytics.logEvent(AnalyticsEventViewItem, parameters: parameters)
        print("📊 Analytics: Product View - \(productName)")
    }

    /// Registra início de checkout
    /// - Parameters:
    ///   - value: Valor total
    ///   - currency: Moeda (padrão: BRL)
    ///   - items: Número de itens
    static func logBeginCheckout(value: Double,
                                 currency: String = "BRL",
                                 items: Int = 1) {
        let parameters: [String: Any] = [
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            "items_count": items
        ]

        Analytics.logEvent(AnalyticsEventBeginCheckout, parameters: parameters)
        print("📊 Analytics: Begin Checkout - \(currency) \(value)")
    }

    /// Registra compra
    /// - Parameters:
    ///   - transactionId: ID da transação
    ///   - value: Valor total
    ///   - currency: Moeda (padrão: BRL)
    ///   - items: Número de itens
    static func logPurchase(transactionId: String,
                           value: Double,
                           currency: String = "BRL",
                           items: Int = 1) {
        let parameters: [String: Any] = [
            AnalyticsParameterTransactionID: transactionId,
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            "items_count": items
        ]

        Analytics.logEvent(AnalyticsEventPurchase, parameters: parameters)
        print("📊 Analytics: Purchase - \(transactionId) - \(currency) \(value)")
    }

    // MARK: - Custom Events

    /// Registra evento customizado
    /// - Parameters:
    ///   - eventName: Nome do evento (máximo 40 caracteres)
    ///   - parameters: Parâmetros adicionais (opcional)
    static func logCustomEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
        print("📊 Analytics: Custom Event - \(eventName)")
    }

    // MARK: - User Properties

    /// Define propriedade do usuário
    /// - Parameters:
    ///   - value: Valor da propriedade
    ///   - property: Nome da propriedade
    static func setUserProperty(value: String?, forName property: String) {
        Analytics.setUserProperty(value, forName: property)
        print("📊 Analytics: User Property - \(property): \(value ?? "nil")")
    }

    /// Define ID do usuário
    /// - Parameter userId: ID do usuário
    static func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
        print("📊 Analytics: User ID - \(userId ?? "nil")")
    }

    // MARK: - Notification Events

    /// Registra notificação recebida
    /// - Parameters:
    ///   - notificationId: ID da notificação
    ///   - campaign: Nome da campanha (opcional)
    ///   - inForeground: Se estava em foreground
    static func logNotificationReceived(notificationId: String,
                                       campaign: String? = nil,
                                       inForeground: Bool) {
        var parameters: [String: Any] = [
            "notification_id": notificationId,
            "in_foreground": inForeground
        ]

        if let campaign = campaign {
            parameters["campaign"] = campaign
        }

        let eventName = inForeground ? "notification_received_foreground" : "notification_received_background"
        Analytics.logEvent(eventName, parameters: parameters)
        print("📊 Analytics: Notification Received - \(notificationId)")
    }

    /// Registra abertura de notificação
    /// - Parameters:
    ///   - notificationId: ID da notificação
    ///   - campaign: Nome da campanha (opcional)
    ///   - action: Ação executada (opcional)
    static func logNotificationOpened(notificationId: String,
                                     campaign: String? = nil,
                                     action: String? = nil) {
        var parameters: [String: Any] = [
            "notification_id": notificationId
        ]

        if let campaign = campaign {
            parameters["campaign"] = campaign
        }

        if let action = action {
            parameters["action"] = action
        }

        Analytics.logEvent(AnalyticsEventSelectContent, parameters: parameters)
        print("📊 Analytics: Notification Opened - \(notificationId)")
    }
}

// MARK: - Usage Examples
/*

 // 1. Log screen view
 AnalyticsHelper.logScreenView(screenName: "HomeViewController")

 // 2. Log user action
 AnalyticsHelper.logUserAction(action: "button_clicked",
                               category: "navigation",
                               label: "checkout_button")

 // 3. Log product view
 AnalyticsHelper.logProductView(productId: "123",
                                productName: "Tênis Nike",
                                category: "Esportes",
                                price: 299.90)

 // 4. Log purchase
 AnalyticsHelper.logPurchase(transactionId: "ORDER-123",
                             value: 299.90,
                             currency: "BRL")

 // 5. Set user properties
 AnalyticsHelper.setUserId("user123")
 AnalyticsHelper.setUserProperty(value: "premium", forName: "user_type")

 // 6. Log custom event
 AnalyticsHelper.logCustomEvent("feature_used", parameters: [
     "feature_name": "dark_mode",
     "enabled": true
 ])

 // 7. Log notification events
 AnalyticsHelper.logNotificationReceived(notificationId: "notif-123",
                                         campaign: "black_friday",
                                         inForeground: true)

 AnalyticsHelper.logNotificationOpened(notificationId: "notif-123",
                                       campaign: "black_friday")

 */
