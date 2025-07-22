import 'package:flutter/material.dart';

enum RarityBadgeSize {
  small,
  medium,
  large,
}

class RarityBadge extends StatelessWidget {
  final String rarity;
  final RarityBadgeSize size;

  const RarityBadge({
    super.key,
    required this.rarity,
    this.size = RarityBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final rarityData = _getRarityData(rarity);
    final sizeData = _getSizeData(size);

    return Container(
      width: sizeData.width,
      height: sizeData.height,
      decoration: BoxDecoration(
        color: rarityData.color,
        borderRadius: BorderRadius.circular(sizeData.borderRadius),
        border: Border.all(
          color: Colors.white,
          width: size == RarityBadgeSize.large ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: rarityData.color.withOpacity(0.3),
            blurRadius: sizeData.shadowBlur,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rarityData.emoji,
            style: TextStyle(fontSize: sizeData.emojiSize),
          ),
          if (size != RarityBadgeSize.small) ...[
            const SizedBox(height: 2),
            Text(
              rarityData.shortName,
              style: TextStyle(
                color: Colors.white,
                fontSize: sizeData.textSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  RarityData _getRarityData(String rarity) {
    // Handle gear levels (e.g., "level_5")
    if (rarity.startsWith('level_')) {
      final level = int.tryParse(rarity.substring(6)) ?? 1;
      return _getGearLevelData(level);
    }

    // Handle artifact rarities
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return RarityData(
          emoji: '🟠',
          shortName: 'LEG',
          fullName: 'Legendary',
          color: const Color(0xFFFF9800),
        );
      case 'epic':
        return RarityData(
          emoji: '🟣',
          shortName: 'EPI',
          fullName: 'Epic',
          color: const Color(0xFF9C27B0),
        );
      case 'rare':
        return RarityData(
          emoji: '🔵',
          shortName: 'RAR',
          fullName: 'Rare',
          color: const Color(0xFF2196F3),
        );
      case 'common':
        return RarityData(
          emoji: '🟢',
          shortName: 'COM',
          fullName: 'Common',
          color: const Color(0xFF4CAF50),
        );
      default:
        return RarityData(
          emoji: '⚪',
          shortName: 'UNK',
          fullName: 'Unknown',
          color: Colors.grey,
        );
    }
  }

  RarityData _getGearLevelData(int level) {
    if (level >= 8) {
      return RarityData(
        emoji: '👑',
        shortName: 'L$level',
        fullName: 'Legendary',
        color: const Color(0xFFFF9800),
      );
    } else if (level >= 6) {
      return RarityData(
        emoji: '🟣',
        shortName: 'L$level',
        fullName: 'Epic',
        color: const Color(0xFF9C27B0),
      );
    } else if (level >= 4) {
      return RarityData(
        emoji: '🔵',
        shortName: 'L$level',
        fullName: 'Rare',
        color: const Color(0xFF2196F3),
      );
    } else if (level >= 2) {
      return RarityData(
        emoji: '🟢',
        shortName: 'L$level',
        fullName: 'Common',
        color: const Color(0xFF4CAF50),
      );
    } else {
      return RarityData(
        emoji: '⚪',
        shortName: 'L$level',
        fullName: 'Basic',
        color: Colors.grey,
      );
    }
  }

  SizeData _getSizeData(RarityBadgeSize size) {
    switch (size) {
      case RarityBadgeSize.small:
        return SizeData(
          width: 28,
          height: 28,
          emojiSize: 12,
          textSize: 8,
          borderRadius: 6,
          shadowBlur: 2,
        );
      case RarityBadgeSize.medium:
        return SizeData(
          width: 40,
          height: 40,
          emojiSize: 16,
          textSize: 10,
          borderRadius: 8,
          shadowBlur: 4,
        );
      case RarityBadgeSize.large:
        return SizeData(
          width: 60,
          height: 60,
          emojiSize: 24,
          textSize: 12,
          borderRadius: 12,
          shadowBlur: 6,
        );
    }
  }
}

class RarityData {
  final String emoji;
  final String shortName;
  final String fullName;
  final Color color;

  const RarityData({
    required this.emoji,
    required this.shortName,
    required this.fullName,
    required this.color,
  });
}

class SizeData {
  final double width;
  final double height;
  final double emojiSize;
  final double textSize;
  final double borderRadius;
  final double shadowBlur;

  const SizeData({
    required this.width,
    required this.height,
    required this.emojiSize,
    required this.textSize,
    required this.borderRadius,
    required this.shadowBlur,
  });
}
