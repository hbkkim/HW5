import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QuizSetupScreen(),
    );
  }
}

class QuizSetupScreen extends StatefulWidget {
  @override
  _QuizSetupScreenState createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  int _numberOfQuestions = 10;
  String? _selectedCategory;
  String? _selectedDifficulty;
  String? _selectedType;

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  Map<String, int> _categories = {};

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
  final url = Uri.parse('https://opentdb.com/api_category.php');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final categoryList = data['trivia_categories'] as List<dynamic>;

      setState(() {
        _categories = {
          for (var category in categoryList)
            category['name'] as String: category['id'] as int,
        };
      });
    } else {
      print('Failed to fetch categories: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching categories: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Setup'),
      ),
      body: _categories.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading categories...'),
                ElevatedButton(
                  onPressed: _fetchCategories,
                  child: Text('Retry'),
                ),
              ],
            ),
          )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Quiz Preferences',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Category'),
                    items: _categories.keys
                        .map((category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    value: _selectedCategory,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Difficulty'),
                    items: _difficulties
                        .map((difficulty) => DropdownMenuItem<String>(
                              value: difficulty,
                              child: Text(difficulty),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDifficulty = value;
                      });
                    },
                    value: _selectedDifficulty,
                  ),
                   DropdownButtonFormField<String>(
                     value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Question Type',
                       border: OutlineInputBorder(),
                     ),
                     items: [
                        DropdownMenuItem(
                           value: 'multiple',
                           child: Text('Multiple Choice'),
                      ),
                      DropdownMenuItem(
                        value: 'boolean',
                        child: Text('True/False'),
                      ),
                    ],
                  onChanged: (value) {
                   setState(() {
                   _selectedType = value!;
                   });
                  },
                ),
                  SizedBox(height: 16),
                  Text('Number of Questions: $_numberOfQuestions'),
                  Slider(
                    min: 1,
                    max: 50,
                    divisions: 49,
                    value: _numberOfQuestions.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        _numberOfQuestions = value.toInt();
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedCategory != null &&
                          _selectedDifficulty != null &&
                          _selectedType != null) {
                        final categoryId = _categories[_selectedCategory]!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizScreen(
                              numberOfQuestions: _numberOfQuestions,
                              category: categoryId,
                              difficulty: _selectedDifficulty!.toLowerCase(),
                              type: _selectedType!.replaceAll(' ', '_').toLowerCase(),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please select all options!'),
                          ),
                        );
                      }
                    },
                    child: Text('Start Quiz'),
                  ),
                ],
              ),
            ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final int numberOfQuestions;
  final int category;
  final String difficulty;
  final String type;

  QuizScreen({
    required this.numberOfQuestions,
    required this.category,
    required this.difficulty,
    required this.type,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _questions = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  int _score = 0;
  String? _feedback;
  List<String>? _currentOptions;
  Timer? _timer; // Timer for countdown
  int _remainingTime = 10; // Set initial time limit (in seconds)

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url = Uri.parse(
        'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}&category=${widget.category}&difficulty=${widget.difficulty}&type=${widget.type}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _questions = data['results'] as List<dynamic>;
          _isLoading = false;
          _setCurrentOptions();
          _startTimer(); // Start the timer when questions are fetched
        });
      } else {
        print('Failed to fetch questions: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setCurrentOptions() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correct_answer'];
    final incorrectAnswers = List<String>.from(currentQuestion['incorrect_answers']);
    _currentOptions = [...incorrectAnswers, correctAnswer]..shuffle();
    _remainingTime = 10; // Reset the timer for the new question
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _timer?.cancel(); // Stop the timer when it reaches 0
        _submitAnswer(); // Automatically submit the answer when time is up
        setState(() {
          _feedback = 'Time is up! The correct answer was "${_questions[_currentQuestionIndex]['correct_answer']}".';
        });
      }
    });
  }

  void _submitAnswer() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion['correct_answer'];

    if (_selectedAnswer == correctAnswer) {
      setState(() {
        _score++;
        _feedback = 'Correct!';
      });
    } else {
      setState(() {
        _feedback = 'Incorrect! The correct answer was "$correctAnswer".';
      });
    }

    Future.delayed(Duration(seconds: 2), () {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _feedback = null; // Clear feedback for the next question
          _setCurrentOptions(); // Set options for the next question
          _startTimer(); // Restart the timer
        });
      } else {
        _showFinalScore();
      }
    });
  }

  void _showFinalScore() {
    _timer?.cancel(); // Stop the timer when the quiz is completed
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quiz Completed!'),
          content: Text('Your final score is $_score / ${_questions.length}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context); // Return to setup screen
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? Center(child: Text('No questions found!'))
              : _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final questionText = currentQuestion['question'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Score: $_score / ${_questions.length}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Question ${_currentQuestionIndex + 1}/${_questions.length}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                questionText,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Time Remaining: $_remainingTime seconds', // Timer display
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          ...?_currentOptions?.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _selectedAnswer,
              onChanged: (value) {
                setState(() {
                  _selectedAnswer = value;
                });
              },
            );
          }).toList(),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedAnswer == null ? null : _submitAnswer,
            child: Text('Submit Answer'),
          ),
          if (_feedback != null) ...[
            SizedBox(height: 16),
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _feedback == 'Correct!' ? Colors.green : Colors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
