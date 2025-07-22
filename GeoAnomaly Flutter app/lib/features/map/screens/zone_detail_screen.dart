import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/zone_model.dart';
import '../../detector/models/detector_model.dart';
import '../providers/zone_provider.dart';

class ZoneDetailScreen extends ConsumerStatefulWidget {
  final String zoneId;
  final Zone? zoneData; // ✅ PRIDANÉ: Optional zone data from map

  const ZoneDetailScreen({
    super.key,
    required this.zoneId,
    this.zoneData, // ✅ PRIDANÉ: Zone data parameter
  });

  @override
  ConsumerState<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends ConsumerState<ZoneDetailScreen> {
  Detector? _selectedDetector;
  List<Detector> _availableDetectors = [];

  @override
  void initState() {
    super.initState();
    // ✅ FIXED: Load zone with provided data if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(zoneProvider.notifier).loadZoneWithData(
            widget.zoneId,
            widget.zoneData, // ✅ Pass zone data from map
          );
    });
    _loadPlayerDetectors();
  }

  Future<void> _loadPlayerDetectors() async {
    setState(() {
      _availableDetectors = Detector.defaultDetectors.where((detector) {
        return detector.isOwned || _canAcquireDetector(detector);
      }).toList();
    });
  }

  bool _canAcquireDetector(Detector detector) {
    return true; // TODO: Check player tier and ownership
  }

  @override
  Widget build(BuildContext context) {
    final zoneState = ref.watch(zoneProvider);

    // ✅ Loading state
    if (zoneState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Zone...'),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Loading zone details...',
                style: GameTextStyles.cardTitle,
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Error state
    if (zoneState.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zone Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${zoneState.error}',
                  style: GameTextStyles.cardTitle),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(zoneProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Zone not found
    if (zoneState.currentZone == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Zone Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Zone not found', style: GameTextStyles.header),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final zone = zoneState.currentZone!;

    return Scaffold(
      appBar: AppBar(
        title: Text(zone.name),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(zoneProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () => context.go('/map'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Info Card
            _buildZoneInfoCard(zone),
            const SizedBox(height: 16),

            // Zone Status Card - ✅ Using provider state
            _buildZoneStatusCard(zoneState),
            const SizedBox(height: 16),

            // ✅ DEBUG: Distance info card
            _buildDebugDistanceCard(zoneState),
            const SizedBox(height: 16),

            // Detector Selection (only if in zone)
            if (zoneState.isInZone) ...[
              _buildDetectorSelection(),
              const SizedBox(height: 16),
            ],

            // Action Buttons - ✅ Using provider actions
            _buildActionButtons(zoneState),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Debug distance info card
  Widget _buildDebugDistanceCard(ZoneState zoneState) {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Information',
              style: GameTextStyles.clockTime.copyWith(
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            if (zoneState.currentZone != null) ...[
              Text(
                  'Zone: ${zoneState.currentZone!.location.latitude.toStringAsFixed(6)}, ${zoneState.currentZone!.location.longitude.toStringAsFixed(6)}'),
            ],
            if (zoneState.playerLocation != null) ...[
              Text(
                  'Player: ${zoneState.playerLocation!.latitude.toStringAsFixed(6)}, ${zoneState.playerLocation!.longitude.toStringAsFixed(6)}'),
            ],
            if (zoneState.distanceToZone != null) ...[
              Text('Distance: ${zoneState.distanceToZone!.toInt()}m'),
            ],
            Text(
                'Data source: ${widget.zoneData != null ? "Map scan" : "API/Mock"}'),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneInfoCard(Zone zone) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getBiomeEmoji(zone.biome ?? 'unknown'),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: GameTextStyles.clockTime.copyWith(
                          fontSize: 24,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        zone.description ?? 'No description available',
                        style: GameTextStyles.clockLabel.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  _getDangerEmoji(zone.dangerLevel ?? 'unknown'),
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildInfoItem(
                        'Tier Required', 'T${zone.tierRequired}', Icons.star)),
                Expanded(
                    child: _buildInfoItem(
                        'Biome', zone.biome ?? 'Unknown', Icons.terrain)),
                Expanded(
                    child: _buildInfoItem('Danger',
                        zone.dangerLevel ?? 'Unknown', Icons.warning)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneStatusCard(ZoneState zoneState) {
    return Card(
      color: zoneState.isInZone
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: zoneState.isInZone ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                zoneState.isInZone ? Icons.location_on : Icons.location_off,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zoneState.statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: zoneState.isInZone ? Colors.green : Colors.grey,
                    ),
                  ),
                  Text(
                    zoneState.isInZone
                        ? 'Select a detector to start scanning for artifacts'
                        : 'Enter the zone to begin artifact detection',
                    style: TextStyle(
                      fontSize: 14,
                      color: zoneState.isInZone
                          ? Colors.green[700]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectorSelection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Select Detection Equipment',
                  style: GameTextStyles.clockTime.copyWith(
                    fontSize: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._availableDetectors.map(
              (detector) => _buildDetectorOption(detector),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectorOption(Detector detector) {
    final isSelected = _selectedDetector?.id == detector.id;
    final canUse = detector.isOwned;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : canUse
                ? null
                : Colors.grey.withOpacity(0.1),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: canUse
                  ? detector.rarity.color.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              detector.icon,
              color: canUse ? detector.rarity.color : Colors.grey,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  detector.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: canUse ? null : Colors.grey,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: detector.rarity.color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  detector.rarity.displayName,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detector.description,
                style: TextStyle(
                  fontSize: 12,
                  color: canUse ? Colors.grey[600] : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatBar('Range', detector.range, canUse),
                  const SizedBox(width: 12),
                  _buildStatBar('Precision', detector.precision, canUse),
                  const SizedBox(width: 12),
                  _buildStatBar('Battery', detector.battery, canUse),
                ],
              ),
              if (detector.specialAbility != null) ...[
                const SizedBox(height: 4),
                Text(
                  '🔮 ${detector.specialAbility}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: canUse ? AppTheme.primaryColor : Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
              : canUse
                  ? Icon(Icons.radio_button_unchecked, color: Colors.grey)
                  : Icon(Icons.lock, color: Colors.grey),
          enabled: canUse,
          onTap: canUse ? () => _selectDetector(detector) : null,
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, int value, bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              5,
              (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: index < value
                          ? (enabled ? AppTheme.primaryColor : Colors.grey)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(label, style: GameTextStyles.clockLabel.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: GameTextStyles.clockTime.copyWith(fontSize: 13)),
      ],
    );
  }

  Widget _buildActionButtons(ZoneState zoneState) {
    if (zoneState.isInZone) {
      return Column(
        children: [
          // Start Scanning Button
          if (_selectedDetector != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.radar),
                label: Text('Start Scanning with ${_selectedDetector!.name}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Exit Zone Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: zoneState.canExitZone
                  ? () => ref.read(zoneProvider.notifier).exitZone()
                  : null,
              icon: zoneState.isExiting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Icon(Icons.exit_to_app),
              label: Text(zoneState.isExiting ? 'Exiting...' : 'Exit Zone'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: zoneState.canEnterZone
              ? () => ref.read(zoneProvider.notifier).enterZone()
              : null,
          icon: zoneState.isEntering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.login),
          label: Text(zoneState.isEntering ? 'Entering Zone...' : 'Enter Zone'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                zoneState.canEnterZone ? AppTheme.primaryColor : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  void _selectDetector(Detector detector) {
    setState(() {
      _selectedDetector = detector;
    });
    _showSuccessMessage('Selected ${detector.name}');
  }

  Future<void> _startScanning() async {
    if (_selectedDetector == null) return;

    _showSuccessMessage('Starting scan with ${_selectedDetector!.name}...');

    // ✅ Navigate to detector screen
    context.push('/zone/${widget.zoneId}/detector', extra: _selectedDetector);
  }

  String _getBiomeEmoji(String biome) {
    switch (biome.toLowerCase()) {
      case 'forest':
        return '🌲';
      case 'swamp':
        return '🐸';
      case 'desert':
        return '🏜️';
      case 'mountain':
        return '⛰️';
      case 'wasteland':
        return '☠️';
      case 'volcanic':
        return '🌋';
      default:
        return '🌍';
    }
  }

  String _getDangerEmoji(String danger) {
    switch (danger.toLowerCase()) {
      case 'low':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'high':
        return '🟠';
      case 'extreme':
        return '🔴';
      default:
        return '⚪';
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
