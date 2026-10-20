# olist-delivery-risk
Olist 电商订单分析与延迟风险预测

Olist 电商订单分析与延迟风险预测
基于 Kaggle 公共 Brazilian E-Commerce Public Dataset by Olist，完成订单级数据整理、配送延迟探索性分析，以及订单获批时的延迟风险预测。项目以 Python / Pandas / SQL / scikit-learn 为主，依次训练简单基线、逻辑回归和随机森林模型，并分析分类阈值、误报与漏报。
项目定位：数据分析与离线建模练习，而非真实上线的配送预警系统。最终模型为未加权随机森林；测试集 AP 为 0.0848，高于同一测试集延迟率基线 0.0428，但 Precision 较低，不能宣称具有可靠的实际业务预警能力。

1. 数据来源与预测任务
- 数据来源：Kaggle — Brazilian E-Commerce Public Dataset by Olist
- 原始数据时间范围：2016—2018 年，约 10 万笔订单（具体建模样本量见后文）。
- 第一版使用三张原始数据表：
  - olist_orders_dataset.csv：订单及关键时间戳。
  - olist_order_items_dataset.csv：订单商品明细、价格、运费及卖家 ID。
  - olist_customers_dataset.csv：客户地区及关联信息。
- 分析粒度：一行代表一笔订单。商品明细先按 order_id 汇总，再与订单和客户表关联。
- 预测时点：订单获批时（order_approved_at）。仅使用该时点已知或在项目中明确假设可知的信息。
- 标签 is_delayed：若实际送达的日历日期晚于预计送达日，则记为 1，否则记为 0；同一日送达记为 0。
实际送达时间用于生成标签及控制历史标签可用性，不作为模型输入特征。预计配送日期用于构造 promised_days，需假设该日期在订单获批时已经可知。
2. 项目完成内容
1. 数据整理与质量检查：检查订单重复、时间字段与缺失情况；按订单聚合商品信息，构造订单级数据集。
2. 探索性数据分析（EDA）：分析订单时间变化、客户地区延迟情况，以及订单金额等因素与延迟的关联；相关明细保存在 reports/。
3. 预测任务设计：按获批时间划分训练/验证/测试；训练与验证阶段只使用相应边界前已经送达、标签可观察的订单。
4. 模型对比：DummyClassifier 基线、逻辑回归和未加权随机森林。
5. 模型评估与解释：比较 AP、Precision、Recall、F1，分析分类阈值、PR 曲线、误报漏报及置换特征重要性。
EDA 各图的具体文件名与结论尚需根据你的 reports/figures/ 内容补到本 README，避免把未核实的观察写成事实。

3. 主要建模结果
3.1 数据划分
按订单获批时间划分，并考虑训练/验证样本标签的可用性：
数据集	订单数	延迟率
训练集	64,381	6.82%
验证集	12,544	4.30%
测试集	14,456	4.28%


3.2 验证集模型对比
模型	输入特征数	AP	Precision	Recall	F1	分类阈值
DummyClassifier（prior）	9（不实际使用特征）	0.04297	0	0	0	默认分类规则
Logistic Regression	9	0.06865	0.0650	0.4100	0.1122	0.08
Random Forest（未加权）	8	0.11372	0.1535	0.2876	0.2001	0.07474


- AP 衡量延迟订单风险排序质量，不依赖单一分类阈值。基线 AP 约等于验证集延迟率。
- 逻辑回归和随机森林的 Precision / Recall / F1 使用各自在验证集上选择的阈值，而不是统一的 0.5；二者所用特征数量也不相同。
- 模型对比是实际项目结果，并非只改变算法、严格控制其他因素的独立算法比较实验。
3.3 最终随机森林测试集
最终采用未加权 RandomForestClassifier：n_estimators=120，max_depth=10，min_samples_leaf=30，max_features="sqrt"，random_state=42。
指标	测试集结果
订单数	14,456
延迟率（随机排序 AP 基准）	0.0428
Average Precision（AP）	0.0848
Precision	0.0962
Recall	0.4604
F1	0.1591


