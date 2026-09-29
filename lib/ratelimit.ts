// Optional: becomes null (no limiting) when Upstash env vars are not set, e.g. in local dev.
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const url = process.env.UPSTASH_REDIS_REST_URL;
const token = process.env.UPSTASH_REDIS_REST_TOKEN;

export const limiter =
  url && token
    ? new Ratelimit({
        redis: new Redis({ url, token }),
        limiter: Ratelimit.slidingWindow(5, "1 m"), // 5 requests / minute
        prefix: "inventory",
      })
    : null;


