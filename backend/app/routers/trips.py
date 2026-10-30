from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import assert_same_operator_or_admin, get_current_staff
from app.models.models import Operator, OperatorStatus, Route, Seat, StaffUser, Trip, Vehicle
from app.schemas.schemas import RouteCreate, RouteOut, TripCreate, TripDetailOut, TripOut

router = APIRouter(tags=["routes-trips"])


@router.post("/routes", response_model=RouteOut)
def create_route(
    payload: RouteCreate,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    assert_same_operator_or_admin(staff, payload.operator_id)
    operator = db.get(Operator, payload.operator_id)
    if operator is None:
        raise HTTPException(404, "operator not found")
    if operator.status != OperatorStatus.verified:
        raise HTTPException(
            403, "operator must pass KYC verification before listing a route"
        )
    route = Route(**payload.model_dump())
    db.add(route)
    db.commit()
    db.refresh(route)
    return route


@router.get("/routes", response_model=list[RouteOut])
def search_routes(
    origin: str | None = None,
    destination: str | None = None,
    db: Session = Depends(get_db),
):
    q = db.query(Route).filter(Route.is_active.is_(True))
    if origin:
        q = q.filter(Route.origin.ilike(f"%{origin}%"))
    if destination:
        q = q.filter(Route.destination.ilike(f"%{destination}%"))
    return q.all()


@router.post("/trips", response_model=TripOut)
def create_trip(
    payload: TripCreate,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    route = db.get(Route, payload.route_id)
    if route is None:
        raise HTTPException(404, "route not found")
    assert_same_operator_or_admin(staff, route.operator_id)
    vehicle = db.get(Vehicle, payload.vehicle_id)
    if vehicle is None:
        raise HTTPException(404, "vehicle not found")

    trip = Trip(
        route_id=route.id,
        vehicle_id=vehicle.id,
        departure_at=payload.departure_at,
        fare=payload.fare or route.base_fare,
    )
    db.add(trip)
    db.flush()

    for seat_number in range(1, vehicle.seat_count + 1):
        db.add(Seat(trip_id=trip.id, seat_number=seat_number))

    db.commit()
    db.refresh(trip)
    return trip


@router.get("/trips", response_model=list[TripDetailOut])
def search_trips(
    origin: str | None = None,
    destination: str | None = None,
    on_date: date | None = Query(None, alias="date"),
    db: Session = Depends(get_db),
):
    q = db.query(Trip).join(Route)
    if origin:
        q = q.filter(Route.origin.ilike(f"%{origin}%"))
    if destination:
        q = q.filter(Route.destination.ilike(f"%{destination}%"))
    if on_date:
        start = datetime.combine(on_date, datetime.min.time())
        end = datetime.combine(on_date, datetime.max.time())
        q = q.filter(Trip.departure_at >= start, Trip.departure_at <= end)

    trips = q.all()
    return [_trip_detail(trip) for trip in trips]


@router.get("/trips/{trip_id}", response_model=TripDetailOut)
def get_trip(trip_id: str, db: Session = Depends(get_db)):
    trip = db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(404, "trip not found")
    return _trip_detail(trip)


def _trip_detail(trip: Trip) -> TripDetailOut:
    return TripDetailOut(
        id=trip.id,
        route_id=trip.route_id,
        vehicle_id=trip.vehicle_id,
        departure_at=trip.departure_at,
        fare=trip.fare,
        status=trip.status,
        origin=trip.route.origin,
        destination=trip.route.destination,
        seats=trip.seats,
    )
