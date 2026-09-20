export interface Env {
  readonly OAUTH_SESSIONS: DurableObjectNamespace;
  readonly OAUTH_RATE_LIMITS: DurableObjectNamespace;
  readonly NOTION_CLIENT_ID: string;
  readonly NOTION_CLIENT_SECRET: string;
  readonly RATE_LIMIT_KEY_SECRET: string;
  readonly NOTION_REDIRECT_URI: string;
  readonly DAYLINE_CALLBACK_URL: string;
}
