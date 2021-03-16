local cjson = require "cjson"

local param = {
        method = ngx.req.get_method(),
        url = ngx.var.uri
}
local body_buf = cjson.encode(param)
local res = ngx.location.capture("/auth-proxy",{
        method = ngx.HTTP_POST,
        body = body_buf,
})
if res.status ~= ngx.HTTP_OK then
        ngx.exit(res.status)
end