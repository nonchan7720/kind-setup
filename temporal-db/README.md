# temporal db

## login

```bash
kubectl run -n temporal-db --rm -it myshell --image=container-registry.oracle.com/mysql/community-operator -- mysqlsh

MySQL  SQL > \connect root@temporal-db-cluster

# input password
# Save password for 'root@temporal-db-cluster'? [Y]es/[N]o/Ne[v]er (default No): n

# execute files/query.sql
```
