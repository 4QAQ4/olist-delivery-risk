import pandas as pd

#读取订单数据
orders = pd.read_csv('data/raw/olist_orders_dataset.csv')

#查看数据规模
print('订单表的行数和列数是', orders.shape)


# 查看前5行
print('查看前5行数据', orders.head(5))

# 查看字段名称
print('查看字段名称', orders.columns.tolist())

# 查看字段类型
print('查看字段类型', orders.dtypes)