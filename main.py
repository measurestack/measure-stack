from consts import DATASET_ID, TABLE_ID, DAILY_SALT, CLIENT_ID_COOKIE_NAME
import datetime
from fastapi.templating import Jinja2Templates
from firebase_admin import firestore, initialize_app
from flask import Flask
from geoip2.webservice import Client
from google.cloud import bigquery
import hashlib
import ipaddress
import json
import os
from pathlib import Path
from user_agents import parse
from werkzeug.wrappers import Request

initialize_app()

jstemplates = Jinja2Templates(directory = Path(__file__).resolve().parent/'js')
CF_URL = 'cloud_function_url'

app = Flask(__name__)

# NOTE for app routing
# https://stackoverflow.com/questions/53488766/using-flask-routing-in-gcp-function

# delivers measure.js library
@app.get('/measure.js')
def get_measure(request: Request):
        return jstemplates.TemplateResponse("measure.js", {"request": request, "endpoint": request.url_for('track')})

# consent & cookie handling
# initating tracking (forward_data)
@app.route('/events', methods=["GET", "POST"])
def track(
    request:Request, 
    ):
    ts_0 = datetime.datetime.now()
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

    ts_1 = datetime.datetime.now()
    # this processes the tracking
    # TODO
    # request.get('') mit timeout 1ms
    process_tracking(request, response, ts_0, ts_1)

    return response


# this forwards data to the tracking cloud function
app.route('/track')
def process_tracking(request, response, ts_0, ts_1):
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

    
    is_event = True if request.state.tracking_data and request.state.tracking_data.get('en', None) else False
    hash_value = get_hash(request)
    data = request.state.tracking_data or {}

    event_type = data.get("et", "event" if is_event else "request")
    event_name = data.get("en", None if is_event else event_name)
    parameters = {
        **data.get("p", {}),
        **({} if is_event else {
            "request_duration_ms": (ts_1-ts_0).total_seconds() * 1000,
            "method": request.method,
            "status_code": response.status_code
        })
    }
    user_agent = data.get("ua", None) or request.headers.get("user-agent", None)
    url = data.get("url", None if is_event else str(request.url))
    referrer = data.get("r",request.headers.get("Referer", None))
    client_id = data.get("c",request.cookies.get(CLIENT_ID_COOKIE_NAME, None))
    hash_value = data.get("h", hash_value)
    client_host = request.client.host or request.headers.get('X-Forwarded-For')
    user_id = data.get("u", user_id)
    ab_test = data.get("ab", None)

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
        "timestamp": datetime.datetime.now(),
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
        

def get_hash(request):
    hash_str = (
        request.client.host
        + str(request.headers.get("user-agent"))
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
    
# from core.auth    
def get_current_user(request: Request):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    access_token_from_cookie = request.cookies.get(
        config.ACCESS_TOKEN_COOKIE_NAME
    )

    authorization_header = request.headers.get("Authorization")
    access_token_from_header = (
        authorization_header.replace("Bearer ", "")
        if authorization_header
        else None
    )

    if access_token_from_cookie:
        access_token = access_token_from_cookie
    elif access_token_from_header:
        access_token = access_token_from_header
    else:
        raise credentials_exception

    try:
        user_info = decode_and_validate_jwt_access_token(
            access_token, config.SECRET_KEY
        ).user_info
        return user_info
    except AccessTokenExpiredError:
        print("Access Token expired.")
        raise credentials_exception
    except AccessTokenInvalidError:
        print("Access Token invalid")
        raise credentials_exception


def get_user_id(user: AccessTokenUserInfo) -> str:
    return user.user_id

## TODO not sure if this is needed
# # Check if the script is executed directly
# if __name__ == '__main__':
#     # For local testing, call the export_firestore_to_bigquery function directly
#     # Create a WSGI environment for a GET request to '/path'
#     environ = create_environ(path='/path', method='GET',query_string={'ch': '102.129.204.182'},headers=[('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Fake-Request')])
#     track(Request(environ))