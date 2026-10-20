# Olist 订单延迟预测：最终建模实验报告

本报告汇总项目中已完成的基线、逻辑回归和随机森林实验，最终版本为**未加权随机森林**。未独立复现的结果按照 Notebook 中的实验记录报告。

## 1. 任务定义

目标：在订单获批时，根据订单获批时已知或假定可知的订单信息，预测该订单是否会晚于预计送达日完成配送。

预测时点：`order_approved_at`。

目标变量：`is_delayed`。使用日历日期而非完整时间戳比较：

```python
is_delayed = (
    order_delivered_customer_date.dt.normalize()
    > order_estimated_delivery_date.dt.normalize()
).astype(int)
```

上述代码仅示意两列均有效且送达状态已核实的样本的标签规则；实际缺失送达时间不能自动标为 0。实际送达时间用于标签和时间可用性检查，不放入模型输入。

数据来源：[Kaggle Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)；第一版只使用订单表、订单商品表、客户表。订单商品明细按 `order_id` 聚合后得到一行一订单的数据。

## 2. 时间划分与标签可用性

按 `order_approved_at` 确定约 70% / 15% / 15% 的时间边界；随后：

- 训练集：获批时间在验证期开始前，且订单在验证期开始前已经送达。
- 验证集：获批时间在验证期内，且订单在测试期开始前已经送达。
- 测试集：获批时间在测试期内，沿用构造完成的有效标签数据。

| 数据集 | 样本数 | 延迟率 |
|---|---:|---:|
| 训练集 | 64,381 | 6.82% |
| 验证集 | 12,544 | 4.30% |
| 测试集 | 14,456 | 4.28% |

这些样本数量是应用时间与标签可用性筛选后的结果，不应当直接等同于原始 Olist 订单总数。训练集延迟率高于验证、测试集，需注意时间分布变化和筛选引起的选择偏差。

## 3. 评价指标

- **AP（Average Precision）：** 主要比较风险排序的指标；常数评分下的 AP 等于所在数据集正类比例。
- **Precision：** 判为延迟的订单中，实际延迟的比例。
- **Recall：** 实际延迟的订单中，被识别出的比例。
- **F1：** Precision 与 Recall 的调和平均。
- **PR 曲线：** 用于呈现不同阈值下的 Precision–Recall 权衡。

考虑到延迟订单属于少数类，不以 Accuracy 作为主要结论。分类阈值只从验证集选择，再应用到测试集。

## 4. DummyClassifier 基线

使用 `DummyClassifier(strategy="prior")`：只学习训练集正负类比例，不依赖输入特征，类别预测均为未延迟。

| 指标（验证集） | 值 |
|---|---:|
| Accuracy | 0.957031 |
| Precision | 0 |
| Recall | 0 |
| AP | 0.042969 |

混淆矩阵（行：真实 0/1；列：预测 0/1）：

```text
[[12005     0]
 [  539     0]]
```

解释：即使准确率超过 95%，模型也没有识别出任何延迟订单。AP 约 4.30%，是验证集的基础对照水平。

## 5. 逻辑回归模型

### 5.1 输入与预处理

共使用九项特征：

**数值特征（7 个）：**

- `purchase_month`
- `purchase_weekday`
- `purchase_hour`
- `approval_hour`
- `item_count`
- `product_amount`
- `freight_amount`

**类别特征（2 个）：**

- `customer_state`
- `customer_city`

数值特征用 `StandardScaler`，类别特征用 `OneHotEncoder(handle_unknown="ignore")`，仅对训练集拟合预处理器。编码后特征矩阵为 3,710 列。

逻辑回归使用：

```python
LogisticRegression(
    max_iter=1000,
    random_state=42
)
```

实际训练迭代次数为 122。

### 5.2 验证集指标

| 评价方式 | Precision | Recall | F1 | AP |
|---|---:|---:|---:|---:|
| 默认阈值 0.50 | 0 | 0 | 0 | 0.068645 |
| 六个候选阈值中选择的 0.08 | 0.0650 | 0.4100 | 0.1122 | 0.068645 |

