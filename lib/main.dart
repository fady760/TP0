import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

// 1. Settings State (for Sidebar controls)
class Settings extends ChangeNotifier {
  double borderWidth = 0.0;
  double borderRadius = 0.0;
  bool isGradientMode = false;
  MaterialColor baseColor = Colors.blue;

  void updateBorderWidth(double value) {
    borderWidth = value;
    notifyListeners();
  }

  void updateBorderRadius(double value) {
    borderRadius = value;
    notifyListeners();
  }

  void toggleGradientMode(bool value) {
    isGradientMode = value;
    notifyListeners();
  }

  void updateBaseColor(MaterialColor color) {
    baseColor = color;
    notifyListeners();
  }
}

// 2. The Data Model for a single rectangle in the tree
class RectangleNode {
  final String id;
  final Color color;
  final bool isSplit;
  final RectangleNode? child1;
  final RectangleNode? child2;

  RectangleNode({
    required this.id,
    required this.color,
    this.isSplit = false,
    this.child1,
    this.child2,
  });

  // Calculate how many uncut rectangles are inside this node
  int get leafCount {
    if (!isSplit) return 1;
    return (child1?.leafCount ?? 0) + (child2?.leafCount ?? 0);
  }

  // Helper to copy the node with some updated values (used for immutable state)
  RectangleNode copyWith({
    bool? isSplit,
    RectangleNode? child1,
    RectangleNode? child2,
  }) {
    return RectangleNode(
      id: id,
      color: color,
      isSplit: isSplit ?? this.isSplit,
      child1: child1 ?? this.child1,
      child2: child2 ?? this.child2,
    );
  }
}

// Helper to generate a new color based on settings
Color generateColor(Settings settings) {
  final random = Random();
  if (settings.isGradientMode) {
    List<int> shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
    int randomShade = shades[random.nextInt(shades.length)];
    return settings.baseColor[randomShade]!;
  } else {
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1.0,
    );
  }
}

// 3. Application State (History, Undo, Redo, Counter)
class AppState extends ChangeNotifier {
  final Settings settings;
  List<RectangleNode> _history = [];
  int _currentIndex = 0;

  AppState(this.settings) {
    _reset();
  }

  RectangleNode get currentNode => _history[_currentIndex];
  int get totalRectangles => currentNode.leafCount;

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  void undo() {
    if (canUndo) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void redo() {
    if (canRedo) {
      _currentIndex++;
      notifyListeners();
    }
  }

  void reset() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    // Start with a single root rectangle
    _history = [
      RectangleNode(
        id: 'root',
        color: generateColor(settings),
      )
    ];
    _currentIndex = 0;
  }

  // Called when a rectangle is clicked
  void splitNode(String targetId) {
    final newRoot = _splitNodeInTree(currentNode, targetId);
    
    // If the tree actually changed
    if (!identical(newRoot, currentNode)) {
      // If we are not at the very end of history (i.e. user used Undo),
      // we must delete the "future" before adding a new action
      if (_currentIndex < _history.length - 1) {
        _history = _history.sublist(0, _currentIndex + 1);
      }
      
      _history.add(newRoot);
      _currentIndex++;
      notifyListeners();
    }
  }

  // Recursively finds the target node and splits it, returning a brand new tree
  RectangleNode _splitNodeInTree(RectangleNode node, String targetId) {
    if (node.id == targetId && !node.isSplit) {
      // Found the node to split!
      return node.copyWith(
        isSplit: true,
        child1: RectangleNode(
          id: '${node.id}_1',
          color: generateColor(settings),
        ),
        child2: RectangleNode(
          id: '${node.id}_2',
          color: generateColor(settings),
        ),
      );
    }

    if (node.isSplit) {
      // Traverse down the tree
      final newChild1 = _splitNodeInTree(node.child1!, targetId);
      final newChild2 = _splitNodeInTree(node.child2!, targetId);
      
      // If children didn't change, return the original node to save memory
      if (identical(newChild1, node.child1) && identical(newChild2, node.child2)) {
        return node;
      }
      return node.copyWith(child1: newChild1, child2: newChild2);
    }
    
    return node;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Settings settings = Settings();
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    appState = AppState(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Split Rectangles',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(settings: settings, appState: appState),
    );
  }
}

class MainScreen extends StatelessWidget {
  final Settings settings;
  final AppState appState;

  const MainScreen({super.key, required this.settings, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Dynamic Counter Title
        title: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            return Text('Rectangles: ${appState.totalRectangles}');
          }
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // History and Reset Actions
        actions: [
          ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: appState.canUndo ? appState.undo : null,
                    tooltip: 'Undo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: appState.canRedo ? appState.redo : null,
                    tooltip: 'Redo',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: appState.totalRectangles > 1 ? appState.reset : null,
                    tooltip: 'Reset',
                  ),
                  const SizedBox(width: 8),
                ],
              );
            }
          ),
        ],
      ),
      drawer: Drawer(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.deepPurple),
                  child: Text(
                    'Settings',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                ListTile(
                  title: const Text('Border Width (Longueur)'),
                  subtitle: Slider(
                    value: settings.borderWidth,
                    min: 0,
                    max: 20,
                    onChanged: settings.updateBorderWidth,
                  ),
                ),
                ListTile(
                  title: const Text('Border Radius (Rayon)'),
                  subtitle: Slider(
                    value: settings.borderRadius,
                    min: 0,
                    max: 100,
                    onChanged: settings.updateBorderRadius,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Gradient Mode'),
                  value: settings.isGradientMode,
                  onChanged: settings.toggleGradientMode,
                ),
                if (settings.isGradientMode)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Base Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Colors.red,
                            Colors.green,
                            Colors.blue,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                            Colors.pink,
                          ].map((colorOption) {
                            return GestureDetector(
                              onTap: () => settings.updateBaseColor(colorOption),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorOption,
                                  shape: BoxShape.circle,
                                  border: settings.baseColor == colorOption
                                      ? Border.all(width: 3, color: Colors.black)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        // We listen to BOTH settings (borders) and appState (clicks/history)
        child: ListenableBuilder(
          listenable: Listenable.merge([settings, appState]),
          builder: (context, _) {
            return SplitRectangleWidget(
              node: appState.currentNode,
              appState: appState,
              settings: settings,
            );
          }
        ),
      ),
    );
  }
}

// 4. Stateless Widget to draw the tree based on RectangleNode state
class SplitRectangleWidget extends StatelessWidget {
  final RectangleNode node;
  final AppState appState;
  final Settings settings;
  
  const SplitRectangleWidget({
    super.key, 
    required this.node, 
    required this.appState,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (!node.isSplit) {
      return GestureDetector(
        onTap: () => appState.splitNode(node.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: node.color,
            border: settings.borderWidth > 0 
              ? Border.all(
                  width: settings.borderWidth, 
                  color: Colors.black87
                ) 
              : null,
            borderRadius: BorderRadius.circular(settings.borderRadius),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= constraints.maxHeight) {
          // Horizontal orientation: split vertically using Row
          return Row(
            children: [
              Expanded(child: SplitRectangleWidget(node: node.child1!, appState: appState, settings: settings)),
              Expanded(child: SplitRectangleWidget(node: node.child2!, appState: appState, settings: settings)),
            ],
          );
        } else {
          // Vertical orientation: split horizontally using Column
          return Column(
            children: [
              Expanded(child: SplitRectangleWidget(node: node.child1!, appState: appState, settings: settings)),
              Expanded(child: SplitRectangleWidget(node: node.child2!, appState: appState, settings: settings)),
            ],
          );
        }
      },
    );
  }
}
