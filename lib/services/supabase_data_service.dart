import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';
import '../models/set_entry.dart';
import '../models/workout.dart';

class SupabaseDataService {
  SupabaseDataService._();
  static final instance = SupabaseDataService._();
  SupabaseClient get _db => Supabase.instance.client;
  String get userId => _db.auth.currentUser!.id;

  Future<List<Workout>> getWorkouts() async {
    final rows = await _db.from('workouts').select('*, exercises(*, set_entries(*))').eq('user_id', userId).order('sort_order').order('id');
    final workouts = (rows as List).map((r) {
      final m=Map<String,dynamic>.from(r);
      final exerciseRows=List<Map<String,dynamic>>.from((m['exercises'] as List? ?? []).map((e)=>Map<String,dynamic>.from(e)))..sort((a,b){ final c=(a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0); return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int); });
      final exercises=exerciseRows.map((e) {
        final em=Map<String,dynamic>.from(e);
        final sets=(em['set_entries'] as List? ?? []).map((s)=>SetEntry(id:s['id'] as int,exerciseId:em['id'] as int,reps:s['reps'] as int,weight:(s['weight'] as num).toDouble(),restSeconds:s['rest_seconds'] as int?,completedAt:s['completed_at'] == null ? null : DateTime.parse(s['completed_at'] as String))).toList();
        return Exercise(id:em['id'] as int,workoutId:m['id'] as int,name:em['name'],sets:sets,targetSets:em['target_sets'],minReps:em['min_reps'],maxReps:em['max_reps'],restMinSeconds:em['rest_min_seconds'],restMaxSeconds:em['rest_max_seconds'],sortOrder:em['sort_order'] as int? ?? 0);
      }).toList();
      return Workout(id:m['id'] as int,name:m['name'],exercises:exercises,scheduledWeekdays:m['scheduled_weekdays'],scheduledHour:m['scheduled_hour'],scheduledMinute:m['scheduled_minute'],sortOrder:m['sort_order'] as int? ?? 0);
    }).toList();
    workouts.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return workouts;
  }

  Future<List<Workout>> getHistory() async {
    final rows=await _db.from('completed_workouts').select('*, completed_exercises(*, completed_set_entries(*))').eq('user_id',userId).order('completed_at',ascending:false);
    return (rows as List).map((r) {
      final m=Map<String,dynamic>.from(r);
      final exercises=(m['completed_exercises'] as List? ?? []).map((e) {
        final em=Map<String,dynamic>.from(e);
        final sets=(em['completed_set_entries'] as List? ?? []).map((s)=>SetEntry(id:s['id'],exerciseId:em['id'],reps:s['reps'],weight:(s['weight'] as num).toDouble(),restSeconds:s['rest_seconds'] as int?,completedAt:s['completed_at'] == null ? null : DateTime.parse(s['completed_at'] as String))).toList();
        return Exercise(id:em['id'],workoutId:m['id'],name:em['name'],sets:sets);
      }).toList();
      return Workout(id:m['id'],name:m['name'],exercises:exercises,completedAt:DateTime.parse(m['completed_at']));
    }).toList();
  }

  Future<int> insertWorkout(String name) async => (await _db.from('workouts').insert({'user_id':userId,'name':name}).select('id').single())['id'];
  Future<void> updateWorkout(Workout w) => _db.from('workouts').update({'name':w.name,'scheduled_weekdays':w.scheduledWeekdays,'scheduled_hour':w.scheduledHour,'scheduled_minute':w.scheduledMinute,'sort_order':w.sortOrder}).eq('id',w.id!);
  Future<void> reorderWorkouts(List<Workout> workouts) async {
    for (var i = 0; i < workouts.length; i++) {
      await _db.from('workouts').update({'sort_order': i}).eq('id', workouts[i].id!).eq('user_id', userId);
    }
  }
  Future<void> deleteWorkout(int id)=>_db.from('workouts').delete().eq('id',id);
  Future<int> insertExercise(Exercise e) async => (await _db.from('exercises').insert({'workout_id':e.workoutId,'name':e.name,'target_sets':e.targetSets,'min_reps':e.minReps,'max_reps':e.maxReps,'rest_min_seconds':e.restMinSeconds,'rest_max_seconds':e.restMaxSeconds,'sort_order':e.sortOrder}).select('id').single())['id'];
  Future<void> updateExercise(Exercise e)=>_db.from('exercises').update({'name':e.name,'target_sets':e.targetSets,'min_reps':e.minReps,'max_reps':e.maxReps,'rest_min_seconds':e.restMinSeconds,'rest_max_seconds':e.restMaxSeconds}).eq('id',e.id!);
  Future<void> reorderExercises(List<Exercise> exercises) async {
    for (var i = 0; i < exercises.length; i++) {
      await _db.from('exercises').update({'sort_order': i}).eq('id', exercises[i].id!);
    }
  }
  Future<void> deleteExercise(int id)=>_db.from('exercises').delete().eq('id',id);
  Future<void> insertSet(SetEntry s)=>_db.from('set_entries').insert({'exercise_id':s.exerciseId,'reps':s.reps,'weight':s.weight,'rest_seconds':s.restSeconds,'completed_at':s.completedAt?.toUtc().toIso8601String()});
  Future<void> deleteSet(int id)=>_db.from('set_entries').delete().eq('id',id);
  Future<void> deleteCompletedWorkout(int id)=>_db.from('completed_workouts').delete().eq('id',id).eq('user_id',userId);

  Future<void> completeWorkout(Workout w) async {
    final cw=await _db.from('completed_workouts').insert({'user_id':userId,'name':w.name,'completed_at':DateTime.now().toUtc().toIso8601String()}).select('id').single();
    for(final e in w.exercises){
      final ce=await _db.from('completed_exercises').insert({'workout_id':cw['id'],'name':e.name}).select('id').single();
      if(e.sets.isNotEmpty) await _db.from('completed_set_entries').insert(e.sets.map((s)=>{'exercise_id':ce['id'],'reps':s.reps,'weight':s.weight,'rest_seconds':s.restSeconds,'completed_at':s.completedAt?.toUtc().toIso8601String()}).toList());
    }
    await _db.from('set_entries').delete().inFilter('exercise_id',w.exercises.map((e)=>e.id!).toList());
  }
}