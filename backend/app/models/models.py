import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.db import Base


def gen_id() -> str:
    return uuid.uuid4().hex


class OperatorStatus(str, enum.Enum):
    pending = "pending"
    verified = "verified"
    suspended = "suspended"


class Operator(Base):
    __tablename__ = "operators"

    id = Column(String, primary_key=True, default=gen_id)
    name = Column(String, nullable=False)
    country = Column(String, nullable=False)
    business_registration_no = Column(String, nullable=True)
    settlement_account = Column(String, nullable=True)
    status = Column(Enum(OperatorStatus), default=OperatorStatus.pending, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    vehicles = relationship("Vehicle", back_populates="operator")
    routes = relationship("Route", back_populates="operator")
    staff = relationship("StaffUser", back_populates="operator")


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(String, primary_key=True, default=gen_id)
    operator_id = Column(String, ForeignKey("operators.id"), nullable=False)
    plate_number = Column(String, nullable=False)
    seat_count = Column(Integer, nullable=False)
    vehicle_type = Column(String, default="coach")
    roadworthy_doc_ref = Column(String, nullable=True)

    operator = relationship("Operator", back_populates="vehicles")


class Route(Base):
    __tablename__ = "routes"

    id = Column(String, primary_key=True, default=gen_id)
    operator_id = Column(String, ForeignKey("operators.id"), nullable=False)
    origin = Column(String, nullable=False)
    destination = Column(String, nullable=False)
    base_fare = Column(Numeric(10, 2), nullable=False)
    is_active = Column(Boolean, default=True)

    operator = relationship("Operator", back_populates="routes")
    trips = relationship("Trip", back_populates="route")


class TripStatus(str, enum.Enum):
    scheduled = "scheduled"
    boarding = "boarding"
    departed = "departed"
    cancelled = "cancelled"


class Trip(Base):
    __tablename__ = "trips"

    id = Column(String, primary_key=True, default=gen_id)
    route_id = Column(String, ForeignKey("routes.id"), nullable=False)
    vehicle_id = Column(String, ForeignKey("vehicles.id"), nullable=False)
    departure_at = Column(DateTime, nullable=False)
    fare = Column(Numeric(10, 2), nullable=False)
    status = Column(Enum(TripStatus), default=TripStatus.scheduled, nullable=False)

    route = relationship("Route", back_populates="trips")
    vehicle = relationship("Vehicle")
    seats = relationship("Seat", back_populates="trip")


class SeatStatus(str, enum.Enum):
    available = "available"
    held = "held"
    booked = "booked"


class Seat(Base):
    __tablename__ = "seats"
    __table_args__ = (UniqueConstraint("trip_id", "seat_number", name="uq_trip_seat"),)

    id = Column(String, primary_key=True, default=gen_id)
    trip_id = Column(String, ForeignKey("trips.id"), nullable=False)
    seat_number = Column(Integer, nullable=False)
    status = Column(Enum(SeatStatus), default=SeatStatus.available, nullable=False)
    hold_id = Column(String, ForeignKey("seat_holds.id"), nullable=True)

    trip = relationship("Trip", back_populates="seats")


class SeatHold(Base):
    __tablename__ = "seat_holds"

    id = Column(String, primary_key=True, default=gen_id)
    trip_id = Column(String, ForeignKey("trips.id"), nullable=False)
    seat_id = Column(String, ForeignKey("seats.id"), nullable=False)
    rider_phone = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    released = Column(Boolean, default=False)


class PaymentMethod(str, enum.Enum):
    mobile_money = "mobile_money"
    cash_on_boarding = "cash_on_boarding"
    card = "card"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    failed = "failed"
    refunded = "refunded"


class BookingStatus(str, enum.Enum):
    pending_payment = "pending_payment"
    confirmed = "confirmed"
    cancelled = "cancelled"
    boarded = "boarded"


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(String, primary_key=True, default=gen_id)
    trip_id = Column(String, ForeignKey("trips.id"), nullable=False)
    seat_id = Column(String, ForeignKey("seats.id"), nullable=False)
    rider_name = Column(String, nullable=False)
    rider_phone = Column(String, nullable=False)
    payer_phone = Column(String, nullable=True)
    booking_source = Column(String, default="app")  # app | fleet | agent | ussd
    agent_id = Column(String, ForeignKey("staff_users.id"), nullable=True)
    status = Column(Enum(BookingStatus), default=BookingStatus.pending_payment, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    payment = relationship("Payment", back_populates="booking", uselist=False)
    ticket = relationship("Ticket", back_populates="booking", uselist=False)
    trip = relationship("Trip")
    seat = relationship("Seat")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(String, primary_key=True, default=gen_id)
    booking_id = Column(String, ForeignKey("bookings.id"), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    method = Column(Enum(PaymentMethod), nullable=False)
    status = Column(Enum(PaymentStatus), default=PaymentStatus.pending, nullable=False)
    psp_reference = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    booking = relationship("Booking", back_populates="payment")


class Ticket(Base):
    __tablename__ = "tickets"

    id = Column(String, primary_key=True, default=gen_id)
    booking_id = Column(String, ForeignKey("bookings.id"), nullable=False)
    code = Column(String, nullable=False, unique=True)  # 6-digit fallback
    signed_token = Column(String, nullable=False)  # signed QR payload
    issued_at = Column(DateTime, default=datetime.utcnow)
    verified_at = Column(DateTime, nullable=True)

    booking = relationship("Booking", back_populates="ticket")


class StaffRole(str, enum.Enum):
    dispatcher = "dispatcher"
    finance = "finance"
    agent = "agent"
    admin = "admin"


class StaffUser(Base):
    __tablename__ = "staff_users"
    __table_args__ = (UniqueConstraint("phone", name="uq_staff_phone"),)

    id = Column(String, primary_key=True, default=gen_id)
    operator_id = Column(String, ForeignKey("operators.id"), nullable=True)
    name = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    role = Column(Enum(StaffRole), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    operator = relationship("Operator", back_populates="staff")


class UssdSession(Base):
    """Server-side state for a USSD session, keyed by the telco session id.

    USSD is stateless on the wire — each keypress is a fresh HTTP request
    identified only by session_id and the text typed so far — so screen
    state (selected route, trip, seat) has to live here between requests.
    """

    __tablename__ = "ussd_sessions"

    id = Column(String, primary_key=True)  # telco-provided session id
    phone = Column(String, nullable=False)
    screen = Column(String, default="root")
    data = Column(String, default="{}")  # JSON blob of screen state
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)


class AgentLedgerEntry(Base):
    """One row per cash ticket an agent sells, for commission + reconciliation."""

    __tablename__ = "agent_ledger_entries"

    id = Column(String, primary_key=True, default=gen_id)
    agent_id = Column(String, ForeignKey("staff_users.id"), nullable=False)
    booking_id = Column(String, ForeignKey("bookings.id"), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    commission = Column(Numeric(10, 2), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
