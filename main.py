# Standard Library Imports
import datetime
import json
import os
import uuid
from pathlib import Path
import hashlib
import ipaddress
import logging as log
from werkzeug import datastructures

# Third-Party Imports
from firebase_admin import firestore, initialize_app
from flask import abort, Flask, jsonify, make_response, render_template, request
from geoip2.webservice import Client
from google.cloud import bigquery, logging
import jwt
from user_agents import parse

# Local Imports
from consts import *

# Instantiates a client
log_client = logging.Client()

# Retrieves a Cloud Logging handler based on the environment
# you're running in and integrates the handler with the
# Python logging module. By default this captures all logs
# at INFO level and higher
log_client.setup_logging()

initialize_app()

app = Flask(__name__)

# NOTE for app routing
# https://stackoverflow.com/questions/53488766/using-flask-routing-in-gcp-function

# delivers measure.js library
@app.get('/measure.js')
def get_measure():
    app.template_folder = Path(__file__).resolve().parent / 'js'
    return render_template("measure.js")

# consent & cookie handling
# initating tracking (forward_data)
@app.route('/events', methods=["GET", "POST"])
def handle_consent_and_cookies():
    ts_0 = datetime.datetime.now()
    form_data={}
    json_data={}
    if request.method == "POST":
        form_data = request.form.to_dict()
        json_data = request.get_json(silent=True) or {}

    tracking_data = {**form_data, **json_data, **request.args.to_dict()}

    response = make_response(jsonify({"message": "ok"}))
    
    # Handle consent-related logic
    if tracking_data.get('en', '') == 'consent':
        id = tracking_data.get('p', {}).get('id') if isinstance(tracking_data.get('p'), dict) else None
        if id == True and not request.cookies.get(CLIENT_ID_COOKIE_NAME):
            clid = str(uuid.uuid4())
            domain = '.' + '.'.join(request.host.split('.')[-2:]) if not request.host.replace('.', '').isdigit() else request.host
            response.set_cookie(CLIENT_ID_COOKIE_NAME, clid, max_age=60*60*24*365, domain=domain)
            response.set_cookie(HASH_COOKIE_NAME, get_hash(request), max_age=60*60*24*365, domain=domain)
            tracking_data['c'] = clid
        if id == False:
            response.delete_cookie(CLIENT_ID_COOKIE_NAME)
            response.delete_cookie(HASH_COOKIE_NAME)

    ts_1 = datetime.datetime.now()
    # TODO: request.get(f'{CF_URL}/track') w/ timeout 1ms
    tracking(tracking_data, request, response, ts_0, ts_1)

    return response


# app.route('/track')
# NOTE watch out here; request is global, so making another request to CF/track will use the new request object
# hence using "req" here onwards
def tracking(tracking_data, req, response, ts_0, ts_1):
    
    log.info(str(tracking_data))
    hash_value = get_hash(req)
    data = tracking_data or {}

    event_type = data.get("et", "event")
    event_name = data.get("en", None)
    parameters = data.get("p", {})
    user_agent = data.get("ua", None) or req.headers.get("user-agent", None)
    url = data.get("url", None)
    referrer = data.get("r",req.headers.get("Referer", None))
    client_id = data.get("c",req.cookies.get(CLIENT_ID_COOKIE_NAME, None))
    hash_value = data.get("h", hash_value)
    client_host = req.remote_addr or req.headers.get('X-Forwarded-For')
    user_id = data.get("u", None) # will come from the proxy
    ab_test = data.get("ab", []) or []

    try:
        if ipaddress.ip_address(client_host).version == 4:
            # Anonymize IPv4 address
            tmp = client_host.split(".")
            tmp[-1] = '0'
            client_host = ".".join(tmp)
        else:
            # Anonymize IPv6 address
            ip_segments=(str(ipaddress.ip_address(client_host)).split(':'))[:4]
            client_host = ':'.join(ip_segments) + '::'
    except Exception as e:
        log.error(f"failed IP detection {client_host}")

    geo_info = get_geoip_data(client_host)

    ua_info = parse(user_agent)
    device={}
    device["type"] = "mobile" if ua_info.is_mobile else ("tablet" if ua_info.is_tablet else "desktop")
    device["family"] = data.get("df", ua_info.device.family)
    device["brand"] = data.get("db", ua_info.device.brand)
    device["model"] = data.get("dm", ua_info.device.model)
    device["browser"] = data.get("bf", ua_info.browser.family)
    device["browser_version"] = data.get("bv", ua_info.browser.version_string)
    device["os"] = data.get("os", ua_info.os.family)
    device["os_version"] = data.get("ov", ua_info.os.version_string)
    device["is_bot"] = ua_info.is_bot

    location={}
    location["ip_trunc"] = client_host
    if geo_info:
        location["continent"] = geo_info.get('continent',None)
        location["country"] = geo_info.get('country',None)
        location["country_code"] = geo_info.get('country_code',None)
        location["city"] = geo_info.get('city',None)


    # Create the data dictionary with long form column names
    data = {
        "timestamp": ts_0.isoformat(),
        "event_type": event_type,
        "event_name": event_name,
        "parameters": json.dumps(parameters),
        "user_agent": user_agent,
        "url": url,
        "referrer": referrer,
        "client_id": client_id,
        "hash": hash_value,
        "user_id": user_id,
        "device": device,
        "ab_test": ab_test,
        "location": location,
    }

    load_to_bq(data)


