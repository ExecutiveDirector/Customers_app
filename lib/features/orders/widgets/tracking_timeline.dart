import 'package:flutter/material.dart';

class TrackingTimeline extends StatelessWidget {
  final int currentStep;

  const TrackingTimeline({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Order Placed',
      'Confirmed',
      'Preparing',
      'On The Way',
      'Delivered',
    ];

    return Column(
      children: List.generate(
        steps.length,
        (index) {
          final complete = index <= currentStep;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        complete ? Colors.green : Colors.grey.shade300,
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: complete ? Colors.white : Colors.black54,
                    ),
                  ),
                  if (index != steps.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: complete ? Colors.green : Colors.grey,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 4,
                  ),
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      fontWeight:
                          complete ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
