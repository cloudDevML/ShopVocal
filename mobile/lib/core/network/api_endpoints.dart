class ApiEndpoints {
  // En mode développement avec l'émulateur Android, 10.0.2.2 redirige vers la machine hôte (localhost).
  // Si vous testez sur un appareil physique, remplacez par l'adresse IP locale de votre machine (ex: http://192.168.1.X:8000).
  static const String baseUrl = 'http://192.168.202.26:8000';

  // Routes d'authentification
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Routes métier
  static const String products = '/products';
  static const String productAlerts = '/products/alerts';
  static const String clients = '/clients';
  static const String transactions = '/transactions';
  static const String financialSummary = '/transactions/summary';

  // Routes Assistant Vocal IA (NLU)
  static const String textToAction = '/ai/text-to-action';
  static const String voiceToAction = '/ai/voice-to-action';
}
