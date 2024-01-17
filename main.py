import asyncio
import aiohttp
from google.cloud import bigquery
from werkzeug.wrappers import Request
from werkzeug.test import create_environ
import requests
from fastapi.templating import Jinja2Templates
import json
import ipaddress
from user_agents import parse
from pathlib import Path
from dotenv import load_dotenv
import os
from tracking import track_requests
from flask import Flask

# Load environment variables from .env file (only for local testing, otherwise take env variables directly)
load_dotenv()

app = Flask(__name__)

import hashlib
import datetime
from firebase_admin import firestore, initialize_app
from geoip2.webservice import Client
from consts import DATASET_ID, TABLE_ID, DAILY_SALT, CLIENT_ID_COOKIE_NAME

initialize_app()

jstemplates = Jinja2Templates(directory = Path(__file__).resolve().parent/'js')


CF_URL = 'cloud_function_url'

# delivers measure.js library
@app.get("/measure.js")
async def get_measure(request: Request):
        return jstemplates.TemplateResponse("measure.js", {"request": request, "endpoint": request.url_for('track')})

# consent & cookie handling
# and data forwarding to middleware 
# TODO this needds to be a separate function here instead of middleware (core/tracking.py)
@app.route("/events", methods=["GET", "POST"])
async def track(
    request:Request, 
    ):
    form_data={}
    json_data={}
    if request.method == "POST":
        form_data = await request.form()
        try:
            json_data = await request.json()
        except:
            pass
    request.state.tracking_data = {**form_data, **json_data, **request.query_params}
    response = JSONResponse(content={"message": "ok"})
    if request.state.tracking_data.get('en','') == 'consent':
        id = request.state.tracking_data.get('p', {}).get('id') if isinstance(request.state.tracking_data.get('p'), dict) else None
        if id == True and request.cookies.get(CLIENT_ID_COOKIE_NAME, None) is None:
            clid=str(uuid.uuid4())
            response.set_cookie(CLIENT_ID_COOKIE_NAME,clid,max_age=60*60*24*365 ,domain='.'+'.'.join(request.url.hostname.split('.')[-2:]) if not request.url.hostname.replace('.', '').isdigit() else request.url.hostname)
            response.set_cookie(HASH_COOKIE_NAME,get_hash(request),max_age=60*60*24*365 ,domain='.'+'.'.join(request.url.hostname.split('.')[-2:]) if not request.url.hostname.replace('.', '').isdigit() else request.url.hostname)
            request.state.tracking_data['c']=clid
        if id == False:
             response.delete_cookie(CLIENT_ID_COOKIE_NAME)
             response.delete_cookie(HASH_COOKIE_NAME)
    return response

@app.get('/')
async def main():
    track_requests()

    async with aiohttp.ClientSession() as session:
    # Send POST request without immediately waiting for the response
    response_task = asyncio.create_task(
        session.post(f'{CF_URL}/track', data={'key': 'value'})
    )

@app.get("/track")
async def track(request):
    # Get request data as a dictionary based on the request method
    data = {}
    if request.method == "GET":
        data = request.args.to_dict()
    elif request.method == "POST":
        data = request.form.to_dict()
        if not data:
            data = request.get_json()
    else:
        return "Invalid request method"
    
    async with aiohttp.ClientSession() as session:
        # Send POST request without immediately waiting for the response
        response_task = asyncio.create_task(
            session.post('http://httpbin.org/post', data={'key': 'value'})
        )

        # Print some text right after sending the request
        print("Request sent, not waiting for the response...")

        # Now wait for the response and print it
        response = await response_task
        data = await response.text()
        print("Response received:")
        print(data)

    # Extract abbreviated parameter values
    client_id = data.get("c", request.cookies.get(CLIENT_ID_COOKIE_NAME, None))
    # TODO 
    # call_cf('/geo_bq', data)
    requests.post('CF_URL/process', data)

@app.get("/process")
async def route2():
    return {"message": "This is Route 2"}

def flatten(d, parent_key='', sep='_'):
    items = {}
    for k, v in d.items():
        new_key = parent_key + sep + k if parent_key else k
        if isinstance(v, dict):
            items.update(flatten(v, new_key, sep=sep))
        else:
            items[new_key] = v
    return items


def get_geoip_data(ip_address):
    db = firestore.client()
    # Reference to the geoip collection
    geoip_collection = db.collection('geoip')

    # Try to retrieve the record from Firestore
    doc = geoip_collection.document(ip_address).get()
    if doc.exists:
        print("IP data found in Firestore")
        return doc.to_dict()
    else:
        print("IP data not found, querying geoip2...")
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
            print(f"Error retrieving data: {e}")
            return None
        

def track_old(request):
    # Get request data as a dictionary based on the request method
    data = {}
    if request.method == "GET":
        data = request.args.to_dict()
    elif request.method == "POST":
        data = request.form.to_dict()
        if not data:
            data = request.get_json()
    else:
        return "Invalid request method"
    
    # Extract abbreviated parameter values
    client_id = data.get("c", request.cookies.get(CLIENT_ID_COOKIE_NAME, None))
    # TODO 
    # call_cf('/geo_bq', data)
    # rest of code shouldn't be part of this function as per concept above
    timestamp = data.get("ts", datetime.datetime.now().isoformat())
    event_type = data.get("et", "event")
    event_name = data.get("en", None)
    parameters = data.get("p", {})
    user_agent = data.get("ua", None) or request.headers.get("user-agent", None)
    url = data.get("url", None)
    referrer = data.get("r", request.headers.get("Referer", None))
    
    ab_test = data.get("ab", []) or []
    hash_value = data.get("h", None)
    user_id = data.get("u", None)
    client_host = data.get("ch", request.headers.get('X-Forwarded-For'))

    if not hash_value:
        hash_str = (
            client_host
            + str(request.headers.get("user-agent"))
            + DAILY_SALT
        )
        hash_value = hashlib.sha256(hash_str.encode()).hexdigest()

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
        print(f"failed IP detection {client_host}")

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
    print(type(geo_info))
    if geo_info:
        location["continent"] = geo_info.get('continent',None)
        location["country"] = geo_info.get('country',None)
        location["country_code"] = geo_info.get('country_code',None)
        location["city"] = geo_info.get('city',None)


    # Create the data dictionary with long form column names
    data = {
        "timestamp": timestamp,
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


def load_to_bq(data):
    # Insert data into BigQuery
    client = bigquery.Client()
    table_ref = client.dataset(DATASET_ID).table(TABLE_ID)
    errors = client.insert_rows_json(table_ref, [data])

    if errors:
        raise Exception(f"Error inserting rows into BigQuery: {errors}")
    else:
        return "Data inserted successfully into BigQuery"


# Check if the script is executed directly
if __name__ == '__main__':
    # For local testing, call the export_firestore_to_bigquery function directly
    # Create a WSGI environment for a GET request to '/path'
    environ = create_environ(path='/path', method='GET',query_string={'ch': '127.0.0.1'},headers=[('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Fake-Request')])
    track(Request(environ))
