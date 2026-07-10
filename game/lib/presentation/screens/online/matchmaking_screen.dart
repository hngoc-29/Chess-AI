import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/injection.dart';
import '../../blocs/online/matchmaking_bloc.dart';
import '../../blocs/online/online_game_bloc.dart';
import 'online_game_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> with TickerProviderStateMixin {
  int _selectedTimeControl = 1; // 0: 3+0, 1: 10+0, 2: 15+10
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;

  final List<Map<String, dynamic>> _timeControls = [
    {'name': 'Blitz', 'minutes': 3, 'increment': 0, 'icon': Icons.flash_on},
    {'name': 'Rapid', 'minutes': 10, 'increment': 0, 'icon': Icons.timer},
    {'name': 'Classical', 'minutes': 15, 'increment': 10, 'icon': Icons.schedule},
  ];

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _searchAnimation = Tween<double>(begin: 0, end: 1).animate(_searchAnimationController);
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MatchmakingBloc(socketService: getIt()),
        ),
        BlocProvider(
          create: (_) => OnlineGameBloc(socketService: getIt()),
        ),
      ],
      child: BlocListener<MatchmakingBloc, MatchmakingState>(
        listener: (context, state) {
          if (state is MatchmakingMatchFound) {
            context.read<OnlineGameBloc>().add(
                  GameInitialized(
                    room: state.room,
                    playerColor: state.yourColor,
                  ),
                );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<OnlineGameBloc>(),
                  child: const OnlineGameScreen(),
                ),
              ),
            );
          } else if (state is MatchmakingTimedOut) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No opponent found. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (state is MatchmakingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: SafeArea(
              child: BlocBuilder<MatchmakingBloc, MatchmakingState>(
                builder: (context, state) {
                  if (state is MatchmakingSearching) {
                    return _buildSearchingView(context, state);
                  }
                  return _buildTimeControlSelection(context);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeControlSelection(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Choose Time Control',
                  style: GoogleFonts.cinzel(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                ..._buildTimeControlCards(),
                const SizedBox(height: 40),
                _buildPlayButton(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            'Ranked Match',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  List<Widget> _buildTimeControlCards() {
    return List.generate(_timeControls.length, (index) {
      final tc = _timeControls[index];
      final isSelected = _selectedTimeControl == index;
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedTimeControl = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(
                  tc['icon'] as IconData,
                  size: 40,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tc['name'] as String,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                        ),
                      ),
                      Text(
                        '${tc['minutes']} min ${tc['increment'] > 0 ? '+ ${tc['increment']} sec' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.7) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPlayButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _startMatchmaking(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow, size: 28),
              const SizedBox(width: 8),
              Text(
                'Find Opponent',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingView(BuildContext context, MatchmakingSearching state) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _searchAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _searchAnimation.value * 2 * 3.14159,
                      child: Icon(
                        Icons.refresh,
                        size: 80,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Finding Opponent...',
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${state.searchDuration.inSeconds}s',
                  style: GoogleFonts.roboto(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.timeControlMinutes} min + ${state.incrementSeconds} sec',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<MatchmakingBloc>().add(const LeaveQueueRequested());
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startMatchmaking(BuildContext context) {
    final tc = _timeControls[_selectedTimeControl];
    context.read<MatchmakingBloc>().add(
          JoinQueueRequested(
            timeControlMinutes: tc['minutes'] as int,
            incrementSeconds: tc['increment'] as int,
          ),
        );
  }
}
