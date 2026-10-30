import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../theme.dart';
import 'manifest_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final StaffUser me;
  final VoidCallback onLoggedOut;

  const HomeScreen({super.key, required this.api, required this.me, required this.onLoggedOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Operator> _operators = [];
  List<Vehicle> _vehicles = [];
  List<RouteModel> _routes = [];
  List<TripDetail> _trips = [];

  Operator? _selectedOperator;
  RouteModel? _selectedRoute;
  Vehicle? _selectedVehicle;

  final _opNameCtrl = TextEditingController();
  final _opCountryCtrl = TextEditingController(text: "Côte d'Ivoire");
  final _vehPlateCtrl = TextEditingController();
  final _vehSeatsCtrl = TextEditingController(text: '30');
  final _rtOriginCtrl = TextEditingController(text: 'Abidjan');
  final _rtDestCtrl = TextEditingController(text: 'Bouaké');
  final _rtFareCtrl = TextEditingController(text: '3500');
  DateTime? _tripDeparture;

  bool _loading = true;
  String? _opMsg;
  String? _tripMsg;
  bool _opMsgOk = false;
  bool _tripMsgOk = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final operators = await widget.api.listOperators();
      final routes = await widget.api.listRoutes();
      final trips = await widget.api.listTrips();
      setState(() {
        _operators = operators;
        _routes = routes;
        _trips = trips;
        _selectedOperator ??= operators.isNotEmpty ? operators.first : null;
        _selectedRoute ??= routes.isNotEmpty ? routes.first : null;
      });
      if (_selectedOperator != null) await _loadVehicles(_selectedOperator!.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicles(String operatorId) async {
    final vehicles = await widget.api.listVehicles(operatorId);
    setState(() {
      _vehicles = vehicles;
      _selectedVehicle = vehicles.isNotEmpty ? vehicles.first : null;
    });
  }

  Future<void> _createOperator() async {
    final name = _opNameCtrl.text.trim();
    final country = _opCountryCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _opMsg = 'Operator name is required';
        _opMsgOk = false;
      });
      return;
    }
    try {
      await widget.api.createOperator(name, country);
      _opNameCtrl.clear();
      await _loadAll();
      setState(() {
        _opMsg = 'Operator "$name" created.';
        _opMsgOk = true;
      });
    } catch (e) {
      setState(() {
        _opMsg = e.toString();
        _opMsgOk = false;
      });
    }
  }

  Future<void> _verifyOperator(Operator op) async {
    try {
      await widget.api.updateOperatorStatus(op.id, 'verified');
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _createVehicle() async {
    if (_selectedOperator == null) {
      setState(() {
        _opMsg = 'Create an operator first';
        _opMsgOk = false;
      });
      return;
    }
    final plate = _vehPlateCtrl.text.trim();
    final seats = int.tryParse(_vehSeatsCtrl.text.trim()) ?? 0;
    if (plate.isEmpty || seats <= 0) {
      setState(() {
        _opMsg = 'Enter a plate number and seat count';
        _opMsgOk = false;
      });
      return;
    }
    try {
      await widget.api.createVehicle(_selectedOperator!.id, plate, seats);
      _vehPlateCtrl.clear();
      await _loadVehicles(_selectedOperator!.id);
      setState(() {
        _opMsg = 'Vehicle "$plate" added.';
        _opMsgOk = true;
      });
    } catch (e) {
      setState(() {
        _opMsg = e.toString();
        _opMsgOk = false;
      });
    }
  }

  Future<void> _createRoute() async {
    if (_selectedOperator == null) {
      setState(() {
        _tripMsg = 'Create an operator first';
        _tripMsgOk = false;
      });
      return;
    }
    final origin = _rtOriginCtrl.text.trim();
    final dest = _rtDestCtrl.text.trim();
    final fare = num.tryParse(_rtFareCtrl.text.trim()) ?? 0;
    try {
      await widget.api.createRoute(_selectedOperator!.id, origin, dest, fare);
      await _loadAll();
      setState(() {
        _tripMsg = 'Route $origin → $dest created.';
        _tripMsgOk = true;
      });
    } catch (e) {
      setState(() {
        _tripMsg = e.toString();
        _tripMsgOk = false;
      });
    }
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
    if (time == null) return;
    setState(() => _tripDeparture = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _createTrip() async {
    if (_selectedRoute == null) {
      setState(() {
        _tripMsg = 'Create a route first';
        _tripMsgOk = false;
      });
      return;
    }
    if (_selectedVehicle == null) {
      setState(() {
        _tripMsg = 'Add a vehicle first';
        _tripMsgOk = false;
      });
      return;
    }
    if (_tripDeparture == null) {
      setState(() {
        _tripMsg = 'Pick a departure time';
        _tripMsgOk = false;
      });
      return;
    }
    try {
      await widget.api.createTrip(_selectedRoute!.id, _selectedVehicle!.id, _tripDeparture!);
      await _loadAll();
      setState(() {
        _tripMsg = 'Trip scheduled.';
        _tripMsgOk = true;
        _tripDeparture = null;
      });
    } catch (e) {
      setState(() {
        _tripMsg = e.toString();
        _tripMsgOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voya Fleet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${widget.me.name} · ${widget.me.role}',
                style: const TextStyle(color: VoyaColors.inkSoft, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.api.logout();
              widget.onLoggedOut();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _SectionCard(
                    title: '1. Operator & vehicle',
                    children: [
                      TextField(controller: _opNameCtrl, decoration: const InputDecoration(labelText: 'Operator name')),
                      const SizedBox(height: 10),
                      TextField(controller: _opCountryCtrl, decoration: const InputDecoration(labelText: 'Country')),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _createOperator, child: const Text('Create operator')),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<Operator>(
                        value: _selectedOperator,
                        decoration: const InputDecoration(labelText: 'Operator'),
                        items: _operators
                            .map((o) => DropdownMenuItem(value: o, child: Text('${o.name} (${o.status})')))
                            .toList(),
                        onChanged: (o) {
                          setState(() => _selectedOperator = o);
                          if (o != null) _loadVehicles(o.id);
                        },
                      ),
                      if (_selectedOperator != null && _selectedOperator!.status != 'verified' && widget.me.isPlatformAdmin) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _verifyOperator(_selectedOperator!),
                          child: const Text('Approve KYC (mark verified)'),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(controller: _vehPlateCtrl, decoration: const InputDecoration(labelText: 'Plate number')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _vehSeatsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Seat count'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _createVehicle, child: const Text('Add vehicle')),
                      if (_opMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(_opMsg!, style: TextStyle(color: _opMsgOk ? VoyaColors.good : VoyaColors.crit, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: '2. Route & trip',
                    children: [
                      TextField(controller: _rtOriginCtrl, decoration: const InputDecoration(labelText: 'Origin')),
                      const SizedBox(height: 10),
                      TextField(controller: _rtDestCtrl, decoration: const InputDecoration(labelText: 'Destination')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _rtFareCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Base fare'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _createRoute, child: const Text('Create route')),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<RouteModel>(
                        value: _selectedRoute,
                        decoration: const InputDecoration(labelText: 'Route'),
                        items: _routes
                            .map((r) => DropdownMenuItem(value: r, child: Text('${r.origin} → ${r.destination}')))
                            .toList(),
                        onChanged: (r) => setState(() => _selectedRoute = r),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Vehicle>(
                        value: _selectedVehicle,
                        decoration: const InputDecoration(labelText: 'Vehicle'),
                        items: _vehicles
                            .map((v) => DropdownMenuItem(value: v, child: Text('${v.plateNumber} (${v.seatCount} seats)')))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedVehicle = v),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _pickDeparture,
                        child: Text(_tripDeparture == null
                            ? 'Pick departure time'
                            : DateFormat('EEE d MMM, HH:mm').format(_tripDeparture!)),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _createTrip, child: const Text('Schedule trip')),
                      if (_tripMsg != null) ...[
                        const SizedBox(height: 8),
                        Text(_tripMsg!, style: TextStyle(color: _tripMsgOk ? VoyaColors.good : VoyaColors.crit, fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: '3. Trips & manifests',
                    children: _trips.isEmpty
                        ? [const Text('No trips scheduled yet.', style: TextStyle(color: VoyaColors.inkSoft))]
                        : _trips
                            .map((t) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text('${t.origin} → ${t.destination}'),
                                    subtitle: Text(DateFormat('EEE d MMM, HH:mm').format(t.departureAt)),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ManifestScreen(api: widget.api, trip: t)),
                                    ),
                                  ),
                                ))
                            .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
