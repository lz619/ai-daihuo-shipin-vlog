# 不鸣 AI Omni 1.1 接口参考

## 适用范围

本参考仅用于用户选择 `omni-1.1` 时的首帧图生视频任务。模型支持单张首帧图生视频、竖屏 9:16、720P/1080P/4K 输出和 3 至 10 秒的整数时长；成片自带音效。最低可选生成时长为 3 秒。

## 已确认的接口规则

- **创建任务：** `POST https://api.lk888.ai/v1/media/generate`
- **查询任务：** `GET https://api.lk888.ai/v1/media/status?task_id={task_id}`
- **模型字段：** `model: "omni-1.1"`
- **鉴权：** 首选 `Authorization: Bearer <API_KEY>`。文档也兼容 `x-api-key`、`x-goog-api-key` 与查询参数 `key`；一次请求只使用一种已获用户授权的鉴权方式。
- **首帧：** `params.images` 只允许 1 张图片。可以传公网图片网址，或传 `data:<mime>;base64,<data>` 内联图片；单张解码后默认不超过 10MB，单次请求的全部内联图片解码后默认不超过 30MB，请求体默认不超过 50MB。
- **必填参数：** `params.aspect_ratio`、`params.resolution`、`params.duration`。
- **竖屏值：** `params.aspect_ratio: "9:16"`。
- **时长值：** 字符串形式的 `"3"` 至 `"10"`；按秒计费。
- **轮询：** 每 5 至 10 秒查询一次。使用 `is_final === true` 判断终态；使用 `state` 判断结果，取值为 `pending`、`running`、`success` 或 `failed`。不使用中文 `status` 或 `status_group` 做程序判断。
- **结果：** 在 `is_final === true` 且 `state === "success"` 时读取 `result_url`。文档说明该地址已完成转存。

## 任务创建请求结构

```json
{
  "model": "omni-1.1",
  "params": {
    "aspect_ratio": "9:16",
    "duration": "4",
    "images": ["<一张首帧的公网网址或内联数据网址>"],
    "resolution": "1080P"
  },
  "prompt": "<中文图生视频提示词>"
}
```

## 执行边界

- 只有用户明确要求“提交生成”且提供可用 API 密钥后，才能创建任务。
- **本机密钥位置：** 优先读取 Windows 环境变量 `BUMING_API_KEY`。如果不存在，可读取技能根目录下 `.secrets\buming-api-key.txt`；该文件只允许包含一行原始 API 密钥。不得将密钥写入项目状态、提示词、日志或聊天回复。
- 创建任务前，确认首帧状态为 `approved`，并按用户选择确定分辨率。
- 任务创建成功后，保存 `task_id`，按 5 至 10 秒间隔轮询；停止条件为 `is_final === true`。
- 成功时下载或保存 `result_url`；失败时记录 `error`、任务参数和失败状态，不自动重复扣费请求。
- `notify_url` 为可选回调地址。除非用户提供其公开可访问的回调地址并要求使用，否则不传此字段。
