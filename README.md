# terraform - 多云基础设施即代码

这个项目使用Terraform来管理多云环境的基础设施资源，包括AWS、火山引擎和Cloudflare。项目采用模块化设计，每个组件都是独立的模块，可以单独使用，也可以组合使用。

## 项目结构

```
.
├── README.md                       # 项目说明文档
├── aws_subaccount_guide.md         # AWS子账号使用指南
├── main.tf                         # 主配置文件，用于组合各个模块
├── var.tf                          # 全局变量定义
├── provider.tf                     # Provider配置文件
├── init_s3_backend.sh              # S3后端初始化脚本
├── verify_aws_connection.sh        # AWS连接验证脚本
├── verify_cloudflare_token.sh      # Cloudflare令牌验证脚本
├── query_terraform_state_audit.sh  # Terraform状态审计查询脚本
├── destroy_old_resources.sh        # 旧资源销毁脚本
├── modules/                        # 模块目录
│   ├── aws/                        # AWS模块
│   │   ├── s3/                     # S3存储桶模块
│   │   └── terraform_state_audit/  # Terraform状态审计模块
│   ├── volcengine/                 # 火山引擎模块
│   │   └── network/                # 网络模块（VPC、子网、路由表）
│   └── cloudflare/                 # Cloudflare模块
│       └── dns/                    # DNS模块
├── terraform-init/                 # S3后端初始化目录
└── examples/                       # 示例目录
    ├── basic/                      # 基础示例
    └── complete/                   # 完整示例
```

## 模块说明

### AWS模块 (aws)

#### S3存储桶模块 (s3)

S3存储桶模块用于创建和管理AWS S3存储桶，支持以下功能：
- 创建S3存储桶
- 配置版本控制
- 配置服务器端加密
- 配置公共访问阻止
- 配置生命周期规则

#### Terraform状态审计模块 (terraform_state_audit)

Terraform状态审计模块用于为Terraform状态文件创建审计跟踪系统，包括以下功能：
- 创建CloudTrail跟踪以监控S3存储桶活动
- 设置Lambda函数处理S3事件并查询CloudTrail获取用户信息
- 使用DynamoDB表存储审计记录
- 支持TTL自动清理旧记录

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

### 初始化S3远程状态存储

本项目使用AWS S3作为Terraform状态文件的远程存储。首次使用前，需要初始化S3后端：

1. **创建S3存储桶**（仅首次使用时需要）

   ```bash
   # 确保设置了AWS凭证
   export AWS_ACCESS_KEY_ID="您的AWS访问密钥ID"
   export AWS_SECRET_ACCESS_KEY="您的AWS访问密钥密码"
   # 或者使用配置文件
   export AWS_PROFILE="subaccount"
   
   # 进入terraform-init目录
   cd terraform-init
   
   # 初始化并创建S3存储桶
   terraform init
   terraform apply
   
   # 返回主目录
   cd ..
   ```

2. **初始化S3后端**

   ```bash
   # 使用默认参数
   ./init_s3_backend.sh
   
   # 或指定参数
   ./init_s3_backend.sh my-terraform-state us-west-1 terraform-state-lock subaccount
   ```

### 验证连接

在开始使用前，可以验证与各云服务提供商的连接：

1. **验证AWS连接**

   ```bash
   ./verify_aws_connection.sh subaccount
   ```

2. **验证Cloudflare令牌**

   ```bash
   export CLOUDFLARE_API_TOKEN="您的API令牌"
   ./verify_cloudflare_token.sh
   ```

### 常规使用流程

1. 克隆仓库
2. 根据需要修改变量配置
3. 初始化Terraform：`terraform init`
4. 查看计划：`terraform plan`
5. 应用更改：`terraform apply`

### 查询Terraform状态审计记录

如果启用了Terraform状态审计模块，可以查询状态变更记录：

```bash
# 查询过去7天的记录
./query_terraform_state_audit.sh terraform-state-audit 7 subaccount

# 自定义查询
./query_terraform_state_audit.sh [表名] [天数] [配置文件]
```

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

### AWS S3远程状态存储相关变量
- aws_region：AWS区域，用于S3后端存储
- terraform_state_bucket：存储Terraform状态文件的S3存储桶名称
- terraform_state_key：Terraform状态文件在S3存储桶中的路径
- terraform_state_dynamodb_table：用于Terraform状态锁定的DynamoDB表名称

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

### AWS认证（用于S3远程状态存储）
```bash
# 方法1：使用环境变量设置AWS凭证
export AWS_ACCESS_KEY_ID="您的AWS访问密钥ID"
export AWS_SECRET_ACCESS_KEY="您的AWS访问密钥密码"

# 方法2：使用配置文件（推荐）
export AWS_PROFILE="subaccount"
```

## AWS子账号使用说明

本项目默认使用名为"subaccount"的AWS配置文件，该配置文件对应AWS子账号。使用子账号可以提高安全性，并且便于权限管理。

### 配置子账号

1. 获取子账号的访问密钥ID和密钥（通常由AWS管理员提供）

2. 使用AWS CLI配置子账号：
```bash
aws configure --profile subaccount
```

3. 或者手动编辑配置文件：

~/.aws/credentials文件：
```
[subaccount]
aws_access_key_id = 您的子账号访问密钥ID
aws_secret_access_key = 您的子账号密钥
```

~/.aws/config文件：
```
[profile subaccount]
region = ap-east-1
output = json
```

4. 验证子账号连接：
```bash
./verify_aws_connection.sh subaccount
```

5. 在Terraform中使用子账号：
```hcl
provider "aws" {
  profile = "subaccount"
  region  = "ap-east-1"
}
```

更多详细信息，请参考`aws_subaccount_guide.md`文件。

## 注意事项

- 每个模块都可以独立使用
- 模块之间的依赖关系通过变量传递
- 建议先部署网络模块，再部署其他模块
- 使用S3远程状态存储可以实现团队协作和状态锁定
- 所有敏感信息都应通过环境变量提供，而不是硬编码在配置文件中
- 定期轮换访问密钥以提高安全性
- 子账号的权限可能与主账号不同，某些操作可能无法执行
- 如果遇到权限问题，请联系AWS管理员