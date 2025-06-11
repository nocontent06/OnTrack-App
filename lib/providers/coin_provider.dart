import 'package:flutter/material.dart';
// --- Coin Provider ---
class CoinProvider extends ChangeNotifier {
  int coins = 0;

  void addCoins(int km) {
    coins += km;
    notifyListeners();
  }
}
