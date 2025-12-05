<template>
  <div class="app-container">
    <!-- 主卡片 -->
    <div class="main-panel">
      <!-- 头部 -->
      <header class="header">
        <div class="app-title">Near 倒计时</div>
        <div class="header-actions">
          <div class="tab-switch">
            <button
              class="tab-btn"
              :class="{ active: currentTab === 'upcoming' }"
              @click="currentTab = 'upcoming'"
            >
              进行中
            </button>
            <button
              class="tab-btn"
              :class="{ active: currentTab === 'completed' }"
              @click="currentTab = 'completed'"
            >
              已结束
            </button>
          </div>
          <button class="settings-btn" @click="showSettings = true" title="设置">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="3"></circle>
              <path d="M12 1v6m0 6v6m-9-9h6m6 0h6m-2.636-6.364l-4.243 4.243m0 4.242l4.243 4.243M6.343 6.343l4.243 4.243m0 4.242l-4.243 4.243"></path>
            </svg>
          </button>
        </div>
      </header>

      <!-- 列表内容 -->
      <div class="list-container">
        <div v-if="filteredCountdowns.length === 0" class="empty-state">
          <div class="empty-icon">🍃</div>
          <p>暂无{{ currentTab === 'upcoming' ? '进行中' : '已结束' }}的事件</p>
        </div>

        <div v-for="item in filteredCountdowns" :key="item.id"
          class="list-item"
          :data-id="item.id">
          <!-- 左侧图标 -->
          <div class="item-icon" :class="item.iconType || 'rocket'">
            <span v-html="getIconSvg(item.iconType)"></span>
          </div>

          <!-- 中间信息 -->
          <div class="item-content">
            <div class="item-header-row">
              <div class="item-title">{{ item.name }}</div>
              <div class="item-date-small">{{ formatDate(item.date) }}</div>
            </div>
            
            <div class="item-details">
              <div class="timer-group">
                <span class="days-num">{{ calculateDays(item.date) }}</span>
                <span class="days-label">天</span>
                <span class="time-detail">{{ calculateTimeDetail(item.date) }}</span>
              </div>
            </div>

            <!-- 进度条 (移到内容下方，更宽敞) -->
            <div class="progress-container">
              <div class="progress-bar">
                <div class="progress-fill" :style="{ width: calculateProgress(item) + '%' }"></div>
              </div>
              <span class="progress-text">{{ calculateProgress(item) }}%</span>
            </div>
          </div>

          <!-- 按钮组 (绝对定位，但有足够的 padding 保护内容) -->
          <div class="item-actions">
            <button
              class="action-btn delete"
              @click.stop="deleteCountdown(item.id)"
              title="删除">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
            </button>
            
            <button 
              v-if="currentTab === 'upcoming'"
              class="action-btn pin" 
              :class="{ active: item.pinned }" 
              @click.stop="pinCountdown(item.id)" 
              title="置顶"
            >
              <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" stroke="none">
                <path d="M16,12V4H17V2H7V4H8V12L6,14V16H11.2V22H12.8V16H18V14L16,12Z" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- 悬浮添加按钮 (FAB) -->
      <button class="fab-btn" @click="showForm = true" title="新建倒计时">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <line x1="12" y1="5" x2="12" y2="19"></line>
          <line x1="5" y1="12" x2="19" y2="12"></line>
        </svg>
      </button>
    </div>

    <!-- 设置页面 -->
    <transition name="slide">
      <div v-if="showSettings" class="modal-overlay" @click="showSettings = false">
        <div class="settings-page" @click.stop>
          <div class="settings-page-header">
          <button class="settings-close-btn" @click="showSettings = false">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
          <h2>设置</h2>
          <button class="settings-save-btn" @click="saveAIConfigData">保存</button>
        </div>

      <div class="settings-tabs">
        <button
          class="settings-tab-btn"
          :class="{ active: settingsTab === 'ai' }"
          @click="settingsTab = 'ai'"
        >
          ✨ AI 配置
        </button>
      </div>

        <div class="settings-body" v-if="settingsTab === 'ai'">
          <div class="form-group">
            <label>API URL</label>
            <input v-model="aiConfig.baseURL" placeholder="https://your-api.com" />
          </div>
          <div class="form-group">
            <label>API Key</label>
            <input v-model="aiConfig.apiKey" type="password" placeholder="sk-..." />
          </div>
          <div class="form-group">
            <label>模型</label>
            <input v-model="aiConfig.model" placeholder="gpt-4" />
          </div>
          <button class="btn-test-full" @click="testAIConfig" :disabled="aiLoading">
            {{ aiLoading ? '测试中...' : '🧪 测试连接' }}
          </button>
        </div>
        </div>
      </div>
    </transition>

    <!-- 添加/编辑页面 -->
    <transition name="slide">
      <div v-if="showForm" class="modal-overlay" @click="cancelEdit">
        <div class="form-page" @click.stop>
        <div class="form-page-header">
          <button class="header-close-btn" @click="cancelEdit">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
          <h2>{{ editingId ? '编辑倒计时' : '新建倒计时' }}</h2>
          <button class="header-save-btn" @click="addCountdown" :disabled="!form.name || !form.date">保存</button>
        </div>

        <div class="form-page-body">
          <div class="form-group">
            <label>AI 智能解析</label>
            <div class="ai-input-group">
              <input v-model="aiInput" placeholder="例如：过年倒计时 / 今年的进度" @keyup.enter="parseWithAI" />
              <button class="ai-btn" @click="parseWithAI" :disabled="aiLoading">
                {{ aiLoading ? '解析中...' : '✨ AI' }}
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>事件名称</label>
            <input v-model="form.name" placeholder="例如：项目上线" autofocus />
          </div>

          <div class="form-group">
            <label>开始时间</label>
            <input v-model="form.startDate" type="datetime-local" class="date-input" />
          </div>

          <div class="form-group">
            <label>目标时间</label>
            <input v-model="form.date" type="datetime-local" class="date-input" />
          </div>

          <div class="form-group">
            <label>选择图标</label>
            <div class="icon-selector">
              <div
                v-for="type in ['rocket', 'palm', 'headphone', 'code', 'gift']"
                :key="type"
                class="icon-option"
                :class="{ selected: form.iconType === type }"
                @click="form.iconType = type"
              >
                <div class="icon-preview" :class="type" v-html="getIconSvg(type)"></div>
              </div>
            </div>
          </div>
        </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';
