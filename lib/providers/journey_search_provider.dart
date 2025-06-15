import 'package:flutter/material.dart';

class JourneySearchProvider extends ChangeNotifier {
  String? fromStationId;
  String? toStationId;
  String? fromStationName;
  String? toStationName;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  int? generalTransferTime; // in minutes

  // Journey options for API
  int? transferTime;
  bool accessibility = false;
  bool bike = false;
  bool startWithWalking = false;
  String walkingSpeed = 'normal';
  String language = 'en';
  bool nationalExpress = true;
  bool national = true;
  bool interregional = true;
  bool regional = true;
  bool suburban = true;
  bool bus = true;
  bool ferry = true;
  bool subway = true;
  bool tram = true;
  bool onCall = false;
  bool tickets = false;
  bool polylines = false;
  bool subStops = false;
  bool entrances = false;
  bool remarks = false;
  bool scheduledDays = false;
  bool pretty = false;

  void setFrom(String id, String name) {
    fromStationId = id;
    fromStationName = name;
    notifyListeners();
  }

  void setTo(String id, String name) {
    toStationId = id;
    toStationName = name;
    notifyListeners();
  }

  void setDate(DateTime? date) {
    selectedDate = date;
    notifyListeners();
  }

  void setTime(TimeOfDay? time) {
    selectedTime = time;
    notifyListeners();
  }

  void setNow() {
    selectedDate = null;
    selectedTime = null;
    notifyListeners();
  }

  void setGeneralTransferTime(int? minutes) {
    generalTransferTime = minutes;
    notifyListeners();
  }

  void reset() {
    fromStationId = null;
    toStationId = null;
    fromStationName = null;
    toStationName = null;
    selectedDate = null;
    selectedTime = null;
    generalTransferTime = null;
    notifyListeners();
  }

  void setJourneyOptions({
    int? transferTime,
    bool? accessibility,
    bool? bike,
    bool? startWithWalking,
    String? walkingSpeed,
    String? language,
    bool? nationalExpress,
    bool? national,
    bool? interregional,
    bool? regional,
    bool? suburban,
    bool? bus,
    bool? ferry,
    bool? subway,
    bool? tram,
    bool? onCall,
    bool? tickets,
    bool? polylines,
    bool? subStops,
    bool? entrances,
    bool? remarks,
    bool? scheduledDays,
    bool? pretty,
  }) {
    this.transferTime = transferTime ?? this.transferTime;
    this.accessibility = accessibility ?? this.accessibility;
    this.bike = bike ?? this.bike;
    this.startWithWalking = startWithWalking ?? this.startWithWalking;
    this.walkingSpeed = walkingSpeed ?? this.walkingSpeed;
    this.language = language ?? this.language;
    this.nationalExpress = nationalExpress ?? this.nationalExpress;
    this.national = national ?? this.national;
    this.interregional = interregional ?? this.interregional;
    this.regional = regional ?? this.regional;
    this.suburban = suburban ?? this.suburban;
    this.bus = bus ?? this.bus;
    this.ferry = ferry ?? this.ferry;
    this.subway = subway ?? this.subway;
    this.tram = tram ?? this.tram;
    this.onCall = onCall ?? this.onCall;
    this.tickets = tickets ?? this.tickets;
    this.polylines = polylines ?? this.polylines;
    this.subStops = subStops ?? this.subStops;
    this.entrances = entrances ?? this.entrances;
    this.remarks = remarks ?? this.remarks;
    this.scheduledDays = scheduledDays ?? this.scheduledDays;
    this.pretty = pretty ?? this.pretty;
    notifyListeners();
  }
}