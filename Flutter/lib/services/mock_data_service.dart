class MockDataService {
  // Mock user data
  static Map<String, dynamic> currentUser = {
    'id': '1',
    'name': 'John Doe',
    'email': 'john@example.com',
    'avatar': 'https://picsum.photos/200',
    'rating': 4.8,
    'memberSince': DateTime(2023),
    'location': 'Jakarta, Indonesia',
  };

  // Mock items data
  static List<Map<String, dynamic>> items = [
    {
      'id': '1',
      'title': 'Vintage Camera',
      'description': 'A beautiful vintage camera in excellent condition',
      'images': [
        'https://picsum.photos/500/300?random=1',
        'https://picsum.photos/500/300?random=2',
        'https://picsum.photos/500/300?random=3',
      ],
      'category': 'Electronics',
      'condition': 'Good',
      'estimatedValue': 2000000,
      'location': 'Jakarta Selatan',
      'userId': '2',
      'userName': 'Jane Smith',
      'userRating': 4.5,
      'preferredItems': ['DSLR Camera', 'Vintage Lenses'],
    },
    {
      'id': '2',
      'title': 'Gaming Laptop',
      'description': 'High-performance gaming laptop, 1 year old',
      'images': [
        'https://picsum.photos/500/300?random=4',
        'https://picsum.photos/500/300?random=5',
      ],
      'category': 'Electronics',
      'condition': 'Like New',
      'estimatedValue': 15000000,
      'location': 'Jakarta Barat',
      'userId': '3',
      'userName': 'Mike Johnson',
      'userRating': 4.7,
      'preferredItems': ['MacBook Pro', 'iPad Pro'],
    },
  ];

  // Mock trades data
  static List<Map<String, dynamic>> trades = [
    {
      'id': '1',
      'status': 'active',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'item1': {
        'id': '1',
        'title': 'Vintage Camera',
        'image': 'https://picsum.photos/60/60?random=1',
        'userId': '1',
      },
      'item2': {
        'id': '2',
        'title': 'DSLR Camera',
        'image': 'https://picsum.photos/60/60?random=2',
        'userId': '2',
      },
    },
    // Add more mock trades...
  ];

  // Mock reviews data
  static List<Map<String, dynamic>> reviews = [
    {
      'id': '1',
      'rating': 5,
      'comment': 'Great trader! Item was exactly as described.',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'userId': '2',
      'userName': 'Jane Smith',
      'userAvatar': 'https://picsum.photos/40/40?random=1',
      'tradeId': '1',
      'photos': [
        'https://picsum.photos/60/60?random=1',
        'https://picsum.photos/60/60?random=2',
      ],
    },
    // Add more mock reviews...
  ];

  // Mock notifications data
  static List<Map<String, dynamic>> notifications = [
    {
      'id': '1',
      'type': 'tradeOffer',
      'title': 'New Trade Offer',
      'message': 'John wants to trade their Camera for your Laptop',
      'date': DateTime.now().subtract(const Duration(minutes: 30)),
      'read': false,
    },
    {
      'id': '2',
      'type': 'match',
      'title': 'New Match!',
      'message': 'You and Sarah both liked each other\'s items',
      'date': DateTime.now().subtract(const Duration(hours: 2)),
      'read': false,
    },
    // Add more mock notifications...
  ];
}