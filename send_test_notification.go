package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type DitoNotificationData struct {
	Notification     string               `json:"notification"`
	Reference        string               `json:"reference"`
	LogID            string               `json:"log_id"`
	NotificationName string               `json:"notification_name"`
	UserID           string               `json:"user_id"`
}

type SavedNotificationPayload struct {
	Timestamp    string                 `json:"timestamp"`
	MessageID    string                 `json:"messageId"`
	From         string                 `json:"from"`
	Data         map[string]interface{} `json:"data"`
}

func sendNotification(ctx context.Context, client *messaging.Client, token, title, message, notificationID, reference, deeplink string) error {
	logID := fmt.Sprintf("log_%s", time.Now().Format("20060102150405"))

	msg := &messaging.Message{
		Token: token,
		Data: map[string]string{
			"channel":           "DITO",
			"notification":      notificationID,
			"reference":         reference,
			"log_id":            logID,
			"notification_name": "Test Notification",
			"user_id":           reference,
			"title":             title,
			"message":           message,
			"link":              deeplink,
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Title:     title,
				Body:      message,
				ChannelID: "dito",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Alert: &messaging.ApsAlert{
						Title: title,
						Body:  message,
					},
					Sound:            "default",
					Badge:            intPtr(1),
					ContentAvailable: true,
					MutableContent:   true,
				},
			},
		},
	}

	response, err := client.Send(ctx, msg)
	if err != nil {
		return fmt.Errorf("erro ao enviar notificação: %w", err)
	}

	fmt.Println("✅ Notificação enviada com sucesso!")
	fmt.Printf("   Message ID: %s\n", response)
	fmt.Printf("   Notification ID: %s\n", notificationID)
	fmt.Printf("   Reference: %s\n", reference)
	fmt.Printf("   Platform: Android + iOS (com background support)\n")

	return nil
}

func intPtr(i int) *int {
	return &i
}

func sendFromSampleJSON(ctx context.Context, client *messaging.Client, token string) error {
	data, err := os.ReadFile("sample_notification.json")
	if err != nil {
		return fmt.Errorf("erro ao ler sample_notification.json: %w", err)
	}

	var payload SavedNotificationPayload
	if err := json.Unmarshal(data, &payload); err != nil {
		return fmt.Errorf("erro ao parsear JSON: %w", err)
	}

	channel, _ := payload.Data["channel"].(string)
	notification, _ := payload.Data["notification"].(string)
	reference, _ := payload.Data["reference"].(string)
	logID, _ := payload.Data["log_id"].(string)
	notificationName, _ := payload.Data["notification_name"].(string)
	userID, _ := payload.Data["user_id"].(string)
	title, _ := payload.Data["title"].(string)
	message, _ := payload.Data["message"].(string)
	link, _ := payload.Data["link"].(string)

	if channel == "" {
		channel = "DITO"
	}
	if logID == "" {
		logID = fmt.Sprintf("log_%s", time.Now().Format("20060102150405"))
	}

	msg := &messaging.Message{
		Token: token,
		Data: map[string]string{
			"channel":           channel,
			"notification":      notification,
			"reference":         reference,
			"log_id":            logID,
			"notification_name": notificationName,
			"user_id":           userID,
			"title":             title,
			"message":           message,
			"link":              link,
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Title:     title,
				Body:      message,
				ChannelID: "dito",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Alert: &messaging.ApsAlert{
						Title: title,
						Body:  message,
					},
					Sound:            "default",
					Badge:            intPtr(1),
					ContentAvailable: true,
					MutableContent:   true,
				},
			},
		},
	}

	response, err := client.Send(ctx, msg)
	if err != nil {
		return fmt.Errorf("erro ao enviar notificação: %w", err)
	}

	fmt.Println("✅ Notificação enviada com sucesso!")
	fmt.Printf("   Message ID: %s\n", response)
	fmt.Printf("   Notification ID: %s\n", notification)
	fmt.Printf("   Reference: %s\n", reference)
	fmt.Printf("   Title: %s\n", title)
	fmt.Printf("   Body: %s\n", message)
	fmt.Printf("   Platform: Android + iOS (com background support)\n")

	return nil
}

func main() {
	token := flag.String("token", "", "Token FCM do dispositivo (obrigatório se não usar -from-sample)")
	title := flag.String("title", "Teste de Notificação", "Título da notificação")
	message := flag.String("message", "Esta é uma notificação de teste", "Mensagem da notificação")
	notificationID := flag.String("notification-id", fmt.Sprintf("test_notif_%s", time.Now().Format("20060102150405")), "ID da notificação")
	reference := flag.String("reference", "test_user_456", "Referência do usuário")
	deeplink := flag.String("deeplink", "", "Deeplink da notificação")
	fromSample := flag.Bool("from-sample", false, "Enviar notificação usando dados do sample_notification.json")
	credentialsFile := flag.String("credentials", "./serviceAccountKey.json", "Caminho para o arquivo de credenciais do Firebase (opcional, usa GOOGLE_APPLICATION_CREDENTIALS se não fornecido)")

	flag.Parse()

	if *token == "" && !*fromSample {
		fmt.Fprintln(os.Stderr, "❌ Erro: --token é obrigatório (ou use -from-sample para ler do sample_notification.json)")
		fmt.Fprintln(os.Stderr, "\nUso:")
		flag.PrintDefaults()
		os.Exit(1)
	}

	if *fromSample && *token == "" {
		fmt.Fprintln(os.Stderr, "❌ Erro: --token é obrigatório mesmo com -from-sample")
		fmt.Fprintln(os.Stderr, "\nUso: ./send_test_notification -from-sample -token SEU_TOKEN")
		os.Exit(1)
	}

	ctx := context.Background()

	var opt option.ClientOption
	if *credentialsFile != "" {
		opt = option.WithCredentialsFile(*credentialsFile)
	} else {
		credPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
		if credPath == "" {
			fmt.Fprintln(os.Stderr, "❌ Erro: GOOGLE_APPLICATION_CREDENTIALS não está definido")
			fmt.Fprintln(os.Stderr, "\nConfigure a variável de ambiente:")
			fmt.Fprintln(os.Stderr, `  export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"`)
			fmt.Fprintln(os.Stderr, "\nOu use --credentials para especificar o arquivo")
			os.Exit(1)
		}
		opt = option.WithCredentialsFile(credPath)
	}

	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ Erro ao inicializar Firebase: %v\n", err)
		fmt.Fprintln(os.Stderr, "\nCertifique-se de que:")
		fmt.Fprintln(os.Stderr, "1. Você baixou o arquivo de credenciais do Firebase Console")
		fmt.Fprintln(os.Stderr, "2. O arquivo de credenciais está no caminho correto")
		os.Exit(1)
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "❌ Erro ao criar cliente de mensagens: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("✅ Firebase Admin SDK inicializado")

	var sendErr error
	if *fromSample {
		sendErr = sendFromSampleJSON(ctx, client, *token)
	} else {
		sendErr = sendNotification(ctx, client, *token, *title, *message, *notificationID, *reference, *deeplink)
	}

	if sendErr != nil {
		fmt.Fprintf(os.Stderr, "❌ %v\n", sendErr)
		os.Exit(1)
	}
}
