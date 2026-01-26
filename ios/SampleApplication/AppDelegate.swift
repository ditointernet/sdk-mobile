import DitoSDK
import FirebaseAnalytics
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
  var fcmToken: String?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication
      .LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configura o Firebase primeiro (necessário para Analytics e Messaging)
    FirebaseApp.configure()
    Analytics.setAnalyticsCollectionEnabled(true)
    // Registra evento de abertura do app no Analytics
    Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)

    // Define o delegate do Firebase Messaging para tratar token e mensagens
    Messaging.messaging().delegate = self

    // Inicializa o Dito SDK (configurações internas do SDK)
    Dito.configure(<#T##self: Dito##Dito#>)

    // Configura o centro de notificações e registra o app para receber push
    UNUserNotificationCenter.current().delegate = self
    registerForPushNotifications(application: application)

    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // IMPORTANTE: setar o token APNS no Firebase Messaging ANTES de solicitar o token FCM
    Messaging.messaging().apnsToken = deviceToken

    Messaging.messaging().token { [weak self] fcmToken, error in
      if let error = error {
        print("Error fetching FCM registration token: \(error)")
      } else if let fcmToken = fcmToken {
        self?.fcmToken = fcmToken
        print("FCM registration token: \(fcmToken)")
      }
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print(
      "Failed to register for remote notifications: \(error.localizedDescription)"
    )
  }

  // MARK: Background remote notification (silent / content-available)
  // Este método é chamado quando uma notificação silenciosa é recebida
  // mesmo que o app esteja em background ou encerrado
  // é necessário ter o "Remote notifications" habilitado em Background Modes e "Background fetch" ativado
  func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    let callNotificationReceived: (String) -> Void = { token in
      // Garantir que o evento de recebimento seja disparado mesmo em background
      Dito.notificationReceived(userInfo: userInfo, token: token)
      // Notifica o Firebase Messaging sobre a mensagem recebida
      Messaging.messaging().appDidReceiveMessage(userInfo)
      // Chama o completion handler indicando que novos dados foram processados
      completionHandler(.newData)
    }

    if let token = self.fcmToken {
      callNotificationReceived(token)
    } else {
      // Fallback: tentar obter o token se ainda não estiver armazenado
      Messaging.messaging().token { [weak self] token, error in
        if let token = token {
          self?.fcmToken = token
          callNotificationReceived(token)
        } else {
          print(
            "FCM token indisponível em background: \(error?.localizedDescription ?? "erro desconhecido")"
          )
          completionHandler(.noData)
        }
      }
    }
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo

    if let token = fcmToken {
      Dito.notificationReceived(userInfo: userInfo, token: token)
    } else {
      Messaging.messaging().token { [weak self] token, error in
        if let token = token {
          self?.fcmToken = token
          Dito.notificationReceived(userInfo: userInfo, token: token)
        }
      }
    }

    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler([[.banner, .list, .sound, .badge]])
  }

  private func registerForPushNotifications(application: UIApplication) {
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions
    ) { granted, error in
      if let error = error {
        print(
          "Error requesting notification authorization: \(error.localizedDescription)"
        )
        return
      }

      guard granted else {
        print("Notification authorization not granted")
        return
      }

      print("Autorização de notificações concedida")
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    // Notifica o Dito SDK sobre o clique na notificação
    Dito.notificationClick(userInfo: userInfo)

    // Notifica o Firebase Messaging sobre a interação com a notificação
    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler()
  }
}
