import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/models/serp_text_block.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/answer_walkthrough_sheet.dart';

/// Demo screen for testing the AnswerWalkthroughSheet widget.
///
/// This screen provides buttons to test different JSON examples and
/// a text field for entering custom file paths.
class AnswerWalkthroughDemo extends StatefulWidget {
  const AnswerWalkthroughDemo({super.key});

  @override
  State<AnswerWalkthroughDemo> createState() => _AnswerWalkthroughDemoState();
}

class _AnswerWalkthroughDemoState extends State<AnswerWalkthroughDemo> {
  final _pathController = TextEditingController(text: 'coffee.json');
  bool _isLoading = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Scaffold(
      backgroundColor: appTheme.bg,
      appBar: AppBar(
        title: const Text('Answer Walkthrough Demo'),
        backgroundColor: appTheme.bgLight,
        foregroundColor: appTheme.text,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: appTheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Answer Walkthrough Sheet Demo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: appTheme.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Test the walkthrough sheet with different JSON files.',
              style: TextStyle(
                fontSize: 14,
                color: appTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Preset buttons
            Text(
              'PRESET EXAMPLES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _loadPreset('coffee'),
                    icon: const Icon(Icons.coffee),
                    label: const Text('Coffee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.primary,
                      foregroundColor: appTheme.bgLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _loadPreset('math'),
                    icon: const Icon(Icons.functions),
                    label: const Text('Math (LaTeX)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.secondary,
                      foregroundColor: appTheme.bgLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Custom path input
            Text(
              'CUSTOM FILE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: appTheme.bgLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appTheme.borderMuted),
              ),
              child: TextField(
                controller: _pathController,
                style: TextStyle(color: appTheme.text),
                decoration: InputDecoration(
                  hintText: 'Enter file path (e.g., coffee.json)',
                  hintStyle: TextStyle(color: appTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: appTheme.primary,
                            ),
                          )
                        : Icon(Icons.play_arrow, color: appTheme.primary),
                    onPressed: _isLoading ? null : _loadFromPath,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paths are relative to the repository root. Try: coffee.json, math.json',
              style: TextStyle(
                fontSize: 11,
                color: appTheme.textMuted,
              ),
            ),
            const SizedBox(height: 32),

            // Test buttons
            OutlinedButton.icon(
              onPressed: () => _showInvalidData(context),
              icon: const Icon(Icons.warning_amber),
              label: const Text('Test Invalid Data Fallback'),
              style: OutlinedButton.styleFrom(
                foregroundColor: appTheme.textMuted,
                side: BorderSide(color: appTheme.borderMuted),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadPreset(String preset) {
    switch (preset) {
      case 'coffee':
        _showWalkthrough(_coffeeData, 'What is Coffee?');
        break;
      case 'math':
        _showWalkthrough(_mathData, "Speed of Light from Maxwell's Equations");
        break;
    }
  }

  Future<void> _loadFromPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      _showError('Please enter a file path');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String jsonString;

      // Check if it's an absolute path (starts with /)
      if (!kIsWeb && path.startsWith('/')) {
        final file = File(path);
        if (await file.exists()) {
          jsonString = await file.readAsString();
        } else {
          throw Exception('File not found: $path');
        }
      } else {
        // Try loading from assets for relative paths
        try {
          jsonString = await rootBundle.loadString(path);
        } catch (_) {
          try {
            jsonString = await rootBundle.loadString('assets/$path');
          } catch (_) {
            throw Exception('File not found: $path');
          }
        }
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final response = SerpAiResponse.fromJson(json);

      if (!response.hasContent) {
        _showError('File parsed but contains no content');
        return;
      }

      if (mounted) {
        AnswerWalkthroughSheet.show(
          context,
          response: response,
          title: _extractTitle(path),
        );
      }
    } catch (e) {
      _showError('Error loading file: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _extractTitle(String path) {
    // Extract filename without extension as title
    final filename = path.split('/').last;
    final name = filename.replaceAll('.json', '');
    return name[0].toUpperCase() + name.substring(1);
  }

  void _showWalkthrough(Map<String, dynamic> data, String title) {
    final response = SerpAiResponse.fromJson(data);
    AnswerWalkthroughSheet.show(
      context,
      response: response,
      title: title,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _showInvalidData(BuildContext context) {
    final success = AnswerWalkthroughSheet.showFromJson(
      context,
      jsonString: 'invalid json {{{}}}',
      title: 'Invalid Data Test',
    );

    success.then((result) {
      if (!result && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to parse JSON - fallback triggered'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

/// Coffee example data from SerpAPI.
const Map<String, dynamic> _coffeeData = {
  "text_blocks": [
    {
      "type": "paragraph",
      "snippet":
          "Coffee is a popular brewed beverage made from the roasted and ground seeds of the coffee plant. It is one of the most widely consumed drinks in the world, prized for its invigorating, caffeinated effect. While its exact origins are debated, coffee likely originated in Ethiopia, with credible evidence of it being consumed in Yemen in the mid-15th century.",
      "reference_indexes": [5, 6, 0, 2, 7]
    },
    {"type": "heading", "snippet": "Types of beans and roasts"},
    {
      "type": "paragraph",
      "snippet":
          "The flavor profile of coffee varies depending on the bean species, growing region, and roasting process.",
      "reference_indexes": [0]
    },
    {
      "type": "paragraph",
      "snippet": "Bean types:",
      "snippet_highlighted_words": ["Bean types"],
      "reference_indexes": [0, 8]
    },
    {
      "type": "list",
      "list": [
        {
          "snippet":
              "Arabica: Accounts for roughly 60% of global production. It is a delicate bean that grows at higher altitudes, resulting in a more flavorful and aromatic cup."
        },
        {
          "snippet":
              "Robusta: A heartier, more disease-resistant bean that can grow at lower altitudes. It has a bolder, more bitter flavor and contains 50–60% more caffeine than Arabica beans."
        }
      ],
      "reference_indexes": [0]
    },
    {
      "type": "paragraph",
      "snippet": "Roast levels:",
      "snippet_highlighted_words": ["Roast levels"],
      "reference_indexes": [9]
    },
    {
      "type": "list",
      "list": [
        {
          "snippet":
              "Light: Lighter in color and roasted flavor with higher acidity."
        },
        {
          "snippet":
              "Medium: Balanced in flavor and acidity, considered the most common roast."
        },
        {
          "snippet":
              "Dark: Black in color with low acidity and a more bitter, roasted flavor."
        }
      ],
      "reference_indexes": [0]
    },
    {"type": "heading", "snippet": "Brewing methods"},
    {
      "type": "paragraph",
      "snippet":
          "There are many ways to prepare coffee, each producing a different result:",
      "reference_indexes": [1]
    },
    {
      "type": "list",
      "list": [
        {
          "snippet":
              "Drip coffee: A common method where water drips through a filter basket containing coffee grounds."
        },
        {
          "snippet":
              "Pour-over: Similar to drip coffee, but the hot water is poured slowly and manually over the grounds for a more controlled brew."
        },
        {
          "snippet":
              "French press: Coffee grounds are steeped in hot water, then pressed down with a mesh plunger to separate the grounds from the liquid."
        },
        {
          "snippet":
              "Espresso: A concentrated shot made by forcing pressurized hot water through finely-ground beans. It serves as the base for many popular coffee drinks."
        },
        {
          "snippet":
              "Cold brew: Coarsely ground beans are steeped in cold water for an extended period, resulting in a brew with lower acidity."
        },
        {
          "snippet":
              "Instant coffee: Dried coffee that dissolves quickly in hot water."
        }
      ],
      "reference_indexes": [10, 1]
    },
    {"type": "heading", "snippet": "Popular coffee drinks"},
    {
      "type": "paragraph",
      "snippet":
          "Beyond a simple cup of black coffee, countless recipes incorporate espresso, steamed milk, and other ingredients:",
      "reference_indexes": [1]
    },
    {
      "type": "list",
      "list": [
        {
          "snippet":
              "Latte: Espresso with steamed milk and a thin layer of foam."
        },
        {
          "snippet":
              "Cappuccino: Espresso with equal parts steamed milk and milk foam."
        },
        {"snippet": "Americano: Espresso diluted with hot water."},
        {
          "snippet":
              "Macchiato: Espresso \"marked\" with a dollop of milk foam."
        },
        {"snippet": "Mocha: A latte with added chocolate syrup."},
        {
          "snippet":
              "Flat White: Espresso with steamed milk, but less foam than a latte."
        },
        {
          "snippet":
              "Affogato: A scoop of gelato or ice cream \"drowned\" with a shot of hot espresso."
        }
      ]
    },
  ],
  "references": [
    {
      "title": "Coffee | Origin, Types, Uses, History, & Facts - Britannica",
      "link": "https://www.britannica.com/topic/coffee",
      "snippet":
          "coffee * What is coffee? Coffee is a beverage brewed from the roasted and ground seeds of the tropical evergreen coffee plant.",
      "source": "Britannica",
      "index": 0
    },
    {
      "title": "Types of Coffee Drinks: Latte, Cappuccino, Macchiato and More",
      "link":
          "https://www.today.com/food/drinks/types-of-coffee-drinks-rcna222247",
      "snippet":
          "A Guide to Coffee Drinks: Cappuccino, Latte, Macchiato, Flat White and Beyond.",
      "source": "TODAY.com",
      "index": 1
    },
  ]
};

/// Math example data with LaTeX expressions (Maxwell's Equations -> Speed of Light).
const Map<String, dynamic> _mathData = {
  "text_blocks": [
    {
      "type": "paragraph",
      "snippet":
          r"The speed of light ( $c$) is derived from Maxwell's equations by transforming them into the wave equation for electric and magnetic fields in a vacuum.",
      "snippet_latex": ["c"],
      "reference_indexes": [2, 0]
    },
    {"type": "heading", "snippet": "1. Maxwell's Equations in Free Space"},
    {
      "type": "paragraph",
      "snippet":
          r"In a vacuum where there are no charges ( $\rho =0$) and no currents ( $J=0$), the equations are:",
      "snippet_latex": [r"\rho =0", "J=0"],
      "reference_indexes": [4, 7, 8, 9, 10]
    },
    {
      "type": "list",
      "list": [
        {
          "snippet": r"Gauss's Law: $\nabla \cdot \mathbf{E}=0$",
          "snippet_latex": [r"\nabla \cdot \mathbf{E}=0"]
        },
        {
          "snippet": r"Gauss's Law for Magnetism: $\nabla \cdot \mathbf{B}=0$",
          "snippet_latex": [r"\nabla \cdot \mathbf{B}=0"]
        },
        {
          "snippet":
              r"Faraday's Law: $\nabla \times \mathbf{E}=-\frac{\partial \mathbf{B}}{\partial t}$",
          "snippet_latex": [
            r"\nabla \times \mathbf{E}=-\frac{\partial \mathbf{B}}{\partial t}"
          ]
        },
        {
          "snippet":
              r"Ampère-Maxwell Law: $\nabla \times \mathbf{B}=\mu _{0}\epsilon _{0}\frac{\partial \mathbf{E}}{\partial t}$",
          "snippet_latex": [
            r"\nabla \times \mathbf{B}=\mu _{0}\epsilon _{0}\frac{\partial \mathbf{E}}{\partial t}"
          ]
        }
      ],
      "reference_indexes": [11, 12, 13, 14, 15]
    },
    {"type": "heading", "snippet": "2. Deriving the Wave Equation"},
    {
      "type": "paragraph",
      "snippet":
          r"To isolate the electric field ( $\mathbf{E}$), take the curl of Faraday's Law: $\nabla \times (\nabla \times \mathbf{E})=\nabla \times \left(-\frac{\partial \mathbf{B}}{\partial t}\right)$",
      "snippet_latex": [
        r"\mathbf{E}",
        r"\nabla \times (\nabla \times \mathbf{E})=\nabla \times \left(-\frac{\partial \mathbf{B}}{\partial t}\right)"
      ]
    },
    {
      "type": "paragraph",
      "snippet":
          r"Using the vector identity $\nabla \times (\nabla \times \mathbf{E})=\nabla (\nabla \cdot \mathbf{E})-\nabla ^{2}\mathbf{E}$ and substituting Gauss's Law ( $\nabla \cdot \mathbf{E}=0$): $-\nabla ^{2}\mathbf{E}=-\frac{\partial }{\partial t}(\nabla \times \mathbf{B})$",
      "snippet_latex": [
        r"\nabla \times (\nabla \times \mathbf{E})=\nabla (\nabla \cdot \mathbf{E})-\nabla ^{2}\mathbf{E}",
        r"\nabla \cdot \mathbf{E}=0",
        r"-\nabla ^{2}\mathbf{E}=-\frac{\partial }{\partial t}(\nabla \times \mathbf{B})"
      ]
    },
    {
      "type": "paragraph",
      "snippet":
          r"Substitute the Ampère-Maxwell Law for $\nabla \times \mathbf{B}$: $-\nabla ^{2}\mathbf{E}=-\frac{\partial }{\partial t}\left(\mu _{0}\epsilon _{0}\frac{\partial \mathbf{E}}{\partial t}\right)\implies \nabla ^{2}\mathbf{E}=\mu _{0}\epsilon _{0}\frac{\partial ^{2}\mathbf{E}}{\partial t^{2}}$",
      "snippet_latex": [
        r"\nabla \times \mathbf{B}",
        r"-\nabla ^{2}\mathbf{E}=-\frac{\partial }{\partial t}\left(\mu _{0}\epsilon _{0}\frac{\partial \mathbf{E}}{\partial t}\right)\implies \nabla ^{2}\mathbf{E}=\mu _{0}\epsilon _{0}\frac{\partial ^{2}\mathbf{E}}{\partial t^{2}}"
      ]
    },
    {"type": "heading", "snippet": "3. Identifying the Speed"},
    {
      "type": "paragraph",
      "snippet":
          r"The standard form of a 3D wave equation is $\nabla ^{2}f=\frac{1}{v^{2}}\frac{\partial ^{2}f}{\partial t^{2}}$, where $v$ is the wave velocity. Comparing this to the derived equation: $\frac{1}{v^{2}}=\mu _{0}\epsilon _{0}\implies v=\frac{1}{\sqrt{\mu _{0}\epsilon _{0}}}$",
      "snippet_latex": [
        r"\nabla ^{2}f=\frac{1}{v^{2}}\frac{\partial ^{2}f}{\partial t^{2}}",
        "v",
        r"\frac{1}{v^{2}}=\mu _{0}\epsilon _{0}\implies v=\frac{1}{\sqrt{\mu _{0}\epsilon _{0}}}"
      ]
    },
    {
      "type": "paragraph",
      "snippet":
          r"By plugging in the measured values for vacuum permittivity ( $\epsilon _{0}\approx 8.854\times 10^{-12}\text{\ F/m}$) and vacuum permeability ( $\mu _{0}=4\pi \times 10^{-7}\text{\ T}\cdot \text{m/A}$), the calculated speed is approximately 299,792,458 m/s, matching the known speed of light.",
      "snippet_latex": [
        r"\epsilon _{0}\approx 8.854\times 10^{-12}\text{\ F/m}",
        r"\mu _{0}=4\pi \times 10^{-7}\text{\ T}\cdot \text{m/A}"
      ],
      "reference_indexes": [2, 0, 3]
    }
  ],
  "references": [
    {
      "title": "How to Derive the Speed of Light from Maxwell's Equations",
      "link":
          "https://www.wikihow.com/Derive-the-Speed-of-Light-from-Maxwell%27s-Equations",
      "snippet":
          "Substitute the Ampere-Maxwell Law. Using the BAC-CAB identity...",
      "source": "wikiHow",
      "index": 0
    },
    {
      "title": "How do you get the speed of light from Maxwell's equations?",
      "link": "https://www.reddit.com/r/AskPhysics/comments/1fe5cgb/",
      "snippet":
          "You derive the wave equation for electric and magnetic fields...",
      "source": "Reddit",
      "index": 1
    },
    {
      "title": "Maxwell's equations and light",
      "link":
          "https://web.pa.msu.edu/courses/2000fall/phy232/lectures/emwaves/maxwell.html",
      "snippet":
          "Using some not-so-simple calculus, Maxwell's equations can be used to show...",
      "source": "Michigan State University",
      "index": 2
    },
    {
      "title": "Maxwell's Equations and the Speed of Light | Doc Physics",
      "link": "https://www.youtube.com/watch?v=8PE5GEXqmT8",
      "snippet": "Field dotted along some length...",
      "source": "YouTube",
      "index": 3
    }
  ]
};
