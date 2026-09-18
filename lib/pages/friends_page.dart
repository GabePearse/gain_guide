import 'package:flutter/material.dart';
import '../services/supabase_friends_service.dart';

class FriendsPage extends StatefulWidget { const FriendsPage({super.key}); @override State<FriendsPage> createState()=>_FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage>{
  final _service=SupabaseFriendsService.instance; late Future<List<FriendRecord>> _items;
  @override void initState(){super.initState();_reload();}
  void _reload(){_items=_service.list();}
  Future<void> _add() async {
    final c=TextEditingController();
    final email=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Add friend'),content:TextField(controller:c,keyboardType:TextInputType.emailAddress,autofocus:true,decoration:const InputDecoration(labelText:'Their GainGuide email')),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,c.text),child:const Text('Send request'))]));
    if(email==null||email.trim().isEmpty)return;
    try{await _service.send(email);setState(_reload);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Friends'),actions:[IconButton(onPressed:_add,icon:const Icon(Icons.person_add_alt_1),tooltip:'Add friend')]),body:FutureBuilder<List<FriendRecord>>(future:_items,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text('Could not load friends: ${s.error}'));final items=s.data??[];if(items.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('No friends yet. Add someone by the email they use for GainGuide. They will need to accept your request.')));return RefreshIndicator(onRefresh:()async{setState(_reload);await _items;},child:ListView(padding:const EdgeInsets.all(16),children:items.map((f){final pending=f.status=='pending';return Card(child:ListTile(leading:CircleAvatar(child:Text(f.displayName.isEmpty?'?':f.displayName[0].toUpperCase())),title:Text(f.displayName),subtitle:Text(f.status=='accepted'?'Friend':f.incoming?'Wants to be your friend':'Request pending'),trailing:pending&&f.incoming?Wrap(children:[IconButton(tooltip:'Decline',onPressed:()async{await _service.respond(f.requestId,false);setState(_reload);},icon:const Icon(Icons.close)),IconButton(tooltip:'Accept',onPressed:()async{await _service.respond(f.requestId,true);setState(_reload);},icon:const Icon(Icons.check))]):null));}).toList()));}));
}