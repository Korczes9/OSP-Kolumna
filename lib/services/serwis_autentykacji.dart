/// Serwis obsługujący autentykację użytkownika
class AuthService {
  bool _loggedInUser = false;

  /// Logs in user with email and password
  /// Returns `true` if login was successful, otherwise `false`
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      if (email.isEmpty || password.isEmpty) {
        print('Error: Email and password are required');
        return false;
      }

      if (!email.contains('@')) {
        print('Error: Invalid email format');
        return false;
      }

      if (password.length < 6) {
        print('Error: Password must be at least 6 characters');
        return false;
      }

      _loggedInUser = true;
      print('User logged in: $email');
      return true;
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }

  /// Logs out current user
  void logout() {
    _loggedInUser = false;
    print('User logged out');
  }

  /// Checks if user is logged in
  bool isLoggedIn() => _loggedInUser;

  /// Registers a new user
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        print('Błąd: Wszystkie pola są wymagane');
        return false;
      }

      print('Nowy użytkownik zarejestrowany: $email');
      return true;
    } catch (e) {
      print('Błąd podczas rejestracji: $e');
      return false;
    }
  }

  /// Resets user password
  Future<bool> resetujHaslo(String email) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (email.isEmpty) {
        print('Błąd: Email jest wymagany');
        return false;
      }

      print('Link do resetowania hasla wyslany na: $email');
      return true;
    } catch (e) {
      print('Błąd podczas resetowania hasła: $e');
      return false;
    }
  }
}
