"""Alert model"""

from datetime import datetime
from enum import Enum

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Enum as SQLEnum
from app.models.database import Base


class AlertCondition(str, Enum):
    ABOVE = "above"       # 가격이 목표가 이상
    BELOW = "below"       # 가격이 목표가 이하
    CHANGE_UP = "change_up"     # 변동률 상승
    CHANGE_DOWN = "change_down"  # 변동률 하락


class AlertStatus(str, Enum):
    ACTIVE = "active"
    TRIGGERED = "triggered"
    DISABLED = "disabled"


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String(20), nullable=False, index=True)
    condition = Column(SQLEnum(AlertCondition), nullable=False)
    target_price = Column(Float, nullable=False)
    notification_channel = Column(String(50), default="email")  # email, slack, sns
    notification_target = Column(String(255), nullable=False)    # email addr or channel
    status = Column(SQLEnum(AlertStatus), default=AlertStatus.ACTIVE)
    triggered_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    repeat = Column(Boolean, default=False)  # 반복 알림 여부
    cooldown_minutes = Column(Integer, default=60)  # 재알림 대기 시간