import { invoke } from '@tauri-apps/api/core';
import { AIService } from './ai-service.js';
import Sortable from 'sortablejs';

const countdowns = ref([]);
const currentTab = ref('upcoming');
const showForm = ref(false);
const showSettings = ref(false);
const settingsTab = ref('ai');
const form = ref({ name: '', date: '', startDate: '', iconType: 'rocket' });
const aiInput = ref('');
const aiConfig = ref({ baseURL: '', apiKey: '', model: '' });
const aiLoading = ref(false);
const editingId = ref(null);
let timer = null;
let sortableInstance = null;

const initSortable = () => {
  nextTick(() => {
    const container = document.querySelector('.list-container');
    console.log('initSortable called, container:', container);
    console.log('container children:', container?.children.length);

    if (!container) return;

    if (sortableInstance) {
      sortableInstance.destroy();
    }

    sortableInstance = Sortable.create(container, {
      animation: 150,
      forceFallback: true,
      fallbackClass: 'sortable-fallback',
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      filter: '.empty-state',
      onStart: (evt) => {
        console.log('Sortable onStart:', evt.oldIndex);
      },
      onEnd: async (evt) => {
        console.log('Sortable onEnd:', evt.oldIndex, '->', evt.newIndex);
        const { oldIndex, newIndex } = evt;
        if (oldIndex === newIndex) return;

        try {
          const filtered = filteredCountdowns.value;

          const ids = [...filtered.map(f => f.id)];
          const [movedId] = ids.splice(oldIndex, 1);
          ids.splice(newIndex, 0, movedId);

          for (let i = 0; i < ids.length; i++) {
            const item = countdowns.value.find(c => c.id === ids[i]);
            if (item) item.order = i;
          }

          countdowns.value = [...countdowns.value];

          for (const item of countdowns.value) {
            if (ids.includes(item.id)) {
              await invoke('save_countdown', { countdown: item });
            }
          }

          showToast('排序已保存', 'success');
        } catch (error) {
          console.error('排序失败:', error);
          showToast('排序失败: ' + error, 'error');
          await loadCountdowns();
        }
      }
    });

    console.log('Sortable instance created:', sortableInstance);
  });
};

