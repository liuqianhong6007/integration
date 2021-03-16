local mysql  = require("resty/mysql")

local _M = {
  _version = "0.1.0",
  host,
  port,
  user,
  password,
  database,
  conn,
  primary_keys = {},
  table_structs = {}
}

-- 初始化 mysql 连接
function _M:new(o,host,port,user,password,database)
  local o = o or {}
  setmetatable(o,self)
  self.__index = self
  self.host = host or "localhost"
  self.port = port or 3306
  self.user = user or "user"
  self.password = password or "password"
  self.database = database or "database"

  -- 创建 mysql 实例
  local conn,err = mysql:new()
  if not conn then
    error(string.format("new mysql error: %s",err))
  end
 
  -- 设置超时时间
  conn:set_timeout(1000)

  -- 创建连接
  local res,err,errno,sqlstate =  conn:connect({
    host = self.host,
    port = self.port,
    user = self.user,
    password = self.password,
    database = self.database,
  })
  if not res then
    error(string.format("connect mysql error: %s,errno: %s,sqlstate: %s",err,errno,sqlstate))
  end
  print("connect to "..self.user.."@"..self.host..":"..self.port.." success")
  self.conn = conn

  local sqlStr = string.format("use %s",database)
  res,err,errno,sqlstate = self.conn:query(sqlStr)
  if not res then
    self:close()
    error(string.format("db query error: %s,errno: %s,sqlstate: %s",err,errno,sqlstate))
  end
  return true,o
end

-- 关闭 mysql
function _M:close()
  if not self.conn then
    return
  end
  self.conn:close()
end

-- 查询 SQL，带返回值
function _M:query(sqlStr)
  print(sqlStr)
  local result = {}
  local res,err,errno,sqlstate = self.conn:query(sqlStr)
  if not res then
    error(string.format("db query error: %s,errno: %s,sqlstate: %s",err,errno,sqlstate))
  end

  for i,row in ipairs(res) do
    local rowData = {}
    for k,v in pairs(row) do
      rowData[k] = v
    end
    table.insert(result,rowData)
  end
  return result
end

-- 执行 SQL，无返回值
function _M:execute(sqlStr)
  print(sqlStr)
  local res,err,errno,sqlstate = self.conn:query(sqlStr)
  if not res then
    error(string.format("db query error: %s,errno: %s,sqlstate: %s",err,errno,sqlstate))
  end
end

-- 执行事务
function _M:execute_rollback_if_failed(sqlStr)
  print(sqlStr)
  local res,err,errno,sqlstate = self.conn:query(sqlStr)
  if not res then
    self.conn:query("ROLLBACK")
    error(string.format("db query error: %s,errno: %s,sqlstate: %s",err,errno,sqlstate))
  end 
end


-- 查询指定 schema 的所有表
function _M:query_table_list()
  local sqlStr = string.format("SELECT table_name,table_comment FROM information_schema.`TABLES` WHERE `table_schema` = '%s'",self.database)
  return self:query(sqlStr)
end

-- 查询指定表的表结构
function _M:query_table_struct(table_name)
  local sqlStr = string.format("SELECT column_name,data_type,column_comment,column_key,extra FROM information_schema.`COLUMNS` WHERE `table_schema` = '%s' AND `table_name` = '%s'",self.database,table_name)
  return self:query(sqlStr)
end

-- 解析表
function _M:parse_table(table_name)
  local columns = self:query_table_struct(table_name)
  -- 存储表结构
  if self.table_structs[table_name] == nil then
    self.table_structs[table_name] = columns
  end

  -- 存储表主键
  if self.primary_keys[table_name] == nil then
    for i, column in ipairs(columns) do
      for k,v in pairs(column) do
        if k =="column_key" and v == "PRI" then
          self.primary_keys[table_name] = column["column_name"]
          goto exit
        end
      end
    end
    ::exit::
  end
  return self.primary_keys[table_name],self.table_structs[table_name]
end

-- 查询指定表的数据
function _M:query_table_data(table_name)
  local sqlStr = string.format("SELECT * FROM `%s`",table_name)
  return self:query(sqlStr)
end

-- 更新指定表的数据
function _M:update_table_data(table_name,rows)
  -- 获取表的主键
  local pri_key,table_struct = self:parse_table(table_name)  
  
  -- 开启事务
  self.conn:query("START TRANSACTION")

  -- 更新表数据
  for i,row in ipairs(rows) do
    -- 拼接 SQL
    local updateSql = "UPDATE "..table_name.." SET "
    local whereSql = ""
    for column_key,column_val in pairs(row) do
      if column_key ~= pri_key then
        updateSql = updateSql.."`"..column_key.."`".." = '"..column_val.."',"
      else
        whereSql = " WHERE ".."`"..pri_key.."`".." = '"..column_val.."'"
      end
    end
    
    -- 必须带有主键条件
    if whereSql == "" then
      error("update row not contain primary key")
    end

    -- 执行更新 SQL
    updateSql = string.sub(updateSql,0,#updateSql -1)
    self:execute_rollback_if_failed(updateSql..whereSql)
  end

  -- 提交事务
  self.conn:query("COMMIT")
end

-- 删除指定表的数据
function _M:delete_table_data(table_name,rows)
  -- 获取表的主键
  local pri_key,table_struct = self:parse_table(table_name)

  -- 拼接 SQL
  local deleteSql = "DELETE FROM "..table_name.." WHERE `"..pri_key.."` in("
  for index,val in ipairs(rows) do
    deleteSql = deleteSql.."'"..val.."',"
  end
  deleteSql = string.sub(deleteSql,0,#deleteSql -1)..")"

  -- 执行删除 SQL
  self:execute(deleteSql)
end

-- 新增指定表数据
function _M:insert_table_data(table_name,rows)
  -- 获取表的主键
  local pri_key,table_struct = self:parse_table(table_name)

  -- 拼接 SQL
  local insertOrder = {} -- 字段顺序
  local insertSql = "INSERT INTO "..table_name.."("
  for index,column in ipairs(table_struct) do
    if column["column_name"] ~= pri_key then
      insertSql = insertSql.."`"..column["column_name"].."`,"
      table.insert(insertOrder,column["column_name"])
    end
  end
  insertSql = string.sub(insertSql,0,#insertSql - 1)..") values "

  for index,row in pairs(rows) do
    insertSql = insertSql.."("
    for i,insertColumnKey in ipairs(insertOrder) do
      local insertColumnVal = row[insertColumnKey]
      insertSql = insertSql.."'"..insertColumnVal.."',"
    end
    insertSql = string.sub(insertSql,0,#insertSql - 1).."),"
  end
  insertSql = string.sub(insertSql,0,#insertSql - 1)

  -- 执行新增 SQL
  self:execute(insertSql)
end

return _M
