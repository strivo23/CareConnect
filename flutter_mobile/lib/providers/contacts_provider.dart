import 'package:flutter/material.dart';

import '../models/contact_model.dart';
import '../services/contacts_repository.dart';

class ContactsProvider extends ChangeNotifier {
  ContactsProvider({ContactsRepository? repository}) : _repository = repository ?? ContactsRepository();

  final ContactsRepository _repository;

  bool _isLoading = false;
  bool _isOffline = false;
  List<EmergencyContactModel> _contacts = const [];
  List<GuardianModel> _guardians = const [];
  List<RelationshipModel> _relationships = const [];

  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  List<EmergencyContactModel> get contacts => _contacts;
  List<GuardianModel> get guardians => _guardians;
  List<RelationshipModel> get relationships => _relationships;

  Future<void> loadForResident(int residentId) async {
    _setLoading(true);
    try {
      _contacts = await _repository.fetchContacts(residentId: residentId);
      _guardians = await _repository.fetchGuardians(residentId: residentId);
      _relationships = await _repository.fetchRelationships();
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
      _contacts = const [];
      _guardians = const [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addContact(Map<String, dynamic> payload) async {
    await _repository.createContact(payload);
    notifyListeners();
  }

  Future<void> updateContact(int id, Map<String, dynamic> payload) async {
    await _repository.updateContact(id, payload);
    notifyListeners();
  }

  Future<void> deleteContact(int id) async {
    await _repository.deleteContact(id);
    _contacts = _contacts.where((item) => item.id != id).toList();
    notifyListeners();
  }

  Future<void> verifyContact(int id) async {
    await _repository.verifyContact(id);
    notifyListeners();
  }

  Future<void> refreshRelationships() async {
    _relationships = await _repository.fetchRelationships();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