watch(currentTab, () => {
  initSortable();
});

// 图标 SVG 定义
const icons = {
  rocket: '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"></path><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"></path><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"></path><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"></path></svg>',
  palm: '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M13 8c0-2.76-2.46-5-5.5-5S2 5.24 2 8h2c0-1.66 1.57-3 3.5-3S11 6.34 11 8h2z"></path><path d="M13 7.14A5.82 5.82 0 0 1 16.5 6c3.04 0 5.5 2.24 5.5 5h-2c0-1.66-1.57-3-3.5-3a3.8 3.8 0 0 0-3.5 2.14"></path><path d="M16 10c0-2.76-2.46-5-5.5-5S5 7.24 5 10h2c0-1.66 1.57-3 3.5-3S14 8.34 14 10h2z"></path><path d="M14 10v10"></path></svg>',
  headphone: '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M3 18v-6a9 9 0 0 1 18 0v6"></path><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"></path></svg>',
  code: '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>',
  gift: '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 12 20 22 4 22 4 12"></polyline><rect x="2" y="7" width="20" height="5"></rect><line x1="12" y1="22" x2="12" y2="7"></line><path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z"></path><path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"></path></svg>'
};

const getIconSvg = (type) => icons[type] || icons.rocket;

const loadCountdowns = async () => {
  const data = await invoke('get_countdowns');
  countdowns.value = data.map(item => {
    if (!item.startDate) {
      const target = new Date(item.date);
      const start = item.createdAt ? new Date(item.createdAt) : new Date(target);
      if (!item.createdAt) start.setDate(start.getDate() - 30);

      const toLocalISO = (d) => {
        const pad = (n) => n < 10 ? '0' + n : n;
        return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
      };

      return { ...item, startDate: toLocalISO(start), iconType: item.iconType || 'rocket', order: item.order || 0 };
    }
    return { ...item, order: item.order || 0 };
  });
};

const filteredCountdowns = computed(() => {
  const now = new Date();
  now.setHours(0,0,0,0);

  return countdowns.value.filter(item => {
    const target = new Date(item.date);
    target.setHours(0,0,0,0);
    const isCompleted = target < now;
    return currentTab.value === 'completed' ? isCompleted : !isCompleted;
  }).sort((a, b) => (a.order || 0) - (b.order || 0));
});

const calculateDays = (targetDate) => {
  const now = new Date();
  const target = new Date(targetDate);
  const nowStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetStart = new Date(target.getFullYear(), target.getMonth(), target.getDate());
  
  const diff = targetStart - nowStart;
  const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
  return days > 0 ? days : 0;
};

const calculateTimeDetail = (targetDate) => {
  const now = new Date();
  const target = new Date(targetDate);
  
  let diff = target - now;
  if (diff < 0) return '已结束';

  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  
  return `${hours}小时 ${minutes}分`;
};

const calculateProgress = (item) => {
  const start = new Date(item.startDate).getTime();
  const end = new Date(item.date).getTime();
  const now = new Date().getTime();
  
  if (now >= end) return 100;
  if (now <= start) return 0;
  
  const total = end - start;
  const current = now - start;
  return Math.round((current / total) * 100);
};

const formatDate = (dateStr) => {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric' });
};

