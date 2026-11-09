import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

/// Ochiq sozlamalar. Domen o'zgarsa, `flutter build web --dart-define=...` bilan almashtiriladi.
class TegioConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zfgeeblonoxqxcdndshm.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_PVqbVxlztmqxBj263R7yJw_ruvWgroN',
  );

  /// Chop etiladigan QR havolalari shu manzilga olib boradi.
  static const publicUrl = String.fromEnvironment('TEGIO_PUBLIC_URL', defaultValue: 'https://tegio.uz');

  static String get apiUrl => '$supabaseUrl/functions/v1/api';
}

Future<void> initTegio() =>
    Supabase.initialize(url: TegioConfig.supabaseUrl, publishableKey: TegioConfig.publishableKey);

SupabaseClient get db => Supabase.instance.client;

class TegioApiException implements Exception {
  const TegioApiException(this.code);

  final String code;

  @override
  String toString() => 'TegioApiException($code)';
}

/// `api` Edge Function'ga POST. Kirilgan bo'lsa, JWT avtomatik qo'shiladi.
Future<Json> callApi(String path, [Json body = const {}]) async {
  final token = db.auth.currentSession?.accessToken;
  final response = await http.post(
    Uri.parse('${TegioConfig.apiUrl}$path'),
    headers: {'content-type': 'application/json', 'authorization': ?(token == null ? null : 'Bearer $token')},
    body: jsonEncode(body),
  );
  final decoded = jsonDecode(response.body) as Json;
  if (response.statusCode >= 400) throw TegioApiException(decoded['error'] as String? ?? 'server_error');
  return decoded;
}

/// RPC natijasi ro'yxat bo'lganda.
Future<List<Json>> rpcList(String name, [Json? params]) async {
  final result = await db.rpc<dynamic>(name, params: params);
  return (result as List).cast<Json>();
}

Future<Json> rpcJson(String name, [Json? params]) async {
  final result = await db.rpc<dynamic>(name, params: params);
  return result as Json;
}
