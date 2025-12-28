import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/dq_firestore.dart';
import 'package:fermi_frontend/models/answer_value.dart';

/// Controller for Daily Question feature.
/// Manages archive data, Firestore subscriptions, and unseen results tracking.
class DailyQuestionController extends ChangeNotifier {
  final DailyQuestionService _service;
  final DQFirestoreService _firestoreService;

  // Archive data from /archive/week
  Map<String, bool> _weeklyItems = {}; // {date: participated}
  String? _todayDate; // Current DQ date to subscribe to

  // Real-time DQ state from Firestore
  DQDocument? _todayDocument;
  StreamSubscription<DQDocument?>? _firestoreSubscription;

  // Persisted set of dates user has viewed results for
  static const String _seenResultsKey = 'dq_seen_results';
  Set<String> _seenResults = {};

  // Computed set: participated dates not in _seenResults (excluding today)
  final Set<String> _unseenResults = {};

  // Loading/error states
  bool _isLoading = false;
  String? _errorMessage;

  DailyQuestionController({
    required DailyQuestionService service,
    required DQFirestoreService firestoreService,
  })  : _service = service,
        _firestoreService = firestoreService;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, bool> get weeklyItems => _weeklyItems;
  String? get todayDate => _todayDate;
  DQDocument? get todayDocument => _todayDocument;
  Set<String> get unseenResults => _unseenResults;

  /// Whether user has participated in today's DQ.
  bool get hasParticipatedToday =>
      _todayDate != null && (_weeklyItems[_todayDate] ?? false);

  /// Get sorted list of dates for the carousel (most recent first).
  List<String> get carouselDates {
    final dates = _weeklyItems.keys.toList();
    dates.sort((a, b) => b.compareTo(a)); // Descending order
    return dates;
  }

  /// Initialize controller with persisted data.
  /// Call this after creating the controller.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenResultsKey) ?? [];
    _seenResults = seenList.toSet();
  }

  /// Persist seen results to SharedPreferences.
  Future<void> _persistSeenResults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenResultsKey, _seenResults.toList());
  }

  /// Main entry point: fetch archive and subscribe to today's DQ.
  /// Call this on app launch and after submission/results_ready.
  Future<void> refreshArchiveAndSubscribe() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final archive = await _service.getWeeklyArchive();

      _weeklyItems = archive.items;
      final newTodayDate = archive.today;

      // Compute unseen results: participated dates not in seen set (excluding today)
      _unseenResults.clear();
      for (final entry in _weeklyItems.entries) {
        final date = entry.key;
        final participated = entry.value;
        // If participated and not seen, mark as unseen (exclude today - it's handled separately)
        if (participated &&
            !_seenResults.contains(date) &&
            date != newTodayDate) {
          _unseenResults.add(date);
        }
      }

      // If today changed, update subscription
      if (newTodayDate != _todayDate) {
        await _cancelCurrentSubscription();
        _todayDate = newTodayDate;
        _subscribeToToday();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to the current today's DQ document.
  void _subscribeToToday() {
    if (_todayDate == null) return;

    // print('[DQController] Subscribing to Firestore: $_todayDate');
    _firestoreSubscription = _firestoreService.watchDQ(_todayDate!).listen(
      (doc) {
        _onFirestoreUpdate(doc);
      },
      onError: (e) {
        // print('[DQController] Firestore error: $e');
      },
    );
  }

  /// Handle Firestore document updates.
  void _onFirestoreUpdate(DQDocument? doc) {
    final previousDoc = _todayDocument;
    _todayDocument = doc;

    // Check if results just became ready
    if (doc != null &&
        doc.resultsReady &&
        previousDoc != null &&
        !previousDoc.resultsReady) {
      _handleResultsReady();
    }

    notifyListeners();
  }

  /// Handle when results_ready transitions to true.
  void _handleResultsReady() {
    // Add old today to unseen results if user participated
    if (_todayDate != null && (_weeklyItems[_todayDate] ?? false)) {
      _unseenResults.add(_todayDate!);
    }

    // Re-fetch archive to get new today
    // Use a slight delay to ensure backend has updated
    Future.delayed(const Duration(seconds: 2), () {
      refreshArchiveAndSubscribe();
    });
  }

  /// Cancel current Firestore subscription.
  Future<void> _cancelCurrentSubscription() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _todayDocument = null;
  }

  /// Mark results as seen for a date (removes unseen indicator and persists).
  void markResultsSeen(String date) {
    if (_unseenResults.remove(date)) {
      _seenResults.add(date);
      _persistSeenResults();
      notifyListeners();
    }
  }

  /// Check if a date has unseen results.
  bool hasUnseenResults(String date) => _unseenResults.contains(date);

  /// Start today's question. Returns the question details.
  Future<DQQuestionResponse> startQuestion() async {
    try {
      // print('[DQController] Starting question...');
      return await _service.startQuestion();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Submit an answer for the current question.
  Future<DQSubmitResponse> submitAnswer(AnswerValue answer) async {
    try {
      // print('[DQController] Submitting answer...');
      final response = await _service.submitAnswer(answer);

      // Refresh archive to update participation status
      await refreshArchiveAndSubscribe();

      return response;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    // print('[DQController] Disposing...');
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
