import 'dart:convert';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/models/avatar_info.dart';
import 'package:http/http.dart' as http;
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/models/survival_models.dart';
import 'package:fermi_frontend/models/precision_rush_models.dart';
import 'package:fermi_frontend/models/user_limits.dart';
import 'package:fermi_frontend/utils/env.dart';
import 'package:fermi_frontend/utils/om_constants.dart';
import 'package:fermi_frontend/services/tracing_service.dart';

/// Exception thrown when API rate limit (HTTP 429) is exceeded.
class RateLimitException implements Exception {
  final int retryAfterSeconds;
  RateLimitException(this.retryAfterSeconds);

  @override
  String toString() =>
      'Too many requests. Please wait $retryAfterSeconds seconds.';
}

class ApiService {
  final String _apiBaseUrl;
  final AuthService authService;
  final http.Client client;
  final TracingService _tracing;

  ApiService({
    required this.authService,
    http.Client? client,
    String? apiBaseUrl,
    TracingService? tracing,
  })  : client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? resolveApiBaseUrlOrThrow(),
        _tracing = tracing ?? TracingService.instance;

  // --- Auth-aware request helpers ---
  Future<http.Response> get(String path) => _authGet(path);
  Future<http.Response> post(String path, Object? body) =>
      _authPost(path, body);

