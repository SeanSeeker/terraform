# terraform - 多云基础设施即代码

这个项目使用Terraform来管理多云环境的基础设施资源，包括火山引擎和Cloudflare。项目采用模块化设计，每个组件都是独立的模块，可以单独使用，也可以组合使用。

## 项目结构

```
.
├── README.md
├── main.tf           # 主配置文件，用于组合各个模块
├── var.tf           # 全局变量定义
├── provider.tf      # Provider配置文件
├── modules/         # 模块目录
│   ├── volcengine/  # 火山引擎模块
│   │   └── network/ # 网络模块（VPC、子网、路由表）
│   └── cloudflare/  # Cloudflare模块
│       └── dns/     # DNS模块
└── examples/       # 示例目录
    ├── basic/      # 基础示例
    └── complete/   # 完整示例
```

## 模块说明

### 火山引擎模块 (volcengine)

#### 网络模块 (network)

网络模块用于创建和管理VPC、子网和路由表等网络资源。

### Cloudflare模块 (cloudflare)

#### DNS模块 (dns)

DNS模块用于管理Cloudflare的DNS记录。

### 计划中的模块

以下模块计划在未来实现：

- ECS模块：用于管理火山引擎弹性计算服务器实例
- RDS模块：用于管理火山引擎关系型数据库服务
- SLB模块：用于管理火山引擎负载均衡服务

## 使用方法

1. 克隆仓库
2. 根据需要修改变量配置
3. 初始化Terraform：`terraform init`
4. 查看计划：`terraform plan`
5. 应用更改：`terraform apply`

## 变量配置

主要的变量配置在`var.tf`文件中，具体值在`terraform.tfvars`中设置：

### 火山引擎相关变量
- region：部署区域
- vpc_base_name：VPC基础名称
- vpc_cidr：VPC的CIDR块
- zone_subnet_counts：可用区和子网配置
- region_short_map：区域名称到简写的映射

### Cloudflare相关变量
- cloudflare_zone_id：Cloudflare区域ID
- domain_name：域名

## 环境变量配置

为了安全起见，推荐使用环境变量来设置敏感信息：

### 火山引擎认证
```bash
export VOLCENGINE_ACCESS_KEY="您的访问密钥ID"
export VOLCENGINE_SECRET_KEY="您的访问密钥密码"
```

### Cloudflare认证
```bash
export CLOUDFLARE_API_TOKEN="您的API令牌"
# 或者使用以下组合
# export CLOUDFLARE_EMAIL="您的邮箱"
# export CLOUDFLARE_API_KEY="您的API密钥"
```

## 注意事项

- 每个模块都可以独立使用
- 模块之间的依赖关系通过变量传递
- 建议先部署网络模块，再部署其他模块