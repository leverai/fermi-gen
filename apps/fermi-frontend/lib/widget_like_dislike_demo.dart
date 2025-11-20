import 'package:flutter/material.dart';
import 'widgets/animated_like_dislike.dart';

void main() => runApp(const LikeDislikeDemoApp());

class LikeDislikeDemoApp extends StatelessWidget {
  const LikeDislikeDemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Animated Like/Dislike Demo',
      home: _DemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();
  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  VoteState state = VoteState.none;
  int likes = 12;

  Future<void> _upvote() async => setState(() => likes += 1);
  Future<void> _deUpvote() async => setState(() => likes -= 1);
  Future<void> _downvote() async => setState(() {});
  Future<void> _deDownvote() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animated Like/Dislike Demo')),
      body: Center(
        child: AnimatedLikeDislike(
          voteState: state,
          likeCount: likes,
          onUpvote: () async {
            if (state == VoteState.downvoted) await _deDownvote();
            await _upvote();
            setState(() => state = VoteState.upvoted);
          },
          onDeUpvote: () async {
            await _deUpvote();
            setState(() => state = VoteState.none);
          },
          onDownvote: () async {
            if (state == VoteState.upvoted) await _deUpvote();
            await _downvote();
            setState(() => state = VoteState.downvoted);
          },
          onDeDownvote: () async {
            await _deDownvote();
            setState(() => state = VoteState.none);
          },
        ),
      ),
    );
  }
}
