import json
from datetime import datetime


def lambda_handler(event, context):
    print("Incoming event:", json.dumps(event))
    params = event.get("queryStringParameters") or {}
    name = params.get("name", "Unknown")
    headers = event.get("headers", {}) or {}
    token_header = headers.get("x-token-id") or None
    claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
    groups = claims.get("cognito:groups", [])
    if "student" not in groups and "admin" not in groups:
        print("Access denied: User is not in the 'student' or 'admin' group.")
        return {
            "statusCode": 403,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Access denied"})
        }
        
    if token_header:
        print(f"Called endpoint with token {token_header}")       
    # name = event.get("queryStringParameters", {}).get("name", "Unknown") # this is unsafe because queryStringParameters ends up being null or None if you don't pass any

    response = {
        "message": f"Hello {name} from Python!",
        "timestamp": datetime.utcnow().isoformat()
    }

    print("Response:", json.dumps(response))

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(response)
    }