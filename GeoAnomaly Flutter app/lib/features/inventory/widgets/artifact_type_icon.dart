import 'package:flutter/material.dart';

class ArtifactTypeIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;

  const ArtifactTypeIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconData(type);
    final iconColor = color ?? Colors.white;

    return Icon(
      iconData.icon,
      size: size,
      color: iconColor,
    );
  }

  ArtifactIconData _getIconData(String type) {
    switch (type.toLowerCase()) {
      case 'crystal':
        return const ArtifactIconData(
          icon: Icons.diamond,
          description: 'Energy Crystal',
        );
      case 'orb':
        return const ArtifactIconData(
          icon: Icons.circle,
          description: 'Power Orb',
        );
      case 'scroll':
        return const ArtifactIconData(
          icon: Icons.description,
          description: 'Ancient Scroll',
        );
      case 'tablet':
        return const ArtifactIconData(
          icon: Icons.tablet,
          description: 'Stone Tablet',
        );
      case 'rune':
        return const ArtifactIconData(
          icon: Icons.auto_awesome,
          description: 'Runic Stone',
        );
      case 'amulet':
        return const ArtifactIconData(
          icon: Icons.circle_outlined,
          description: 'Mystical Amulet',
        );
      case 'shard':
        return const ArtifactIconData(
          icon: Icons.change_history,
          description: 'Crystal Shard',
        );
      case 'essence':
        return const ArtifactIconData(
          icon: Icons.blur_on,
          description: 'Pure Essence',
        );
      case 'totem':
        return const ArtifactIconData(
          icon: Icons.account_balance,
          description: 'Ancient Totem',
        );
      case 'gem':
        return const ArtifactIconData(
          icon: Icons.scatter_plot,
          description: 'Precious Gem',
        );
      default:
        return const ArtifactIconData(
          icon: Icons.help_outline,
          description: 'Unknown Artifact',
        );
    }
  }
}

class ArtifactIconData {
  final IconData icon;
  final String description;

  const ArtifactIconData({
    required this.icon,
    required this.description,
  });
}

// Widget for displaying artifact type with text
class ArtifactTypeDisplay extends StatelessWidget {
  final String type;
  final double iconSize;
  final double textSize;
  final Color? color;
  final bool showDescription;

  const ArtifactTypeDisplay({
    super.key,
    required this.type,
    this.iconSize = 20,
    this.textSize = 14,
    this.color,
    this.showDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    final artifactIcon = ArtifactTypeIcon(
      type: type,
      size: iconSize,
      color: color,
    );
    final iconData = artifactIcon._getIconData(type);
    final displayColor = color ?? Theme.of(context).textTheme.bodyMedium?.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArtifactTypeIcon(
          type: type,
          size: iconSize,
          color: displayColor,
        ),
        const SizedBox(width: 6),
        Text(
          showDescription ? iconData.description : _capitalizeFirst(type),
          style: TextStyle(
            fontSize: textSize,
            color: displayColor,
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
