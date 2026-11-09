import 'package:flutter/foundation.dart';
import 'package:tegio_core/tegio_core.dart';

/// Tanlangan biznes va filial (B-02). Rollar ham shu yerdan o'qiladi (B-03).
class BizController extends ChangeNotifier {
  List<Json> businesses = [];
  Json? _business;
  Json? _location;

  Json get business => _business!;
  Json get location => _location!;
  String get id => business['id'] as String;
  String get locationId => location['id'] as String;
  String get role => business['role'] as String;
  bool get isOwner => role == 'owner';
  bool get canManage => role != 'cashier';
  List<Json> get locations => (business['locations'] as List).cast<Json>();

  Future<void> load() async {
    await db.rpc<dynamic>('claim_staff_invites');
    businesses = await rpcList('my_businesses');
    final kept = businesses.where((b) => b['id'] == _business?['id']);
    _business = kept.isNotEmpty ? kept.first : (businesses.isEmpty ? null : businesses.first);
    if (_business != null) _pickLocation(_location?['id'] as String?);
    notifyListeners();
  }

  void selectBusiness(String businessId) {
    _business = businesses.firstWhere((b) => b['id'] == businessId);
    _pickLocation(null);
    notifyListeners();
  }

  void selectLocation(String id) {
    _pickLocation(id);
    notifyListeners();
  }

  void _pickLocation(String? id) {
    final kept = locations.where((l) => l['id'] == id);
    _location = kept.isNotEmpty ? kept.first : locations.first;
  }
}

final biz = BizController();
