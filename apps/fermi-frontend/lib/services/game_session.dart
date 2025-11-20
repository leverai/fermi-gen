import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/game_realtime.dart';

class GameSessionController {
  final String gameId;
  final GameRealtime realtime;
  final ApiService api;

  GameSessionController({
    required this.gameId,
    required this.realtime,
    required this.api,
  });

  Future<void> leaveGame() async {
    final String me = realtime.currentPlayerId;
    await api.removePlayer(gameId: gameId, playerId: me);
  }
}
