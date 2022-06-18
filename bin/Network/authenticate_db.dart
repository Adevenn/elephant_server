import 'package:postgres/postgres.dart';

import '../Exception/database_exception.dart';
import '../Model/constants.dart';
import '../Model/hash.dart';

class AuthenticateDB {
  final String authUsername;
  final String authPwd;

  AuthenticateDB({required this.authUsername, required this.authPwd});

  Future<void> tryAddAccount(String username, String password) async {
    try{
      var hashPwd = Hash.hashString(password);
      var connection = PostgreSQLConnection(
          Constants.authIP, Constants.authPort, Constants.authName,
          username: authUsername, password: authPwd, timeoutInSeconds: 3);
      await connection.open();
      var request =
          "CALL add_account('$username', '${hashPwd['hash_pwd']}', '${hashPwd['salt']}');";
      await connection.mappedResultsQuery(request);
      await connection.close();
    } catch(e){
      print(e);
      throw DatabaseException('AuthenticateDB.tryAddAccount:\n$e');
    }
  }

  Future<void> trySignIn(String username, String password) async {
    try {
      var connection = PostgreSQLConnection(
          Constants.authIP, Constants.authPort, Constants.authName,
          username: authUsername, password: authPwd, timeoutInSeconds: 3);
      await connection.open();

      /* Get salt */
      var request = "SELECT get_salt('$username');";
      var result = await connection.mappedResultsQuery(request);
      var salt = result[0]['']!['get_salt'];

      /* Verify username - password */
      request =
          "CALL sign_in('$username', '${Hash.hashWithSalt(password + salt)}');";
      result = await connection.mappedResultsQuery(request);
      await connection.close();
    } catch (e) {
      print(e);
      throw DatabaseException('AuthenticateDB.trySignIn:\n$e');
    }
  }
}
