import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'Map285.dart'; //replace
import 'Map287.dart'; //replace


class Room {
  final String roomId;
  final String roomType; 
  int totalSeats;
  int occupiedSeats;

  Room({
    required this.roomId,
    required this.roomType, 
    this.totalSeats = 0,
    this.occupiedSeats = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['room_id'] ?? '',
      roomType: json['description_2'] ?? 'Unknown Type', 
      totalSeats: 0,
      occupiedSeats: 0,
    );
  }

  void addSeat(bool occupied) {
    totalSeats += 1;
    if (occupied) {
      occupiedSeats += 1;
    }
  }
}


Future<List<Room>> fetchRoomsForFloor(String floorName) async {
  final response = await http.get(Uri.parse('https://uclapi.com/workspaces/sensors?survey_id=115&token=uclapi-47ccfea341ed403-36900a24718217f-25f091619e58a0a-10c2964300e026b'));
  
  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    var floorMap = data['maps'].firstWhere((map) => map['name'] == floorName, orElse: () => null);
    if (floorMap == null) {
      throw Exception('Floor $floorName not found');
    }
    List<dynamic> sensors = floorMap['sensors'].values.toList();
    Map<String, Room> rooms = {};

    for (var sensor in sensors) {
      String roomType = sensor['description_2'] ?? 'Unknown Type'; 
      if (roomType == 'Unknown Type') continue; 
      bool occupied = sensor['occupied'] ?? false;

      rooms.putIfAbsent(roomType, () => Room.fromJson({
        'room_id': sensor['room_id'] ?? 'Unknown ID',
        'description_2': roomType,
      })).addSeat(occupied);
    }

    return rooms.values.toList().where((room) => room.roomType != 'Unknown Type').toList(); 
  } else {
    throw Exception('Failed to load room data');
  }
}


class Floor285Screen extends StatefulWidget {
  const Floor285Screen({super.key});

  @override
  _Floor285ScreenState createState() => _Floor285ScreenState();
}

class _Floor285ScreenState extends State<Floor285Screen> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<Room>>? _roomsFuture;
  List<Room>? _allRooms; 
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRooms().then((_) {
      _roomsFuture = Future.value(_allRooms);
    });
  }


  void _onSearchChanged() {
    _filterRooms(_searchController.text);
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final rooms = await fetchRoomsForFloor("Fifth Floor");
      _allRooms = rooms;
      _filterRooms(_searchController.text);
    } catch (e) {
      // Handle errors if necessary
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterRooms(String query) {
    if (_allRooms == null) {
      return; 
    }

    List<Room> filteredRooms;
    if (query.isEmpty) {
      filteredRooms = _allRooms!;
    } else {
      filteredRooms = _allRooms!.where((room) {
        return room.roomType.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }

    setState(() {
      _roomsFuture = Future.value(filteredRooms);
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "5F - Marshgate",
            style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 80, 6, 119),
          iconTheme: const IconThemeData(
          color: Colors.white, 
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 48.0,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  // Trigger UI update
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search...',
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            _searchController.clear();
                            _filterRooms(''); 
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
      
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<Room>>(
                  future: _roomsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _buildRoomList(snapshot.data!);
                    } else if (snapshot.connectionState == ConnectionState.done && (!snapshot.hasData || snapshot.data!.isEmpty)) {
                      return const Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off, 
                              size: 48.0, 
                              color: Colors.grey
                              ),
                            Text(
                              "Oops! We couldn't find any matches.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 20,
                                color: Color.fromARGB(255, 114, 114, 114),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 16.0),
                              child: Text(
                                "Try adjusting your search to find what you're looking for.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color.fromARGB(255, 97, 97, 97),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const SizedBox.shrink(); 
                    }
                  },
                ),
              ),
            ],
          ),
        );
      }


    Widget _buildRoomList(List<Room> rooms) {
      return RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return buildCard(
              context,
              room.roomType,
              "Marshgate - 5F, E20 2AE",
              room.totalSeats - room.occupiedSeats,
              room.totalSeats,
              () {
               // replace jump
              },
            );
          },
        ),
      );
    }

