import datetime
from fastapi import FastAPI, Response, HTTPException
from starlette.background import BackgroundTask
from starlette.responses import FileResponse, JSONResponse, RedirectResponse

from app.core.auth import get_current_user, get_user_id
import hashlib
import httpx
from app.core.config import config
from consts import DAILY_SALT, CLIENT_ID_COOKIE_NAME, HASH_COOKIE_NAME
import re
import json
import logging

logger = logging.getLogger(__name__)

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
    response.background = BackgroundTask(forward_data, request, response, timestamp, timestamp2) # this background task should be triggered after the response was send to browser, hopefully request and repsonse objects are still available
    return response

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

# this will return a variant for a test with name test_name. 
# the variants dict will contain an entry for each variant and an int weight. 
# The weights determine the propabilities of the variant. so {"default":3,"variant":1} will return variant in 25% of the cases
# You must provide the same test_name AND variant dict to get consistent results
# this is not random. It will determine the variant based on the user hash which is combined of IP + user_agent + daily salt
# this should still be rather equally distirbuted except for super hashes which belong to a lot of users with the same IP
# including the test name into the hashing will ensure that there is no correlation between variants of different tests
def get_variant(request, test_name, variants):
    # Check if test_name contains only a-z, 0-9, _, and -
    if not re.match("^[a-z0-9_-]+$", test_name):
        raise HTTPException(status_code=400, detail="Invalid test_name format. Use only a-z, 0-9, _, and -")

    hash_value = request.cookies.get(HASH_COOKIE_NAME, "") or get_hash(request)

    # Concatenate the hash with the test_name
    concatenated_string = hash_value + test_name
    
    # Convert the concatenated string into a number using a hashing function
    #hashed_value = int(hashlib.sha256(concatenated_string.encode()).hexdigest(), 16)
    hashed_value = int.from_bytes(hashlib.sha256(concatenated_string.encode()).digest(), 'big')
        
    # Map the hashed value to the range [1, n]
    n = sum(variants.values())
    mapped_value = (hashed_value % n) + 1
    
    # Determine the variant based on the mapped value
    cumulative_weight = 0
    sortd = sorted(variants.items())
    for variant, weight in sortd:
        cumulative_weight += weight
        if mapped_value <= cumulative_weight:
            # log to tracker
            request.state.tracking_data = {**(request.state.tracking_data or {}), "ab": (request.state.tracking_data or {}).get("ab", []) + [{"name": test_name, "variant": variant, "def": json.dumps(dict(sortd), separators=(',', ':'))}]}

            return variant
