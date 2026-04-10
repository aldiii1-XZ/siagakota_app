import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

// ============ LOADING STATES ============

/// Elegant loading indicator
class SiagaLoadingWidget extends StatefulWidget {
  final String? message;
  final bool showOverlay;

  const SiagaLoadingWidget({
    super.key,
    this.message,
    this.showOverlay = false,
  });

  @override
  State<SiagaLoadingWidget> createState() => _SiagaLoadingWidgetState();
}

class _SiagaLoadingWidgetState extends State<SiagaLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRotatingLogo(),
          if (widget.message != null) ...[
            const SizedBox(height: AppTheme.lg),
            Text(
              widget.message!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.neutral600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (widget.showOverlay) {
      return Container(
        color: Colors.black.withAlpha((0.3 * 255).round()),
        child: content,
      );
    }
    return content;
  }

  Widget _buildRotatingLogo() {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(
          Icons.emergency_share_outlined,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

/// Loading shimmer effect for cards
class ShimmerLoadingCard extends StatefulWidget {
  final double height;
  final double borderRadius;

  const ShimmerLoadingCard({
    super.key,
    this.height = 200,
    this.borderRadius = AppTheme.radiusLg,
  });

  @override
  State<ShimmerLoadingCard> createState() => _ShimmerLoadingCardState();
}

class _ShimmerLoadingCardState extends State<ShimmerLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: [
              AppTheme.neutral100,
              AppTheme.neutral200,
              AppTheme.neutral100,
            ],
            stops: [
              _controller.value - 0.2,
              _controller.value,
              _controller.value + 0.2,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

// ============ EMPTY STATES ============

/// Empty state widget dengan icon & message
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon dengan gradient background
              Container(
                width: iconSize + 20,
                height: iconSize + 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      (iconColor ?? AppTheme.primary).withAlpha((0.1 * 255).round()),
                      (iconColor ?? AppTheme.primary).withAlpha((0.05 * 255).round()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? AppTheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.xl),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral900,
                ),
              ),
              const SizedBox(height: AppTheme.md),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.neutral600,
                    height: 1.5,
                  ),
                ),
              ),

              // Action button
              if (action != null) ...[
                const SizedBox(height: AppTheme.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============ ANIMATED WIDGETS ============

/// Slide-in animation from left
class SlideInFromLeft extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const SlideInFromLeft({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SlideInFromLeft> createState() => _SlideInFromLeftState();
}

class _SlideInFromLeftState extends State<SlideInFromLeft>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: widget.child,
    );
  }
}

/// Fade-in with scale animation
class FadeInScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const FadeInScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeInScale> createState() => _FadeInScaleState();
}

class _FadeInScaleState extends State<FadeInScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============ GRADIENT WIDGETS ============

/// Button dengan gradient background
class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final Gradient? gradient;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha((0.3 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null && !isLoading) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: AppTheme.md),
                ],
                if (isLoading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(200)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                ],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card dengan gradient border
class GradientBorderCard extends StatelessWidget {
  final Widget child;
  final double borderWidth;
  final Gradient? gradient;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.borderWidth = 2,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg - borderWidth),
        ),
        child: child,
      ),
    );
  }
}

// ============ ICON SYSTEM ============

/// Custom icon with background
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.primary;
    final icColor = iconColor ?? Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withAlpha((0.7 * 255).round())],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withAlpha((0.3 * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: icColor,
        size: size / 2,
      ),
    );
  }
}

/// Status icon with animation
class StatusIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool animate;

  const StatusIcon({
    super.key,
    required this.icon,
    required this.color,
    this.animate = true,
  });

  @override
  State<StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<StatusIcon> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat();
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Icon(widget.icon, color: widget.color, size: 24);
    }

    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Icon(widget.icon, color: widget.color, size: 24),
    );
  }
}

// ============ INFO CARDS ============

/// Info card dengan icon & title
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? accentColor;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = accentColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                bgColor.withAlpha((0.03 * 255).round()),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: icon,
                    backgroundColor: bgColor,
                    size: 40,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AppTheme.lg),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral900,
                ),
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