const addCountdown = async () => {
  if (!form.value.name || !form.value.date) return;

  const startDate = form.value.startDate || new Date().toISOString();

  try {
    await invoke('save_countdown', {
      countdown: {
        id: editingId.value || `countdown-${Date.now()}`,
        name: form.value.name,
        date: form.value.date,
        startDate: startDate,
        iconType: form.value.iconType,
        createdAt: new Date().toISOString(),
        order: countdowns.value.length
      }
    });

    resetForm();
    await loadCountdowns();
  } catch (error) {
    console.error('保存倒计时失败:', error);
    alert('保存失败: ' + error);
  }
};

const editCountdown = (item) => {
  editingId.value = item.id;
  form.value = {
    name: item.name,
    date: item.date,
    startDate: item.startDate,
    iconType: item.iconType || 'rocket'
  };
  showForm.value = true;
};

const cancelEdit = () => {
  resetForm();
};

const resetForm = () => {
  const now = new Date();
  const pad = (n) => n < 10 ? '0' + n : n;
  const currentLocal = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
  
  form.value = { name: '', date: '', startDate: currentLocal, iconType: 'rocket' };
  editingId.value = null;
  showForm.value = false;
};

const deleteCountdown = async (id) => {
  console.log('[删除] 开始删除，ID:', id);

  try {
    console.log('[删除] 调用 Tauri 命令');
    const result = await invoke('delete_countdown', { id: id });
    console.log('[删除] Tauri 返回:', result);
    showToast('删除成功', 'success');
    await loadCountdowns();
    console.log('[删除] 完成');
  } catch (error) {
    console.error('[删除] 失败:', error);
    showToast('删除失败: ' + error, 'error');
  }
};

const pinCountdown = async (id) => {
  try {
    await invoke('pin_countdown', { id: id });
    await loadCountdowns();
  } catch (error) {
    console.error('置顶失败:', error);
    showToast('置顶失败: ' + error, 'error');
  }
};

const loadAIConfig = async () => {
  const config = await invoke('get_ai_config');
  if (config) {
    aiConfig.value = config;
  }
};

const saveAIConfigData = async () => {
  try {
    const config = {
      baseURL: aiConfig.value.baseURL,
      apiKey: aiConfig.value.apiKey,
      model: aiConfig.value.model
    };
    await invoke('save_ai_config', { config });
    alert('✅ 配置保存成功');
    showSettings.value = false;
  } catch (error) {
    alert('❌ 保存失败: ' + error.message);
  }
};

const testAIConfig = async () => {
  if (!aiConfig.value.baseURL || !aiConfig.value.apiKey || !aiConfig.value.model) {
    showToast('⚠️ 请先填写完整配置', 'warning');
    return;
  }

  aiLoading.value = true;
  try {
    const service = new AIService(aiConfig.value);
    await service.parseCountdown('测试连接');
    showToast('✅ 连接成功！AI 配置正常', 'success');
  } catch (error) {
    showToast('❌ 连接失败: ' + error.message, 'error');
  } finally {
    aiLoading.value = false;
  }
};

const showToast = (message, type = 'info') => {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
};

const parseWithAI = async () => {
  if (!aiInput.value.trim()) return;
  if (!aiConfig.value.baseURL || !aiConfig.value.apiKey || !aiConfig.value.model) {
    alert('请先配置 AI 设置');
    showSettings.value = true;
    return;
  }

  aiLoading.value = true;
  try {
    const service = new AIService(aiConfig.value);
    const result = await service.parseCountdown(aiInput.value);
    form.value.name = result.name;
    form.value.date = result.date;
    if (result.startDate) {
      form.value.startDate = result.startDate;
    }
    aiInput.value = '';
  } catch (error) {
    alert('AI 解析失败: ' + error.message);
  } finally {
    aiLoading.value = false;
  }
};

onMounted(async () => {
  await loadCountdowns();
  loadAIConfig();
  initSortable();
  timer = setInterval(() => {
    countdowns.value = [...countdowns.value];
  }, 60000);
});

