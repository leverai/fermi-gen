import 'dart:convert';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:http/http.dart' as http;
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/utils/env.dart';
import 'package:fermi_frontend/utils/om_constants.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final String _apiBaseUrl;
  final AuthService authService;
  final http.Client client;

  ApiService({
    required this.authService,
    http.Client? client,
    String? apiBaseUrl,
  })  : client = client ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? resolveApiBaseUrlOrThrow();

  // --- Auth-aware request helpers ---
  Future<http.Response> _authGet(String path) async {
    final String? token = authService.accessToken;
    if (token == null) throw Exception('User is not authorized');
    final Uri uri = Uri.parse('$_apiBaseUrl$path');
    http.Response resp = await client.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
    if (resp.statusCode == 401) {
      final bool refreshed = await authService.refreshAccessToken();
      if (!refreshed) return resp;
      final String? newToken = authService.accessToken;
      if (newToken == null) return resp;
      resp = await client.get(uri, headers: {
        'Authorization': 'Bearer $newToken',
        'Accept': 'application/json',
      });
    }
    return resp;
  }

  Future<http.Response> _authPost(String path, Object? body) async {
    final String? token = authService.accessToken;
    if (token == null) throw Exception('User is not authorized');
    final Uri uri = Uri.parse('$_apiBaseUrl$path');
    http.Response resp = await client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
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
        },
        body: jsonEncode(body),
      );
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

  Future<Map<String, dynamic>> getPlayerStats(
      {required String playerId}) async {
    try {
      final response = await _authPost('/game/get_player_stats', {
        'player_id': playerId,
      });

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

  Future<PlayerStatsResponse> getPlayerStatsTyped(
      {required String playerId}) async {
    final raw = await getPlayerStats(playerId: playerId);
    return PlayerStatsResponse.fromJson(raw);
  }

  Future<String> createGame({
    required bool isPrivate,
    String? category,
    String? difficulty,
    int? nQuestions,
  }) async {
    try {
      final body = {
        'question_round_settings': {
          if (nQuestions != null) 'n_questions': nQuestions,
          'category': category,
          'difficulty': difficulty,
        },
        'is_private': isPrivate,
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

  Future<String> joinRandomGame({
    String? category,
    String? difficulty,
    int? nQuestions,
  }) async {
    try {
      final body = {
        'resource_id': null,
        'question_round_settings': {
          if (nQuestions != null) 'n_questions': nQuestions,
          'category': category,
          'difficulty': difficulty,
        },
      };

      debugPrint(
          '🔍 joinRandomGame: Sending request body: ${jsonEncode(body)}');
      final response = await _authPost('/game/join_random', body);
      debugPrint('🔍 joinRandomGame: Response status: ${response.statusCode}');
      debugPrint('🔍 joinRandomGame: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['resource_id'] as String);
      }
      final error = jsonDecode(response.body)['detail'];
      throw Exception('Failed to join random game: $error');
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
      // Optimistically update client-side auth state
      authService.locale = locale;
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
}

// Moved to utils/env.dart
