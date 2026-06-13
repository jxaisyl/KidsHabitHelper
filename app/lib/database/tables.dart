import 'package:drift/drift.dart';

class Children extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get avatar => text().withDefault(const Constant('👦'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get minutesChange => integer()();
  TextColumn get icon => text().withDefault(const Constant('✅'))();
}

class Records extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId => integer().references(Children, #id)();
  IntColumn get ruleId => integer().references(Rules, #id)();
  IntColumn get minutesChange => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