onUnmounted(() => {
  if (timer) clearInterval(timer);
  if (sortableInstance) sortableInstance.destroy();
});
</script>

<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
}

:root {
  --bg-gradient-start: #F8FAFC;
  --bg-gradient-end: #E2E8F0;
  --card-bg: #FFFFFF;
  --text-primary: #1E293B;
  --text-secondary: #64748B;
  --primary-gradient: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%);
  --primary-shadow: rgba(99, 102, 241, 0.3);
  --border-light: rgba(0,0,0,0.04);
}

.app-container {
  height: 100vh;
  width: 100vw;
  background: transparent;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 12px;
  box-sizing: border-box;
  overflow: hidden;
}

.main-panel {
  width: 100%;
  height: 100%;
  background: linear-gradient(to bottom right, var(--bg-gradient-start), var(--bg-gradient-end));
  border: 1px solid #FFFFFF;
  border-radius: 20px;
  box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0,0,0,0.02);
  display: flex;
  flex-direction: column;
  position: relative;
  z-index: 1;
  overflow: hidden;
}

.header {
  padding: 20px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(255,255,255,0.6);
  backdrop-filter: blur(10px);
  z-index: 10;
  border-bottom: 1px solid rgba(0,0,0,0.05);
}

.app-title {
  font-size: 17px;
  font-weight: 700;
  color: var(--text-primary);
  letter-spacing: -0.5px;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.settings-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: rgba(0,0,0,0.04);
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.settings-btn:hover {
  background: rgba(0,0,0,0.08);
  color: var(--text-primary);
}

.tab-switch {
  background: rgba(0,0,0,0.04);
  padding: 4px;
  border-radius: 12px;
  display: flex;
  gap: 4px;
}

.tab-btn {
  border: none;
  background: transparent;
  padding: 6px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.tab-btn.active {
  background: #FFFFFF;
  color: #6366F1;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}

.list-container {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  background: transparent;
  padding-bottom: 80px;
  position: relative;
}

.list-container::-webkit-scrollbar {
  display: none;
}

.list-item {
  background: var(--card-bg);
  border-radius: 12px;
  padding: 10px 40px 10px 12px;
  display: flex;
  align-items: center;
  gap: 12px;
  transition: all 0.15s ease-out;
  position: relative;
  box-shadow: 0 2px 4px -1px rgba(0, 0, 0, 0.02);
  border: 1px solid rgba(255,255,255,0.5);
  cursor: grab;
}

.list-item:hover:not(.sortable-drag) {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05), 0 4px 6px -2px rgba(0, 0, 0, 0.02);
}

.item-icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 18px;
  transition: all 0.3s;
}

.item-icon.rocket { background: #EEF2FF; color: #6366F1; }
.item-icon.palm { background: #ECFDF5; color: #10B981; }
.item-icon.headphone { background: #FDF4FF; color: #8B5CF6; }
.item-icon.code { background: #F0F9FF; color: #0EA5E9; }
.item-icon.gift { background: #FFF1F2; color: #F43F5E; }

.item-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.item-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 2px;
}

.item-header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  width: 100%;
}

.item-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex: 1;
  text-align: left;
}

.item-date-small {
  font-size: 11px;
  color: var(--text-secondary);
  font-weight: 500;
  white-space: nowrap;
  text-align: right;
  flex-shrink: 0;
  margin-left: auto;
}

.item-info {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 8px;
}

.timer-compact {
  display: flex;
  align-items: baseline;
  gap: 3px;
}

.days-num {
  font-size: 18px;
  font-weight: 800;
  color: var(--text-primary);
  line-height: 1;
  letter-spacing: -0.5px;
}

.days-label {
  font-size: 10px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-right: 3px;
}

.time-detail {
  font-size: 11px;
  color: var(--text-secondary);
  font-variant-numeric: tabular-nums;
  opacity: 0.8;
}

.item-date {
  font-size: 10px;
  color: var(--text-secondary);
  font-weight: 500;
  flex-shrink: 0;
}

.progress-compact {
  display: flex;
  align-items: center;
  gap: 6px;
}

.progress-bar {
  flex: 1;
  height: 4px;
  background: #F1F5F9;
  border-radius: 10px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: var(--primary-gradient);
  border-radius: 10px;
}

.progress-text {
  font-size: 9px;
  font-weight: 600;
  color: #6366F1;
  min-width: 26px;
  text-align: right;
}

.item-actions {
  position: absolute;
  right: 8px;
  top: 0;
  bottom: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 8px 0;
  pointer-events: auto;
}

.action-btn {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  border: none;
  background: transparent;
  color: #CBD5E1;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.action-btn:hover {
  background: #F1F5F9;
}

.action-btn.delete:hover {
  color: #EF4444;
  background: #FEF2F2;
}

.action-btn.pin:hover {
  color: #6366F1;
  background: #EEF2FF;
}

.action-btn.pin.active {
  color: #6366F1;
  background: #EEF2FF;
  opacity: 1;
}

/* FAB */
.fab-btn {
  position: absolute;
  bottom: 12px;
  right: 12px;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--primary-gradient);
  color: white;
  border: none;
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
  z-index: 20;
}

.fab-btn svg {
  width: 20px;
  height: 20px;
  transition: all 0.3s;
}

.fab-btn:hover {
  width: 56px;
  height: 56px;
  transform: rotate(90deg);
  box-shadow: 0 10px 20px -5px var(--primary-shadow);
}

.fab-btn:hover svg {
  width: 24px;
  height: 24px;
}

.header-close-btn, .header-save-btn {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 14px;
  font-weight: 600;
}

.header-close-btn {
  background: #F1F5F9;
  color: var(--text-secondary);
}

.header-close-btn:hover {
  background: #E2E8F0;
  color: var(--text-primary);
}

.header-save-btn {
  background: var(--primary-gradient);
  color: white;
  width: auto;
  padding: 0 20px;
}

.header-save-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px var(--primary-shadow);
}

.header-save-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 6px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.form-group input {
  width: 100%;
  padding: 12px 16px;
  background: #F8FAFC;
  border: 1px solid #E2E8F0;
  border-radius: 12px;
  font-size: 15px;
  box-sizing: border-box;
  transition: all 0.2s;
  color: var(--text-primary);
  font-family: inherit;
}

.form-group input:focus {
  outline: none;
  background: #FFFFFF;
  border-color: #6366F1;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
}

.icon-selector {
  display: flex;
  gap: 10px;
  justify-content: space-between;
}

.icon-option {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: #F8FAFC;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
}

.icon-preview {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #94A3B8;
}

.icon-option:hover {
  background: #F1F5F9;
}

.icon-option.selected {
  background: #EEF2FF;
  border-color: #6366F1;
}

.icon-option.selected .icon-preview {
  color: #6366F1;
}

.modal-actions {
  padding: 0 24px 24px;
}

.btn-save {
  width: 100%;
  padding: 14px;
  background: var(--primary-gradient);
  color: white;
  border: none;
  border-radius: 14px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 4px 12px var(--primary-shadow);
}

.btn-save:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 16px var(--primary-shadow);
}

