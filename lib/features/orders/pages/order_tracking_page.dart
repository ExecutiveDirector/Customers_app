import 'package:flutter/material.dart';
import 'package:aquagas/features/orders/models/order_tracking.dart';
import 'package:aquagas/features/orders/models/tracking_status_extension.dart';

class OrderTrackingPage extends StatelessWidget {
  final OrderTracking tracking;

  const OrderTrackingPage({
    super.key,
    required this.tracking,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> steps = tracking.timelineSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _buildStatusCard(),
            const SizedBox(height: 24),
            Stepper(
              currentStep: tracking.currentStep,
              controlsBuilder: (BuildContext _, ControlsDetails __) =>
                  const SizedBox.shrink(),
              steps: List<Step>.generate(
                steps.length,
                (int index) => Step(
                  title: Text(steps[index]),
                  content: const SizedBox.shrink(),
                  isActive: index <= tracking.currentStep,
                  state: index < tracking.currentStep
                      ? StepState.complete
                      : StepState.indexed,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (tracking.hasRider) _buildRiderCard(),
            const SizedBox(height: 24),
            _buildTimelineInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Icon(Icons.local_shipping, size: 48),
            const SizedBox(height: 12),
            Text(
              tracking.status.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.person),
                SizedBox(width: 8),
                Text(
                  'Assigned Rider',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(tracking.riderName ?? 'Unknown Rider'),
              subtitle: Text(tracking.riderPhone ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            if (tracking.createdAt != null)
              _timelineRow('Order Created', tracking.createdAt!),
            if (tracking.assignedAt != null)
              _timelineRow('Rider Assigned', tracking.assignedAt!),
            if (tracking.dispatchedAt != null)
              _timelineRow('Dispatched', tracking.dispatchedAt!),
            if (tracking.deliveredAt != null)
              _timelineRow('Delivered', tracking.deliveredAt!),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(String title, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text('${date.day}/${date.month}/${date.year}'),
        ],
      ),
    );
  }
}
