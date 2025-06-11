# OnTrack - Train Connection App

OnTrack is a Flutter application designed to help users plan their train journeys, search for train connections, and book tickets seamlessly. The app features a user-friendly interface and provides various functionalities to enhance the travel experience.

## Features

- **Journey Planner**: Users can input their departure and arrival locations, along with the desired date and time to search for available train connections.
- **Search Results**: Displays a list of available trains based on the user's search criteria, allowing users to view details and select their preferred options.
- **Trip Suggestions**: Users can explore suggested trips based on their interests and preferences, making it easier to plan future travels.
- **Profile and Settings**: Users can manage their profiles, view their travel coins earned from train journeys, and adjust app settings.

## Project Structure

```
ontrack
├── lib
│   ├── main.dart
│   ├── pages
│   │   ├── journey_planner_page.dart
│   │   ├── search_results_page.dart
│   │   ├── trip_suggestions_page.dart
│   │   ├── profile_page.dart
│   │   └── settings_page.dart
│   ├── widgets
│   │   ├── journey_form.dart
│   │   ├── train_result_card.dart
│   │   ├── coin_display.dart
│   │   └── profile_form.dart
│   ├── models
│   │   ├── train.dart
│   │   ├── trip.dart
│   │   └── user.dart
│   └── services
│       ├── train_service.dart
│       ├── trip_service.dart
│       └── user_service.dart
├── pubspec.yaml
└── README.md
```

## Getting Started

To get started with the OnTrack app, follow these steps:

1. **Clone the Repository**: 
   ```
   git clone https://github.com/yourusername/ontrack.git
   ```

2. **Navigate to the Project Directory**: 
   ```
   cd ontrack
   ```

3. **Install Dependencies**: 
   ```
   flutter pub get
   ```

4. **Run the App**: 
   ```
   flutter run
   ```

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.