.btn-save:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.empty-state {
  text-align: center;
  color: var(--text-secondary);
  margin-top: 60px;
  font-size: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.empty-icon {
  font-size: 32px;
  opacity: 0.5;
}

@keyframes popIn {
  from { transform: scale(0.9) translateY(10px); opacity: 0; }
  to { transform: scale(1) translateY(0); opacity: 1; }
}

.ai-input-group {
  display: flex;
  gap: 6px;
}

.ai-input-group input {
  flex: 1;
}

.ai-btn, .config-btn {
  padding: 12px 16px;
  background: var(--primary-gradient);
  color: white;
  border: none;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.config-btn {
  padding: 12px;
  background: #F1F5F9;
  font-size: 16px;
}

.ai-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.ai-btn:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px var(--primary-shadow);
}

.config-btn:hover {
  background: #E2E8F0;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.3);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 12px;
}

.settings-page, .form-page {
  width: 100%;
  height: 100%;
  background: linear-gradient(to bottom right, var(--bg-gradient-start), var(--bg-gradient-end));
  border: 1px solid #FFFFFF;
  border-radius: 20px;
  box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0,0,0,0.02);
  z-index: 2001;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.slide-enter-active, .slide-leave-active {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-enter-from {
  transform: translateX(100%);
}

.slide-leave-to {
  transform: translateX(100%);
}

.settings-page-header, .form-page-header {
  padding: 20px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: rgba(255,255,255,0.8);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid rgba(0,0,0,0.05);
}

.settings-page-header h2, .form-page-header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
  flex: 1;
  text-align: center;
}

.form-page-body {
  flex: 1;
  padding: 24px;
  background: #FFFFFF;
  overflow-y: auto;
  margin: 0 24px 24px;
  border-radius: 16px;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.02);
}

