import json
import boto3
import uuid
import os

dynamodb = boto3.resource('dynamodb')
ses = boto3.client('ses')
table = dynamodb.Table(os.environ['TABLE_NAME'])
sender = os.environ['SENDER_EMAIL']
recipient = os.environ['RECIPIENT_EMAIL']

def lambda_handler(event, context):
    if event['httpMethod'] == 'OPTIONS':
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "OPTIONS,POST"
            },
            "body": json.dumps("CORS preflight success")
        }

    try:
        body = json.loads(event['body'])

        item = {
            'id': str(uuid.uuid4()),
            'name': body['name'],
            'email': body['email'],
            'message': body['message']
        }

        table.put_item(Item=item)

        ses.send_email(
            Source=sender,
            Destination={'ToAddresses': [recipient]},
            Message={
                'Subject': {'Data': 'New Contact Form Submission'},
                'Body': {'Text': {'Data': json.dumps(item, indent=2)}}
            }
        )

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "OPTIONS,POST"
            },
            "body": json.dumps({"message": "Form submitted successfully"})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "OPTIONS,POST"
            },
            "body": json.dumps({"error": str(e)})
        }