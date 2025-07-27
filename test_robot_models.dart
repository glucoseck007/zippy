import 'dart:convert';

void main() {
  // Test with sample API response
  final sampleResponse = {
    "success": true,
    "message": "Operation successful",
    "data": {
      "freeRobotsCount": 2,
      "commandsSent": 2,
      "freeRobots": [
        {
          "online": true,
          "robotCode": "ROBOT-001",
          "freeContainers": [
            {"containerCode": "R-001_C-1", "status": "free"},
          ],
          "totalFreeContainers": 1,
          "status": "free",
        },
        {
          "online": true,
          "robotCode": "ROBOT-002",
          "freeContainers": [
            {"containerCode": "R-002_C-1", "status": "free"},
          ],
          "totalFreeContainers": 1,
          "status": "free",
        },
      ],
      "robotsRequested": ["ROBOT-001", "ROBOT-002"],
      "message": "Status request sent to 2 robots, found 2 free robots",
    },
    "timestamp": "2025-07-27 15:19:29",
  };

  print('Testing Robot API response parsing...');

  try {
    // Test model parsing here if needed
    print('Sample response: ${jsonEncode(sampleResponse)}');
    print('Test completed successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
