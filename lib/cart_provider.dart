import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final String description;
  final String image;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    this.quantity = 1,
  });
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get total =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(CartItem item) {
    int index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
