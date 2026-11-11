// Base URL for the PinWall API hosted on Render.
// Override locally with: --dart-define=API_URL=http://10.0.2.2:8000
const String kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://pinwall-api.onrender.com',
);

const List<String> kGenres = [
  'nature',
  'abstract',
  'minimalist',
  'dark',
  'anime',
  'space',
];
