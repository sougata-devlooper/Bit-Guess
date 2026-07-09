import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'game_logic.dart';
import 'game_theme.dart';

class GameScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const GameScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GameState _gameState = GameState();
  final TextEditingController _guessController = TextEditingController();
  final FocusNode _guessFocus = FocusNode();
  
  late ConfettiController _confettiController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  String _hintToast = "";
  bool _showToast = false;
  Timer? _toastTimer;

  // Background Animation
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _guessController.dispose();
    _guessFocus.dispose();
    _confettiController.dispose();
    _shakeController.dispose();
    _bgController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _startGame(String difficulty) {
    setState(() {
      _gameState.startNewGame(difficulty);
      _guessController.clear();
      _guessFocus.requestFocus();
    });
  }

  void _makeGuess() {
    if (_guessController.text.isEmpty) return;
    int? guess = int.tryParse(_guessController.text);
    if (guess == null) return;

    setState(() {
      _gameState.makeGuess(guess);
      _guessController.clear();

      if (_gameState.messageStatus == 'error' || _gameState.messageStatus == 'lose') {
        _shakeController.forward(from: 0);
      }
      if (_gameState.messageStatus == 'win') {
        _confettiController.play();
      }
    });
    _guessFocus.requestFocus();
  }

  void _requestHint() {
    String hint = _gameState.requestHint();
    setState(() {
      _hintToast = hint;
      _showToast = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.isDark ? GameTheme.darkBg : GameTheme.lightBg;
    Color cardBg = widget.isDark ? GameTheme.darkCard : GameTheme.lightCard;
    Color textMain = widget.isDark ? GameTheme.darkTextMain : GameTheme.lightTextMain;
    Color textMuted = widget.isDark ? GameTheme.darkTextMuted : GameTheme.lightTextMuted;
    Color borderColor = widget.isDark ? GameTheme.darkBorder : GameTheme.lightBorder;
    Color patternColor = widget.isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Animation
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return CustomPaint(
                painter: PixelBgPainter(
                  offset: _bgController.value,
                  patternColor: patternColor,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFFFACC15), Color(0xFFF472B6), 
                Color(0xFF38BDF8), Color(0xFF4ADE80), 
                Color(0xFFE94560), Color(0xFFFF2E63)
              ],
              createParticlePath: (size) {
                final path = Path();
                path.addRect(Rect.fromLTWH(0, 0, 12, 12));
                return path;
              },
            ),
          ),

          // Theme Toggle
          Positioned(
            top: 20,
            right: 20,
            child: RetroButton(
              onPressed: widget.onToggleTheme,
              color: cardBg,
              borderColor: borderColor,
              textColor: textMain,
              text: widget.isDark ? "☀️" : "🌙",
              padding: const EdgeInsets.all(10),
            ),
          ),

          // Main Game Container
          Center(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset((_shakeAnimation.value * (_shakeController.isAnimating ? (DateTime.now().millisecond % 2 == 0 ? 1 : -1) : 0)), 0),
                  child: child,
                );
              },
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.92,
                  maxWidth: 480,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border.all(color: borderColor, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor,
                        offset: const Offset(12, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "NUMBER GUESSER",
                        style: GoogleFonts.pressStart2p(
                          fontSize: 22,
                          color: widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light,
                          shadows: [
                            Shadow(color: borderColor, offset: const Offset(2, 2)),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Pick a difficulty",
                        style: TextStyle(fontSize: 24, color: textMuted),
                      ),
                      const SizedBox(height: 20),

                      // Difficulty Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ['easy', 'medium', 'hard'].map((diff) {
                          bool isActive = _gameState.difficulty == diff;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: RetroButton(
                              onPressed: () => _startGame(diff),
                              color: isActive
                                  ? (widget.isDark ? GameTheme.accentActiveDark : GameTheme.accentActiveLight)
                                  : cardBg,
                              borderColor: borderColor,
                              textColor: isActive ? Colors.white : textMain,
                              text: diff.toUpperCase(),
                              fontSize: 10,
                              isActive: isActive,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: borderColor, width: 4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem("TRIES", "${_gameState.attempts}", textMain),
                            _buildStatItem("HP", _gameState.over && !_gameState.won ? "DEAD" : (_gameState.won ? "WIN" : "${_gameState.maxAttempts - _gameState.attempts}"), textMain),
                            _buildStatItem("MP", "${_gameState.hintsLeft}", textMain),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Message Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(minHeight: 60),
                        decoration: BoxDecoration(
                          color: _getMessageBg(widget.isDark, cardBg),
                          border: Border.all(color: _getMessageBorder(widget.isDark, borderColor), width: 4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _gameState.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _getMessageColor(widget.isDark, textMain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Group
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor, width: 4),
                              ),
                              child: TextField(
                                controller: _guessController,
                                focusNode: _guessFocus,
                                enabled: !_gameState.over,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.pressStart2p(fontSize: 16, color: textMain),
                                decoration: InputDecoration(
                                  hintText: "1-${_gameState.rangeMax}",
                                  hintStyle: TextStyle(color: textMuted),
                                  border: InputBorder.none,
                                  filled: true,
                                  fillColor: cardBg,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                onSubmitted: (_) => _makeGuess(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          RetroButton(
                            onPressed: _gameState.over ? () {} : _makeGuess,
                            color: widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light,
                            borderColor: borderColor,
                            textColor: Colors.black,
                            text: "GUESS",
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Row
                      Row(
                        children: [
                          Expanded(
                            child: RetroButton(
                              onPressed: (_gameState.over || _gameState.hintsLeft <= 0) ? () {} : _requestHint,
                              color: widget.isDark ? GameTheme.accent1Dark : GameTheme.accent1Light,
                              borderColor: borderColor,
                              textColor: Colors.black,
                              text: "HINT(${_gameState.hintsLeft})",
                              disabled: _gameState.over || _gameState.hintsLeft <= 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RetroButton(
                              onPressed: () => _startGame(_gameState.difficulty),
                              color: widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light,
                              borderColor: borderColor,
                              textColor: Colors.black,
                              text: "RESET",
                            ),
                          ),
                        ],
                      ),

                      // History
                      if (_gameState.history.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.only(top: 15),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: borderColor, width: 4)),
                          ),
                          child: Column(
                            children: [
                              Text("LOGS", style: TextStyle(fontSize: 22, color: textMuted)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: _gameState.history.map((pip) {
                                  Color pipColor;
                                  Color pipText = Colors.black;
                                  if (pip.direction == 'correct') {
                                    pipColor = widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight;
                                    pipText = Colors.white;
                                  } else if (pip.direction == 'high') {
                                    pipColor = widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light;
                                  } else {
                                    pipColor = widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light;
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: pipColor,
                                      border: Border.all(color: borderColor, width: 4),
                                    ),
                                    child: Text(
                                      "${pip.guess}",
                                      style: GoogleFonts.pressStart2p(fontSize: 12, color: pipText),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Score Display
                      if (_gameState.won) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: widget.isDark ? GameTheme.successBgDark : GameTheme.successBgLight,
                            border: Border.all(
                              color: widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight,
                              width: 4,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "SCORE:${_gameState.currentScore}",
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 24,
                                  color: widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "${_gameState.attempts} ATK - ${(_gameState.startTime.difference(DateTime.now()).inMilliseconds.abs() / 1000.0).toStringAsFixed(1)}S"
                                "${_gameState.bestScores[_gameState.difficulty] != null && _gameState.bestScores[_gameState.difficulty]! > _gameState.currentScore ? ' (BEST:${_gameState.bestScores[_gameState.difficulty]})' : ' (NEW BEST!)'}",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Hint Toast
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showToast ? 30 : -100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: widget.isDark ? GameTheme.accent1Dark : GameTheme.accent1Light,
                  border: Border.all(color: borderColor, width: 4),
                  boxShadow: [
                    BoxShadow(color: borderColor, offset: const Offset(8, 8)),
                  ],
                ),
                child: Text(
                  _hintToast,
                  style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.black),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.pressStart2p(fontSize: 18, color: textColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 18, color: textColor)),
      ],
    );
  }

  Color _getMessageBg(bool isDark, Color defaultBg) {
    if (_gameState.messageStatus == 'win') return isDark ? GameTheme.successBgDark : GameTheme.successBgLight;
    if (_gameState.messageStatus == 'lose') return isDark ? GameTheme.dangerBgDark : GameTheme.dangerBgLight;
    return defaultBg;
  }

  Color _getMessageColor(bool isDark, Color defaultColor) {
    if (_gameState.messageStatus == 'win') return isDark ? GameTheme.successTextDark : GameTheme.successTextLight;
    if (_gameState.messageStatus == 'lose') return isDark ? GameTheme.dangerTextDark : GameTheme.dangerTextLight;
    return defaultColor;
  }

  Color _getMessageBorder(bool isDark, Color defaultColor) {
    if (_gameState.messageStatus == 'win') return isDark ? GameTheme.successTextDark : GameTheme.successTextLight;
    if (_gameState.messageStatus == 'lose') return isDark ? GameTheme.dangerTextDark : GameTheme.dangerTextLight;
    return defaultColor;
  }
}

class RetroButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final Color borderColor;
  final Color textColor;
  final String text;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final bool isActive;
  final bool disabled;

  const RetroButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.borderColor,
    required this.textColor,
    required this.text,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.fontSize = 12.8, // 0.8rem approx
    this.isActive = false,
    this.disabled = false,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    bool isDown = _isPressed || widget.isActive || widget.disabled;
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.disabled ? null : (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: widget.disabled ? null : () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: isDown ? const Offset(4, 4) : Offset.zero,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.disabled ? widget.color.withOpacity(0.5) : widget.color,
            border: Border.all(color: widget.borderColor, width: 4),
            boxShadow: isDown
                ? null
                : [
                    BoxShadow(
                      color: widget.borderColor,
                      offset: const Offset(4, 4),
                    ),
                  ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.pressStart2p(fontSize: widget.fontSize, color: widget.textColor),
          ),
        ),
      ),
    );
  }
}

class PixelBgPainter extends CustomPainter {
  final double offset;
  final Color patternColor;

  PixelBgPainter({required this.offset, required this.patternColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.fill;

    double tileSize = 60.0;
    double currentOffset = offset * tileSize;

    for (double y = -tileSize; y < size.height + tileSize; y += tileSize) {
      for (double x = -tileSize; x < size.width + tileSize; x += tileSize) {
        canvas.drawRect(Rect.fromLTWH(x + currentOffset, y + currentOffset, tileSize / 2, tileSize / 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + tileSize / 2 + currentOffset, y + tileSize / 2 + currentOffset, tileSize / 2, tileSize / 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelBgPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.patternColor != patternColor;
  }
}
