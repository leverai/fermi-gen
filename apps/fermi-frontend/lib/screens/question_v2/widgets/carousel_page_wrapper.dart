import 'package:flutter/material.dart';

/// Wrapper widget that preserves state using AutomaticKeepAliveClientMixin
/// This ensures carousel pages retain their state when scrolled away
class CarouselPageWrapper extends StatefulWidget {
  const CarouselPageWrapper({
    super.key,
    required this.child,
    required this.index,
  });

  final Widget child;
  final int index;

  @override
  State<CarouselPageWrapper> createState() => _CarouselPageWrapperState();
}

class _CarouselPageWrapperState extends State<CarouselPageWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return widget.child;
  }
}
