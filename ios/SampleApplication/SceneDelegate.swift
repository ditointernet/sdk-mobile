import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🔵 SceneDelegate: scene willConnectTo called")
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ SceneDelegate: Failed to cast scene as UIWindowScene")
            return
        }
        print("✅ SceneDelegate: WindowScene created successfully")

        // Verificar se a window foi criada pelo storyboard
        if let window = window {
            print("✅ SceneDelegate: Window exists from storyboard: \(window)")
            print("✅ SceneDelegate: Root view controller: \(String(describing: window.rootViewController))")
        } else {
            print("⚠️ SceneDelegate: Window is nil, creating manually...")
            // Criar window manualmente se não foi criada pelo storyboard
            let window = UIWindow(windowScene: windowScene)

            // Carregar o storyboard e instanciar o view controller inicial
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let initialViewController = storyboard.instantiateInitialViewController() {
                window.rootViewController = initialViewController
                print("✅ SceneDelegate: Loaded initial view controller from Main storyboard")
            } else {
                print("❌ SceneDelegate: Failed to load initial view controller from storyboard")
            }

            self.window = window
            window.makeKeyAndVisible()
            print("✅ SceneDelegate: Window created and made key and visible")
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }


}

