const { getHashh } = require('./helpers');
const store = require('./store')
const uuid = require('uuid');
const cookieParser = require('cookie-parser')();
const querystring = require('querystring');
const { getCookie, setCookie, deleteCookie } = require('hono/cookie');
const { getConnInfo } = require('hono/bun');
//const https = require('https');
//const http = require('http');

module.exports = async function handleEvent(context) {
    req = context.req;
    const json = await req.json().catch(() => ({}));
    const form = await req.parseBody().catch(() => {})
    const query = req.query()
  
    // Merge JSON, form, and query params into a single object
    const trackingData = { ...query, ...form, ...json };
  
    const now = new Date().toISOString();
    const ip = req.header('X-Forwarded-For') || getConnInfo(context).remote?.address;

    trackingData.ts = trackingData.ts || now;
    trackingData.et = trackingData.et || "event";
    trackingData.ua = trackingData.ua || req.header('user-agent');
    trackingData.c = trackingData.c || getCookie(context,'CLIENT_ID_COOKIE_NAME');
    trackingData.h = trackingData.h || getHashh(ip, trackingData.ua);
    trackingData.h1 = trackingData.h1 || getCookie(context,'HASH_COOKIE_NAME') || trackingData.h //process.env.HASH_COOKIE_NAME
    trackingData.ch = ip;

    if (trackingData.en === 'consent') {
        if (trackingData.p.id===true) {
            const domain = context.env.hostname.includes('.') ? '.' + context.env.hostname.split('.').slice(-2).join('.') : context.env.hostname;
            trackingData.c = trackingData.c || uuid.v4();
            setCookie(context,'CLIENT_ID_COOKIE_NAME', trackingData.c,{maxAge: 31536000, domain: domain }); // maxAge 1y; reset cookie runtime on every consent call
            setCookie(context,'HASH_COOKIE_NAME', trackingData.h1,{maxAge: 31536000, domain: domain }); // store hash at time of first consent into this cookie to pin user to the A/B variant
        } else if (trackingData.p.id === false) {
            deleteCookie(context, 'CLIENT_ID_COOKIE_NAME');
            deleteCookie(context, 'HASH_COOKIE_NAME');
        }
    }
    // send data further to background processing
    // const protocol = req.protocol || req.headers['x-forwarded-proto'] || 'https'; // Use https by default if X-Forwarded-Proto is not present
    // const host = req.headers['host'];
    // const cloudFunctionUrl = `${protocol}://${host}${req.originalUrl}`;
    // request = protocol === 'https' ? https.request : http.request; // http should only be used for local testing
    // req = request(`${protocol}://${host}/store`,{method: 'POST', timeout: 1000, headers: { 'Content-Type': 'application/json' } }, (res) => {} );
    // req.write(JSON.stringify(trackingData));
    // req.end();

    // async background processing of geolocation & storage
    store(trackingData).catch((error) => {
        console.error("store task failed:\n", error);
    });;

    return context.json({ message: "ok", c: trackingData.c, h: trackingData.h}); // return before async storage
};
