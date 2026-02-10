import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'package:fermi_frontend/screens/lobby/lobby_screen.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/game_realtime.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/screens/question_v2/helpers/leave.dart';
import 'package:fermi_frontend/services/game_session.dart';

class LobbyScreenController extends StatefulWidget {
  const LobbyScreenController({
    super.key,
    required this.gameId,
    required this.realtime,
    required this.api,
    this.initialPlayers,
  });

  final String gameId;
  final GameRealtime realtime;
  final ApiService api;
  final List<PlayerState>? initialPlayers;

  @override
  State<LobbyScreenController> createState() => _LobbyScreenControllerState();
}

class _LobbyScreenControllerState extends State<LobbyScreenController> {
  StreamSubscription<GameSnapshot>? _sub;
  List<PlayerState> _players = const <PlayerState>[];
  bool _isHost = false;
  bool _isLobbyReady = false;
  String? _joinUrl;
  bool _navigatedToQuestions = false;
  GameSessionController? _session;
  int _botsToInvite = 0;
  DateTime? _createdAt;
  int? _maxPlayers;
  bool _isShowingLeaveDialog = false;

  @override
  void initState() {
    super.initState();
    _session = GameSessionController(
      gameId: widget.gameId,
      realtime: widget.realtime,
      api: widget.api,
    );
    // Seed players with initial snapshot (from Main) for hero continuity
    if (widget.initialPlayers != null) {
      _players = List<PlayerState>.from(widget.initialPlayers!);
    }
    _sub = widget.realtime.watchGame(widget.gameId).listen((snapshot) {
      setState(() {
        _isHost = snapshot.isHost;
        _isLobbyReady = snapshot.state == GameState.lobbyReady;
        _joinUrl = snapshot.joinUrl;
        _createdAt = snapshot.createdAt;
        _maxPlayers = snapshot.maxPlayers;
        // Calculate how many bots can be invited
        final int currentPlayerCount = snapshot.players.length;
        final int maxPlayers =
            snapshot.maxPlayers ?? 8; // Fallback for legacy games
        final int remainingSpots = maxPlayers - currentPlayerCount;
        _botsToInvite = min(4, max(0, remainingSpots));
        // Lobby: preserve natural order as provided by the snapshot
        _players = snapshot.players.values
            .map((p) => PlayerState(
                  playerId: p.playerId,
                  isHost: p.isHost,
                  status: PlayerStatus.none,
                  score: p.score.round(),
                  avatarUrl: p.pictureUrl,
                  displayName: p.name,
                  ringState: RingState.review, // Static ring in lobby
                ))
            .toList(growable: false);
      });
      // Navigate to QuestionScreenV2 when a question becomes active
      if (!_navigatedToQuestions &&
          (snapshot.state == GameState.questionN ||
              snapshot.state == GameState.questionLast)) {
        _navigatedToQuestions = true;
        final int count = snapshot.nQuestions.clamp(1, 1000);

        if (!mounted) return;
        final ThemeData base = Theme.of(context);
        final AppTheme appTheme =
            base.extension<AppTheme>() ?? AppTheme.defaultTheme();
        final ThemeData themed = base.copyWith(
          scaffoldBackgroundColor: appTheme.bg,
          extensions: <ThemeExtension<dynamic>>[
            base.extension<AppFont>() ?? const AppFont(),
            appTheme,
          ],
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => Theme(
                data: themed,
                child: Scaffold(
                  resizeToAvoidBottomInset: false,
                  backgroundColor: Colors.transparent,
                  body: QuestionScreenV2(
                    gameId: widget.gameId,
                    realtime: widget.realtime,
                    questionCount: count,
                    isHost: _isHost,
                    session: _session,
                    initialPlayers: _players,
                  ),
                ),
              ),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
            ),
          );
        });
      }
      // Diagnostics removed after verification
    }, onError: (Object error, StackTrace st) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Realtime error: $error')));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.realtime.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      await widget.api.startGame(gameId: widget.gameId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to start game: $e')));
    }
  }

  Future<void> _shareInvite() async {
    final String? url = _joinUrl;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite link available')),
      );
      return;
    }
    try {
      if (kIsWeb) {
        // Web: Copy to clipboard and show feedback
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link copied.')),
        );
      } else {
        // Mobile: Use native share sheet
        // sharePositionOrigin is required on iPad for the popover anchor.
        final box = context.findRenderObject() as RenderBox?;
        final origin =
            box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
        await Share.share(url,
            subject: 'Join my Fermi game', sharePositionOrigin: origin);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy invite link: $e')),
      );
    }
  }

  Future<void> _inviteBots() async {
    if (_botsToInvite <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bot slots available')),
      );
      return;
    }
    try {
      // Request four Gemini bots (1 to 4)
      await widget.api.addBots(
        gameId: widget.gameId,
        botIds: ['bot-gemini1', 'bot-gemini2', 'bot-gemini3', 'bot-gemini4'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invited 4 bots to the game')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to invite bots: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final AppTheme appTheme =
        base.extension<AppTheme>() ?? AppTheme.defaultTheme();
    final ThemeData themed = base.copyWith(
      scaffoldBackgroundColor: appTheme.bg,
      extensions: <ThemeExtension<dynamic>>[
        const AppFont(), // Use default fonts (Barlow & Jura)
        appTheme,
      ],
    );

    return Theme(
      data: themed,
      child: LobbyScreen(
        players: _players,
        startEnabled: _isHost && _isLobbyReady,
        onStart: _startGame,
        joinUrl: _joinUrl,
        onShare: _shareInvite,
        currentPlayerId: widget.realtime.currentPlayerId,
        isHost: _isHost,
        onInviteBots: _isHost ? _inviteBots : null,
        botsToInvite: _botsToInvite,
        createdAt: _createdAt,
        maxPlayers: _maxPlayers,
        onLeave: () async {
          if (_isShowingLeaveDialog) return;
          _isShowingLeaveDialog = true;
          final appTheme = Theme.of(context).extension<AppTheme>() ??
              AppTheme.defaultTheme();
          try {
            await confirmLeaveDialog(
              context: context,
              highlightColor: appTheme.danger,
              onConfirm: () async {
                try {
                  final session = GameSessionController(
                    gameId: widget.gameId,
                    realtime: widget.realtime,
                    api: widget.api,
                  );
                  await session.leaveGame();
                } catch (e) {
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave: $e')),
                  );
                  return;
                }
                if (!mounted || !context.mounted) return;
                // First pop Navigator stack to clear any routes pushed via Navigator.push()
                // This handles the case where lobby was opened from main_screen.dart
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Then use go_router to ensure we land on main screen
                // This handles any go_router state and deep link entry
                context.go('/main');
              },
            );
          } finally {
            _isShowingLeaveDialog = false;
          }
        },
      ),
    );
  }
}
