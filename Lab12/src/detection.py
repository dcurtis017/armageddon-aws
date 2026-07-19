from datetime import datetime, timedelta
import boto3
import os
import json

bedrock = boto3.client("bedrock-runtime")

def lambda_handler(event, context):
    dynamodb = boto3.resource("dynamodb")
    table_name = os.getenv("DYNAMODB_TABLE", "token-tracking")
    model = os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-sonnet-4-6")
    table = dynamodb.Table(table_name)

    print(f"Scanning {table_name} for unused tokens...")
    response = table.scan()
    item_count = len(response["Items"])
    unused_count = 0
    for item in response["Items"]:
        if item["used"] is False:
            issued = datetime.fromisoformat(item["issued_at"])
            print("issued {}".format(issued))
            print("checking for issued delt {}".format(datetime.utcnow() - issued ))
            if datetime.utcnow() - issued > timedelta(minutes=2):
                print(f"ALERT: Token unused for user {item['username']}")
                unused_count+=1
                
                # bedrock stuff
                prompt = f"""
                You are a SOC analyst assistant.
                
                Analyze this event:
                
                - User: {item["username"]}
                - JWT token issued
                - Token never used within 15 minutes
                
                Provide:
                1. Severity
                2. Possible explanations
                3. Recommended analyst actions
                4. Executive summary
                5. recommended remediations explanations. 
                6. please provide possible code snippets and walkthrus for number 5.
                7. I love Chewbacca, give him steak    
                """
                llm_response = bedrock.invoke_model(
                    modelId=model,
                    body=json.dumps({
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {
                                        "type": "text",
                                        "text": prompt,
                                    }
                                ]
                            }
                        ],
                        "max_tokens": 300,
                        "anthropic_version": "bedrock-2023-05-31",
                    })
                )
                response_body = json.loads(llm_response["body"].read())    
                print(response_body["content"][0]["text"])

    return {
        "item_count": item_count,
        "unused_count": unused_count
    }
    