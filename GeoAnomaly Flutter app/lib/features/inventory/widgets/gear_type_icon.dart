import 'package:flutter/material.dart';

class GearTypeIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;

  const GearTypeIcon({
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

  GearIconData _getIconData(String type) {
    switch (type.toLowerCase()) {
      case 'helmet':
        return const GearIconData(
          icon: Icons.sports_motorsports,
          description: 'Protective Helmet',
        );
      case 'shield':
        return const GearIconData(
          icon: Icons.shield,
          description: 'Combat Shield',
        );
      case 'armor':
        return const GearIconData(
          icon: Icons.security,
          description: 'Body Armor',
        );
      case 'weapon':
        return const GearIconData(
          icon: Icons.gavel,
          description: 'Weapon',
        );
      case 'boots':
        return const GearIconData(
          icon: Icons.directions_walk,
          description: 'Combat Boots',
        );
      case 'gloves':
        return const GearIconData(
          icon: Icons.back_hand,
          description: 'Tactical Gloves',
        );
      case 'belt':
        return const GearIconData(
          icon: Icons.horizontal_rule,
          description: 'Utility Belt',
        );
      case 'backpack':
        return const GearIconData(
          icon: Icons.backpack,
          description: 'Equipment Pack',
        );
      case 'tool':
        return const GearIconData(
          icon: Icons.build,
          description: 'Tool',
        );
      case 'accessory':
        return const GearIconData(
          icon: Icons.star,
          description: 'Accessory',
        );
      default:
        return const GearIconData(
          icon: Icons.inventory,
          description: 'Equipment',
        );
    }
  }
}

class GearIconData {
  final IconData icon;
  final String description;

  const GearIconData({
    required this.icon,
    required this.description,
  });
}

// Widget for displaying gear type with text and level
class GearTypeDisplay extends StatelessWidget {
  final String type;
  final int level;
  final double iconSize;
  final double textSize;
  final Color? color;
  final bool showDescription;
  final bool showLevel;

  const GearTypeDisplay({
    super.key,
    required this.type,
    this.level = 1,
    this.iconSize = 20,
    this.textSize = 14,
    this.color,
    this.showDescription = false,
    this.showLevel = true,
  });

  @override
  Widget build(BuildContext context) {
    final gearIcon = GearTypeIcon(
      type: type,
      size: iconSize,
      color: color,
    );
    final iconData = gearIcon._getIconData(type);
    final displayColor = color ?? Theme.of(context).textTheme.bodyMedium?.color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GearTypeIcon(
          type: type,
          size: iconSize,
          color: displayColor,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showDescription ? iconData.description : _capitalizeFirst(type),
              style: TextStyle(
                fontSize: textSize,
                color: displayColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showLevel && level > 0)
              Text(
                'Level $level',
                style: TextStyle(
                  fontSize: textSize * 0.8,
                  color: displayColor?.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
