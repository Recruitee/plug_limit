local id = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local burst = tonumber(ARGV[3])

local function time_msec()
  local t = redis.pcall('TIME')
  return t[1] * 1000 + math.floor(t[2] / 1000)
end

local function headers(limit, window, ttl, remaining)
  return {
    tostring(limit) .. ' ' ..
    tostring(limit) .. ';w=' .. tostring(window) .. ';policy=token_bucket',
    tostring(ttl),
    tostring(remaining)
  }
end

if redis.pcall('EXISTS', id) == 1 then
  local now = time_msec()
  local data = redis.pcall('HMGET', id, 'count', 'ts')
  local ttl = redis.pcall('TTL', id)
  local count = data[1]
  local ts = data[2]

  local dc = (limit - burst) * (now - ts) / window / 1000
  local new_count = count + dc

  if new_count >= 1 then
    local new_count = math.floor(redis.pcall('HINCRBYFLOAT', id, 'count', dc - 1))
    redis.pcall('HSET', id, 'ts', now)
    if new_count >= 1 then
      local h = headers(limit, window, ttl, new_count)
      return {'allow', h}
    else
      local h = headers(limit, window, ttl, 0)
      local dt_token = math.ceil(window / (limit - burst))
      h[#h+1] = tostring(dt_token)
      return {'allow', h}
    end
  else
    local h = headers(limit, window, ttl, 0)
    local dt_token = math.abs(math.ceil(window / (limit - burst) - (now - ts) / 1000))
    h[#h+1] = tostring(dt_token)
    return {'block', h}
  end
else
  local count = burst - 1
  local now = time_msec()
  redis.pcall('HSET', id, 'count', count, 'ts', now)
  redis.pcall('EXPIRE', id, window)
  local h = headers(limit, window, window, count)
  if count >= 1 then
    return {'allow', h}
  else
    local dt_token = math.ceil(window / (limit - burst))
    h[#h+1] = tostring(dt_token)
    return {'allow', h}
  end
end

