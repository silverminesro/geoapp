import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ScanButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isScanning;
  final Duration? cooldownRemaining;

  const ScanButton({
    super.key,
    required this.onPressed,
    this.isScanning = false,
    this.cooldownRemaining,
  });

  @override
  State<ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
  }

  @override
  void didUpdateWidget(ScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _animationController.repeat();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _isOnCooldown =>
      widget.cooldownRemaining != null &&
      widget.cooldownRemaining!.inSeconds > 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cooldown timer
        if (_isOnCooldown)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.cooldownRemaining!.inMinutes}:${(widget.cooldownRemaining!.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Scan button
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isScanning ? _scaleAnimation.value : 1.0,
              child: Transform.rotate(
                angle: widget.isScanning
                    ? _rotationAnimation.value * 3.14159
                    : 0.0,
                child: FloatingActionButton(
                  onPressed: widget.onPressed,
                  backgroundColor: _getButtonColor(),
                  heroTag: "scan_button",
                  tooltip: _getTooltip(),
                  child: _getButtonIcon(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getButtonColor() {
    if (widget.isScanning) {
      return AppTheme.primaryColor.withOpacity(0.8);
    } else if (_isOnCooldown) {
      return Colors.grey[600]!;
    } else {
      return AppTheme.primaryColor;
    }
  }

  String _getTooltip() {
    if (widget.isScanning) {
      return 'Scanning...';
    } else if (_isOnCooldown) {
      return 'On cooldown';
    } else {
      return 'Scan for zones';
    }
  }

  Widget _getButtonIcon() {
    if (widget.isScanning) {
      return CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      );
    } else if (_isOnCooldown) {
      return Icon(
        Icons.timer,
        color: Colors.white,
        size: 28,
      );
    } else {
      return Icon(
        Icons.search,
        color: Colors.white,
        size: 28,
      );
    }
  }
}
