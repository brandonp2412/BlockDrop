import 'package:flutter/material.dart';
import 'screens/tetris_game_screen.dart';

void main() {
  runApp(const TetrisApp());
}

class TetrisApp extends StatelessWidget {
  const TetrisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Drop - Tetris',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const TetrisGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