def get_geoip_data(ip_address):
    db = firestore.client()
    # Reference to the geoip collection
    geoip_collection = db.collection('geoip')

    # Try to retrieve the record from Firestore
    doc = geoip_collection.document(ip_address).get()
    if doc.exists:
        log.info("IP data found in Firestore")
        return doc.to_dict()
    else:
        log.info("IP data not found, querying geoip2...")
        # Use your geoip2 account credentials
        client = Client(account_id=os.getenv('GEOIP_ACCOUNT_ID'), license_key=os.getenv('GEOIP_API_KEY'), host='geolite.info')

        try:
            # Get data from geoip2
            response = client.city(ip_address)
            data = {
                'ip_mask': ip_address,
                'continent': response.continent.name,
                'country': response.country.name,
                'country_code': response.country.iso_code,
                'city': response.city.name,
                'updated_at': datetime.datetime.now()
            }

            # Store the data in Firestore
            geoip_collection.document(ip_address).set(data)
            return data
        except Exception as e:
            log.error(f"Error retrieving data: {e}")
            return None
        

def get_hash(req):
    hash_str = (
        str(req.remote_addr)
        + str(req.headers.get("user-agent"))
        + DAILY_SALT
    )
    hash_value = hashlib.sha256(hash_str.encode()).hexdigest()
    return hash_value


def flatten(d, parent_key='', sep='_'):
    items = {}
    for k, v in d.items():
        new_key = parent_key + sep + k if parent_key else k
        if isinstance(v, dict):
            items.update(flatten(v, new_key, sep=sep))
        else:
            items[new_key] = v
    return items


def load_to_bq(data):
    # Insert data into BigQuery
    client = bigquery.Client()
    table_ref = client.dataset(DATASET_ID).table(TABLE_ID)
    errors = client.insert_rows_json(table_ref, [data])

    if errors:
        raise Exception(f"Error inserting rows into BigQuery: {errors}")
    else:
        return "Data inserted successfully into BigQuery"


def main(request):
    with app.app_context():
        headers = datastructures.Headers()
        for key, value in request.headers.items():
            headers.add(key, value)
        with app.test_request_context(
            method=request.method, 
            base_url=request.base_url, 
            path=request.path, 
            query_string=request.query_string, 
            headers=headers, 
            data=request.data
        ):
            try:
                rv = app.preprocess_request()
                if rv is None:
                    rv = app.dispatch_request()
            except Exception as e:
                rv = app.handle_user_exception(e)
            response = app.make_response(rv)
            origin = request.headers.get('Origin') 
            response = app.process_response(response)

            response.headers.add('Access-Control-Allow-Origin', origin)
            response.headers.add('Access-Control-Allow-Credentials', 'true')
            response.headers.add('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
            response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
            
            return response