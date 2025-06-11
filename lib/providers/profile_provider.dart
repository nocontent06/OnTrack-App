import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  String name;
  String email;
  ImageProvider? picture;

  ProfileProvider({
    this.name = 'Your Name',
    this.email = 'your@email.com',
    this.picture,
  });

  void update({String? name, String? email, ImageProvider? picture}) {
    if (name != null) this.name = name;
    if (email != null) this.email = email;
    if (picture != null) this.picture = picture;
    notifyListeners();
  }
}