- 逻辑回归输出的最大验证概率约 0.489228，因此默认阈值 0.5 时没有预测任何延迟订单。
- 在 0.05、0.08、0.10、0.15、0.20、0.50 六个阈值中，0.08 的验证集 F1 最高（不是全部可能阈值的全局最优保证）。
- 阈值 0.08 下，成功识别 221 笔延迟订单，但产生 3,179 笔误报。

阈值 0.08 下的验证集混淆矩阵：

```text
[[8826 3179]
 [ 318  221]]
```

### 5.3 错误案例分析

- 对验证集提取过预测概率较高的 5 笔误报及预测概率较低的 5 笔漏报订单。
- 另外使用分析阈值 0.15 对全部 FP / FN / TP / TN 分组，比较商品金额、运费、商品数量和预测概率。
- 在这项统计中，FP 平均商品金额约 296.88、平均运费约 46.49；TN 对应约 137.49 和 21.58。
- 这些属于模型分组特征差异，不能直接解释为高金额、高运费导致延迟或误报。

**注意：** 错误案例分析用的阈值 0.15 与逻辑回归用于比较 F1 的阈值 0.08 不同，报告和讲解时需分别说明。

## 6. 随机森林实验

### 6.1 初始模型

最初使用逻辑回归相同的九项特征：

```python
RandomForestClassifier(
    n_estimators=120,
    max_depth=16,
    min_samples_leaf=10,
    max_features="sqrt",
    random_state=42
)
```

验证集 AP 约为 **0.069742**。

### 6.2 特征工程与消融

新增尝试：

- `promised_days`：预计送达日历日期减去获批日历日期，单位为天。
- `seller_hist_delay_rate`：卖家截至当前订单获批前，已经送达订单的历史延迟比例。
- `seller_hist_order_count`：卖家截至当前订单获批前，已经送达订单的数量。

卖家历史信息通过原始订单商品表中的 `seller_id` 构造，不需要新增卖家维表；但卖家历史特征在最后并没有入模。

| 实验配置 | 验证集 AP |
|---|---:|
| 原始 9 特征随机森林 | 0.069742 |
| 增加 `promised_days` | 0.111274 |
| `promised_days` + 卖家历史延迟率 | 0.108493 |
| `promised_days` + 卖家历史订单数 | 0.088290 |
| 三项新增特征全部加入 | 0.093244 |

这些数值是实际记录的实验配置结果，与后续进一步调整树深度、叶节点和特征组合得到的最终模型不同。

最显著的发现是预计配送天数的加入有明显帮助；卖家历史特征在当前构造方式下没有额外改善。

### 6.3 最终版本（未加权）

最后保留八项特征：

```python
final_features = [
    "purchase_month",
    "purchase_weekday",
    "purchase_hour",
    "approval_hour",
    "item_count",
    "freight_amount",
    "promised_days",
    "customer_state",
]
```

数值特征直接保留，`customer_state` 进行 One-Hot 编码；预处理器仅在训练集拟合。

最终随机森林模型：

```python
RandomForestClassifier(
    n_estimators=120,
    max_depth=10,
    min_samples_leaf=30,
    max_features="sqrt",
    random_state=42,
    n_jobs=-1
)
```

其中 `class_weight` 默认为 `None`，即不使用类别加权。

模型及其预处理配置已保存到：

```text
models/random_forest_v1.joblib
```

### 6.4 最终结果

| 数据集 | AP |
|---|---:|
| 训练集 | 0.236955 |
| 验证集 | 0.113722 |
| 测试集 | 0.084813 |

根据验证集 F1 选择分类阈值约 0.074742，并且原样用于测试集：

| 指标 | 验证集 | 测试集 |
|---|---:|---:|
| Precision | 0.1535 | 0.0962 |
| Recall | 0.2876 | 0.4604 |
| F1 | 0.2001 | 0.1591 |
| 延迟率 | 