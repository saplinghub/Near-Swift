import axios from 'axios';

export class AIService {
  constructor(config) {
    this.baseURL = config.baseURL;
    this.apiKey = config.apiKey;
    this.model = config.model;
  }

  async parseCountdown(text) {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const date = now.getDate();

    try {
      const response = await axios.post(
        `${this.baseURL}/v1/chat/completions`,
        {
          model: this.model,
          messages: [
            {
              role: 'system',
              content: `你是一个智能倒计时事件解析助手。当前时间：${year}年${month}月${date}日。

规则：
1. 理解用户意图，自动计算时间并生成合适的事件名称
2. 返回JSON：{"name":"事件名称","date":"YYYY-MM-DDTHH:mm","startDate":"YYYY-MM-DDTHH:mm"}
3. startDate 是事件开始时间，date 是目标时间

示例：
- "过年倒计时" → name:"春节倒计时🧧", startDate:现在, date:${year+1}-01-29T00:00
- "今年的进度" → name:"${year}年进度📊", startDate:${year}-01-01T00:00, date:${year}-12-31T23:59
- "高考倒计时" → name:"高考加油💪", startDate:现在, date:${year}-06-07T09:00
- "下周五下午3点项目上线" → name:"项目上线🚀", startDate:现在, date:计算下周五15:00
- "距离生日还有多久" → name:"生日快乐🎂", startDate:现在, date:今年生日或明年生日

要求：
- 事件名称简洁有趣，可加emoji
- 自动推断合理的时间
- 如果是进度类（如"今年进度"），startDate设为起点时间
- 如果是倒计时类，startDate设为当前时间`
            },
            {
              role: 'user',
              content: text
            }
          ],
          temperature: 0.7
        },
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json'
          }
        }
      );

      const content = response.data.choices[0].message.content;
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
      throw new Error('无法解析AI响应');
    } catch (error) {
      throw new Error(error.response?.data?.error?.message || error.message);
    }
  }
}
