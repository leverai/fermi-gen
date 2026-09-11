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
import 'package:fermi_frontend/widgets/styled_dialog.dart';
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
    this.searchQuery,
    this.onStartSucceeded,
  });

  final String gameId;
  final GameRealtime realtime;
  final ApiService api;
  final List<PlayerState>? initialPlayers;

  /// The smart-search query for this game, if it is a search game (null for
  /// category games and for join/deep-link entry, which has no local query).
  ///
  /// The search runs server-side at start; on a successful start this query is
  /// the one to persist to recents (the host who created the game owns it).
  final String? searchQuery;

  /// Invoked once the game START call succeeds. The create flow wires this to
  /// save [searchQuery] to recents (recents reflect queries that produced a
  /// playable game). Null when there is nothing to do on start (e.g. join).
  final VoidCallback? onStartSucceeded;

  @override
  State<LobbyScreenController> createState() => _LobbyScreenControllerState();
}

class _LobbyScreenControllerState extends State<LobbyScreenController> {
  StreamSubscription<GameSnapshot>? _sub;
  List<PlayerState> _players = const <PlayerState>[];
  bool _isHost = false;
  bool _isLobbyReady = false;
  bool _isStarting = false;
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
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      // Questions are fetched server-side when the game starts (the smart
      // search, if any, runs here too), so this call may take a moment. The
      // loading state keeps the host informed and guards against double taps.
      // Navigation to the question screen happens via the realtime listener
      // once the state flips to a question state.
      await widget.api.startGame(gameId: widget.gameId);
      // The game started: persist the search query to recents now (only
      // queries that produced a playable game are remembered). We keep the
      // loading state until the realtime listener navigates away.
      widget.onStartSucceeded?.call();
    } on SearchInsufficientQuestionsException catch (e) {
      // The eligible corpus cannot currently fill a game. The lobby's query is
      // immutable, so describe this as an availability issue rather than
      // advising the host to enter a different search here.
      if (!mounted) return;
      setState(() => _isStarting = false);
      await _showStartErrorDialog(
        title: 'Not enough questions available',
        message: e.message,
      );
    } on SearchNoResultsException catch (e) {
      // Legacy rolling-deploy compatibility for older backends that still
      // describe a too-small search result as a query-actionable 422.
      if (!mounted) return;
      setState(() => _isStarting = false);
      await _showStartErrorDialog(
        title: 'No questions found',
        message: e.message,
      );
    } on SearchEmbeddingException catch (e) {
      // Transient embed failure: retrying the same query is reasonable.
      if (!mounted) return;
      setState(() => _isStarting = false);
      await _showStartErrorDialog(
        title: "Couldn't start the game",
        message: e.message,
      );
    } catch (e) {
      // Generic start failure (non-search, or any other error).
      if (!mounted) return;
      setState(() => _isStarting = false);
      await _showStartErrorDialog(
        title: "Couldn't start the game",
        message: 'Something went wrong starting the game. Please try again.',
      );
    }
  }

  /// Shows a single-action ("OK") styled dialog explaining why the game did not
  /// start. Used for the search-specific failures and the generic fallback.
  Future<void> _showStartErrorDialog({
    required String title,
    required String message,
  }) async {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StyledDialog(
        message: title,
        secondaryMessage: message,
        primaryButtonLabel: 'OK',
        primaryButtonColor: appTheme.highlight,
        onPrimaryPressed: () => Navigator.of(ctx).pop(),
        showAsDialog: true,
      ),
    );
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
        startEnabled: _isHost && _isLobbyReady && !_isStarting,
        isStarting: _isStarting,
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
