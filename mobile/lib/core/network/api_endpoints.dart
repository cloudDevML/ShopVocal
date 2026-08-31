import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // Sur le web (Chrome), localhost:8000 communique directement avec le backend sur la machine hôte.
  // Sur appareil physique, l'IP locale (192.168.202.35:8000) permet l'accès via le réseau Wi-Fi.
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://192.168.202.35:8000';

  // Routes d'authentification
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';

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
