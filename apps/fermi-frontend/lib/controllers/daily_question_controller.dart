import 'dart:async';

import 'package:flutter/material.dart';
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

  // Unseen results tracking (dates where user hasn't viewed results yet)
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

  /// Main entry point: fetch archive and subscribe to today's DQ.
  /// Call this on app launch and after submission/results_ready.
  Future<void> refreshArchiveAndSubscribe() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[DQController] Fetching weekly archive...');
      final archive = await _service.getWeeklyArchive();

      _weeklyItems = archive.items;
      final newTodayDate = archive.today;

      print(
          '[DQController] Got ${_weeklyItems.length} items, today=$newTodayDate');

      // If today changed, update subscription
      if (newTodayDate != _todayDate) {
        print('[DQController] Today changed: $_todayDate -> $newTodayDate');
        await _cancelCurrentSubscription();
        _todayDate = newTodayDate;
        _subscribeToToday();
      }
    } catch (e, st) {
      print('[DQController] Error: $e');
      print('[DQController] Stack: $st');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to the current today's DQ document.
  void _subscribeToToday() {
    if (_todayDate == null) return;

    print('[DQController] Subscribing to Firestore: $_todayDate');
    _firestoreSubscription = _firestoreService.watchDQ(_todayDate!).listen(
      (doc) {
        _onFirestoreUpdate(doc);
      },
      onError: (e) {
        print('[DQController] Firestore error: $e');
      },
    );
  }

  /// Handle Firestore document updates.
  void _onFirestoreUpdate(DQDocument? doc) {
    final previousDoc = _todayDocument;
    _todayDocument = doc;

    print('[DQController] Firestore update: status=${doc?.status}, '
        'results_ready=${doc?.resultsReady}');

    // Check if results just became ready
    if (doc != null &&
        doc.resultsReady &&
        previousDoc != null &&
        !previousDoc.resultsReady) {
      print('[DQController] Results just became ready!');
      _handleResultsReady();
    }

    notifyListeners();
  }

  /// Handle when results_ready transitions to true.
  void _handleResultsReady() {
    // Add old today to unseen results if user participated
    if (_todayDate != null && (_weeklyItems[_todayDate] ?? false)) {
      print('[DQController] Adding $_todayDate to unseen results');
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

  /// Mark results as seen for a date (removes unseen indicator).
  void markResultsSeen(String date) {
    if (_unseenResults.remove(date)) {
      print('[DQController] Marked $date as seen');
      notifyListeners();
    }
  }

  /// Check if a date has unseen results.
  bool hasUnseenResults(String date) => _unseenResults.contains(date);

  /// Start today's question. Returns the question details.
  Future<DQQuestionResponse> startQuestion() async {
    try {
      print('[DQController] Starting question...');
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
      print('[DQController] Submitting answer...');
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
    print('[DQController] Disposing...');
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
