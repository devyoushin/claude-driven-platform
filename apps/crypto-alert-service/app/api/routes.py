"""Alert API routes"""

from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import get_db
from app.models.alert import Alert, AlertCondition, AlertStatus
from app.metrics.custom_metrics import alerts_created_total, active_alerts_gauge

router = APIRouter()


# ─── Schemas ─────────────────────────────────────────────────────────────────

class AlertCreate(BaseModel):
    symbol: str
    condition: AlertCondition
    target_price: float
    notification_channel: str = "email"
    notification_target: str
    repeat: bool = False
    cooldown_minutes: int = 60


class AlertResponse(BaseModel):
    id: int
    symbol: str
    condition: AlertCondition
    target_price: float
    notification_channel: str
    notification_target: str
    status: AlertStatus
    repeat: bool
    cooldown_minutes: int
    triggered_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Endpoints ───────────────────────────────────────────────────────────────

@router.post("/alerts", response_model=AlertResponse, status_code=201)
async def create_alert(alert: AlertCreate, db: AsyncSession = Depends(get_db)):
    """새 알림 생성"""
    new_alert = Alert(
        symbol=alert.symbol.upper(),
        condition=alert.condition,
        target_price=alert.target_price,
        notification_channel=alert.notification_channel,
        notification_target=alert.notification_target,
        repeat=alert.repeat,
        cooldown_minutes=alert.cooldown_minutes,
    )
    db.add(new_alert)
    await db.commit()
    await db.refresh(new_alert)

    alerts_created_total.labels(symbol=new_alert.symbol, condition=new_alert.condition.value).inc()
    active_alerts_gauge.inc()

    return new_alert


@router.get("/alerts", response_model=list[AlertResponse])
async def list_alerts(
    symbol: Optional[str] = None,
    status: Optional[AlertStatus] = None,
    db: AsyncSession = Depends(get_db),
):
    """알림 목록 조회"""
    query = select(Alert).order_by(Alert.created_at.desc())
    if symbol:
        query = query.where(Alert.symbol == symbol.upper())
    if status:
        query = query.where(Alert.status == status)

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/alerts/{alert_id}", response_model=AlertResponse)
async def get_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    """알림 상세 조회"""
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@router.delete("/alerts/{alert_id}", status_code=204)
async def delete_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    """알림 삭제"""
    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    await db.delete(alert)
    await db.commit()

    if alert.status == AlertStatus.ACTIVE:
        active_alerts_gauge.dec()


@router.patch("/alerts/{alert_id}/disable", response_model=AlertResponse)
async def disable_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    """알림 비활성화"""
    await db.execute(
        update(Alert).where(Alert.id == alert_id).values(status=AlertStatus.DISABLED)
    )
    await db.commit()

    result = await db.execute(select(Alert).where(Alert.id == alert_id))
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")

    active_alerts_gauge.dec()
    return alert
