from google.cloud import bigquery
from werkzeug.wrappers import Request
from fastapi.templating import Jinja2Templates
import json
import ipaddress
from user_agents import parse
from pathlib import Path
from dotenv import load_dotenv
import os
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
# TODO "middleware" needs to be a separate function here instead see below and (core/tracking.py)
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
    # this needs to call the substituted middleware


# TODO middleware to be a proper functions block (from core/tracking.py)
# TODO instead of a request this should work with the response from /events
def get_hash(request):
    hash_str = (
        request.client.host
        + str(request.headers.get("user-agent"))
        + DAILY_SALT
    )
    hash_value = hashlib.sha256(hash_str.encode()).hexdigest()
    return hash_value

async def track_requests(request, call_next):
    timestamp = datetime.datetime.now()
    request.state.tracking_data = None
    response: Response = await call_next(request)
    timestamp2 = datetime.datetime.now()
    # this background task should be triggered after the response was send to browser, hopefully request and repsonse objects are still available
    response.background = BackgroundTask(forward_data, request, response, timestamp, timestamp2) 
    return response

# this forwards data to the tracking cloud function
async def forward_data(request, response, timestamp, timestamp2):
    try:
        user = get_current_user(request)
        user_id = get_user_id(user)
    except:
        user_id = None

    event_name = type(response).__name__.replace("Response", "") if response else "Unknown"
    if "content-type" in response.headers:
        event_name = response.headers.get("content-type", "").split(";")[0]
    else:
        event_name = type(response).__name__ if response else "Unknown"

    hash_value = get_hash(request)
    is_event = True if request.state.tracking_data and request.state.tracking_data.get('en', None) else False

    data = request.state.tracking_data or {}
    data = {
        "ts": data.get("ts", datetime.datetime.now().isoformat()),
        "et": data.get("et", "event" if is_event else "request"),
        "en": data.get("en", None if is_event else event_name ),
        "p": {**data.get("p", {}), **({} if is_event else {
            "request_duration_ms": (timestamp2-timestamp).total_seconds() * 1000,
            "method": request.method,
            "status_code": response.status_code,
           })},
        "ua": data.get("ua", None) or request.headers.get("user-agent", None),
        "url": data.get("url", None if is_event else str(request.url)),
        "r": data.get("r",request.headers.get("Referer", None)),
        "c": data.get("c",request.cookies.get(CLIENT_ID_COOKIE_NAME, None)),
        "h": data.get("h", hash_value),
        "u": data.get("u", user_id),
        "ch": request.client.host,
        "ab": data.get("ab", None)
    }
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{config.TRACKING_ENDPOINT}", json=data)
            if response.status_code != 200:
                logger.error(f"Error sending tracking data. Status code: {response.status_code}, Response: {response.text}")

            return response
    except Exception as e:
        logger.exception("Failed sending to tracker: ("+str(e)+") ", exc_info=e)

        return
    """
    table_id = f"{DATASET_ID}.{TABLE_ID}"
    client.insert_rows_json(table_id, [insert_data])
    job_config = bigquery.LoadJobConfig()
    job_config.source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON
        # Start load job
    return
    load_job = client.load_table_from_json(
        [insert_data], table_id, job_config=job_config
    )
    print("Starting job {}".format(load_job.job_id))

    # Waits for the job to complete.
    load_job.result()  
    """


# TODO old cloud function part
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

# this is the tracking function from the cloud function
def track(request):
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
    timestamp = data.get("ts", datetime.datetime.now().isoformat())
    event_type = data.get("et", "event")
    event_name = data.get("en", None)
    parameters = data.get("p", {})
    user_agent = data.get("ua", None) or request.headers.get("user-agent", None)
    url = data.get("url", None)
    referrer = data.get("r", request.headers.get("Referer", None))
    client_id = data.get("c", request.cookies.get(CLIENT_ID_COOKIE_NAME, None))
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

    # Insert data into BigQuery
    client = bigquery.Client()
    table_ref = client.dataset(DATASET_ID).table(TABLE_ID)
    errors = client.insert_rows_json(table_ref, [data])

    if errors:
        raise Exception(f"Error inserting rows into BigQuery: {errors}")
    else:
        return "Data inserted successfully into BigQuery"

## TODO not sure if this is needed
# # Check if the script is executed directly
# if __name__ == '__main__':
#     # For local testing, call the export_firestore_to_bigquery function directly
#     # Create a WSGI environment for a GET request to '/path'
#     environ = create_environ(path='/path', method='GET',query_string={'ch': '102.129.204.182'},headers=[('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Fake-Request')])
#     track(Request(environ))