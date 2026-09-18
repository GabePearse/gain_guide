import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRecord {
  final int requestId; final String userId; final String displayName; final String status; final bool incoming;
  const FriendRecord({required this.requestId,required this.userId,required this.displayName,required this.status,required this.incoming});
}

class SupabaseFriendsService {
  SupabaseFriendsService._(); static final instance=SupabaseFriendsService._();
  SupabaseClient get _db=>Supabase.instance.client;
  String get _me=>_db.auth.currentUser!.id;

  Future<List<FriendRecord>> list() async {
    final rows=await _db.from('friend_requests').select('id,sender_id,receiver_id,status').or('sender_id.eq.$_me,receiver_id.eq.$_me').order('created_at',ascending:false);
    final out=<FriendRecord>[];
    for(final raw in rows){
      final r=Map<String,dynamic>.from(raw); final incoming=r['receiver_id']==_me; final other=(incoming?r['sender_id']:r['receiver_id']) as String;
      final p=await _db.from('profiles').select('display_name').eq('id',other).maybeSingle();
      out.add(FriendRecord(requestId:r['id'],userId:other,displayName:(p?['display_name'] as String?)??'GainGuide user',status:r['status'],incoming:incoming));
    }
    return out;
  }
  Future<void> send(String email) async {
    final p=await _db.rpc('find_profile_by_email',params:{'search_email':email.trim()});
    if(p is! List || p.isEmpty) throw Exception('No GainGuide account found with that email.');
    await _db.from('friend_requests').insert({'sender_id':_me,'receiver_id':p.first['id']});
  }
  Future<void> respond(int id,bool accept)=>_db.from('friend_requests').update({'status':accept?'accepted':'declined','responded_at':DateTime.now().toUtc().toIso8601String()}).eq('id',id);
}