import '../models/movement.dart';

abstract class MovementsRepository {
  Future<List<Movement>> getMovements(String labId, {int limit = 50});
  Future<Movement> registerMovement(Movement movement);
}
