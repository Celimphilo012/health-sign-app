import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_request_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ChatRequestProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  // Stream subscriptions
  StreamSubscription<List<ChatRequestModel>>? _patientCallsSub;
  List<ChatRequestModel> _patientCalls = [];
  List<ChatRequestModel> get patientCalls => _patientCalls;
  StreamSubscription<List<ChatRequestModel>>? _incomingRequestsSub;
  StreamSubscription<ChatRequestModel?>? _activeRequestSub;

  List<ChatRequestModel> _incomingRequests = [];
  ChatRequestModel? _activeRequest;
  List<UserModel> _patients = [];
  List<UserModel> _filteredPatients = [];
  bool _isLoading = false;

  List<ChatRequestModel> get incomingRequests => _incomingRequests;
  ChatRequestModel? get activeRequest => _activeRequest;
  List<UserModel> get filteredPatients => _filteredPatients;
  bool get isLoading => _isLoading;
  bool get hasActiveChat => _activeRequest != null;

  // ── REAL-TIME: listen for incoming requests (patient) ─
  void listenForRequests(String patientId) {
    _incomingRequestsSub?.cancel();
    _incomingRequestsSub = _service.getIncomingRequestsStream(patientId).listen(
      (requests) {
        _incomingRequests = requests;
        notifyListeners();
      },
      onError: (e) => debugPrint('Incoming requests error: $e'),
    );
  }

  void listenForPatientCalls() {
    _patientCallsSub?.cancel();
    _patientCallsSub = _service.getPatientCallsStream().listen(
      (calls) {
        _patientCalls = calls;
        notifyListeners();
        debugPrint('Patient calls updated: ${calls.length} calls');
      },
      onError: (e) => debugPrint('Patient calls stream error: $e'),
    );
  }

  // ── REAL-TIME: listen for accepted request (nurse) ────
  void listenForAcceptedRequest(String nurseId) {
    _activeRequestSub?.cancel();
    _activeRequestSub = _service.getNurseActiveChatStream(nurseId).listen(
      (request) {
        final wasNull = _activeRequest == null;
        _activeRequest = request;
        // Notify so nurse UI updates immediately
        notifyListeners();
        debugPrint('Active request updated: ${request?.patientName ?? 'none'}');
      },
      onError: (e) => debugPrint('Active request error: $e'),
    );
  }

  // ── Load all patients ─────────────────────────────────
  Future<void> loadPatients() async {
    _isLoading = true;
    notifyListeners();
    try {
      _patients = await _service.getPatients();
      _filteredPatients = List.from(_patients);
    } catch (e) {
      debugPrint('Error loading patients: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Search patients ───────────────────────────────────
  void searchPatients(String query) {
    if (query.trim().isEmpty) {
      _filteredPatients = List.from(_patients);
    } else {
      _filteredPatients = _patients
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _filteredPatients = List.from(_patients);
    notifyListeners();
  }

  // ── Send chat request ─────────────────────────────────
  Future<bool> sendRequest({
    required UserModel nurse,
    required UserModel patient,
  }) async {
    try {
      await _service.sendChatRequest(
        nurseId: nurse.uid,
        nurseName: nurse.name,
        patientId: patient.uid,
        patientName: patient.name,
      );
      return true;
    } catch (e) {
      debugPrint('Error sending request: $e');
      return false;
    }
  }

  // ── Accept request ────────────────────────────────────
  Future<String?> acceptRequest(String requestId, String patientId) async {
    try {
      final convId = await _service.acceptChatRequest(requestId, patientId);
      // Remove from incoming list immediately
      _incomingRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      return convId;
    } catch (e) {
      debugPrint('Error accepting request: $e');
      return null;
    }
  }

  // ── Decline request ───────────────────────────────────
  Future<void> declineRequest(String requestId) async {
    try {
      await _service.declineChatRequest(requestId);
      _incomingRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining request: $e');
    }
  }

  // ── End active conversation ───────────────────────────
  Future<void> endConversation() async {
    if (_activeRequest == null) return;
    try {
      await _service.endConversation(_activeRequest!.id);
      _activeRequest = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending conversation: $e');
    }
  }

  @override
  void dispose() {
    _incomingRequestsSub?.cancel();
    _activeRequestSub?.cancel();
    _patientCallsSub?.cancel();
    super.dispose();
  }
}
