import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import 'package:voya_ui/voya_ui.dart';
import '../ui/form_sheet.dart';
import '../ui/user_message.dart';
import 'manifest_screen.dart';

final _departureFmt = DateFormat('EEE d MMM, HH:mm');

class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final StaffUser me;
  final VoidCallback onLoggedOut;

  const HomeScreen(
      {super.key,
      required this.api,
      required this.me,
      required this.onLoggedOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Operator> _operators = [];
  List<Vehicle> _vehicles = [];
  List<RouteModel> _routes = [];
  List<TripDetail> _trips = [];
  Operator? _selectedOperator;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final operators = await widget.api.listOperators();
      final routes = await widget.api.listRoutes();
      final trips = await widget.api.listTrips();
      if (!mounted) return;
      setState(() {
        _operators = operators;
        _routes = routes;
        _trips = trips;
        _selectedOperator = operators
                .where((o) => o.id == _selectedOperator?.id)
                .firstOrNull ??
            (operators.isNotEmpty ? operators.first : null);
      });
      if (_selectedOperator != null) await _loadVehicles(_selectedOperator!.id);
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicles(String operatorId) async {
    final vehicles = await widget.api.listVehicles(operatorId);
    if (mounted) setState(() => _vehicles = vehicles);
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  // ---- creation flows (one task per sheet) --------------------------------

  Future<void> _addOperator() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final country = TextEditingController(text: "Côte d'Ivoire");
    final ok = await showFormSheet(
      context,
      title: 'New operator',
      submitLabel: 'Create operator',
      formKey: formKey,
      fields: [
        TextFormField(
          controller: name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Operator name'),
          validator: (v) => _required(v, 'Operator name'),
        ),
        TextFormField(
          controller: country,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Country'),
          validator: (v) => _required(v, 'Country'),
        ),
      ],
      onSubmit: () =>
          widget.api.createOperator(name.text.trim(), country.text.trim()),
    );
    if (ok == true) {
      _toast('Operator "${name.text.trim()}" created.');
      await _loadAll();
    }
  }

  Future<void> _verifyOperator(Operator op) async {
    try {
      await widget.api.updateOperatorStatus(op.id, 'verified');
      await _loadAll();
    } catch (e) {
      if (mounted) _toast(userMessage(e));
    }
  }

  Future<void> _addVehicle() async {
    final op = _selectedOperator;
    if (op == null) return;
    final formKey = GlobalKey<FormState>();
    final plate = TextEditingController();
    final seats = TextEditingController(text: '30');
    final ok = await showFormSheet(
      context,
      title: 'Add vehicle to ${op.name}',
      submitLabel: 'Add vehicle',
      formKey: formKey,
      fields: [
        TextFormField(
          controller: plate,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Plate number'),
          validator: (v) => _required(v, 'Plate number'),
        ),
        TextFormField(
          controller: seats,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Seat count'),
          validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) > 0
              ? null
              : 'Enter a seat count above 0',
        ),
      ],
      onSubmit: () => widget.api
          .createVehicle(op.id, plate.text.trim(), int.parse(seats.text.trim())),
    );
    if (ok == true) {
      _toast('Vehicle "${plate.text.trim()}" added.');
      await _loadVehicles(op.id);
    }
  }

  Future<void> _addRoute() async {
    final op = _selectedOperator;
    if (op == null) return;
    final formKey = GlobalKey<FormState>();
    final origin = TextEditingController(text: 'Abidjan');
    final dest = TextEditingController(text: 'Bouaké');
    final fare = TextEditingController(text: '3500');
    final ok = await showFormSheet(
      context,
      title: 'New route for ${op.name}',
      submitLabel: 'Create route',
      formKey: formKey,
      fields: [
        TextFormField(
          controller: origin,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Origin'),
          validator: (v) => _required(v, 'Origin'),
        ),
        TextFormField(
          controller: dest,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Destination'),
          validator: (v) => _required(v, 'Destination'),
        ),
        TextFormField(
          controller: fare,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
              labelText: 'Base fare', suffixText: 'FCFA'),
          validator: (v) => (num.tryParse(v?.trim() ?? '') ?? 0) > 0
              ? null
              : 'Enter a fare above 0',
        ),
      ],
      onSubmit: () => widget.api.createRoute(op.id, origin.text.trim(),
          dest.text.trim(), num.parse(fare.text.trim())),
    );
    if (ok == true) {
      _toast('Route ${origin.text.trim()} → ${dest.text.trim()} created.');
      await _loadAll();
    }
  }

  Future<void> _addTrip() async {
    if (_routes.isEmpty || _vehicles.isEmpty) {
      _toast(_routes.isEmpty
          ? 'Create a route first.'
          : 'Add a vehicle first.');
      return;
    }
    final formKey = GlobalKey<FormState>();
    RouteModel route = _routes.first;
    Vehicle vehicle = _vehicles.first;
    DateTime? departure;
    final departureCtrl = TextEditingController();
    final ok = await showFormSheet(
      context,
      title: 'Schedule trip',
      submitLabel: 'Schedule trip',
      formKey: formKey,
      fields: [
        DropdownButtonFormField<RouteModel>(
          value: route,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Route'),
          items: [
            for (final r in _routes)
              DropdownMenuItem(
                  value: r, child: Text('${r.origin} → ${r.destination}')),
          ],
          onChanged: (r) => route = r ?? route,
        ),
        DropdownButtonFormField<Vehicle>(
          value: vehicle,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Vehicle'),
          items: [
            for (final v in _vehicles)
              DropdownMenuItem(
                  value: v, child: Text('${v.plateNumber} · ${v.seatCount} seats')),
          ],
          onChanged: (v) => vehicle = v ?? vehicle,
        ),
        Builder(
          builder: (ctx) => TextFormField(
            controller: departureCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Departure',
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
            ),
            validator: (_) => departure == null ? 'Pick a departure time' : null,
            onTap: () async {
              final picked = await _pickDeparture(ctx);
              if (picked != null) {
                departure = picked;
                departureCtrl.text = _departureFmt.format(picked);
              }
            },
          ),
        ),
      ],
      onSubmit: () => widget.api.createTrip(route.id, vehicle.id, departure!),
    );
    if (ok == true) {
      _toast('Trip scheduled.');
      await _loadAll();
    }
  }

  Future<DateTime?> _pickDeparture(BuildContext ctx) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
        context: ctx, initialTime: const TimeOfDay(hour: 7, minute: 0));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          VoyaMark(size: 28),
          SizedBox(width: Space.sm + 2),
          Text('Fleet'),
        ]),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text('${widget.me.name} · ${widget.me.role}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.api.logout();
              widget.onLoggedOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _operators.isEmpty && _trips.isEmpty) {
      return ListView(
          padding: const EdgeInsets.all(Space.md),
          children: const [ListSkeleton()]);
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [ErrorState(message: _error!, onRetry: _loadAll)],
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 840;
      final trips = _tripsSection();
      final setup = _setupSection();
      if (!wide) {
        return ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [...trips, const SizedBox(height: Space.lg), ...setup],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ListView(
                padding: const EdgeInsets.all(Space.lg), children: trips),
          ),
          Expanded(
            flex: 2,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(0, Space.lg, Space.lg, Space.lg),
                children: setup),
          ),
        ],
      );
    });
  }

  List<Widget> _tripsSection() => [
        SectionHeader(
          title: 'Trips',
          trailing: TextButton.icon(
            onPressed: _addTrip,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Schedule trip'),
          ),
        ),
        if (_trips.isEmpty)
          EmptyState(
            icon: Icons.directions_bus_outlined,
            message: 'No trips scheduled yet.',
            actionLabel: 'Schedule trip',
            onAction: _addTrip,
          )
        else
          for (final t in _trips)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.md, vertical: Space.xs),
                  title: Text('${t.origin} → ${t.destination}',
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                      '${_departureFmt.format(t.departureAt)} · ${formatFare(t.fare)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ManifestScreen(api: widget.api, trip: t))),
                ),
              ),
            ),
      ];

  List<Widget> _setupSection() {
    final op = _selectedOperator;
    return [
      SectionHeader(
        title: 'Operators',
        trailing: TextButton.icon(
          onPressed: _addOperator,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ),
      if (_operators.isEmpty)
        EmptyState(
          icon: Icons.business_outlined,
          message: 'Create an operator to get started.',
          actionLabel: 'New operator',
          onAction: _addOperator,
        )
      else
        for (final o in _operators)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: _OperatorTile(
              operator: o,
              selected: o.id == op?.id,
              canVerify: widget.me.isPlatformAdmin && o.status != 'verified',
              onTap: () {
                setState(() => _selectedOperator = o);
                _loadVehicles(o.id).catchError((Object e) {
                  if (mounted) _toast(userMessage(e));
                });
              },
              onVerify: () => _verifyOperator(o),
            ),
          ),
      if (op != null) ...[
        const SizedBox(height: Space.lg),
        SectionHeader(
          title: 'Vehicles · ${op.name}',
          trailing: TextButton.icon(
            onPressed: _addVehicle,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (_vehicles.isEmpty)
          const EmptyState(
              icon: Icons.airport_shuttle_outlined,
              message: 'No vehicles for this operator yet.')
        else
          for (final v in _vehicles)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.airport_shuttle_outlined),
                  title: Text(v.plateNumber),
                  subtitle: Text('${v.seatCount} seats'),
                ),
              ),
            ),
        const SizedBox(height: Space.lg),
        SectionHeader(
          title: 'Routes',
          trailing: TextButton.icon(
            onPressed: _addRoute,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (_routes.isEmpty)
          const EmptyState(
              icon: Icons.alt_route_outlined, message: 'No routes yet.')
        else
          for (final r in _routes)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.alt_route_outlined),
                  title: Text('${r.origin} → ${r.destination}'),
                  subtitle: Text(formatFare(r.baseFare)),
                ),
              ),
            ),
      ],
    ];
  }
}

class _OperatorTile extends StatelessWidget {
  final Operator operator;
  final bool selected;
  final bool canVerify;
  final VoidCallback onTap;
  final VoidCallback onVerify;
  const _OperatorTile({
    required this.operator,
    required this.selected,
    required this.canVerify,
    required this.onTap,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (operator.status) {
      'verified' => (BadgeTone.good, Icons.verified_outlined),
      'suspended' => (BadgeTone.crit, Icons.block),
      _ => (BadgeTone.warn, Icons.schedule),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
              color: selected ? VoyaColors.ochre : VoyaColors.line,
              width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(operator.name,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    StatusBadge(
                        label: operator.status, tone: tone, icon: icon),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(operator.country,
                    style: Theme.of(context).textTheme.bodySmall),
                if (canVerify) ...[
                  const SizedBox(height: Space.sm),
                  OutlinedButton(
                    onPressed: onVerify,
                    child: const Text('Approve KYC'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