.settings-close-btn, .settings-save-btn {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 14px;
  font-weight: 600;
}

.settings-close-btn {
  background: #F1F5F9;
  color: var(--text-secondary);
}

.settings-close-btn:hover {
  background: #E2E8F0;
  color: var(--text-primary);
}

.settings-save-btn {
  background: var(--primary-gradient);
  color: white;
  width: auto;
  padding: 0 20px;
}

.settings-save-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px var(--primary-shadow);
}

.settings-tabs {
  display: flex;
  gap: 8px;
  padding: 16px 24px 0;
  background: transparent;
}

.settings-tab-btn {
  padding: 10px 16px;
  border: none;
  background: rgba(255,255,255,0.6);
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  border-radius: 12px 12px 0 0;
  transition: all 0.2s;
}

.settings-tab-btn.active {
  background: #FFFFFF;
  color: #6366F1;
  box-shadow: 0 -2px 8px rgba(0,0,0,0.04);
}

.settings-tab-btn:hover {
  background: rgba(255,255,255,0.8);
}

.settings-body {
  flex: 1;
  padding: 24px;
  background: #FFFFFF;
  overflow-y: auto;
  margin: 0 24px 24px;
  border-radius: 0 16px 16px 16px;
  box-shadow: 0 4px 6px -1px rgba(0,0,0,0.02);
}

.btn-test-full {
  width: 100%;
  padding: 12px;
  background: #F1F5F9;
  color: var(--text-primary);
  border: none;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  margin-top: 8px;
}

.btn-test-full:hover:not(:disabled) {
  background: #E2E8F0;
}

.btn-test-full:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.sortable-fallback {
  opacity: 0.9;
  box-shadow: 0 8px 25px rgba(99, 102, 241, 0.4);
}

.sortable-ghost {
  opacity: 0.4;
  background: #E0E7FF !important;
  border: 2px dashed #6366F1 !important;
}

.sortable-chosen {
  box-shadow: 0 8px 25px rgba(99, 102, 241, 0.3);
}

.sortable-drag {
  opacity: 0.9;
  transform: scale(1.02);
}

.list-item {
  cursor: grab;
}

.list-item:active {
  cursor: grabbing;
}

.toast {
  position: fixed;
  top: 24px;
  left: 50%;
  transform: translateX(-50%) translateY(-100px);
  background: #FFFFFF;
  padding: 12px 24px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  font-size: 14px;
  font-weight: 600;
  z-index: 10000;
  opacity: 0;
  transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
  border: 1px solid rgba(0,0,0,0.05);
}

.toast.show {
  opacity: 1;
  transform: translateX(-50%) translateY(0);
}

.toast-success {
  color: #10B981;
  background: #ECFDF5;
  border-color: #10B981;
}

.toast-error {
  color: #EF4444;
  background: #FEF2F2;
  border-color: #EF4444;
}

.toast-warning {
  color: #F59E0B;
  background: #FFFBEB;
  border-color: #F59E0B;
}
</style>
