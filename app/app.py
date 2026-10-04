import boto3
import requests
from flask import Flask, render_template_string

app = Flask(__name__)

MERCHANT_ID = "WVG7DPHJ6P9F1"

def get_api_token():
    client = boto3.client("secretsmanager", region_name="eu-west-1")
    response = client.get_secret_value(SecretId="clover/api-token")
    return response["SecretString"]

def get_employees():
    api_token = get_api_token()
    url = f"https://apisandbox.dev.clover.com/v3/merchants/{MERCHANT_ID}/employees"
    headers = {
        "accept": "application/json",
        "authorization": f"Bearer {api_token}"
    }
    response = requests.get(url, headers=headers)
    data = response.json()
    return data.get("elements", [])

@app.route("/")
def dashboard():
    employees = get_employees()
    return render_template_string("""
        <h1>Clover Dashboard</h1>
        <h2>Employees</h2>
        <ul>
        {% for emp in employees %}
            <li>{{ emp['name'] }} — {{ emp['role'] }}</li>
        {% endfor %}
        </ul>
    """, employees=employees)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
