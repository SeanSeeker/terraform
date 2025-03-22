# AWS子账号使用指南

## 配置新的AWS子账号

当您获得新的AWS子账号后，需要进行以下配置才能使用：

### 1. 获取子账号的访问密钥

首先，您需要获取子账号的访问密钥ID和密钥。这些信息通常由AWS管理员提供，或者您可以在AWS控制台中自行创建：

1. 登录AWS控制台
2. 进入IAM服务
3. 选择您的用户名
4. 点击"安全凭证"选项卡
5. 在"访问密钥"部分，点击"创建访问密钥"
6. 保存生成的访问密钥ID和密钥（这是唯一一次可以查看密钥的机会）

### 2. 配置AWS CLI配置文件

您可以使用AWS CLI的配置文件功能来管理多个AWS账号。以下是配置步骤：

#### 方法一：使用AWS CLI命令配置

```bash
# 配置名为"subaccount"的配置文件
aws configure --profile subaccount
```

系统会提示您输入以下信息：
- AWS Access Key ID：输入您的子账号访问密钥ID
- AWS Secret Access Key：输入您的子账号密钥
- Default region name：输入默认区域（如ap-east-1）
- Default output format：输入输出格式（如json）

#### 方法二：手动编辑配置文件

您也可以直接编辑~/.aws/credentials和~/.aws/config文件：

~/.aws/credentials文件：
```
[default]
aws_access_key_id = 您的主账号访问密钥ID
aws_secret_access_key = 您的主账号密钥

[subaccount]
aws_access_key_id = 您的子账号访问密钥ID
aws_secret_access_key = 您的子账号密钥
```

~/.aws/config文件：
```
[default]
region = ap-east-1
output = json

[profile subaccount]
region = ap-east-1
output = json
```

### 3. 使用子账号配置文件

配置完成后，您可以通过在AWS CLI命令中添加`--profile subaccount`参数来使用子账号：

```bash
# 验证子账号连接
./verify_aws_connection.sh subaccount

# 使用子账号查询Terraform状态审计记录
./query_terraform_state_audit.sh terraform-state-audit 7 subaccount
```

您也可以通过设置环境变量来临时切换到子账号：

```bash
export AWS_PROFILE=subaccount
```

设置环境变量后，所有AWS CLI命令都会使用子账号，无需添加`--profile`参数。

### 4. 在Terraform中使用子账号

如果您需要在Terraform中使用子账号，可以在provider配置中指定配置文件：

```hcl
provider "aws" {
  profile = "subaccount"
  region  = "ap-east-1"
}
```

或者使用环境变量：

```bash
export AWS_PROFILE=subaccount
terraform apply
```

## 注意事项

- 请妥善保管您的访问密钥，不要将其泄露给他人
- 定期轮换访问密钥以提高安全性
- 子账号的权限可能与主账号不同，某些操作可能无法执行
- 如果遇到权限问题，请联系AWS管理员