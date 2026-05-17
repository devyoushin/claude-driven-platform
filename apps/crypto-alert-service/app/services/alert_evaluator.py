"""Alert Evaluator - 주기적으로 가격을 확인하고 조건 충족 시 알림 발송"""

import asyncio
import logging
import os
from datetime import datetime, timedelta

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.database import async_session
from app.models.alert import Alert, AlertCondition, AlertStatus
from app.services.notifier import send_notification
from app.metrics.custom_metrics import alerts_triggered_total, alert_evaluation_duration

logger = logging.getLogger(__name__)

PRICE_API_URL = os.getenv("PRICE_API_URL", "http://crypto-price-api:8080")
EVAL_INTERVAL = int(os.getenv("EVAL_INTERVAL_SECONDS", "30"))


class AlertEvaluator:
    """백그라운드에서 알림 조건을 주기적으로 평가"""

    async def run(self):
        logger.info(f"Alert evaluator started (interval: {EVAL_INTERVAL}s)")
        while True:
            try:
                await self.evaluate_all()
            except asyncio.CancelledError:
                logger.info("Alert evaluator stopped")
                return
            except Exception as e:
                logger.error(f"Evaluation error: {e}")
            await asyncio.sleep(EVAL_INTERVAL)

    async def evaluate_all(self):
        """모든 활성 알림을 평가"""
        import time
        start = time.time()

        async with async_session() as db:
            result = await db.execute(
                select(Alert).where(Alert.status == AlertStatus.ACTIVE)
            )
            alerts = result.scalars().all()

            if not alerts:
                return

            # 필요한 심볼의 현재 가격 조회
            symbols = set(a.symbol for a in alerts)
            prices = await self._fetch_prices(symbols)

            for alert in alerts:
                current_price = prices.get(alert.symbol)
                if current_price is None:
                    continue

                if self._should_trigger(alert, current_price):
                    await self._trigger_alert(db, alert, current_price)

            await db.commit()

        duration = time.time() - start
        alert_evaluation_duration.observe(duration)

    def _should_trigger(self, alert: Alert, current_price: float) -> bool:
        """알림 조건 충족 여부 확인"""
        # 쿨다운 확인
        if alert.triggered_at:
            cooldown_end = alert.triggered_at + timedelta(minutes=alert.cooldown_minutes)
            if datetime.utcnow() < cooldown_end:
                return False

        if alert.condition == AlertCondition.ABOVE:
            return current_price >= alert.target_price
        elif alert.condition == AlertCondition.BELOW:
            return current_price <= alert.target_price
        elif alert.condition == AlertCondition.CHANGE_UP:
            return current_price >= alert.target_price
        elif alert.condition == AlertCondition.CHANGE_DOWN:
            return current_price <= alert.target_price

        return False

    async def _trigger_alert(self, db: AsyncSession, alert: Alert, current_price: float):
        """알림 발동 처리"""
        logger.info(f"Alert triggered: {alert.symbol} {alert.condition.value} {alert.target_price} (current: {current_price})")

        # 알림 발송
        await send_notification(
            channel=alert.notification_channel,
            target=alert.notification_target,
            message={
                "alert_id": alert.id,
                "symbol": alert.symbol,
                "condition": alert.condition.value,
                "target_price": alert.target_price,
                "current_price": current_price,
                "triggered_at": datetime.utcnow().isoformat(),
            },
        )

        # 상태 업데이트
        new_status = AlertStatus.ACTIVE if alert.repeat else AlertStatus.TRIGGERED
        await db.execute(
            update(Alert)
            .where(Alert.id == alert.id)
            .values(status=new_status, triggered_at=datetime.utcnow())
        )

        alerts_triggered_total.labels(
            symbol=alert.symbol,
            condition=alert.condition.value,
            channel=alert.notification_channel,
        ).inc()

    async def _fetch_prices(self, symbols: set) -> dict:
        """crypto-price-api에서 현재 가격 조회"""
        prices = {}
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(f"{PRICE_API_URL}/api/v1/prices")
                if resp.status_code == 200:
                    for item in resp.json():
                        if item["symbol"] in symbols:
                            prices[item["symbol"]] = item["price"]
        except Exception as e:
            logger.error(f"Failed to fetch prices: {e}")
        return prices
