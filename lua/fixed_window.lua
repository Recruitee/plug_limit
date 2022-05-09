-- Fixed window rate limiter script
--
-- Script allows to limit requests number in a specified time interval.
-- Requests count for given limiter is reset every fixed time interval given as a command argument.
--
-- Script invocation syntax assuming that script is already cached with `sha`:
-- EVALSHA sha 1 key limit time
-- where:
-- sha is a script sha resulting from the SCRIPT LOAD command execution,
-- key is a given rate limiter id following Redis naming conventions, for example "limiter:123456",
-- limit and time are a requests count limit in a given time interval in seconds.
--
-- Script returns an array: [remaining_count, remaining_time], where:
-- remaining_count is a remaining allowed requests count in a remaining_time amount of seconds.
-- Value of remaining_count will be negative if number of requests exceeded initially given limit.
-- Negative remaining_count value in most cases should result in given request blocking and sending http response with 429 status.
-- Leveraging negative remaining_count for exceeding requests, user can implement additional layer of defense: if remaining_count is less than some assumed value additional blocking rule might be imposed on the ingress proxy for a given user_id abuser.
--
-- Example script usage:
-- EVALSHA "hex_script_sha" 1 "limiter:123456" 10 60
-- In a command above "limiter:123456" will be allowed to issue 10 requests in 60 seconds time.

local id = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])

local function headers(limit, window, remaining)
  return {
    tostring(limit),
    tostring(window),
    tostring(remaining)
  }
end

if redis.pcall('EXISTS', id) == 1 then
  local count = redis.pcall('DECR', id)
  local ttl = redis.pcall('TTL', id)
  if count >= 0 then
    local h = headers(limit, ttl, count)
    return {'allow', h}
  else
    local h = headers(limit, ttl, 0)
    return {'block', h}
  end
else
  local count = limit - 1
  redis.pcall('SETEX', id, window, count)
  local h = headers(limit, window, count)
  return {'allow', h}
end

