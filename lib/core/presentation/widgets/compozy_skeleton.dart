import 'package:material_ui/material_ui.dart';

import '../../theme/compozy_theme.dart';

/// Subtle breathing placeholder; must not run an infinite ticker when
/// MediaQuery.disableAnimations is true.
class CompozySkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const CompozySkeleton({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius,
  });

  @override
  State<CompozySkeleton> createState() => _CompozySkeletonState();
}

class _CompozySkeletonState extends State<CompozySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.5;
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final scaledHeight = textScaler.scale(widget.height);
    final radius = widget.borderRadius ?? CompozyRadius.input;

    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final opacity = _animation.value;
          return Container(
            width: widget.width,
            height: scaledHeight,
            decoration: BoxDecoration(
              color: palette.surface2.withValues(alpha: opacity),
              borderRadius: radius,
            ),
          );
        },
      ),
    );
  }
}

/// Fixed-height card placeholders for list loading states.
class CompozySkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;

  const CompozySkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 92,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: CompozyRadius.card,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  CompozySkeleton(width: 80, height: 10),
                  CompozySkeleton(
                    width: 54,
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(9999)),
                  ),
                ],
              ),
              const CompozySkeleton(width: 180, height: 12),
              Row(
                children: const [
                  CompozySkeleton(
                    width: 18,
                    height: 18,
                    borderRadius: BorderRadius.all(Radius.circular(9999)),
                  ),
                  SizedBox(width: 8),
                  CompozySkeleton(width: 70, height: 10),
                  Spacer(),
                  CompozySkeleton(width: 50, height: 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
