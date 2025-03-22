// Terraform状态变更处理器
// 当S3存储桶中的tfstate文件发生变化时，此Lambda函数会被触发
// 它会查询CloudTrail以获取相关操作的用户信息，并将审计记录存储到DynamoDB
// 这样可以跟踪谁在什么时间修改了Terraform状态，对于安全审计和问题排查非常有用

// 导入AWS SDK，用于与AWS服务交互
const AWS = require('aws-sdk');
// 创建CloudTrail客户端，用于查询API调用历史
const cloudtrail = new AWS.CloudTrail();
// 创建DynamoDB文档客户端，用于存储审计记录
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    console.log('接收到S3事件:', JSON.stringify(event, null, 2));
    
    try {
        // 从环境变量获取配置
        const auditTableName = process.env.AUDIT_TABLE_NAME || 'terraform-state-audit';
        const cloudtrailName = process.env.CLOUDTRAIL_NAME || 'terraform-state-audit-trail';
        
        // 处理每个S3事件记录
        for (const record of event.Records) {
            // 获取S3事件详情
            const bucket = record.s3.bucket.name;
            const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
            const eventTime = record.eventTime;
            const eventName = record.eventName;
            
            console.log(`处理事件: ${eventName} 对于文件 ${key} 在存储桶 ${bucket}`);
            
            // 只处理.tfstate文件
            if (!key.endsWith('.tfstate')) {
                console.log('跳过非tfstate文件');
                continue;
            }
            
            // 查询CloudTrail获取相关事件
            // 扩大时间窗口，提高匹配概率
            const startTime = new Date(new Date(eventTime).getTime() - 120 * 60 * 1000); // 事件前120分钟
            const endTime = new Date(new Date(eventTime).getTime() + 30 * 60 * 1000);   // 事件后30分钟
            
            // 改进CloudTrail查询，使用多种属性组合查询以提高匹配精度
            // 注意：CloudTrail API不支持在同一请求中使用多个LookupAttributes进行AND操作
            // 因此我们需要分别查询并合并结果
            
            // 使用多种查询策略来提高匹配精度
            
            // 1. 按资源名称查询 - 存储桶名称
            const resourceNameParams = {
                LookupAttributes: [
                    {
                        AttributeKey: 'ResourceName',
                        AttributeValue: bucket
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                MaxResults: 50  // 增加结果数量以提高匹配概率
            };
            
            console.log('查询CloudTrail事件(按存储桶名称):', JSON.stringify(resourceNameParams, null, 2));
            const resourceNameEvents = await cloudtrail.lookupEvents(resourceNameParams).promise();
            
            // 2. 按资源类型查询 - S3对象
            const resourceTypeParams = {
                LookupAttributes: [
                    {
                        AttributeKey: 'ResourceType',
                        AttributeValue: 'AWS::S3::Object'
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                MaxResults: 50
            };
            
            console.log('查询CloudTrail事件(按S3对象类型):', JSON.stringify(resourceTypeParams, null, 2));
            const resourceTypeEvents = await cloudtrail.lookupEvents(resourceTypeParams).promise();
            
            // 3. 按事件名称查询 - 常见的S3操作
            // 查询多种S3操作事件类型，提高匹配概率
            // 增加更多S3事件类型，特别是与ObjectCreated:Put相关的事件
            const s3EventTypes = [
                'PutObject', 'CopyObject', 'UploadPart', 'CompleteMultipartUpload', 'InitiateMultipartUpload',
                'PutObjectAcl', 'RestoreObject', 'CreateMultipartUpload', 'PostObject', 'CopyObjectPart'
            ];
            let eventNameEvents = { Events: [] };
            
            // 对每种事件类型进行单独查询并合并结果
            for (const eventType of s3EventTypes) {
                const eventNameParams = {
                    LookupAttributes: [
                        {
                            AttributeKey: 'EventName',
                            AttributeValue: eventType
                        }
                    ],
                    StartTime: startTime,
                    EndTime: endTime,
                    MaxResults: 50
                };
                
                console.log(`查询CloudTrail事件(按${eventType}事件):`, JSON.stringify(eventNameParams, null, 2));
                const result = await cloudtrail.lookupEvents(eventNameParams).promise();
                if (result.Events && result.Events.length > 0) {
                    eventNameEvents.Events = [...eventNameEvents.Events, ...result.Events];
                }
            }
            
            // 3.1 额外查询CompleteMultipartUpload事件 - 这也是一种常见的S3上传方式
            const multipartUploadParams = {
                LookupAttributes: [
                    {
                        AttributeKey: 'EventName',
                        AttributeValue: 'CompleteMultipartUpload'
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                MaxResults: 50
            };
            
            console.log('查询CloudTrail事件(按CompleteMultipartUpload事件):', JSON.stringify(multipartUploadParams, null, 2));
            const multipartUploadEvents = await cloudtrail.lookupEvents(multipartUploadParams).promise();
            
            // 3.2 额外查询InitiateMultipartUpload事件 - 这包含了分段上传的初始用户信息
            const initiateMultipartParams = {
                LookupAttributes: [
                    {
                        AttributeKey: 'EventName',
                        AttributeValue: 'InitiateMultipartUpload'
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                MaxResults: 50
            };
            
            console.log('查询CloudTrail事件(按InitiateMultipartUpload事件):', JSON.stringify(initiateMultipartParams, null, 2));
            const initiateMultipartEvents = await cloudtrail.lookupEvents(initiateMultipartParams).promise();
            
            // 4. 按事件源查询 - S3服务
            const eventSourceParams = {
                LookupAttributes: [
                    {
                        AttributeKey: 'EventSource',
                        AttributeValue: 's3.amazonaws.com'
                    }
                ],
                StartTime: startTime,
                EndTime: endTime,
                MaxResults: 50
            };
            
            console.log('查询CloudTrail事件(按S3事件源):', JSON.stringify(eventSourceParams, null, 2));
            const eventSourceEvents = await cloudtrail.lookupEvents(eventSourceParams).promise();
            
            // 合并所有查询结果并去重
            const allEvents = [
                ...(resourceNameEvents.Events || []), 
                ...(resourceTypeEvents.Events || []),
                ...(eventNameEvents.Events || []),
                ...(multipartUploadEvents.Events || []),
                ...(initiateMultipartEvents.Events || []),
                ...(eventSourceEvents.Events || [])
            ];
            
            const uniqueEvents = [];
            const eventIds = new Set();
            
            for (const event of allEvents) {
                if (!eventIds.has(event.EventId)) {
                    eventIds.add(event.EventId);
                    uniqueEvents.push(event);
                }
            }
            
            // 过滤事件，优先考虑与当前S3对象相关的事件
            const filteredEvents = uniqueEvents.filter(event => {
                try {
                    const cloudTrailEvent = JSON.parse(event.CloudTrailEvent || '{}');
                    const resources = cloudTrailEvent.resources || [];
                    const requestParams = cloudTrailEvent.requestParameters || {};
                    
                    // 记录事件详情用于调试
                    console.log(`评估事件 ${event.EventId} (${event.EventName})`, JSON.stringify({
                        eventName: event.EventName,
                        requestParams: requestParams,
                        resources: event.Resources,
                        cloudTrailResources: resources
                    }, null, 2));
                    
                    // 检查事件是否与当前S3对象相关 - 增强版匹配逻辑
                    // 1. 检查资源ARN是否包含存储桶和对象键
                    const isResourceMatch = resources.some(resource => {
                        if (!resource.ARN) return false;
                        
                        // 检查存储桶匹配
                        const bucketMatch = resource.ARN.includes(bucket);
                        if (!bucketMatch) return false;
                        
                        // 提取资源ARN中的对象键
                        const arnParts = resource.ARN.split(':');
                        const resourcePath = arnParts.length > 5 ? arnParts[5] : '';
                        const resourceKey = resourcePath.startsWith('object/') ? resourcePath.substring(7) : resourcePath;
                        
                        // 检查对象键匹配 - 使用多种匹配策略
                        return (
                            resource.ARN.includes(key) || 
                            resource.ARN.endsWith(key) || 
                            key.endsWith(resource.ARN.split('/').pop() || '') ||
                            (resourceKey && (key === resourceKey || key.endsWith(resourceKey) || resourceKey.endsWith('.tfstate')))
                        );
                    });
                    
                    // 2. 检查请求参数中的键是否匹配 - 增强版匹配逻辑
                    const isKeyMatch = requestParams.key === key || 
                                      requestParams.Key === key ||
                                      (requestParams.key && key.endsWith(requestParams.key)) ||
                                      (requestParams.Key && key.endsWith(requestParams.Key)) ||
                                      (requestParams.key && requestParams.key.endsWith('.tfstate')) ||
                                      (requestParams.Key && requestParams.Key.endsWith('.tfstate')) ||
                                      // 检查S3事件通知中的特殊格式
                                      (cloudTrailEvent.eventName === 'PutObject' && 
                                       (requestParams.key && key.includes(requestParams.key) || 
                                        requestParams.Key && key.includes(requestParams.Key))) ||
                                      // 检查S3事件源和对象键后缀
                                      (event.EventSource === 's3.amazonaws.com' && key.endsWith('.tfstate'));
                    
                    // 3. 检查分段上传的特殊情况
                    const isMultipartMatch = 
                        (event.EventName === 'InitiateMultipartUpload' || 
                         event.EventName === 'CompleteMultipartUpload' || 
                         event.EventName === 'UploadPart') && 
                        ((requestParams.bucket === bucket || requestParams.bucketName === bucket) &&
                        ((requestParams.key && (requestParams.key === key || key.endsWith(requestParams.key) || requestParams.key.endsWith('.tfstate'))) ||
                         (requestParams.Key && (requestParams.Key === key || key.endsWith(requestParams.Key) || requestParams.Key.endsWith('.tfstate')))));
                    
                    // 4. 检查事件资源是否包含存储桶名称
                    const isBucketMatch = event.Resources && event.Resources.some(r => r.ResourceName === bucket);
                    
                    // 5. 检查事件名称是否与S3对象操作相关
                    const isS3ObjectEvent = [
                        'PutObject', 'CopyObject', 'UploadPart', 'CompleteMultipartUpload', 'InitiateMultipartUpload',
                        'PutObjectAcl', 'RestoreObject', 'CreateMultipartUpload', 'PostObject', 'CopyObjectPart'
                    ].includes(event.EventName) && 
                    (
                        requestParams.bucket === bucket || 
                        requestParams.bucketName === bucket ||
                        // 检查CloudTrail事件中的其他可能包含存储桶信息的字段
                        (cloudTrailEvent.resources && cloudTrailEvent.resources.some(r => 
                            r.type === 'AWS::S3::Bucket' && r.ARN && r.ARN.includes(bucket)
                        )) ||
                        // 检查事件源是否为S3
                        (event.EventSource === 's3.amazonaws.com' && 
                         (requestParams.key && requestParams.key.endsWith('.tfstate') ||
                          requestParams.Key && requestParams.Key.endsWith('.tfstate')))
                    );
                    
                    return isResourceMatch || isKeyMatch || isMultipartMatch || isBucketMatch || isS3ObjectEvent;
                } catch (e) {
                    console.log('解析事件时出错:', e);
                    return true; // 如果解析出错，保留事件以防万一
                }
            });
            
            // 如果过滤后没有事件，则使用所有唯一事件
            // 优先考虑与S3 PutObject相关的事件
            let finalEvents = filteredEvents.length > 0 ? filteredEvents : uniqueEvents;
            
            // 特别处理ObjectCreated:Put事件
            if (eventName === 'ObjectCreated:Put') {
                // 尝试找到最匹配的PutObject事件
                const putObjectEvents = finalEvents.filter(event => 
                    event.EventName === 'PutObject' || 
                    event.EventName === 'CompleteMultipartUpload' ||
                    event.EventName === 'InitiateMultipartUpload' ||
                    event.EventName === 'UploadPart'
                );
                
                if (putObjectEvents.length > 0) {
                    console.log(`找到 ${putObjectEvents.length} 个PutObject相关事件，优先使用这些事件`);
                    finalEvents = putObjectEvents;
                } else {
                    // 如果没有找到PutObject相关事件，尝试使用任何S3相关事件
                    const s3Events = finalEvents.filter(event => 
                        event.EventSource === 's3.amazonaws.com' ||
                        (event.Resources && event.Resources.some(r => r.ResourceType === 'AWS::S3::Object' || r.ResourceType === 'AWS::S3::Bucket'))
                    );
                    
                    if (s3Events.length > 0) {
                        console.log(`找到 ${s3Events.length} 个S3相关事件，使用这些事件作为备选`);
                        finalEvents = s3Events;
                    }
                }
            }
            
            console.log(`找到 ${uniqueEvents.length} 个相关事件，过滤后剩余 ${finalEvents.length} 个事件`);
            
            // 找到最相关的事件（优先考虑过滤后的事件，并按时间接近度排序）
            let relevantEvent = null;
            let minTimeDiff = Infinity;
            
            // 首先尝试从过滤后的事件中找到最接近的事件
            for (const event of finalEvents || []) {
                const eventTimeObj = new Date(event.EventTime);
                const timeDiff = Math.abs(eventTimeObj.getTime() - new Date(eventTime).getTime());
                
                if (timeDiff < minTimeDiff) {
                    minTimeDiff = timeDiff;
                    relevantEvent = event;
                }
            }
            
            // 提取用户信息 - 增强版，更好地识别子账号
            let userIdentity = '未知';
            let eventSource = '未知';
            let eventType = eventName;
            let accountId = '未知';
            let userType = '未知';
            
            // 如果没有找到相关事件，尝试直接从S3事件中提取信息
            if (!relevantEvent && record.userIdentity) {
                console.log('未找到CloudTrail事件，尝试从S3事件中提取用户信息:', JSON.stringify(record.userIdentity, null, 2));
                
                // 从S3事件中提取用户信息
                if (record.userIdentity.principalId) {
                    const principalParts = record.userIdentity.principalId.split(':');
                    if (principalParts.length > 1) {
                        // AWS:username 格式
                        userIdentity = principalParts[1];
                        userType = 'IAMUser';
                    } else {
                        userIdentity = record.userIdentity.principalId;
                    }
                }
                
                if (record.awsRegion) {
                    eventSource = `s3.${record.awsRegion}.amazonaws.com`;
                } else {
                    eventSource = 's3.amazonaws.com';
                }
                
                accountId = record.userIdentity.accountId || '未知';
            }
            
            if (relevantEvent) {
                const cloudTrailEvent = JSON.parse(relevantEvent.CloudTrailEvent);
                
                // 记录完整的CloudTrail事件用于调试
                console.log('选中的CloudTrail事件:', JSON.stringify({
                    eventId: relevantEvent.EventId,
                    eventName: relevantEvent.EventName,
                    eventTime: relevantEvent.EventTime,
                    fullEvent: cloudTrailEvent
                }, null, 2));
                
                // 提取账号ID
                accountId = cloudTrailEvent.recipientAccountId || 
                            (cloudTrailEvent.userIdentity?.accountId) || 
                            '未知';
                
                // 提取用户类型
                userType = cloudTrailEvent.userIdentity?.type || '未知';
                
                // 记录原始用户身份信息用于调试
                console.log('原始用户身份信息:', JSON.stringify({
                    userIdentity: cloudTrailEvent.userIdentity,
                    eventName: cloudTrailEvent.eventName,
                    eventSource: cloudTrailEvent.eventSource,
                    requestParameters: cloudTrailEvent.requestParameters
                }, null, 2));
                
                // 根据用户类型提取最合适的身份标识
                if (userType === 'AssumedRole') {
                    // 对于扮演角色的用户，提取更多信息以识别子账号
                    const arnParts = (cloudTrailEvent.userIdentity?.arn || '').split('/');
                    const sessionName = arnParts.length > 1 ? arnParts[1] : '';
                    
                    // 从ARN中提取角色名称
                    const arnSegments = (cloudTrailEvent.userIdentity?.arn || '').split(':');
                    const rolePathAndName = arnSegments.length > 5 ? arnSegments[5].split('/') : [];
                    const roleName = rolePathAndName.length > 0 ? rolePathAndName[rolePathAndName.length - 1].split('/')[0] : '';
                    
                    // 检查sessionContext中的信息
                    const sessionContext = cloudTrailEvent.userIdentity?.sessionContext || {};
                    const sessionIssuer = sessionContext.sessionIssuer || {};
                    
                    // 记录详细的会话信息用于调试
                    // 这些信息对于理解AssumedRole类型的用户身份非常重要
                    // 包括ARN、会话名称、会话发起者和会话上下文等关键信息
                    console.log('AssumedRole详细信息:', JSON.stringify({
                        arn: cloudTrailEvent.userIdentity?.arn,
                        sessionName: sessionName,
                        roleName: roleName,
                        sessionIssuer: sessionIssuer,
                        sessionContext: sessionContext
                    }, null, 2));
                    
                    // 用户身份识别策略 - 增强版：
                    // 1. 首先尝试使用会话名称（通常是最具辨识度的标识符）
                    // 2. 如果会话名称不可用，尝试使用角色名称和会话发起者组合
                    // 3. 如果以上都不可用，则使用完整ARN作为标识符
                    
                    // 优先使用会话名称，如果会话名称看起来像IAM用户名，则很可能是子账号
                    if (sessionName && !sessionName.startsWith('i-') && !sessionName.startsWith('AIDA')) {
                        userIdentity = sessionName;
                    } 
                    // 其次尝试从sessionIssuer获取信息
                    else if (sessionIssuer.userName) {
                        userIdentity = `${sessionIssuer.userName} (via ${roleName || sessionIssuer.type})`;
                    }
                    // 尝试使用角色名称
                    else if (roleName) {
                        userIdentity = `Role:${roleName}`;
                    }
                    // 最后使用完整ARN
                    else {
                        userIdentity = cloudTrailEvent.userIdentity?.arn || '未知';
                    }
                } else if (userType === 'IAMUser') {
                    // 对于IAM用户，优先使用用户名
                    // 子账号通常是IAM用户类型
                    
                    // 记录更多调试信息
                    console.log('IAM用户详细信息:', JSON.stringify({
                        userName: cloudTrailEvent.userIdentity?.userName,
                        directUserName: cloudTrailEvent.userName,
                        arn: cloudTrailEvent.userIdentity?.arn,
                        sessionContext: cloudTrailEvent.userIdentity?.sessionContext,
                        accessKeyId: cloudTrailEvent.userIdentity?.accessKeyId,
                        fullUserIdentity: cloudTrailEvent.userIdentity
                    }, null, 2));
                    
                    // 优先使用userName，这是最可靠的子账号标识符
                    // 增强子账号识别逻辑
                    const userName = cloudTrailEvent.userIdentity?.userName ||
                                    cloudTrailEvent.userName;
                    
                    const arnUserName = cloudTrailEvent.userIdentity?.arn ? 
                                      cloudTrailEvent.userIdentity.arn.split('/').pop() : null;
                    
                    // 检查是否有会话上下文信息
                    const sessionContext = cloudTrailEvent.userIdentity?.sessionContext || {};
                    const sessionIssuer = sessionContext.sessionIssuer || {};
                    const sessionUserName = sessionIssuer.userName;
                    
                    // 优先级：直接用户名 > ARN中的用户名 > 会话用户名 > 访问密钥 > ARN
                    userIdentity = userName || 
                                  arnUserName || 
                                  sessionUserName ||
                                  cloudTrailEvent.userIdentity?.accessKeyId || 
                                  cloudTrailEvent.userIdentity?.arn || 
                                  '未知';
                } else if (userType === 'Root') {
                    // 根账号
                    userIdentity = '根账号';
                } else if (userType === 'AWSService') {
                    // AWS服务
                    userIdentity = `AWS服务 (${cloudTrailEvent.userIdentity?.invokedBy || '未知服务'})`;
                } else if (userType === 'FederatedUser') {
                    // 联合身份用户
                    const federatedUserArn = cloudTrailEvent.userIdentity?.arn || '';
                    const federatedUserName = federatedUserArn.split('/').pop() || '';
                    
                    console.log('联合身份用户详细信息:', JSON.stringify({
                        arn: federatedUserArn,
                        principalId: cloudTrailEvent.userIdentity?.principalId,
                        userName: federatedUserName,
                        fullUserIdentity: cloudTrailEvent.userIdentity
                    }, null, 2));
                    
                    userIdentity = federatedUserName || 
                                  cloudTrailEvent.userIdentity?.principalId || 
                                  federatedUserArn || 
                                  '联合身份用户';
                } else {
                    // 其他情况，尝试使用可用的任何标识符
                    console.log('其他用户类型详细信息:', JSON.stringify({
                        type: userType,
                        identity: cloudTrailEvent.userIdentity
                    }, null, 2));
                    
                    userIdentity = cloudTrailEvent.userIdentity?.arn || 
                                   cloudTrailEvent.userIdentity?.userName || 
                                   cloudTrailEvent.userIdentity?.principalId || 
                                   cloudTrailEvent.userIdentity?.accessKeyId || 
                                   '未知';
                }
                
                eventSource = relevantEvent.EventSource || '未知';
                eventType = relevantEvent.EventName || eventType;
                
                console.log('提取的用户信息:', {
                    userIdentity,
                    userType,
                    accountId,
                    eventSource,
                    eventType
                });
            }
            
            // 创建增强版审计记录，包含更多用户身份信息
            const auditRecord = {
                StateFileKey: key,
                Timestamp: eventTime,
                EventType: eventType,
                EventSource: eventSource,
                UserIdentity: userIdentity,
                UserType: userType,
                AccountId: accountId,
                BucketName: bucket,
                // 可选：设置TTL（如果启用）
                ExpirationTime: process.env.ENABLE_TTL === 'true' ? Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) : null // 90天后过期
            };
            
            // 存储到DynamoDB
            const params = {
                TableName: auditTableName,
                Item: auditRecord
            };
            
            console.log('存储审计记录:', params);
            await dynamodb.put(params).promise();
            console.log('审计记录已存储');
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: '处理成功' })
        };
    } catch (error) {
        // 增强错误日志记录，包含更多上下文信息
        console.error('处理错误:', {
            errorMessage: error.message,
            errorStack: error.stack,
            errorName: error.name,
            eventCount: event.Records ? event.Records.length : 0,
            timestamp: new Date().toISOString()
        });
        
        // 尝试记录更多诊断信息
        try {
            if (event.Records && event.Records.length > 0) {
                const record = event.Records[0];
                console.error('事件记录样本:', {
                    eventSource: record.eventSource,
                    eventName: record.eventName,
                    s3: {
                        bucket: record.s3?.bucket?.name,
                        key: record.s3?.object?.key
                    }
                });
            }
        } catch (logError) {
            console.error('记录诊断信息时出错:', logError);
        }
        
        return {
            statusCode: 500,
            body: JSON.stringify({ 
                message: '处理失败', 
                error: error.message,
                timestamp: new Date().toISOString()
            })
        };
    }
};