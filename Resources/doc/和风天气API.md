# 和风天气（QWeather）免费接口文档（Markdown 格式）

**版本信息**：基于 v7 API（2025 年最新标准版）  
**免费范围**：所有“天气和基础服务”接口在每月请求量 ≤ 5 万次 内完全免费。注册账号后创建免费项目即可获取 Key 使用。  
**基址（Base URL）**：  
- 生产环境：`https://api.qweather.com/v7/`  
- 开发测试环境：`https://devapi.qweather.com/v7/`（推荐测试使用）  

**通用认证方式**：  
1. 简单 Key：`?key=YOUR_KEY`  
2. JWT 签名（推荐，更安全）  

**通用参数**：  
- `key`：你的 API Key（字符串，必填）  
- `location`：位置ID（从 GeoAPI 获取）或经纬度 `longitude,latitude`（字符串，必填，大多数接口）  
- `lang`：多语言支持（zh、en 等，默认 zh）  
- `unit`：单位制（m 公制、i 英制，部分接口支持）  
- `gzip`：是否启用压缩（yes/no）  

**通用返回**：JSON 格式  
```json
{
  "code": "200",  // 成功为 "200"，其他为错误码
  "updateTime": "2025-12-23T12:00+08:00",
  "fxLink": "http://...",  // 自述链接
  "refer": { ... }  // 数据来源
}
```
**常见错误码**：401（Key 无效）、402（超出配额）、404（位置无效）等。

以下为“天气和基础服务”中所有免费接口的详细文档。

## 1. 天气预报（Weather Forecast）

**官方文档**：https://dev.qweather.com/docs/api/weather/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 实时天气 | 当前天气状况 | `weather/now` | location（必填）<br>lang（可选） | now: temp, feelsLike, icon, text, windDir, windScale, humidity, precip, pressure, vis, cloud, dew |
| 7 天每日预报 | 未来 7 天每日天气 | `weather/7d` | location（必填） | daily 数组：fxDate, tempMax/tempMin, iconDay/iconNight, textDay/textNight, windDirDay, precip, uvIndex, humidity |
| 15 天每日预报 | 未来 15 天每日天气（免费版最高支持 15 天） | `weather/15d` | location（必填） | 同 7d，但数组更长 |
| 24 小时逐小时预报 | 未来 24 小时每小时天气 | `weather/24h` | location（必填） | hourly 数组：fxTime, temp, icon, text, precip, windDir, windScale, humidity, pop（降水概率） |
| 72 小时逐小时预报 | 未来 72 小时每小时天气 | `weather/72h` | location（必填） | 同 24h |
| 168 小时逐小时预报 | 未来 7 天每小时天气 | `weather/168h` | location（必填） | 同上 |

**示例请求**：  
`https://api.qweather.com/v7/weather/7d?location=101010100&key=YOUR_KEY`

## 2. 分钟级降水预报（Minutely Precipitation）

**官方文档**：https://dev.qweather.com/docs/api/minutely/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 5 分钟级降水 | 未来 2 小时内每 5 分钟降水预报（中国大陆 1km 精度） | `minutely/5m` | location=经度,纬度（必填，经纬度格式） | summary（文字概述）<br>minutely 数组：fxTime, precip（降水量 mm）, type（降水类型） |

**示例**：`https://api.qweather.com/v7/minutely/5m?location=116.41,39.90&key=YOUR_KEY`

## 3. 天气灾害预警（Weather Warning）

**官方文档**：https://dev.qweather.com/docs/api/warning/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 当前预警 | 指定地点正在生效的预警 | `warning/now` | location（必填）<br>lang（可选） | warning 数组：id, title, text（详细描述）, type, level（级别）, startTime, endTime, status, sender（发布单位） |

**示例**：`https://api.qweather.com/v7/warning/now?location=101010100&key=YOUR_KEY`

## 4. 生活指数（Lifestyle Indices）

**官方文档**：https://dev.qweather.com/docs/api/indices/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 1 天指数 | 今天及明日生活指数 | `indices/1d` | location（必填）<br>type（指数类型，必填，如 1,3,5 逗号分隔） | indices 数组：date, type（指数ID）, name, level, category, text（建议） |
| 3 天指数 | 未来 3 天生活指数 | `indices/3d` | 同上 | 同上，多天数组 |

**常见 type 值**（全部免费）：  
1 运动、2 洗车、3 穿衣、5 钓鱼、6 紫外线、8 旅游、9 花粉过敏、10 舒适度、11 感冒、12 空气污染扩散、13 空调、14 过敏、15 太阳镜、16 化妆  

**示例**：`https://api.qweather.com/v7/indices/1d?location=101010100&type=1,3,5&key=YOUR_KEY`

## 5. 空气质量（Air Quality）

**官方文档**：https://dev.qweather.com/docs/api/air-quality/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 实时空气质量 | 当前 AQI | `air/now` | location（必填） | now: aqi, level, category, primary（首要污染物）, pm10, pm2p5, no2, so2, co, o3 |
| 5 天空气质量预报 | 未来 5 天每日空气质量 | `air/5d` | location（必填） | daily 数组：fxDate, aqi, level, category |

**示例**：`https://api.qweather.com/v7/air/now?location=101010100&key=YOUR_KEY`

## 6. 时光机 - 历史天气（Historical Weather）

**官方文档**：https://dev.qweather.com/docs/api/time-machine/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 历史天气（过去 10 天） | 指定日期的历史实时天气 | `historical/weather` | location（必填）<br>date=YYYYMMDD（必填） | weather: tempMax/tempMin/tempAvg, icon, text, precip, windDir, windScale 等 |
| 历史空气质量 | 指定日期的历史 AQI | `historical/air` | 同上 | air: aqi, level, pm2p5 等 |

**注意**：仅支持最近 10 天历史数据。

## 7. GeoAPI - 地理位置服务

**官方文档**：https://dev.qweather.com/docs/api/geoapi/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 城市搜索 | 模糊搜索城市 | `geo/city/lookup` | location（关键词，必填）<br>adm（行政区，可选）<br>range（world/cn，可选）<br>number（返回数量，默认 10）<br>lang | places 数组：id（城市ID）, name, adm1/adm2, country, lat, lon, timezone |
| POI 搜索 | 兴趣点搜索 | `geo/poi/lookup` | location（关键词）<br>type（poi 类型） | 同上，更多 POI 信息 |

**示例**：`https://api.qweather.com/v7/geo/city/lookup?location=北京&key=YOUR_KEY`

## 8. 天文数据（Astronomy）

**官方文档**：https://dev.qweather.com/docs/api/astronomy/

| 接口 | 描述 | 请求 URL | 主要参数 | 返回字段要点 |
|------|------|----------|----------|--------------|
| 日出日落 | 指定日期日出日落时间 | `astronomy/sun` | location（必填）<br>date=YYYYMMDD（可选，默认今天） | sunrise, sunset, solarNoon, dayLength |
| 月升月落及月相 | 月亮数据 | `astronomy/moon` | 同上 | moonrise, moonset, moonPhase（月相名称及图标） |

**示例**：`https://api.qweather.com/v7/astronomy/sun?location=101010100&date=20251223&key=YOUR_KEY`

**注册与使用建议**：  
前往 https://console.qweather.com 注册 → 创建项目（免费） → 获取 Key。  
所有接口均支持 HTTPS，推荐添加 `gzip=yes` 压缩响应。  
如需更详细的响应示例或某个接口的完整 JSON 结构，可进一步查看官方文档对应页面。

如果某个具体接口需要代码调用示例（Swift、Python 等），随时告诉我！