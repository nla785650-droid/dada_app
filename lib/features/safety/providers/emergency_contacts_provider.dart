import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContactState {
  const EmergencyContactState({
    this.contactName,
    this.contactPhone,
  });

  final String? contactName;
  final String? contactPhone;

  EmergencyContactState copyWith({
    String? contactName,
    String? contactPhone,
  }) {
    return EmergencyContactState(
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
    );
  }
}

class EmergencyContactNotifier extends StateNotifier<EmergencyContactState> {
  EmergencyContactNotifier() : super(const EmergencyContactState()) {
    _load();
  }

  static const _kName = 'emergency_contact_name';
  static const _kPhone = 'emergency_contact_phone';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = EmergencyContactState(
      contactName: p.getString(_kName),
      contactPhone: p.getString(_kPhone),
    );
  }

  Future<void> save({
    required String name,
    required String phone,
  }) async {
    final n = name.trim();
    final ph = phone.trim();
    if (n.isEmpty && ph.isEmpty) {
      await clear();
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, n);
    await p.setString(_kPhone, ph);
    state = EmergencyContactState(
      contactName: n.isEmpty ? null : n,
      contactPhone: ph.isEmpty ? null : ph,
    );
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kName);
    await p.remove(_kPhone);
    state = const EmergencyContactState();
  }
}

final emergencyContactProvider =
    StateNotifierProvider<EmergencyContactNotifier, EmergencyContactState>(
  (ref) => EmergencyContactNotifier(),
);
