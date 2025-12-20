import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Daily Question document from Firestore.
/// The frontend subscribes to this for real-time status updates.
class DQDocument {
  final String questionUid;
  final String status; // NOT_STARTED, ACTIVE, CLOSED
  final DateTime windowStart;
  final DateTime windowEnd;
  final bool resultsReady;

  DQDocument({
    required this.questionUid,
    required this.status,
    required this.windowStart,
    required this.windowEnd,
    required this.resultsReady,
  });

  factory DQDocument.fromFirestore(Map<String, dynamic> data) {
    return DQDocument(
      questionUid: data['question_uid'] as String? ?? '',
      status: data['status'] as String? ?? 'NOT_STARTED',
      windowStart: (data['window_start'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      windowEnd: (data['window_end'] as Timestamp?)?.toDate() ??
          DateTime.now().toUtc(),
      resultsReady: data['results_ready'] as bool? ?? false,
    );
  }

  /// Whether the DQ is currently active and users can participate.
  bool get isActive => status == 'ACTIVE';

  /// Whether the DQ window has closed.
  bool get isClosed => status == 'CLOSED';

  /// Whether the DQ has not started yet.
  bool get isNotStarted => status == 'NOT_STARTED';
}

/// Service for managing Firestore subscriptions for Daily Questions.
class DQFirestoreService {
  final FirebaseFirestore _firestore;

  DQFirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Watch a specific DQ document by date.
  /// Date should be in YYYY-MM-DD format.
  Stream<DQDocument?> watchDQ(String date) {
    // print('[DQFirestore] Subscribing to daily_questions/$date');
    return _firestore
        .collection('daily_questions')
        .doc(date)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // print('[DQFirestore] Document does not exist: $date');
        return null;
      }
      final data = snapshot.data()!;
      // print('[DQFirestore] Got update for $date: status=${data['status']}, '
      //     'results_ready=${data['results_ready']}');
      return DQDocument.fromFirestore(data);
    });
  }
}
