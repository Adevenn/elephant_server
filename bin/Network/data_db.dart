import 'package:postgres/postgres.dart';

import '../Exception/database_exception.dart';
import '../Model/constants.dart';

class DB {
  final String username;
  final String password;

  DB({required this.username, required this.password});

  Future<void> test() async {
    try {
      var connection = PostgreSQLConnection(
          Constants.dataIP, Constants.dataPort, Constants.dataName,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      await connection.close();
    } catch (e) {
      throw DatabaseException('DB.query: Error in the process\n$e');
    }
  }

  Future<void> query(String request) async {
    try {
      var connection = PostgreSQLConnection(
          Constants.dataIP, Constants.dataPort, Constants.dataName,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      await connection.query(request);
      await connection.close();
    } catch (e) {
      print(e);
      throw DatabaseException('DB.query: Error in the process\n$e');
    }
  }

  Future<List<dynamic>> queryWithResult(String request) async {
    try {
      var connection = PostgreSQLConnection(
          Constants.dataIP, Constants.dataPort, Constants.dataName,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      var result =
          await connection.mappedResultsQuery(request, timeoutInSeconds: 3);
      await connection.close();
      return result;
    } catch (e) {
      print(e);
      throw DatabaseException('DB.queryWithResult: Error in the process\n$e');
    }
  }
}
