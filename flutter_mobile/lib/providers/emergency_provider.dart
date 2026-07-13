import 'package:flutter/material.dart';

import '../models/emergency_action_model.dart';
import '../services/emergency_repository.dart';

class EmergencyProvider extends ChangeNotifier {
  EmergencyProvider({EmergencyRepository? repository}) : _repository = repository ?? EmergencyRepository();

  final EmergencyRepository _repository;

  bool _isLoading = false;
  String? _lastMessage;

  bool get isLoading => _isLoading;
  String? get lastMessage => _lastMessage;
  List<EmergencyActionModel> get quickActions => EmergencyRepository.actions;

  Future<bool> triggerSOS() async {
    _setLoading(true);
    try {
      final response = await _repository.triggerSOS();
      _lastMessage = response['message']?.toString() ?? 'SOS sent successfully';
      return true;
    } catch (error) {
      _lastMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> triggerAction(EmergencyActionModel action) async {
    _setLoading(true);
    try {
      final response = await _repository.triggerQuickAction(action);
      _lastMessage = response['message']?.toString() ?? '${action.label} alert sent';
      return true;
    } catch (error) {
      _lastMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
