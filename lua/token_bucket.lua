local id = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local burst = tonumber(ARGV[3])

if limit < burst then
  error('Invalid token_bucket script input. Limit can not be smaller than burst rate.')
end

if burst < 1 then
  error('Invalid token_bucket script input. Burst must be greater than or equal to one.')
end

local function time_msec()
  local t = redis.pcall('TIME')
  return t[1] * 1000 + math.floor(t[2] / 1000)
end

local function headers(limit, window, ttl, remaining, burst)
  return {
    tostring(limit) .. ' ' ..
      tostring(limit) .. ';w=' .. tostring(window) .. ';burst=' ..
      tostring(burst) .. ';policy=token_bucket',
    tostring(ttl),
    tostring(remaining)
  }
end

if redis.pcall('EXISTS', id) == 1 then
  local now = time_msec()
  local data = redis.pcall('HMGET', id, 'bucket', 'remaining', 'ts')
  local ttl = redis.pcall('TTL', id)
  local bucket = data[1]
  local remaining = data[2]
  local ts = data[3]

  local d_bucket = (limit - burst) * (now - ts) / window / 1000
  local new_bucket = bucket + d_bucket

  if new_bucket >= 1 then
    local new_bucket = math.floor(redis.pcall('HINCRBYFLOAT', id, 'bucket', d_bucket - 1))
    local remaining = redis.pcall('HINCRBY', id, 'remaining', -1)
    redis.pcall('HSET', id, 'ts', now)
    local h = headers(limit, window, ttl, remaining, burst)
    if new_bucket >= 1 then
      return {'allow', h}
    else
      local retry_after = math.min(math.ceil(window / (limit - burst)), ttl)
      h[#h+1] = tostring(retry_after)
      return {'allow', h}
    end
  else
    local h = headers(limit, window, ttl, remaining, burst)
    local retry_after = math.min(math.abs(math.ceil(window / (limit - burst) - (now - ts) / 1000)), ttl)
    h[#h+1] = tostring(retry_after)
    return {'block', h}
  end
else
  local now = time_msec()
  local remaining = limit - 1
  local bucket = burst - 1
  redis.pcall('HSET', id, 'bucket', bucket, 'remaining', remaining, 'ts', now)
  redis.pcall('EXPIRE', id, window)
  local h = headers(limit, window, window, remaining, burst)
  if bucket >= 1 then
    return {'allow', h}
  else
    local dt_token = math.ceil(window / (limit - burst))
    h[#h+1] = tostring(dt_token)
    return {'allow', h}
  end
end
