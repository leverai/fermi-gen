import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/number_decompose.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Production Firestore-backed implementation of GameRealtime.
class FirestoreGameRealtime implements GameRealtime {
  FirestoreGameRealtime({
    required this.currentPlayerId,
    this.submit,
    this.next,
    this.upvote,
    this.deUpvote,
    this.downvote,
    this.deDownvote,
    this.resolveLocale,
    this.setLocale,
    this.gameConfig,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  final String currentPlayerId;
  final FirebaseFirestore _firestore;
  final GameConfig? gameConfig;
  final Future<void> Function(
      String gameId, int questionIndex, AnswerValue answer)? submit;
  final Future<void> Function(String gameId)? next;
  final Future<void> Function(String questionUid)? upvote;
  final Future<void> Function(String questionUid)? deUpvote;
  final Future<void> Function(String questionUid)? downvote;
  final Future<void> Function(String questionUid)? deDownvote;
  final String? Function()? resolveLocale; // returns 'US' | 'EU' | null
  final Future<void> Function(String locale)? setLocale;
  final Map<String, List<String>> _questionUidsByGame =
      <String, List<String>>{};
  final Map<String, String> _currentUidByGame = <String, String>{};
  // Cache last raw revealed question data per (gameId:index)
  final Map<String, Map<String, dynamic>> _lastQuestionRawByKey =
      <String, Map<String, dynamic>>{};
  // Controllers to allow re-emitting on locale changes
  final Map<String, StreamController<RevealedQuestion>> _revealedControllers =
      <String, StreamController<RevealedQuestion>>{};

  @override
  Stream<GameSnapshot> watchGame(String gameId) {
    final docRef = _firestore.collection('games').doc(gameId);
    return docRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return const GameSnapshot(
          state: GameState.preLobby,
          isHost: false,
          questionNumber: 0,
          nQuestions: 0,
          durationSeconds: 0,
          players: <String, PlayerSummary>{},
          isPrivate: false,
          progressAnswered: <String, bool>{},
          allAnswered: false,
        );
      }

      final dynamic rawState = data['state'];
      final GameState state = _parseState(rawState);

      final Map<String, dynamic> playersRaw = (() {
        final raw = data['players'];
        if (raw == null) return <String, dynamic>{};
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return <String, dynamic>{};
      })();
      final Map<String, PlayerSummary> players = <String, PlayerSummary>{};
      playersRaw.forEach((String playerId, dynamic value) {
        final Map<String, dynamic> v = (() {
          if (value == null) return <String, dynamic>{};
          if (value is Map) {
            return Map<String, dynamic>.from(value);
          }
          return <String, dynamic>{};
        })();
        players[playerId] = PlayerSummary(
          playerId: playerId,
          name: v['name'] as String?,
          pictureUrl: v['picture'] as String?,
          score: (v['score'] is num) ? (v['score'] as num).toDouble() : 0.0,
          isHost: (v['is_host'] as bool?) ?? false,
          isActive: (v['is_active'] as bool?) ?? true,
          rank: (v['rank'] as num?)?.toInt(),
        );
      });

      final String hostId = (data['host'] as String?) ?? '';
      final bool isHost =
          currentPlayerId.isNotEmpty && hostId == currentPlayerId;

      final int nQuestions = (data['n_questions'] as num?)?.toInt() ?? 0;
      int questionNumber = (data['question_number'] as num?)?.toInt() ?? 0;
      final String? currentQuestionUid = data['question_uid'] as String?;

      // Cache question_uids for mapping by index
      final List<dynamic>? qUidsDyn = data['question_uids'] as List<dynamic>?;
      if (qUidsDyn != null) {
        _questionUidsByGame[gameId] =
            qUidsDyn.whereType<String>().toList(growable: false);
      }

      // Derive questionNumber from uid when the field is 0/missing
      if (questionNumber == 0 && currentQuestionUid != null) {
        final List<String>? known = _questionUidsByGame[gameId];
        if (known != null && known.isNotEmpty) {
          final int idx = known.indexOf(currentQuestionUid);
          if (idx >= 0) {
            questionNumber = idx + 1; // 1-based
          }
        }
      }

      // Read per-question duration (seconds) from authoritative game doc field
      int durationSeconds = (data['question_duration_s'] as num?)?.toInt() ?? 0;

      final bool isPrivate = (data['private'] as bool?) ?? false;
      final String? joinUrl = data['join_url'] as String?;

      // Progress answered map
      final Map<String, dynamic> progressRaw = (() {
        final raw = data['progress'];
        if (raw == null) return <String, dynamic>{};
        if (raw is Map) {
          return Map<String, dynamic>.from(raw);
        }
        return <String, dynamic>{};
      })();
      final Map<String, bool> answered = <String, bool>{};
      final answeredRaw = progressRaw['answered'];
      if (answeredRaw is Map) {
        Map<String, dynamic>.from(answeredRaw)
            .forEach((k, v) => answered[k] = (v as bool?) ?? false);
      }
      final bool allAnswered = (progressRaw['all_answered'] as bool?) ?? false;

      if (currentQuestionUid != null && currentQuestionUid.isNotEmpty) {
        _currentUidByGame[gameId] = currentQuestionUid;
      }

      return GameSnapshot(
        state: state,
        isHost: isHost,
        questionNumber: questionNumber,
        nQuestions: nQuestions,
        durationSeconds: durationSeconds,
        players: players,
        isPrivate: isPrivate,
        joinUrl: joinUrl,
        progressAnswered: answered,
        allAnswered: allAnswered,
        currentQuestionUid: currentQuestionUid,
        questionUids: _questionUidsByGame[gameId] ?? const <String>[],
      );
    });
  }

  // Legacy deadline parsing removed; duration now provided directly by server.

  @override
  Stream<RevealPayload> revealsForQuestion(String gameId, int questionIndex) {
    final String? uid =
        _uidForIndex(gameId, questionIndex) ?? _currentUidByGame[gameId];
    final CollectionReference<Map<String, dynamic>> col =
        _firestore.collection('games').doc(gameId).collection('answers');

    if (uid != null && uid.isNotEmpty) {
      return col
          .where(FieldPath.documentId, isEqualTo: uid)
          .where('revealed', isEqualTo: true)
          .limit(1)
          .snapshots()
          .where((qs) {
        final bool has = qs.docs.isNotEmpty;
        return has;
      }).map((qs) => _mapAnswerDocToReveal(qs.docs.first.data()));
    }

    return col
        .where('revealed', isEqualTo: true)
        .limit(1)
        .snapshots()
        .where((qs) {
      final bool has = qs.docs.isNotEmpty;
      return has;
    }).map((qs) => _mapAnswerDocToReveal(qs.docs.first.data()));
  }

  @override
  Stream<RevealedQuestion> revealedQuestion(String gameId, int questionIndex) {
    final String key = '$gameId:$questionIndex';
    final controller = _revealedControllers.putIfAbsent(
        key, () => StreamController<RevealedQuestion>.broadcast());

    final String? uid =
        _uidForIndex(gameId, questionIndex) ?? _currentUidByGame[gameId];
    final CollectionReference<Map<String, dynamic>> col =
        _firestore.collection('games').doc(gameId).collection('questions');

    Stream<QuerySnapshot<Map<String, dynamic>>> baseStream;
    if (uid != null && uid.isNotEmpty) {
      baseStream = col
          .where(FieldPath.documentId, isEqualTo: uid)
          .where('revealed', isEqualTo: true)
          .limit(1)
          .snapshots();
    } else {
      baseStream = col.where('revealed', isEqualTo: true).limit(1).snapshots();
    }

    baseStream.where((qs) => qs.docs.isNotEmpty).listen((qs) {
      final Map<String, dynamic> raw = qs.docs.first.data();
      _lastQuestionRawByKey[key] = raw;
      controller.add(_mapQuestionDocToRevealed(raw));
    }, onError: (Object err, StackTrace st) {
      debugPrint('[rt] question stream error: $err');
    });

    return controller.stream;
  }

  @override
  Stream<PlayersAnswersSnapshot> playersAnswersForQuestion(
    String gameId,
    int questionIndex,
  ) {
    final String? uid =
        _uidForIndex(gameId, questionIndex) ?? _currentUidByGame[gameId];
    final CollectionReference<Map<String, dynamic>> col = _firestore
        .collection('games')
        .doc(gameId)
        .collection('players_results');

    if (uid != null && uid.isNotEmpty) {
      return col
          .where(FieldPath.documentId, isEqualTo: uid)
          .where('revealed', isEqualTo: true)
          .limit(1)
          .snapshots()
          .where((qs) {
        final bool has = qs.docs.isNotEmpty;
        return has;
      }).map((qs) => _mapPlayersAnswersDoc(qs.docs.first.data()));
    }

    return col
        .where('revealed', isEqualTo: true)
        .limit(1)
        .snapshots()
        .where((qs) {
      final bool has = qs.docs.isNotEmpty;
      return has;
    }).map((qs) => _mapPlayersAnswersDoc(qs.docs.first.data()));
  }

  @override
  Future<void> submitAnswer(
    String gameId,
    int questionIndex,
    AnswerValue answer,
  ) async {
    final submitFn = submit;
    if (submitFn != null) {
      await submitFn(gameId, questionIndex, answer);
    }
  }

  @override
  Future<void> requestForceReveal(String gameId, int questionIndex) async {
    // Backend performs reveal when appropriate; no-op here.
    return;
  }

  @override
  Future<void> goNext(String gameId) async {
    final nextFn = next;
    if (nextFn != null) {
      await nextFn(gameId);
    }
  }

  @override
  String? get currentLocale => resolveLocale?.call();

  @override
  Future<void> setUserLocale(String locale) async {
    final fn = setLocale;
    if (fn != null) {
      await fn(locale);
    }
    // Re-emit mapped revealed questions for current panes using cached raw
    _lastQuestionRawByKey.forEach((String key, Map<String, dynamic> raw) {
      final StreamController<RevealedQuestion>? c = _revealedControllers[key];
      if (c != null && !c.isClosed) {
        c.add(_mapQuestionDocToRevealed(raw));
      }
    });
  }

  @override
  Future<void> upvoteQuestion(String questionUid) async {
    final fn = upvote;
    if (fn != null) {
      await fn(questionUid);
    }
  }

  @override
  Future<void> deUpvoteQuestion(String questionUid) async {
    final fn = deUpvote;
    if (fn != null) {
      await fn(questionUid);
    }
  }

  @override
  Future<void> downvoteQuestion(String questionUid) async {
    final fn = downvote;
    if (fn != null) {
      await fn(questionUid);
    }
  }

  @override
  Future<void> deDownvoteQuestion(String questionUid) async {
    final fn = deDownvote;
    if (fn != null) {
      await fn(questionUid);
    }
  }

  GameState _parseState(dynamic raw) {
    if (raw is num) {
      final int code = raw.toInt();
      switch (code) {
        case 0:
          return GameState.preLobby;
        case 1:
          return GameState.lobbyNotReady;
        case 2:
          return GameState.lobbyReady;
        case 3:
          return GameState.questionN;
        case 4:
          return GameState.questionNFinished;
        case 5:
          return GameState.questionLast;
        case 6:
          return GameState.questionLastFinished;
        case 8:
          return GameState.gameFinished;
        case 9:
          return GameState.gameAborted;
        default:
          return GameState.preLobby;
      }
    }
    return GameState.preLobby;
  }

  String? _uidForIndex(String gameId, int questionIndex) {
    final List<String>? uids = _questionUidsByGame[gameId];
    if (uids == null || uids.isEmpty) return null;
    final int idx = questionIndex.clamp(0, uids.length - 1);
    return uids[idx];
  }

  RevealPayload _mapAnswerDocToReveal(Map<String, dynamic> data) {
    // AnswerDoc schema: number, unit, quantiles, paragraph, revealed
    final double rawNumber = (data['number'] as num?)?.toDouble() ?? 0;
    // Backend now treats unitless as null; use empty string for UI
    final String unit = (data['unit'] as String?) ?? '';
    final AnswerValue parsedAnswer = _parseBackendAnswer(rawNumber, unit);
    return RevealPayload(
      correct: parsedAnswer,
    );
  }

  /// Converts a backend answer (single number) to UI format (number + OM).
  /// Backend stores 1000 as {number: 1000}, UI needs {number: 1, om: 'K'}.
  /// Applies capping for values outside displayable range (>999T or <1).
  AnswerValue _parseBackendAnswer(double rawNumber, String unit) {
    return decomposeNumber(rawNumber, unit);
  }

  PlayersAnswersSnapshot _mapPlayersAnswersDoc(Map<String, dynamic> data) {
    final Map<String, dynamic> playersResults =
        data['players_results'] as Map<String, dynamic>? ?? {};
    final Map<String, AnswerValue> submitted = <String, AnswerValue>{};
    final Map<String, double> scores = <String, double>{};
    final Map<String, AnswerValue> correct = <String, AnswerValue>{};
    final Map<String, double> percentiles = <String, double>{};
    final Map<String, Map<String, AnswerValue>> convertedAnswers =
        <String, Map<String, AnswerValue>>{};

    playersResults.forEach((String playerId, dynamic v) {
      final Map<String, dynamic> entry =
          (v as Map<String, dynamic>? ?? <String, dynamic>{});
      final Map<String, dynamic>? ans =
          entry['answer'] as Map<String, dynamic>?;
      if (ans != null) {
        final double rawNumber = (ans['number'] as num?)?.toDouble() ?? 0;
        final AnswerValue parsedAnswer = _parseBackendAnswer(
          rawNumber,
          (ans['unit'] as String?) ?? '',
        );
        submitted[playerId] = parsedAnswer;
      }
      final Map<String, dynamic>? corr =
          entry['correct_answer'] as Map<String, dynamic>?;
      if (corr != null) {
        final double rawNumber = (corr['number'] as num?)?.toDouble() ?? 0;
        final AnswerValue parsedAnswer = _parseBackendAnswer(
          rawNumber,
          (corr['unit'] as String?) ?? '',
        );
        correct[playerId] = parsedAnswer;
      }
      final dynamic scoreRaw = entry['score'];
      if (scoreRaw is num) {
        scores[playerId] = scoreRaw.toDouble();
      } else if (scoreRaw is Map<String, dynamic>) {
        // Expect backend to provide {number: <float>, quantile: <float>}
        final num? number = scoreRaw['number'] as num?;
        if (number != null) scores[playerId] = number.toDouble();
        final num? quantile = scoreRaw['quantile'] as num?;
        if (quantile != null) {
          percentiles[playerId] = quantile.toDouble();
        }
      }

      // Parse converted_answers for this player
      final Map<String, dynamic>? convertedRaw =
          entry['converted_answers'] as Map<String, dynamic>?;
      if (convertedRaw != null) {
        final Map<String, AnswerValue> playerConverted =
            <String, AnswerValue>{};
        convertedRaw.forEach((String otherPlayerId, dynamic otherAns) {
          if (otherAns is Map<String, dynamic>) {
            final double rawNumber =
                (otherAns['number'] as num?)?.toDouble() ?? 0;
            final AnswerValue parsedAnswer = _parseBackendAnswer(
              rawNumber,
              (otherAns['unit'] as String?) ?? '',
            );
            playerConverted[otherPlayerId] = parsedAnswer;
          }
        });
        convertedAnswers[playerId] = playerConverted;
      }
    });

    final bool allAnswered = (data['revealed'] as bool?) ?? false;
    return PlayersAnswersSnapshot(
      submitted: submitted,
      scores: scores,
      allAnswered: allAnswered,
      correct: correct,
      percentiles: percentiles,
      convertedAnswers: convertedAnswers,
    );
  }

  RevealedQuestion _mapQuestionDocToRevealed(Map<String, dynamic> data) {
    final String text = (data['text'] as String?) ?? '';
    List<String> tags = (data['tags'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
    // Read upvotes count if present on the question doc
    final int upvotes = (data['upvotes'] as num?)?.toInt() ?? 0;
    // Read backend category name if present
    final String category = (data['category'] as String?) ?? '';
    // Read current player's vote verdict from players_votes map
    int myVoteVerdict = 0;
    final Object? playersVotesRaw = data['players_votes'];
    if (playersVotesRaw is Map<String, dynamic>) {
      final dynamic v = playersVotesRaw[currentPlayerId];
      if (v is num) {
        myVoteVerdict = v.toInt();
      }
    }
    // Optional difficulty/year for tag synthesis
    final String difficulty = (() {
      final Object? raw = data['difficulty'];
      if (raw is String) return raw;
      if (raw is num) return raw.toInt().toString();
      return '';
    })();
    final String yearStr = (() {
      final num? y = data['year'] as num?;
      return y == null ? '' : y.toInt().toString();
    })();

    // Units now arrive as UnitInfo objects per region: { US: [...], EU: [...] }
    final Object? unitsRaw = data['units'];
    List<String> units = const <String>[]; // abbreviations for UI tape
    final Map<String, String> unitOptions = <String, String>{}; // name -> abbr
    final Map<String, String> abbrToId = <String, String>{};
    final Map<String, String> idToAbbr = <String, String>{};
    if (unitsRaw is Map<String, dynamic>) {
      final String locale = (resolveLocale?.call() ?? 'US').toUpperCase();
      final List<dynamic>? region = unitsRaw[locale] as List<dynamic>? ??
          unitsRaw['US'] as List<dynamic>?;
      final Iterable<Map<String, dynamic>> entries =
          (region ?? const <dynamic>[]).whereType<Map<String, dynamic>>();
      final List<String> abbrs = <String>[];
      for (final Map<String, dynamic> e in entries) {
        final String? id = e['id'] as String?;
        final String? name = e['name'] as String?;
        final String? abbr = e['abbreviation'] as String?;
        if (id != null && abbr != null) {
          abbrs.add(abbr);
          if (name != null && name.isNotEmpty) {
            unitOptions[name] = abbr;
          } else {
            unitOptions[abbr] = abbr;
          }
          abbrToId[abbr] = id;
          idToAbbr[id] = abbr;
        }
      }
      units = abbrs;
    } else if (unitsRaw is List) {
      // Legacy fallback: list of abbreviations
      final List<String> abbrs =
          unitsRaw.whereType<String>().toList(growable: false);
      units = abbrs;
      for (final String ab in abbrs) {
        unitOptions[ab] = ab;
      }
    }

    // If no explicit tags array is provided, synthesize from category/difficulty/year
    // Convert backend names to display slugs using config
    if (tags.isEmpty) {
      final List<String> synthesized = <String>[];

      // Convert category name → slug
      if (category.isNotEmpty) {
        final String categorySlug = gameConfig?.categories
                .firstWhere((c) => c.name == category,
                    orElse: () => CategoryInfo(
                          index: 0,
                          name: category,
                          slug: category,
                          theme: const {},
                          picture: '',
                        ))
                .slug ??
            category;
        synthesized.add(categorySlug);
      }

      // Convert difficulty name → slug
      if (difficulty.isNotEmpty) {
        final String difficultySlug = gameConfig?.difficulties
                .firstWhere((d) => d.name == difficulty,
                    orElse: () => DifficultyInfo(
                          name: difficulty,
                          slug: difficulty,
                          picture: '',
                        ))
                .slug ??
            difficulty;
        synthesized.add(difficultySlug);
      }

      if (yearStr.isNotEmpty) synthesized.add(yearStr);
      tags = synthesized;
    }

    return RevealedQuestion(
      text: text,
      tags: tags,
      units: units,
      unitOptions: unitOptions,
      unitAbbreviationToId: abbrToId,
      unitIdToAbbreviation: idToAbbr,
      upvotes: upvotes,
      category: category,
      myVoteVerdict: myVoteVerdict,
    );
  }
}
