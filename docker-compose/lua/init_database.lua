mysql = require("luasql.mysql")

local host = os.getenv("DB_HOST")
local port = os.getenv("DB_PORT")
local user = os.getenv("DB_USER")
local password = os.getenv("DB_PASSWORD")
local lib = os.getenv("DB_LIB")

local function close(env,conn,cursor)
  -- 关闭结果集
  if cursor ~= nil  then
    cursor:close()
  end
  -- 关闭连接
  if conn ~= nil then
    conn:close()
  end
  -- 关闭环境
  if env ~= nil then
    env:close()
  end
end

local env  = mysql.mysql()
local conn = env:connect(lib,user,password,host,port)
if conn == nil then
  close(env,conn,nil)
  error("connect to "..user.."@"..host..":"..port.." failed")
end
print("connect to "..user.."@"..host..":"..port.." success")

local status,errorString = conn:execute([[
  CREATE TABLE IF NOT EXISTS `account` (
      `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '账号ID',
      `account` varchar(50) NOT NULL COMMENT '账户',
      `password` varchar(50) NOT NULL COMMENT '密码',
      `create_time` bigint(20) NOT NULL COMMENT '创建时间',
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='账号';
]])
if status ~= 0 then
  close(env,conn,nil)
  error(errorSttring)
end
print("init account table success")

status,errorString = conn:execute([[
  CREATE TABLE IF NOT EXISTS `invite_code` (
      `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '邀请码ID',
      `invite_code` varchar(50) NOT NULL COMMENT '邀请码',
      `used` smallint NOT NULL COMMENT '是否已使用',
      `create_time` bigint(20) NOT NULL COMMENT '创建时间',
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='邀请码';

]])
if status ~= 0 then
  close(env,conn,nil)
  error(errorSttring)
end
print("init invite_code table success")

close(env,conn,nil)
print("close mysql conn")
