import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fermi_frontend/models/game_config.dart';
import 'package:fermi_frontend/services/firestore_game_realtime.dart';

/// Creates a test FirestoreGameRealtime instance with default configuration.
FirestoreGameRealtime createTestRealtime({
  required FakeFirebaseFirestore firestore,
  String currentPlayerId = 'player-1',
  GameConfig? gameConfig,
}) {
  return FirestoreGameRealtime(
    currentPlayerId: currentPlayerId,
    firestore: firestore,
    gameConfig: gameConfig ??
        const GameConfig(
          categories: [
            CategoryInfo(
              index: 0,
              name: 'PLANET_EARTH',
              slug: 'Planet Earth',
              theme: {'primary': '#FF0000'},
              picture: '',
            ),
          ],
          difficulties: [
            DifficultyInfo(
              name: 'EASY',
              slug: 'Easy',
              picture: '',
            ),
          ],
        ),
  );
}