Widget buildCard(
  BuildContext context,
  String roomType, 
  String address, 
  int availableSeats, 
  int totalSeats, 
  void Function() onTap,
){

  final double availablePercentage = availableSeats / totalSeats;

  Color availabilityColor;
  if (availablePercentage > 0.5) {
    availabilityColor = Colors.green;
  } else if (availablePercentage >= 0.2) {
    availabilityColor = Color.fromARGB(255, 255, 200, 0); 
  } else {
    availabilityColor = Colors.red;
  }

  String adjustedAddress = "5F - Marshgate, E20 2AE";
  String adjustedBuildingName = roomType;
  if (roomType == "East Campus - Pool St") {
    adjustedBuildingName = "UCL East - One Pool Street"; //replace
  } else if (roomType == "East Campus - Marshgate") {
    adjustedBuildingName = "UCL East - Marshgate"; //replace
  }

  void Function() adjustedOnTap;
  if (roomType == "Connected Environments") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map285Screen())); //replace
  } else if (roomType == "Student Study Space") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map285Screen())); //replace
  } else if (roomType == "Student Learning Hub") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map287Screen())); //replace
  } else if (roomType == "Digital Accessibility Hub Students") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map287Screen())); //replace
  } else if (roomType == "Digital Accessibility Hub Staff") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map287Screen())); //replace
  } else if (roomType == "People and Nature") {
    adjustedOnTap = () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Map287Screen())); //replace
  } else {
    adjustedOnTap = () => print('No map available for this building');
  }


Map<String, dynamic> getBuildingStatus(String adjustedBuildingName) {
  final now = DateTime.now();
  // final weekday = now.weekday;
  final hour = now.hour;

  bool isOpenToday = true;
  bool isOpenNow = hour >= 7 && hour < 21;
  String openHours = "07:00 - 21:00";

  String statusText = isOpenNow ? "Open now, $openHours" : "Closed now, $openHours";
  // Color statusBoxColor = isOpenNow ? Colors.green : Colors.grey;
  // Color statusTextColor = isOpenNow ? Colors.green : Colors.red;

  // statusText = isOpenToday ? (isOpenNow ? "Open now, $openHours" : "Closed now, $openHours") : "Closed today";

  return {
    'isOpenNow': isOpenNow,
    'isOpenToday': isOpenToday,
    'statusText': statusText,
    'statusBoxColor': isOpenNow ? Colors.green : Colors.grey, 
    'statusTextColor': isOpenNow ? Colors.green : Colors.red 
  };
}


Map<String, dynamic> status = getBuildingStatus(adjustedBuildingName);
// bool isOpenNow = status['isOpenNow'];
// bool isOpenToday = status['isOpenToday'];
String statusText = status['statusText'];
Color statusBoxColor = status['statusBoxColor'];
Color statusTextColor = status['statusTextColor'];


  return Card(
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        adjustedBuildingName, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        adjustedAddress, 
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // IconButton(
              //   icon: const Icon(Icons.chevron_right),
              //   onPressed: onTap, 
              // ),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), 
            decoration: BoxDecoration(
              color: availabilityColor,
              borderRadius: BorderRadius.circular(8), 
            ),
                  child: const Text(
                    'Seats',
                    style: TextStyle(
                    fontSize: 16.0, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                    ), 
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$availableSeats available / $totalSeats total',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
                  decoration: BoxDecoration(
                    color: statusBoxColor, 
                    borderRadius: BorderRadius.circular(8), 
                  ),
                  child: const Text(
                    'Status',
                    style: TextStyle(
                    fontSize: 16.0, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                    ), 
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: statusTextColor),
                ),
              ],
            ),
          ),

          const Divider(),
          InkWell(
            onTap: adjustedOnTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text('View Room Details', 
                    style: TextStyle(fontSize: 16)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 12.0),
                    child: Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}