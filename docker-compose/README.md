## 步骤1： 在当前路径下创建目录 mysql-data

## 步骤2：在当前路径下创建目录 etcd-data，并执行 chmod 777 etcd-data

## 步骤3： 执行命令 docker-compose up -d

## 卸载

    docker-compose down -v

-v  表示清除 volume，不加 -v，在升级时可能出现打包数据仍为旧数据的情况