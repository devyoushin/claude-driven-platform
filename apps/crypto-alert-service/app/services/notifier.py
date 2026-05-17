"""Notification sender - SNS, Email, Slack"""

import json
import logging
import os

import boto3

logger = logging.getLogger(__name__)

SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")
AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-2")


async def send_notification(channel: str, target: str, message: dict):
    """알림 발송"""
    try:
        if channel == "sns":
            await _send_sns(target, message)
        elif channel == "email":
            await _send_sns_email(target, message)
        elif channel == "slack":
            await _send_slack(target, message)
        else:
            logger.warning(f"Unknown notification channel: {channel}")
    except Exception as e:
        logger.error(f"Failed to send notification ({channel}): {e}")


async def _send_sns(topic_arn: str, message: dict):
    """SNS Topic으로 발송"""
    sns = boto3.client("sns", region_name=AWS_REGION)
    sns.publish(
        TopicArn=topic_arn or SNS_TOPIC_ARN,
        Subject=f"[Crypto Alert] {message['symbol']} {message['condition']} {message['target_price']}",
        Message=json.dumps(message, indent=2),
        MessageAttributes={
            "severity": {"DataType": "String", "StringValue": "info"},
            "symbol": {"DataType": "String", "StringValue": message["symbol"]},
        },
    )
    logger.info(f"SNS notification sent: {message['symbol']}")


async def _send_sns_email(email: str, message: dict):
    """SNS를 통한 이메일 발송 (기본 Topic 사용)"""
    sns = boto3.client("sns", region_name=AWS_REGION)
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[Crypto Alert] {message['symbol']} reached {message['current_price']}",
        Message=f"""
Crypto Price Alert Triggered!

Symbol: {message['symbol']}
Condition: {message['condition']}
Target Price: {message['target_price']}
Current Price: {message['current_price']}
Triggered At: {message['triggered_at']}

---
Claude-Driven Platform - Crypto Alert Service
        """.strip(),
    )
    logger.info(f"Email notification sent to: {email}")


async def _send_slack(webhook_url: str, message: dict):
    """Slack Webhook으로 발송"""
    import httpx

    payload = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"💰 {message['symbol']} Alert Triggered",
                },
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Condition:*\n{message['condition']}"},
                    {"type": "mrkdwn", "text": f"*Target:*\n${message['target_price']:,.2f}"},
                    {"type": "mrkdwn", "text": f"*Current:*\n${message['current_price']:,.2f}"},
                    {"type": "mrkdwn", "text": f"*Time:*\n{message['triggered_at']}"},
                ],
            },
        ]
    }

    async with httpx.AsyncClient() as client:
        await client.post(webhook_url, json=payload)
    logger.info(f"Slack notification sent: {message['symbol']}")
