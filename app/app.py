import requests
from flask import Flask, render_template_string

app = Flask(__name__)

MERCHANT_ID = "WVG7DPHJ6P9F1"
API_TOKEN = "f40d507d-0235-8e9b-cd4c-1fd996d1a190"

def get_employees():
    url = f"https://apisandbox.dev.clover.com/v3/merchants/{MERCHANT_ID}/employees"
    headers = {
        "accept": "application/json",
        "authorization": f"Bearer {API_TOKEN}"
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
    app.run(host="0.0.0.0", port=8080)