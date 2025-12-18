import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';

enum DQStatus { loading, active, results, completed }

class DailyQuestionController extends ChangeNotifier {
  final DailyQuestionService _service;

  DQStatusResponse? _statusResponse;
  List<DQHistoryItem>? _history;
  List<DQArchiveItem>? _archive;
  bool _isLoading = false;
  String? _errorMessage;

  DailyQuestionController({required DailyQuestionService service})
      : _service = service;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DQStatusResponse? get statusResponse => _statusResponse;
  List<DQHistoryItem> get history => _history ?? [];
  List<DQArchiveItem> get archive => _archive ?? [];

  /// Loads the initial state: status of today and archive of past days.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[DQController] Starting load...');
      // Parallel fetch
      final results = await Future.wait([
        _service.getStatus(),
        _service.getArchive(),
      ]);
      print('[DQController] Got results: ${results.length} items');

      _statusResponse = results[0] as DQStatusResponse;
      print('[DQController] Status: ${_statusResponse?.windowStatus}');
      _archive = results[1] as List<DQArchiveItem>;
      print('[DQController] Archive: ${_archive?.length} items');
    } catch (e, st) {
      print('[DQController] Error: $e');
      print('[DQController] Stack: $st');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Starts today's question. Returns the question details.
  Future<DQQuestionResponse> startQuestion() async {
    try {
      return await _service.startQuestion();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Submits an answer for the current question.
  Future<void> submitAnswer(AnswerValue answer) async {
    try {
      await _service.submitAnswer(answer);
      // Refresh status to reflect submission
      _statusResponse = await _service.getStatus();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