  Future<http.Response> _authGet(String path) async {
    // Proactive refresh: check token before request
    if (authService.shouldRefreshToken()) {
      await authService.refreshAccessToken();
    }

    final String? token = authService.accessToken;
    if (token == null) throw Exception('User is not authorized');
    final Uri uri = Uri.parse('$_apiBaseUrl$path');
    final String traceparent = _tracing.generateTraceparent();
    http.Response resp = await client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'traceparent': traceparent,
    });
    if (resp.statusCode == 401) {
      final bool refreshed = await authService.refreshAccessToken();
      if (!refreshed) return resp;
      final String? newToken = authService.accessToken;
      if (newToken == null) return resp;
      resp = await client.get(uri, headers: {
        'Authorization': 'Bearer $newToken',
        'Accept': 'application/json',
        'traceparent': traceparent,
      });
    }
    if (resp.statusCode == 429) {
      final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '') ?? 60;
      throw RateLimitException(retryAfter);
    }
    return resp;
  }

  Future<http.Response> _authPost(String path, Object? body) async {
    // Proactive refresh: check token before request
    if (authService.shouldRefreshToken()) {
      await authService.refreshAccessToken();
    }

    final String? token = authService.accessToken;
    if (token == null) throw Exception('User is not authorized');
    final Uri uri = Uri.parse('$_apiBaseUrl$path');
    final String traceparent = _tracing.generateTraceparent();
    http.Response resp = await client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'traceparent': traceparent,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode == 401) {
      final bool refreshed = await authService.refreshAccessToken();
      if (!refreshed) return resp;
      final String? newToken = authService.accessToken;
      if (newToken == null) return resp;
      resp = await client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $newToken',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'traceparent': traceparent,
        },
        body: jsonEncode(body),
      );
    }
    if (resp.statusCode == 429) {
      final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '') ?? 60;
      throw RateLimitException(retryAfter);
    }
    return resp;
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final dynamic detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        return body.toString();
      }
      return body?.toString() ?? 'HTTP ${response.statusCode}';
    } catch (_) {
      final String text = response.body;
      if (text.isNotEmpty) {
        // Trim very long HTML/text responses to keep SnackBar tidy
        return text.substring(0, text.length.clamp(0, 200));
      }
      return 'HTTP ${response.statusCode}';
    }
  }

  Future<Map<String, dynamic>> getGameConfig() async {
    try {
      final response = await _authGet('/game/config');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['detail'];
        throw Exception('Failed to get game config: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<GameConfig> getGameConfigTyped() async {
    final raw = await getGameConfig();
    return GameConfig.fromJson(raw);
  }

  Future<Map<String, dynamic>> getUserLimits() async {
    try {
      final response = await _authGet('/user/limits');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['detail'];
        throw Exception('Failed to get user limits: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<UserLimits> getUserLimitsTyped() async {
    final raw = await getUserLimits();
    final limitsJson = raw['limits'] as Map<String, dynamic>;
    return UserLimits.fromJson(limitsJson);
  }

  Future<Map<String, dynamic>> getPlayerStats() async {
    try {
      final response = await _authPost('/game/get_player_stats', {});

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['detail'];
        throw Exception('Failed to get player stats: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<PlayerStatsResponse> getPlayerStatsTyped() async {
    final raw = await getPlayerStats();
    return PlayerStatsResponse.fromJson(raw);
  }

  Future<String> createGame({
    List<String>? categories,
    String? difficulty,
    int? nQuestions,
  }) async {
    try {
      final body = {
        'question_round_settings': {
          if (nQuestions != null) 'n_questions': nQuestions,
          'categories': categories,
          'difficulty': difficulty,
        },
      };

      final response = await _authPost('/game/create', body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['resource_id'] as String);
      }
      final error = jsonDecode(response.body)['detail'];
      throw Exception('Failed to create game: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<String> joinGame({required String gameId}) async {
    try {
      final response = await _authPost('/game/join', {'resource_id': gameId});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['resource_id'] as String);
      }
      final error = jsonDecode(response.body)['detail'];
      throw Exception('Failed to join game: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> startGame({required String gameId}) async {
    try {
      final response = await _authPost('/game/start', {'resource_id': gameId});

      if (response.statusCode != 200) {
        final error = _extractErrorMessage(response);
        throw Exception('Failed to start game: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  // --- Gameplay actions ---

  int _applyOmMultiplier(AnswerValue value) {
    final int base = value.number.clamp(1, 999);
    final int mult = orderOfMagnitudeMultipliers[value.orderOfMagnitude] ?? 1;
    return base * mult;
  }

  Future<void> submitAnswer({
    required String gameId,
    required AnswerValue answer,
  }) async {
    try {
      final int resolvedNumber = _applyOmMultiplier(answer);
      // Backend expects unit id or null for unitless
      final String? unitOrNull = (answer.unit.isEmpty) ? null : answer.unit;
      final response = await _authPost('/game/answer', {
        'resource_id': gameId,
        'answer': {
          'number': resolvedNumber,
          'unit': unitOrNull,
        }
      });

      if (response.statusCode != 200) {
        final error = _extractErrorMessage(response);
        throw Exception('Failed to submit answer: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> nextQuestion({required String gameId}) async {
    try {
      final response = await _authPost('/game/next_question', {
        'resource_id': gameId,
      });

      if (response.statusCode != 200) {
        final error = _extractErrorMessage(response);
        throw Exception('Failed to request next question: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removePlayer(
      {required String gameId, required String playerId}) async {
    try {
      final response = await _authPost('/game/remove_player', {
        'resource_id': gameId,
        'player_id': playerId,
      });

      if (response.statusCode != 200) {
        final error = _extractErrorMessage(response);
        throw Exception('Failed to leave game: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addBots({
    required String gameId,
    required List<String> botIds,
  }) async {
    try {
      final response = await _authPost('/game/add_bots', {
        'resource_id': gameId,
        'bot_ids': botIds,
      });

      if (response.statusCode != 200) {
        final error = _extractErrorMessage(response);
        throw Exception('Failed to add bots: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  // --- Question votes ---
  Future<void> upvoteQuestion({required String questionUid}) async {
    await _postIdModel(path: '/question/upvote', resourceId: questionUid);
  }

  // --- User settings ---
  Future<void> setUserLocale({required String locale}) async {
    try {
      final resp = await _authPost('/user/set_locale', {'locale': locale});
      if (resp.statusCode != 200) {
        final error = _extractErrorMessage(resp);
        throw Exception('Failed to set locale: $error');
      }
      // Optimistically updateclient-side auth state
      authService.locale = locale;
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final resp = await _authPost('/user/update_profile', {
        'display_name': displayName,
        'avatar_url': avatarUrl,
      });
      if (resp.statusCode != 200) {
        final error = _extractErrorMessage(resp);
        throw Exception('Failed to update profile: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AvatarInfo>> getAvatars() async {
    try {
      final resp = await _authGet('/assets/avatars');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> avatarsList = data['avatars'];
        return avatarsList
            .map((json) => AvatarInfo.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = _extractErrorMessage(resp);
        throw Exception('Failed to load avatars: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deUpvoteQuestion({required String questionUid}) async {
    // Backend exposes only /upvote and /downvote.
    // To remove an existing upvote, call downvote to toggle to no-vote.
    await _postIdModel(path: '/question/downvote', resourceId: questionUid);
  }

  Future<void> downvoteQuestion({required String questionUid}) async {
    await _postIdModel(path: '/question/downvote', resourceId: questionUid);
  }

  Future<void> deDownvoteQuestion({required String questionUid}) async {
    // To remove an existing downvote, call upvote to toggle to no-vote.
    await _postIdModel(path: '/question/upvote', resourceId: questionUid);
  }

  Future<void> _postIdModel(
      {required String path, required String resourceId}) async {
    try {
      final resp = await _authPost(path, {'resource_id': resourceId});
      if (resp.statusCode != 200) {
        final error = _extractErrorMessage(resp);
        throw Exception('Request $path failed: $error');
      }
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  // --- Survival Mode ---

  /// Start a new survival run or resume an existing one.
  /// Returns the question response with run_id, question data, and deadline.
  /// If [withAd] is true, bypasses the daily run limit (after watching ad).
  Future<Map<String, dynamic>> survivalCreateOrResume({
    int? runId,
    bool withAd = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (runId != null) {
        body['run_id'] = runId;
      }
      String path = '/survival/create_or_resume';
      if (withAd) {
        path += '?with_ad=true';
      }
      final resp = await _authPost(path, body);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to start survival: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Submit an answer for the current survival question.
  /// Returns pass/fail status, score, and next question info.
  Future<Map<String, dynamic>> survivalSubmitAnswer({
    required int runId,
    required AnswerValue answer,
  }) async {
    try {
      final int resolvedNumber = _applyOmMultiplier(answer);
      final String? unitOrNull = (answer.unit.isEmpty) ? null : answer.unit;
      final resp = await _authPost('/survival/answer', {
        'run_id': runId,
        'answer': {
          'number': resolvedNumber,
          'unit': unitOrNull,
        },
      });
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to submit survival answer: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's survival statistics.
  Future<Map<String, dynamic>> survivalGetStats() async {
    try {
      final resp = await _authGet('/survival/stats');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to get survival stats: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's survival streak stats (current and best).
  Future<Map<String, dynamic>> survivalGetStreakStats() async {
    try {
      final resp = await _authGet('/survival/streak');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to get survival streak stats: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get survival mode leaderboard.
  Future<LeaderboardResponse> survivalGetLeaderboard({
    int page = 1,
    int pageSize = 25,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    try {
      final resp = await _authGet(
          '/survival/leaderboard?page=$page&page_size=$pageSize&period=${period.apiValue}');
      if (resp.statusCode == 200) {
        return LeaderboardResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to get leaderboard: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Continue a failed survival run after watching a rewarded ad.
  /// Returns the next question to continue the run.
  Future<Map<String, dynamic>> survivalContinueWithAd({
    required int runId,
  }) async {
    try {
      final resp = await _authPost('/survival/continue_with_ad', {
        'run_id': runId,
      });
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to continue with ad: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  // --- Precision Rush Mode ---

  /// Start a new PR run or resume an existing one.
  Future<Map<String, dynamic>> prCreateOrResume({
    int? runId,
    bool withAd = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (runId != null) {
        body['run_id'] = runId;
      }
      String path = '/precision_rush/create_or_resume';
      if (withAd) {
        path += '?with_ad=true';
      }
      final resp = await _authPost(path, body);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to start precision rush: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Submit an answer for the current PR question.
  Future<Map<String, dynamic>> prSubmitAnswer({
    required int runId,
    required AnswerValue answer,
  }) async {
    try {
      final int resolvedNumber = _applyOmMultiplier(answer);
      final String? unitOrNull = (answer.unit.isEmpty) ? null : answer.unit;
      final resp = await _authPost('/precision_rush/answer', {
        'run_id': runId,
        'answer': {
          'number': resolvedNumber,
          'unit': unitOrNull,
        },
      });
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to submit precision rush answer: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's PR statistics.
  Future<Map<String, dynamic>> prGetStats() async {
    try {
      final resp = await _authGet('/precision_rush/stats');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to get precision rush stats: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  /// Get PR mode leaderboard.
  Future<PRLeaderboardResponse> prGetLeaderboard({
    int page = 1,
    int pageSize = 25,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    try {
      final resp = await _authGet(
          '/precision_rush/leaderboard?page=$page&page_size=$pageSize&period=${period.apiValue}');
      if (resp.statusCode == 200) {
        return PRLeaderboardResponse.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
      final error = _extractErrorMessage(resp);
      throw Exception('Failed to get leaderboard: $error');
    } on http.ClientException catch (_) {
      throw Exception('Network error: Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }
}

// Moved to utils/env.dart
