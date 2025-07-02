export interface TrackingEvent {
  en: string;           // event name
  url?: string;         // page URL
  r?: string;           // referrer
  p?: Record<string, any>; // parameters
  ts?: string;          // timestamp
  et?: string;          // event type
  ua?: string;          // user agent
  c?: string;           // client ID
  h?: string;           // hash
  h1?: string;          // stored hash
  ch?: string;          // client IP
  u?: string;           // user ID
}

export interface ProcessedEvent {
  timestamp: string;
  event_type: string;
  event_name: string;
  parameters: string;
  user_agent: string;
  url: string;
  referrer: string;
  client_id: string | null;
  hash: string | null;
  user_id?: string | null;
  consent_given: boolean;
  device: {
    type: string;
    brand: string;
    model: string;
    browser: string;
    browser_version: string;
    os: string;
    os_version: string;
    is_bot: boolean;
  };
  location: {
    ip_trunc: string;
    continent: string | null;
    country: string | null;
    country_code: string | null;
    city: string | null;
  };
}

export interface ConsentSettings {
  id: boolean;
  [key: string]: boolean;
}

export interface ApiResponse {
  message: string;
  c?: string;
  h?: string;
}
