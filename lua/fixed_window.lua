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

