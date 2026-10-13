from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
from datetime import datetime, timedelta

app = Flask(__name__)
CORS(app)

# ✅ Status check
@app.route('/status')
def status():
    return "API running"

# ✅ Updated Crop Recommendation Logic (based on state)
def recommend_crops(land_size, budget, duration, state):
    state = state.lower()
    suggestions = []

    if state in ['punjab', 'haryana', 'uttar pradesh']:
        suggestions += ['Wheat', 'Rice']
    elif state in ['maharashtra', 'karnataka', 'andhra pradesh']:
        suggestions += ['Sugarcane', 'Cotton']
    elif state in ['kerala', 'tamil nadu']:
        suggestions += ['Banana', 'Coconut']
    else:
        suggestions += ['Tomato', 'Onion', 'Potato']

    if int(land_size) < 1:
        suggestions = ['Spinach', 'Lettuce']
    elif int(budget) < 5000:
        suggestions += ['Cabbage', 'Okra']

    return list(set(suggestions))

# ✅ Crop Suggestion Route (Updated)
@app.route('/suggest_crop', methods=['POST'])
def suggest_crop():
    data = request.json or {}
    land_size = data.get('land_size')
    budget    = data.get('budget')
    duration  = data.get('duration')
    state     = data.get('state')

    if not all([land_size, budget, duration, state]):
        return jsonify({'error': 'Missing one or more required fields.'}), 400

    crops = recommend_crops(land_size, budget, duration, state)
    return jsonify({'suggested_crops': crops})

# ✅ Agmarknet API Configs
AGMARKNET_API_KEY  = "579b464db66ec23bdd0000014bab96786f8f4f6e5547fb09be3502b8"
AGMARKNET_BASE_URL = "https://api.data.gov.in/resource/f9efb06e-d50b-4c52-9760-e4c2b3d18b08"

# ✅ Market Price Route
@app.route('/market_price', methods=['POST'])
def get_market_price():
    data      = request.json or {}
    commodity = data.get('commodity')
    state     = data.get('state')

    if not all([commodity, state]):
        return jsonify({"error": "Missing required fields: commodity and state"}), 400

    params = {
        "api-key": AGMARKNET_API_KEY,
        "format":  "json",
        "filters[commodity]": commodity,
        "filters[state]":     state,
        "limit":              10
    }

    try:
        resp    = requests.get(AGMARKNET_BASE_URL, params=params, timeout=10)
        resp.raise_for_status()
        records = resp.json().get("records", [])
        return jsonify({"prices": records})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ Get Available Commodities (last 10 days)
@app.route('/available_commodities', methods=['POST'])
def available_commodities():
    data  = request.json or {}
    state = data.get('state')

    if not state:
        return jsonify({'error': 'State is required.'}), 400

    base_url      = "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070"
    last_10_dates = [
        (datetime.today() - timedelta(days=i)).strftime("%d/%m/%Y")
        for i in range(10)
    ]

    found = set()
    limit  = 100
    offset = 0
    max_offset = 1000

    try:
        while offset < max_offset:
            params = {
                "api-key": AGMARKNET_API_KEY,
                "format":  "json",
                "limit":   limit,
                "offset":  offset
            }
            resp = requests.get(base_url, params=params, timeout=10)
            if resp.status_code != 200:
                break

            recs = resp.json().get("records", [])
            if not recs:
                break

            for r in recs:
                if (
                    r.get("state", "").lower() == state.lower()
                    and r.get("arrival_date") in last_10_dates
                ):
                    found.add(r.get("commodity", "").title())

            offset += limit

        return jsonify({"commodities": sorted(found)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ Market Price by State + Commodity (last 10 days)
@app.route('/market_price_by_commodity', methods=['POST'])
def market_price_by_commodity():
    data      = request.json or {}
    state     = data.get('state')
    commodity = data.get('commodity')

    if not all([state, commodity]):
        return jsonify({'error': 'State and commodity are required.'}), 400

    base_url      = "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070"
    last_10_dates = [
        (datetime.today() - timedelta(days=i)).strftime("%d/%m/%Y")
        for i in range(10)
    ]

    limit   = 100
    offset  = 0
    max_rec = 1000
    out     = []

    try:
        while offset < max_rec:
            params = {
                "api-key": AGMARKNET_API_KEY,
                "format":  "json",
                "limit":   limit,
                "offset":  offset
            }
            resp = requests.get(base_url, params=params, timeout=10)
            if resp.status_code != 200:
                break

            recs = resp.json().get("records", [])
            if not recs:
                break

            for r in recs:
                if (
                    r.get("state", "").lower()     == state.lower()
                    and r.get("commodity", "").lower() == commodity.lower()
                    and r.get("arrival_date") in last_10_dates
                ):
                    out.append({
                        "date":        r.get("arrival_date"),
                        "market":      r.get("market"),
                        "modal_price": r.get("modal_price")
                    })

            offset += limit

        # sort descending by date
        sorted_out = sorted(
            out,
            key=lambda x: datetime.strptime(x["date"], "%d/%m/%Y"),
            reverse=True
        )
        return jsonify({"records": sorted_out})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ✅ Run Server
if __name__ == '__main__':
    # listen on port 8080 for Render / Cloud Run
    app.run(host='0.0.0.0', port=8080)