测试集分类使用从验证集确定的阈值 0.07474。尽管 AP 高于随机排序基准，误报仍较多，模型不适合未经进一步验证便用于实际业务。
3.4 有代表性的实验发现
- 在最初九项订单特征基础上加入 promised_days（预计配送天数），验证集 AP 从 0.06974 提高到 0.11127（该对比来自特征消融实验）。
- 卖家历史延迟率、历史订单数进行了构造与消融，未纳入最终模型。
- 最终模型的置换重要性分析中，customer_state 和 promised_days 对验证集 AP 的影响最明显；特征重要性不代表因果关系。
- 后续类别加权对照实验里，class_weight="balanced" 的验证集 AP 有小幅提高，但最优 F1 没有提高；因此项目仍保留原先的未加权模型作为最终版本。
详细方法、特征消融和指标见 [`reports/experiments.md`](reports/experiments.md)。
4. 仓库结构
olist-delivery-risk/
├── data/
│   ├── raw/                       # Olist 原始 CSV（本地保存）
│   └── processed/                 # 清洗和建模的中间数据（本地生成）
├── src/
│   ├── check_data.ipynb
│   ├── data_feature_item_groupby.ipynb
│   ├── merge_orders.ipynb
│   ├── explore_orders.ipynb
│   ├── prediction_task.ipynb
│   ├── baseline_and_logistic_regression.ipynb
│   ├── random_forest.ipynb
│   ├── check_orders.py
│   └── branch_test.py            # 协作练习文件；正式展示前决定是否移除
├── models/                         # 模型输出（如 random_forest_v1.joblib）
├── reports/
│   ├── figures/                  # 分析图表
│   ├── data_quality.md           # 数据质量记录
│   ├── amount_delay_summary.csv
│   ├── state_delay_summary.csv
│   └── experiments.md            # 本项目模型实验报告
├── .gitignore
├── requirements.txt
└── README.md
上述路径依据当前 VS Code 目录截图整理；models/ 下模型文件是否存在、reports/figures/ 中实际文件名以及各 Notebook 的运行依赖顺序仍应在本地核查。
5. 环境与运行
推荐 Python 3.10+，在 VS Code 中安装 Python 和 Jupyter 扩展，并选择项目虚拟环境作为 Notebook Kernel。实际依赖版本以仓库 requirements.txt 为准。

Windows PowerShell：
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
macOS / Linux：
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
1. 从上述 Kaggle 页面获取三张原始 CSV，放到 data/raw/。
2. 在 VS Code 中打开项目根目录，配置 Python 解释器 / Notebook Kernel。
3. 依次检查并运行数据检查、商品聚合、订单关联和分析 Notebook。
4. 在确认 data/processed/model_dataset.csv、data/processed/orders_with_delay.csv 已生成后，运行 src/baseline_and_logistic_regression.ipynb 和 src/random_forest.ipynb。
5. 核对终端输出、实验报告和模型文件。
运行顺序待核查：不同 Notebook 可能存在前后依赖；当前列出的是概览，不应视为已经在全新环境实测通过的一键复现流程。正式发布前需从干净环境验证一次，并在这里补上准确命令或执行顺序。

6. 局限性
- 延迟订单占比低，Precision 较低且存在较多误报；准确率不适合作为唯一指标。
- 训练、验证与测试来自不同时期，延迟率及订单特征分布可能变化；测试 AP 低于验证 AP。
- 训练和验证时排除了各自截止点前尚未送达的订单，存在潜在选择偏差。
- 第一版仅使用三张原始表；缺少商家地理位置、真实承运过程等变量。
- 假设预计送达日期在订单获批时已知；数据不能验证所有历史业务快照。
- 已查看测试集评估结果；后续不应反复根据该测试集挑选模型配置。