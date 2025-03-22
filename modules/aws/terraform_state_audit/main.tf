# 声明所需的提供商
# 指定AWS提供商的源和版本
# AWS提供商用于管理AWS资源，如CloudTrail、Lambda、DynamoDB等
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # 提供商源，格式为 "命名空间/提供商名称"
      version = "~> 5.0"       # 提供商版本，使用兼容性版本约束
    }
  }
}

# 配置AWS提供商
# 使用profile参数支持多账号管理
# 这允许使用子账号而非主账号操作AWS资源（安全最佳实践）
provider "aws" {
  profile = var.profile # AWS配置文件名称，默认为subaccount
}

# 创建CloudTrail跟踪
# CloudTrail用于记录AWS账号的API调用和资源变更
# 这里专门用于跟踪S3存储桶中Terraform状态文件的变更
resource "aws_cloudtrail" "terraform_state_trail" {
  name                          = var.cloudtrail_name       # CloudTrail跟踪的名称
  s3_bucket_name                = var.s3_bucket_name        # 存储CloudTrail日志的S3存储桶
  include_global_service_events = true                      # 包含全局服务事件（如IAM操作）
  is_multi_region_trail         = var.is_multi_region       # 是否跟踪多个区域的事件
  enable_logging                = true                      # 启用日志记录
  enable_log_file_validation    = true                      # 启用日志文件验证，防止日志被篡改

  # 事件选择器：指定要记录的事件类型
  # 这里配置为只记录S3存储桶的写入操作，减少不必要的日志
  event_selector {
    read_write_type           = "WriteOnly"                      # 只记录写入操作
    include_management_events = true                            # 包含管理事件

    # 数据资源：指定要记录的S3对象
    # 这里配置为只记录指定S3存储桶中的对象操作
    data_resource {
      type   = "AWS::S3::Object"                           # 资源类型为S3对象
      values = ["arn:aws:s3:::${var.s3_bucket_name}/"]    # 指定S3存储桶路径
    }
  }
}

# 创建Lambda函数执行角色
# Lambda函数需要一个IAM角色来定义其权限
# 这个角色允许Lambda服务代表用户执行操作
resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_function_name}-role"  # 角色名称，基于Lambda函数名

  # 信任关系策略，允许Lambda服务担任此角色
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"  # 允许担任角色的操作
        Effect = "Allow"          # 允许效果
        Principal = {
          Service = "lambda.amazonaws.com"  # 允许Lambda服务担任此角色
        }
      },
    ]
  })

  tags = var.tags  # 应用标签
}

# 为Lambda函数添加权限策略
# 这个策略定义了Lambda函数可以执行的具体AWS操作
# 遵循最小权限原则，只授予必要的权限
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.lambda_function_name}-policy"  # 策略名称
  description = "允许Lambda函数访问CloudTrail、S3和DynamoDB的策略"  # 策略描述

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrail",
          "cloudtrail:GetEventSelectors",
          "cloudtrail:ListTags"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ListUsers",
          "sts:GetCallerIdentity"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = "arn:aws:dynamodb:*:*:table/${var.audit_table_name}"
      }
    ]
  })
}

# 将策略附加到角色
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 创建DynamoDB表用于存储审计记录
# DynamoDB是一个完全托管的NoSQL数据库服务
# 这里用于存储Terraform状态文件变更的审计记录
resource "aws_dynamodb_table" "terraform_state_audit" {
  name         = var.audit_table_name  # 表名
  billing_mode = "PAY_PER_REQUEST"     # 按需计费模式，适合不规则访问模式
  hash_key     = "StateFileKey"        # 分区键，用于标识状态文件
  range_key    = "Timestamp"           # 排序键，用于时间序列查询

  # 定义分区键属性
  attribute {
    name = "StateFileKey"  # 属性名
    type = "S"             # 字符串类型
  }

  # 定义排序键属性
  attribute {
    name = "Timestamp"  # 属性名
    type = "S"          # 字符串类型
  }

  # 生存时间配置
  # 允许自动删除旧记录，节省存储成本
  ttl {
    attribute_name = "ExpirationTime"  # TTL属性名
    enabled        = var.enable_ttl     # 是否启用TTL
  }

  # 应用标签
  tags = merge(
    var.tags,
    {
      Name = var.audit_table_name
    },
  )
}

# 创建S3存储桶通知配置
# 当S3存储桶中的Terraform状态文件发生变化时，触发Lambda函数
# 这是实现自动审计的关键机制
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.s3_bucket_name  # S3存储桶名称

  # Lambda函数通知配置
  lambda_function {
    lambda_function_arn = aws_lambda_function.state_change_processor.arn  # Lambda函数ARN
    events              = [
      "s3:ObjectCreated:*",       # 所有创建对象事件
      "s3:ObjectRemoved:*",       # 所有删除对象事件
      "s3:ObjectRestore:*"        # 所有恢复对象事件
    ]      
    filter_prefix       = ""                                                # 前缀过滤器（空表示所有前缀）
    filter_suffix       = ".tfstate"                                        # 后缀过滤器（只处理.tfstate文件）
  }

  # 依赖关系，确保Lambda权限已配置
  depends_on = [aws_lambda_permission.allow_bucket]
}

# 创建Lambda函数处理S3事件
# Lambda函数是一种无服务器计算服务
# 这里用于在Terraform状态文件变更时执行审计逻辑
resource "aws_lambda_function" "state_change_processor" {
  function_name    = var.lambda_function_name                         # 函数名称
  filename         = data.archive_file.lambda_zip.output_path         # 函数代码包路径
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # 代码哈希，用于检测变更
  role             = aws_iam_role.lambda_exec.arn                    # 执行角色ARN
  handler          = "index.handler"                                 # 处理函数入口点
  runtime          = "nodejs16.x"                                    # 运行时环境
  timeout          = 30                                               # 超时时间（秒）
  memory_size      = 128                                              # 内存大小（MB）

  # 环境变量配置
  # 这些变量可以在Lambda函数中访问
  environment {
    variables = {
      AUDIT_TABLE_NAME = var.audit_table_name  # DynamoDB审计表名称
      CLOUDTRAIL_NAME  = var.cloudtrail_name  # CloudTrail跟踪名称
      ENABLE_TTL      = tostring(var.enable_ttl)  # TTL启用状态
    }
  }

  tags = var.tags  # 应用标签
}

# 允许S3触发Lambda函数
# 这个权限允许S3服务调用Lambda函数
# 没有这个权限，S3事件通知将无法触发Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"              # 权限声明ID
  action        = "lambda:InvokeFunction"                   # 允许的操作
  function_name = aws_lambda_function.state_change_processor.function_name  # 函数名称
  principal     = "s3.amazonaws.com"                        # 允许的服务主体
  source_arn    = "arn:aws:s3:::${var.s3_bucket_name}"      # 源资源ARN
}

# 打包Lambda函数代码
# 将JavaScript代码打包成ZIP文件，供Lambda使用
# 这是一个数据源，不是资源，不会创建任何AWS资源
data "archive_file" "lambda_zip" {
  type        = "zip"                                # 打包类型
  output_path = "${path.module}/lambda_function.zip" # 输出路径
  source_file = "${path.module}/lambda/index.js"    # 源代码文件
}