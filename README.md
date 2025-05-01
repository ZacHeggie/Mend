# Mend: Recovery & Injury Prevention

Mend is an iOS app designed to help athletes and fitness enthusiasts track and visualize their recovery metrics to optimize training and prevent injuries.

## Features

- **Recovery Score Dashboard**: View your overall recovery score with a visually appealing ring indicator
- **Detailed Metrics**: Track key recovery indicators:
  - Resting Heart Rate (and delta from average)
  - Heart Rate Variability (and delta from average)
  - Sleep Quality
  - Training Load
- **Interactive Charts**: Expand each metric to view a 7-day trend and detailed explanation
- **Modern UI**: Clean, intuitive interface with smooth animations and transitions

## Recent Fixes

- **Recovery Score Issue Fixed**: Fixed an issue where refreshing the app multiple times would cause the recovery score to continuously improve. Activities are now properly tracked in a persistent list to ensure the same activity doesn't affect the recovery score multiple times.
- **Developer Testing Tools**: Added testing functionality in the Settings screen (Debug mode only) to add test activities and reset processed activities for testing recovery score functionality.

## Technical Details

- Built with SwiftUI
- Chart visualization using Swift Charts
- Custom animations and transitions
- Dark mode support
- Integration with HealthKit for real data
- Simulated data option
- Workout recommendations based on recovery score
- Notification system for recovery alerts

## Requirements

- iOS 16.0+
- Xcode 14.0+

## Future Enhancements

- HealthKit integration for real-time data
- Custom recovery strategies and protocols 