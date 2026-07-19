exports.handler = async (event) => {
    console.log("Incoming event:", JSON.stringify(event));
    const claims = event.requestContext?.authorizer?.claims || {};
    const groups = claims["cognito:groups"] || [];

    const path = event.resource;

    if (!groups.includes("admin")) {
        console.log("Access denied: User is not in the 'admins' group.");
        return {
            statusCode: 403,
            body: JSON.stringify({ error: "Access denied" })
        };
    }    
    const headers = event.headers || {};
    const token_header = headers['x-token-id']

    if (token_header !== undefined) {
        console.log(`Called endpoint with token header ${token_header}`)
    }

    const name = event.queryStringParameters?.name || "Unknown";

    const response = {
        message: `HELLO ${name.toUpperCase()} FROM NODE!`,
    };

    console.log("Response:", JSON.stringify(response));

    return {
        statusCode: 200,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(response),
    };
}