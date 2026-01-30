import DitoSDK
import FirebaseAnalytics
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
  var fcmToken: String?
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication
      .LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    Dito.enableDebugMode(true)
    print("🐛 Debug mode enabled for Dito SDK")
    #endif

    print("🔵 AppDelegate: didFinishLaunchingWithOptions called")

    // Configura o Firebase primeiro (necessário para Analytics e Messaging)
    FirebaseApp.configure()
    print("✅ Firebase configured")

    Analytics.setAnalyticsCollectionEnabled(true)
    // Registra evento de abertura do app no Analytics
    Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)

    // Define o delegate do Firebase Messaging para tratar token e mensagens
    Messaging.messaging().delegate = self

    // Inicializa o Dito SDK (configurações internas do SDK)
    Dito.shared.configure()

    // Configura o centro de notificações e registra o app para receber push
    UNUserNotificationCenter.current().delegate = self
    registerForPushNotifications(application: application)

    // FALLBACK: Se não estiver usando Scenes (iOS 12 ou configuração antiga)
    // Criar window manualmente
    if window == nil {
      print("⚠️ AppDelegate: Window is nil, creating manually (not using Scenes)")
      window = UIWindow(frame: UIScreen.main.bounds)

      let viewController = ViewController()
      let navigationController = UINavigationController(rootViewController: viewController)
      navigationController.navigationBar.prefersLargeTitles = false

      window?.rootViewController = navigationController
      window?.makeKeyAndVisible()
      print("✅ AppDelegate: Window created with NavigationController (no storyboard)")
    }

    print("✅ AppDelegate: didFinishLaunchingWithOptions completed successfully")
    return true
  }


  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("✅ AppDelegate: APNS token recebido")

    // IMPORTANTE: setar o token APNS no Firebase Messaging ANTES de solicitar o token FCM
    Messaging.messaging().apnsToken = deviceToken
    print("✅ AppDelegate: APNS token configurado no Firebase Messaging")

    // Aguardar um pouco antes de solicitar o FCM token
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      Messaging.messaging().token { fcmToken, error in
        if let error = error {
          print("❌ AppDelegate: Error fetching FCM registration token: \(error.localizedDescription)")
        } else if let fcmToken = fcmToken {
          self?.fcmToken = fcmToken
          print("✅ AppDelegate: FCM registration token obtido: \(fcmToken)")

          // Notificar ViewController se necessário
          NotificationCenter.default.post(
            name: NSNotification.Name("FCMTokenReceived"),
            object: nil,
            userInfo: ["token": fcmToken]
          )
        }
      }
    }
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")

    // No simulador, push notifications não funcionam completamente
    // Mas ainda podemos tentar obter o FCM token (pode funcionar em alguns casos)
    #if targetEnvironment(simulator)
    print("⚠️ AppDelegate: Executando no simulador - push notifications limitadas")
    print("⚠️ AppDelegate: Tentando obter FCM token mesmo assim...")

    // Tentar obter FCM token mesmo sem APNS (pode não funcionar)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      Messaging.messaging().token { fcmToken, error in
        if let error = error {
          print("❌ AppDelegate: FCM token não disponível no simulador: \(error.localizedDescription)")
          print("💡 AppDelegate: Para testar push notifications, use um dispositivo físico")
        } else if let fcmToken = fcmToken {
          self?.fcmToken = fcmToken
          print("✅ AppDelegate: FCM token obtido no simulador: \(fcmToken)")
        }
      }
    }
    #else
    print("💡 AppDelegate: Verifique se o entitlement 'aps-environment' está configurado no target")
    #endif
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
    // Salvar notificação para debug
    NotificationDebugHelper.saveNotification(userInfo)

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

    // Salvar notificação para debug
    NotificationDebugHelper.saveNotification(userInfo)

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

    // Salvar notificação para debug (se ainda não foi salva)
    NotificationDebugHelper.saveNotification(userInfo)

    // Notifica o Dito SDK sobre o clique na notificação
    Dito.notificationClick(userInfo: userInfo)

    // Notifica o Firebase Messaging sobre a interação com a notificação
    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler()
  }
}
