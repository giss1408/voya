from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict


class OperatorCreate(BaseModel):
    name: str
    country: str
    business_registration_no: Optional[str] = None
    settlement_account: Optional[str] = None


class OperatorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    country: str
    status: str


class VehicleCreate(BaseModel):
    operator_id: str
    plate_number: str
    seat_count: int
    vehicle_type: str = "coach"


class VehicleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    plate_number: str
    seat_count: int
    vehicle_type: str


class RouteCreate(BaseModel):
    operator_id: str
    origin: str
    destination: str
    base_fare: Decimal


class RouteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    origin: str
    destination: str
    base_fare: Decimal
    is_active: bool


class TripCreate(BaseModel):
    route_id: str
    vehicle_id: str
    departure_at: datetime
    fare: Optional[Decimal] = None


class SeatOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    seat_number: int
    status: str


class TripOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    route_id: str
    vehicle_id: str
    departure_at: datetime
    fare: Decimal
    status: str


class TripDetailOut(TripOut):
    seats: list[SeatOut] = []
    origin: str
    destination: str


class SeatHoldRequest(BaseModel):
    trip_id: str
    seat_number: int
    rider_phone: str


class SeatHoldOut(BaseModel):
    hold_id: str
    seat_id: str
    expires_at: datetime


class BookingCreate(BaseModel):
    hold_id: str
    rider_name: str
    rider_phone: str
    payer_phone: Optional[str] = None
    payment_method: str  # mobile_money | cash_on_boarding | card
    booking_source: str = "app"


class PaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    amount: Decimal
    method: str
    status: str
    psp_reference: Optional[str] = None


class TicketOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    code: str
    signed_token: str
    issued_at: datetime
    verified_at: Optional[datetime] = None


class BookingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    trip_id: str
    seat_id: str
    rider_name: str
    rider_phone: str
    status: str
    created_at: datetime


class BookingDetailOut(BookingOut):
    payment: Optional[PaymentOut] = None
    ticket: Optional[TicketOut] = None


class PaymentConfirm(BaseModel):
    psp_reference: str


class TicketVerifyRequest(BaseModel):
    signed_token: Optional[str] = None
    code: Optional[str] = None


class TicketVerifyResult(BaseModel):
    valid: bool
    reason: Optional[str] = None
    rider_name: Optional[str] = None
    seat_number: Optional[int] = None
    trip_id: Optional[str] = None


class StaffCreate(BaseModel):
    operator_id: Optional[str] = None
    name: str
    phone: str
    password: str
    role: str  # dispatcher | finance | agent | admin


class StaffOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    operator_id: Optional[str] = None
    name: str
    phone: str
    role: str


class LoginRequest(BaseModel):
    phone: str
    password: str


class OperatorStatusUpdate(BaseModel):
    status: str  # pending | verified | suspended


class AgentBookingCreate(BaseModel):
    hold_id: str
    rider_name: str
    rider_phone: str
    payment_method: str = "cash_on_boarding"


class UssdRequest(BaseModel):
    session_id: str
    phone: str
    text: str = ""  # full keypress history the telco gateway sends, "" on first dial


class UssdResponse(BaseModel):
    message: str
    continue_session: bool
