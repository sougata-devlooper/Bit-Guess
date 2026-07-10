import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _gameStarted = false;
  PixelSweepStyle _currentSweepStyle = PixelSweepStyle.topLeft;
  Duration _transitionDuration = const Duration(milliseconds: 800);

  // Background Animation
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _gameState.loadBestScores().then((_) {
      if (mounted) setState(() {});
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _currentSweepStyle = PixelSweepStyle.topLeft;
      _transitionDuration = const Duration(milliseconds: 800);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
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
      _currentSweepStyle = PixelSweepStyle.centerOutward;
      _transitionDuration = const Duration(milliseconds: 400);
      _gameState.startNewGame(difficulty);
      _guessController.clear();
      _gameStarted = true;
    });
  }

  void _goToModeSelection() {
    setState(() {
      _currentSweepStyle = PixelSweepStyle.outwardToCenter;
      _transitionDuration = const Duration(milliseconds: 400);
      _gameStarted = false;
    });
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        Color bgColor = Colors.white;
        Color textMain = Colors.black;
        Color borderColor = Colors.black;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 4),
              boxShadow: [
                BoxShadow(color: borderColor, offset: const Offset(8, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "HIGH SCORES",
                  style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 18, color: textMain),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                IntrinsicWidth(
                  child: Column(
                    children: ['easy', 'medium', 'hard'].map((diff) {
                      int score = _gameState.bestScores[diff] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              diff.toUpperCase(),
                              style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 12, color: textMain),
                            ),
                            const SizedBox(width: 50),
                            Text(
                              score > 0 ? score.toString() : "---",
                              style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 12, color: textMain),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 25),
                RetroButton(
                  onPressed: () => Navigator.pop(context),
                  color: const Color(0xFFFFD700), // yellow
                  borderColor: borderColor,
                  textColor: Colors.black,
                  text: "CLOSE",
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onKeypadTap(String val) {
    if (_gameState.over) return;
    if (_guessController.text.length < 3) {
      setState(() {
        _guessController.text += val;
      });
    }
  }

  void _onKeypadBackspace() {
    if (_gameState.over) return;
    if (_guessController.text.isNotEmpty) {
      setState(() {
        _guessController.text = _guessController.text.substring(0, _guessController.text.length - 1);
      });
    }
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
  }

  Widget _buildKeypadKey({
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    Color cardBg = widget.isDark ? GameTheme.darkCard : GameTheme.lightCard;
    Color borderColor = widget.isDark ? GameTheme.darkBorder : GameTheme.lightBorder;
    Color textMain = widget.isDark ? GameTheme.darkTextMain : GameTheme.lightTextMain;
    Color keyColor = color ?? cardBg;
    Color textColor = color != null ? Colors.black : textMain;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: RetroButton(
          onPressed: onPressed,
          color: keyColor,
          borderColor: borderColor,
          textColor: textColor,
          text: label,
          fontSize: 16,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
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
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: _transitionDuration,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isIncoming = child.key == ValueKey<String>('${widget.isDark}_$_gameStarted');
          if (!isIncoming) {
            return IgnorePointer(child: child);
          }
          return AnimatedBuilder(
            animation: animation,
            builder: (context, childWidget) {
              return ClipPath(
                clipper: PixelSweepClipper(
                  progress: animation.value,
                  style: _currentSweepStyle,
                ),
                child: childWidget,
              );
            },
            child: child,
          );
        },
        child: Container(
          key: ValueKey<String>('${widget.isDark}_$_gameStarted'),
          color: bgColor,
          child: Stack(
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
                  constraints: const BoxConstraints(maxWidth: 480),
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
                      if (!_gameStarted) ...[
                            Text(
                              "NUMBER GUESSER",
                              style: TextStyle(fontFamily: 'Press Start 2P', 
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
                            const SizedBox(height: 25),

                            // Mode Selection Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: ['easy', 'medium', 'hard'].map((diff) {
                                Color buttonColor;
                                if (diff == 'easy') {
                                  buttonColor = widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light;
                                } else if (diff == 'medium') {
                                  buttonColor = widget.isDark ? GameTheme.accent1Dark : GameTheme.accent1Light;
                                } else {
                                  buttonColor = widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light;
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: RetroButton(
                                    onPressed: () => _startGame(diff),
                                    color: buttonColor,
                                    borderColor: borderColor,
                                    textColor: Colors.black,
                                    text: diff.toUpperCase(),
                                    fontSize: 11,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 35),
                            RetroButton(
                              onPressed: _showStatsDialog,
                              color: widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light,
                              borderColor: borderColor,
                              textColor: Colors.black,
                              text: "STATS",
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ] else ...[
                            Text(
                              "NUMBER GUESSER",
                              style: TextStyle(fontFamily: 'Press Start 2P', 
                                fontSize: 22,
                                color: widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light,
                                shadows: [
                                  Shadow(color: borderColor, offset: const Offset(2, 2)),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "MODE: ${_gameState.difficulty.toUpperCase()}",
                              style: TextStyle(fontFamily: 'Press Start 2P', 
                                fontSize: 10,
                                color: textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),

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

                            // Input Group or Play Again buttons
                            if (!_gameState.over) ...[
                              // Large retro arcade guess display screen
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? Colors.black : const Color(0xFFEFEFEF),
                                  border: Border.all(color: borderColor, width: 4),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "YOUR GUESS: ",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textMuted,
                                      ),
                                    ),
                                    Text(
                                      _guessController.text.isEmpty ? "___" : _guessController.text,
                                      style: TextStyle(fontFamily: 'Press Start 2P', 
                                        fontSize: 22,
                                        color: widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),

                              // Custom Arcade Keypad
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildKeypadKey(label: "1", onPressed: () => _onKeypadTap("1")),
                                      _buildKeypadKey(label: "2", onPressed: () => _onKeypadTap("2")),
                                      _buildKeypadKey(label: "3", onPressed: () => _onKeypadTap("3")),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _buildKeypadKey(label: "4", onPressed: () => _onKeypadTap("4")),
                                      _buildKeypadKey(label: "5", onPressed: () => _onKeypadTap("5")),
                                      _buildKeypadKey(label: "6", onPressed: () => _onKeypadTap("6")),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _buildKeypadKey(label: "7", onPressed: () => _onKeypadTap("7")),
                                      _buildKeypadKey(label: "8", onPressed: () => _onKeypadTap("8")),
                                      _buildKeypadKey(label: "9", onPressed: () => _onKeypadTap("9")),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      _buildKeypadKey(
                                        label: "⌫",
                                        onPressed: _onKeypadBackspace,
                                        color: widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light,
                                      ),
                                      _buildKeypadKey(label: "0", onPressed: () => _onKeypadTap("0")),
                                      _buildKeypadKey(
                                        label: "GO",
                                        onPressed: _makeGuess,
                                        color: widget.isDark ? GameTheme.accent3Dark : GameTheme.accent3Light,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              // Action Row
                              Row(
                                children: [
                                  Expanded(
                                    child: RetroButton(
                                      onPressed: _gameState.hintsLeft <= 0 ? () {} : _requestHint,
                                      color: widget.isDark ? GameTheme.accent1Dark : GameTheme.accent1Light,
                                      borderColor: borderColor,
                                      textColor: Colors.black,
                                      text: "HINT(${_gameState.hintsLeft})",
                                      disabled: _gameState.hintsLeft <= 0,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: RetroButton(
                                      onPressed: _goToModeSelection,
                                      color: widget.isDark ? GameTheme.accent2Dark : GameTheme.accent2Light,
                                      borderColor: borderColor,
                                      textColor: Colors.black,
                                      text: _gameState.history.isNotEmpty ? "🔒 MODE" : "MODE",
                                      disabled: _gameState.history.isNotEmpty,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Redirects back to mode selection screen
                              SizedBox(
                                width: double.infinity,
                                child: RetroButton(
                                  onPressed: _goToModeSelection,
                                  color: widget.isDark ? GameTheme.accent1Dark : GameTheme.accent1Light,
                                  borderColor: borderColor,
                                  textColor: Colors.black,
                                  text: "START A NEW GAME",
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                              ),
                            ],

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
                                    Text("LOGS", style: TextStyle(fontSize: 15, color: textMuted)),
                                    const SizedBox(height: 8),
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 70),
                                      width: double.infinity,
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
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
                                            String indicator = pip.direction == 'correct' ? " ✓" : (pip.direction == 'high' ? " ⬇️" : " ⬆️");
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: pipColor,
                                                border: Border.all(color: borderColor, width: 3),
                                              ),
                                              child: Text(
                                                "${pip.guess}$indicator",
                                                style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 9, color: pipText),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
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
                                      style: TextStyle(fontFamily: 'Press Start 2P', 
                                        fontSize: 24,
                                        color: widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${_gameState.attempts} ATK - ${_gameState.elapsedTime.toStringAsFixed(1)}S"
                                      "${_gameState.bestScores[_gameState.difficulty] != null && _gameState.bestScores[_gameState.difficulty]! > _gameState.currentScore ? ' (BEST:${_gameState.bestScores[_gameState.difficulty]})' : ' (NEW BEST!)'}",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: widget.isDark ? GameTheme.successTextDark : GameTheme.successTextLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                  style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 11, color: Colors.black),
                ),
              ),
            ),
          ),

          // Confetti (drawn on top of the main container/card)
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

        ],
      ),
    ),
  ),
);
  }

  Widget _buildStatItem(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontFamily: 'Press Start 2P', fontSize: 18, color: textColor)),
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
            style: TextStyle(fontFamily: 'Press Start 2P', fontSize: widget.fontSize, color: widget.textColor),
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

enum PixelSweepStyle {
  topLeft,
  centerOutward,
  outwardToCenter,
}

class PixelSweepClipper extends CustomClipper<Path> {
  final double progress;
  final PixelSweepStyle style;

  PixelSweepClipper({required this.progress, required this.style});

  @override
  Path getClip(Size size) {
    Path path = Path();
    if (progress == 0.0) return path;
    if (progress == 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    const int cols = 12;
    const int rows = 22;

    final double blockW = size.width / cols;
    final double blockH = size.height / rows;
    
    final double centerRow = rows / 2;
    final double centerCol = cols / 2;
    final double maxDist = sqrt(centerRow * centerRow + centerCol * centerCol);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double delay;
        
        switch (style) {
          case PixelSweepStyle.topLeft:
            delay = (r / rows * 0.4) + (c / cols * 0.2);
            break;
          case PixelSweepStyle.centerOutward:
            double dr = r - centerRow;
            double dc = c - centerCol;
            double dist = sqrt(dr * dr + dc * dc);
            double normalizedDist = dist / maxDist;
            delay = normalizedDist * 0.6;
            break;
          case PixelSweepStyle.outwardToCenter:
            double dr = r - centerRow;
            double dc = c - centerCol;
            double dist = sqrt(dr * dr + dc * dc);
            double normalizedDist = dist / maxDist;
            delay = (1.0 - normalizedDist) * 0.6;
            break;
        }

        double blockProgress = (progress - delay).clamp(0.0, 0.4) / 0.4;
        
        if (blockProgress > 0.0) {
          double scale = Curves.easeInOut.transform(blockProgress);
          
          if (scale >= 1.0) {
            path.addRect(Rect.fromLTWH(c * blockW - 0.5, r * blockH - 0.5, blockW + 1, blockH + 1));
          } else {
            final double cx = c * blockW + blockW / 2;
            final double cy = r * blockH + blockH / 2;
            final double w = blockW * scale;
            final double h = blockH * scale;
            path.addRect(Rect.fromLTWH(cx - w / 2 - 0.5, cy - h / 2 - 0.5, w + 1, h + 1));
          }
        }
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant PixelSweepClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.style != style;
  }
}
