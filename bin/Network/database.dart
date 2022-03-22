import 'package:postgres/postgres.dart';

import '../Exception/database_exception.dart';

class DB {
  final String _ip;
  final int _port;

  DB(this._ip, this._port);

  Future<void> test(String database, username, password) async{
    try {
      var connection = PostgreSQLConnection(_ip, _port, database,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      await connection.close();
    } catch (e) {
      throw DatabaseException('DB.query: Error in the process\n$e');
    }
  }

  Future<void> query(String request, database, username, password) async {
    try {
      var connection = PostgreSQLConnection(_ip, _port, database,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      await connection.query(request);
      await connection.close();
    } catch (e) {
      throw DatabaseException('DB.query: Error in the process\n$e');
    }
  }

  Future<List<dynamic>> queryWithResult(
      String request, database, username, password) async {
    try {
      var connection = PostgreSQLConnection(_ip, _port, database,
          username: username, password: password, timeoutInSeconds: 3);
      await connection.open();
      var result =
          await connection.mappedResultsQuery(request, timeoutInSeconds: 3);
      await connection.close();
      return result;
    } catch (e) {
      throw DatabaseException('DB.queryWithResult: Error in the process\n$e');
    }
  }
}
