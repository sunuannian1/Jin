<?php
/**
 * 班主任工作台（PHP 版本，由 reference.html 转换）
 *
 * 说明：页面的全部前端交互（localStorage 本地存储、Chart.js 图表、Leaflet/高德地图、
 *      html2canvas、DOM 动态渲染与点击事件）均保持原样运行在浏览器中；
 *      PHP 仅负责在服务端输出页面并集中管理下列配置。
 *      需要调整默认值时，直接改下方 $config 即可，无需改动前端 JS。
 * 运行：将本文件放到 PHP 环境（phpStudy / XAMPP / WAMP / Nginx+PHP-FPM）的站点目录，
 *      通过 http://站点地址/reference.php 访问。
 */

// 响应头必须在任何实际输出之前发送
header('Content-Type: text/html; charset=UTF-8');
header('Cache-Control: no-cache, must-revalidate');

// 集中配置（会通过下方各 PHP 输出语句注入到前端，默认值与原 HTML 完全一致）
$config = [
    'title'            => '班主任工作台',                          // 浏览器页面标题
    'data_version'     => 10,                                      // 本地数据版本号（对应原 JS 的 DATA_VERSION）
    'default_class_no' => '（2）班',                                // 首次使用、未设置时的默认班级编号
    'default_teacher'  => '段老师',                                 // 首次使用、未设置时的默认教师姓名
    'amap_js_key'      => 'c58ac6805d9a95484946632fce5addb8',      // 高德地图 JS API Key
    'amap_web_key'     => 'a6660bc33cac44f1a410f963223c9ac1',      // 高德地图 Web 服务 Key
];
?><!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title><?php echo htmlspecialchars($config['title'], ENT_QUOTES, 'UTF-8'); ?></title>
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script defer src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<link rel="stylesheet" href="reference.css">
</head>
<body class="max-w-md mx-auto min-h-screen relative" style="background:transparent;">

<header class="px-5 pt-7 pb-3.5 sticky top-0 z-30" style="background:var(--header-bg,rgba(255,255,255,0.72));backdrop-filter:blur(20px) saturate(180%);-webkit-backdrop-filter:blur(20px) saturate(180%);border-bottom:0.5px solid var(--header-border,rgba(0,0,0,0.06));box-shadow:0 1px 8px rgba(0,0,0,0.04);">
  <div class="relative z-10">
    <div class="flex justify-between items-end">
      <div>
        <p class="text-[11px] mb-1" style="color:var(--text3,#B8AEA4);letter-spacing:0.5px;" id="greetingText">下午好，老师</p>
        <h1 class="text-xl font-bold tracking-tight" style="color:var(--text,#3A322C);" id="headerClassName">高一（2）班</h1>
      </div>
      <div class="text-right flex flex-col items-end pb-0.5">
        <div class="flex items-center gap-1">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color:var(--primary,#D97757);"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
          <p class="text-sm font-semibold" style="color:var(--text,#3A322C);" id="headerDate">8月14日</p>
        </div>
        <p class="text-[11px] mt-0.5" style="color:var(--text3,#B8AEA4);" id="headerWeek">周五</p>
      </div>
    </div>
  </div>
</header>

<!-- 学期选择底部抽屉 -->
<div id="semesterPanel" class="fixed inset-0 z-50 hidden" onclick="if(event.target===this)toggleSemesterPanel()">
  <div class="absolute inset-0" style="background:rgba(0,0,0,0.4);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);"></div>
  <div class="absolute bottom-0 left-0 right-0 bg-white rounded-t-3xl overflow-hidden" style="transform:translateY(100%);transition:transform 0.3s cubic-bezier(0.32,0.72,0,1);max-height:80vh;display:flex;flex-direction:column;" id="semesterDrawer">
    <!-- 顶部拖拽条 -->
    <div class="flex justify-center pt-3 pb-2">
      <div class="w-10 h-1 rounded-full" style="background:#e5e5ea;"></div>
    </div>
    <!-- 标题 -->
    <div class="px-5 pb-3 flex justify-between items-center">
      <div>
        <h3 class="text-lg font-bold text-gray-900">选择学期</h3>
        <p class="text-xs text-gray-400 mt-0.5">切换后仅成绩数据随之变化</p>
      </div>
      <button onclick="toggleSemesterPanel()" class="w-8 h-8 rounded-full flex items-center justify-center" style="background:#f2f2f7;color:#8e8e93;">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
      </button>
    </div>
    <!-- 学期列表 -->
    <div class="flex-1 overflow-y-auto px-5 pb-4" id="semesterGrid" style="padding-top:4px;">
      <!-- 学期卡片动态生成 -->
    </div>
    <!-- 底部新建按钮 -->
    <div class="px-5 py-4 border-t border-gray-100" style="padding-bottom:calc(16px + env(safe-area-inset-bottom));">
      <button onclick="showNewSemesterModal()" class="w-full py-3 rounded-2xl font-medium text-sm flex items-center justify-center gap-2 transition-all active:scale-98" style="background:linear-gradient(135deg,#f8f9fa,#f2f2f7);color:#6b7280;border:1.5px dashed #d1d5db;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
        新建学期
      </button>
    </div>
  </div>
</div>

<main class="px-4 pt-3 relative z-10">

<!-- 1. 首页 -->
<div id="page-home" class="page active">
  <div id="homeStats" class="stats-grid">
    <div class="stat-card">
      <div class="num" id="stat-student" style="color:var(--primary,#D97757);">35</div>
      <div class="label">班级学生</div>
    </div>
    <div class="stat-card">
      <div class="num" id="stat-exam" style="color:var(--primary,#D97757);">0</div>
      <div class="label">待录成绩</div>
    </div>
    <div class="stat-card">
      <div class="num" id="stat-subject" style="color:var(--primary,#D97757);">9</div>
      <div class="label">开设科目</div>
    </div>
  </div>

  <div id="homeQuick" class="card">
    <h3 class="font-semibold mb-4 text-sm text-gray-700">常用功能</h3>
    <div class="grid grid-cols-4 gap-2 text-center text-xs" id="quickActionsGrid"></div>
  </div>

  <div id="homeDuty" class="card">
    <div class="flex justify-between items-center mb-3">
      <h3 class="font-semibold text-sm text-gray-700" id="dutyTitle">今日值日</h3>
      <button onclick="switchDuty()" class="text-xs font-medium px-3 py-1 rounded-full" style="color:var(--primary,#D97757);background:var(--primary-light,#F5E6DE);">下一组 →</button>
    </div>
    <div class="text-sm text-gray-600 leading-relaxed" id="dutyText">加载中...</div>
  </div>

  <div id="homeSchedule" class="card">
    <div class="flex justify-between items-center mb-3">
      <h3 class="font-semibold text-sm text-gray-700">今日课程</h3>
      <span class="text-xs text-gray-400" id="todayScheduleTag"></span>
    </div>
    <div id="todayScheduleContent" class="text-sm text-gray-600">加载中...</div>
  </div>

  <div id="homeTodo" class="card">
    <div class="flex justify-between items-center mb-3">
      <h3 class="font-semibold text-sm text-gray-700">今日待办</h3>
      <button onclick="addTodo()" class="text-xs font-medium px-3 py-1 rounded-full" style="color:var(--primary,#D97757);background:var(--primary-light,#F5E6DE);">+ 添加</button>
    </div>
    <div id="todoList" class="space-y-1"></div>
  </div>
</div>

<!-- 2. 学生 -->
<div id="page-student" class="page">
  <div class="flex gap-2 mb-4">
    <div class="flex-1 relative">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="position:absolute;left:16px;top:50%;transform:translateY(-50%);color:var(--text3,#B8AEA4);z-index:1;"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
      <input type="text" id="stuSearch" placeholder="搜索学生姓名..." class="w-full input-field" style="padding-left:46px !important;">
    </div>
    <button onclick="printStudents()" class="btn-secondary w-11 h-11 flex items-center justify-center p-0" style="border-radius:14px;">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
    </button>
    <button onclick="openStuManage()" class="btn-secondary w-11 h-11 flex items-center justify-center p-0" style="border-radius:14px;">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
    </button>
  </div>

  <div class="relative">
    <div class="flex gap-2 mb-3 overflow-x-auto text-xs pb-1" style="scrollbar-width:none;-webkit-scrollbar:none;">
    <button class="stu-filter-btn stu-filter-active" onclick="filterStu('all')">全部</button>
    <button class="stu-filter-btn" onclick="filterStu(1)">第1排</button>
    <button class="stu-filter-btn" onclick="filterStu(2)">第2排</button>
    <button class="stu-filter-btn" onclick="filterStu(3)">第3排</button>
    <button class="stu-filter-btn" onclick="filterStu(4)">第4排</button>
    <button class="stu-filter-btn" onclick="filterStu(5)">第5排</button>
    <button class="stu-filter-btn" onclick="filterStu(6)">第6排</button>
  </div>
  <div style="position:absolute;right:0;top:0;bottom:7px;width:40px;background:linear-gradient(to right,rgba(0,0,0,0),var(--bg,#FAF7F2) 80%);pointer-events:none;z-index:2;"></div>
  </div>
  <div id="stuCount" class="text-xs mb-3" style="color:var(--text3,#B8AEA4);"></div>

  <div id="stuList"></div>
</div>

<!-- 3. 成绩 -->
<div id="page-score" class="page">
  <div class="flex justify-between items-center mb-4">
    <div class="flex items-center gap-2">
      <h2 class="font-semibold text-sm text-gray-700">考试列表</h2>
      <button onclick="toggleSemesterPanel()" class="text-xs px-2 py-0.5 rounded-full font-medium flex items-center gap-1" style="background:linear-gradient(135deg,#F5E6E0,#F0D8D0);color:#C07060;" id="scoreSemesterBadge">
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
        <span id="scoreSemesterBadgeText">第1学期</span>
      </button>
    </div>
    <div class="flex gap-2">
      <button onclick="openImportScore()" class="btn-secondary btn-xs" style="background: linear-gradient(135deg, #d1fae5, #B8D0C0); color: #B85A3A;">导入</button>
      <button onclick="openSubjManage()" class="btn-secondary btn-xs">科目</button>
      <button onclick="addExam()" class="btn-primary btn-xs">+ 新建</button>
    </div>
  </div>

  <div class="flex gap-2 mb-4 overflow-x-auto text-xs pb-1" id="examFilter"></div>
  <div id="examList"></div>
</div>

<!-- 4. 我的 -->
<div id="page-mine" class="page" style="padding-top:8px;">
  <!-- 用户信息卡 -->
  <div class="card mb-5" style="padding:20px;cursor:pointer;transition:background 0.15s;" onclick="editClassName()" ontouchstart="this.style.background='var(--input-bg,#F5F0E8)'" ontouchend="this.style.background=''">
    <div class="flex items-center gap-4">
      <div class="w-16 h-16 rounded-2xl flex items-center justify-center" style="background:linear-gradient(135deg,var(--primary,#D97757),var(--primary-dark,#C4613F));box-shadow:0 4px 12px var(--primary,#D97757)33;">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
      </div>
      <div class="flex-1">
        <h3 class="font-bold text-lg" style="color:var(--text,#3A322C);" id="teacherNameDisplay">段老师</h3>
        <p class="text-sm mt-0.5" style="color:var(--text2,#8C8279);" id="homeClassName">高一（2）班</p>
      </div>
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color:var(--text3,#B8AEA4);"><polyline points="9 18 15 12 9 6"></polyline></svg>
    </div>
  </div>

  <!-- 教学管理 -->
  <p class="text-xs font-medium mb-2 px-1" style="color:var(--text3,#B8AEA4);letter-spacing:1px;">教学管理</p>
  <div class="card mb-5 overflow-hidden">
    <div class="settings-row" onclick="openSubjManage()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg></div>
      <span class="settings-label">科目管理</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="openStuManage()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg></div>
      <span class="settings-label">学生名册管理</span>
      <span class="settings-arrow"></span>
    </div>
  </div>

  <!-- 通知管理 -->
  <p class="text-xs font-medium mb-2 px-1" style="color:var(--text3,#B8AEA4);letter-spacing:1px;">通知管理</p>
  <div class="card mb-5 overflow-hidden">
    <div class="settings-row" onclick="openTplManage()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg></div>
      <span class="settings-label">通知模板管理</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="openNoticeLog()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l18-8v18l-18-8v-2z"></path><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"></path></svg></div>
      <span class="settings-label">通知发布记录</span>
      <span class="settings-arrow"></span>
    </div>
  </div>

  <!-- 个性化设置 -->
  <p class="text-xs font-medium mb-2 px-1" style="color:var(--text3,#B8AEA4);letter-spacing:1px;">个性化设置</p>
  <div class="card mb-5 overflow-hidden">
    <div class="settings-row" onclick="openHomeLayout()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg></div>
      <span class="settings-label">首页布局设置</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="openQuickActionsEdit()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg></div>
      <span class="settings-label">常用功能管理</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="openThemeSettings()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="13.5" cy="6.5" r=".5"></circle><circle cx="17.5" cy="10.5" r=".5"></circle><circle cx="8.5" cy="7.5" r=".5"></circle><circle cx="6.5" cy="12.5" r=".5"></circle><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"></path></svg></div>
      <span class="settings-label">主题配色</span>
      <span class="settings-value" id="mineThemeName">暖阳橙</span>
      <span class="settings-arrow"></span>
    </div>
  </div>

  <!-- 数据管理 -->
  <p class="text-xs font-medium mb-2 px-1" style="color:var(--text3,#B8AEA4);letter-spacing:1px;">数据管理</p>
  <div class="card overflow-hidden">
    <div class="settings-row" onclick="exportAll()">
      <div class="settings-icon" style="background:var(--primary-light,#F5E6DE);color:var(--primary,#D97757);"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg></div>
      <span class="settings-label">导出全部数据</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="importAll()">
      <div class="settings-icon" style="background:rgba(59,130,246,0.1);color:#3B82F6;"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg></div>
      <span class="settings-label">导入数据恢复</span>
      <span class="settings-arrow"></span>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-row" onclick="clearAll()">
      <div class="settings-icon" style="background:rgba(239,68,68,0.1);color:#EF4444;"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg></div>
      <span class="settings-label" style="color:#EF4444;">清空所有数据</span>
      <span class="settings-arrow" style="color:#EF4444;"></span>
    </div>
  </div>
</div>

<!-- 学生分布地图 -->
<div id="page-stumap" class="page" style="padding:0;position:fixed;top:0;left:0;right:0;bottom:76px;max-width:28rem;margin:0 auto;height:auto;">
  <div id="stuMapContainer" style="width:100%;height:100%;"></div>
  
  <!-- 顶部统计条 -->
  <div style="position:absolute;top:12px;left:50%;transform:translateX(-50%);z-index:500;">
    <div class="card" style="padding:8px 16px;margin:0;display:flex;align-items:center;gap:8px;border-radius:20px;">
      <span class="text-xs" style="color:#3c3c43;font-weight:500;"><b id="mapLocatedCount" style="color:#D97757;">0</b> 位学生 · <b id="mapAreaCount" style="color:#6B8BA5;">0</b> 个小区</span>
    </div>
  </div>



  <!-- 学生详情面板 -->
  <div id="stuDetailPanel" style="position:absolute;bottom:0;left:0;right:0;z-index:600;background:#fff;border-radius:20px 20px 0 0;box-shadow:0 -4px 20px rgba(0,0,0,0.12);transform:translateY(calc(100% + 80px));transition:transform 0.35s cubic-bezier(0.16,1,0.3,1);max-height:60%;overflow:hidden;display:flex;flex-direction:column;">
    <div style="flex-shrink:0;position:relative;padding:8px 16px 4px;cursor:pointer;background:#fff;" onclick="toggleStuDetailPanel()">
      <div style="width:36px;height:4px;background:#e5e5ea;border-radius:2px;margin:0 auto 4px;"></div>
      <button onclick="event.stopPropagation();closeStuDetail()" style="position:absolute;top:6px;right:12px;width:26px;height:26px;border-radius:50%;background:#f2f2f7;border:none;display:flex;align-items:center;justify-content:center;cursor:pointer;">
        <svg width="13px" height="13px" viewBox="0 0 24 24" fill="none" stroke="#8e8e93" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
    </div>
    <div id="stuDetailPanelContent" style="flex:1;overflow-y:auto;padding:0 14px 10px;-webkit-overflow-scrolling:touch;"></div>
  </div>
</div>

</main>
<!-- 学生详情页 -->
<div id="page-stu-detail" class="full-page">
  <div class="page-nav">
    <button class="nav-btn left" onclick="navigateBack()">‹ 返回</button>
    <span class="nav-title">学生详情</span>
    <button class="nav-btn right" onclick="editStu()">编辑</button>
  </div>
  <div class="page-body" id="stuDetailContent"></div>
</div>

<!-- 考试详情页 -->
<div id="page-exam-detail" class="full-page">
  <div class="page-nav">
    <button class="nav-btn left" onclick="navigateBack()">‹ 返回</button>
    <span class="nav-title" id="examDetailTitle">成绩详情</span>
    <div class="flex gap-2"><button class="print-btn" onclick="printExam()" style="display:inline-flex;align-items:center;justify-content:center;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg></button><button class="nav-btn right" onclick="openScoreInput()">录入</button></div>
  </div>
  <div class="page-body" id="examDetailContent"></div>
</div>

<!-- 成绩录入页 -->
<div id="page-score-input" class="full-page">
  <div class="page-nav">
    <button class="nav-btn left" onclick="navigateBack()">‹ 返回</button>
    <span class="nav-title" id="scoreInputTitle">成绩录入</span>
    <button class="nav-btn right" onclick="saveScore()">保存</button>
  </div>
  <div class="page-body">
    <div class="flex justify-between items-center mb-4 text-xs" id="scoreInputMeta"></div>
    <div id="scoreInputListNew" class="space-y-2"></div>
  </div>
  <div class="page-toolbar">
    <div class="flex-1 text-xs text-gray-500">已录入：<span id="scoreInputCount" class="font-semibold text-green-500">0</span>/<span id="scoreInputTotal">35</span></div>
    <button onclick="clearScoreInput()" class="btn-secondary btn-xs">清空</button>
    <button onclick="saveScore()" class="btn-primary btn-xs">保存</button>
  </div>
</div>

<!-- 班级课表页 -->
<div id="page-schedule" class="full-page">
  <div class="page-nav">
    <button class="nav-btn left" onclick="navigateBack()">‹ 返回</button>
    <span class="nav-title">班级课表</span>
    <div class="flex gap-2"><button class="print-btn" onclick="printSchedule()" style="display:inline-flex;align-items:center;justify-content:center;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg></button><button class="nav-btn right" id="scheduleMarkBtn" onclick="toggleMarkMode()" style="color:var(--primary,#D97757);">标记</button><button class="nav-btn right" id="scheduleEditBtn" onclick="toggleScheduleEdit()">编辑</button></div>
  </div>
  <div class="page-body" id="scheduleContent"></div>
</div>

<!-- 值日表页 -->
<div id="page-duty" class="full-page">
  <div class="page-nav">
    <button class="nav-btn left" onclick="navigateBack()">‹ 返回</button>
    <span class="nav-title">值日表</span>
    <div class="flex gap-2"><button class="print-btn" onclick="printDuty()" style="display:inline-flex;align-items:center;justify-content:center;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg></button><button class="nav-btn right" onclick="toggleDutyEdit()">编辑</button></div>
  </div>
  <div class="page-body" id="dutyPageContent"></div>
</div>

<!-- ========== 班级相册 v2 ========== -->
<div id="page-album" class="full-page">
  <div class="gal-page">

    <!-- ===== 相册主页 ===== -->
    <div class="gal-home" id="galHome">
      <div class="gal-home-nav">
        <button class="gal-nav-btn" onclick="navigateBack()" style="padding:0;">
          <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
        </button>
        <div style="text-align:center;">
          <div class="gal-home-nav-title">班级相册</div>
          <div class="gal-home-nav-sub" id="galHomeSummary">0相册 0图片</div>
        </div>
        <div style="width:36px;"></div>
      </div>
      <div class="gal-home-body">
        <div class="gal-category-grid" id="galCategoryGrid"></div>
      </div>
    </div>

    <!-- ===== 相册内页 ===== -->
    <div class="gal-detail" id="galDetail" style="display:none;">
      <!-- 封面区 -->
      <div class="gal-cover" id="galCover">
        <div class="gal-cover-placeholder" id="galCoverPlaceholder">📷</div>
        <div class="gal-cover-overlay"></div>
      </div>

      <!-- 封面导航栏 -->
      <div class="gal-cover-nav" id="galCoverNav">
        <button class="gal-cover-nav-btn gal-back-btn" onclick="galBackToHome()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="0.87" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
        </button>
        <div class="gal-cover-nav-actions">
          <button class="gal-cover-nav-btn text" id="galSelectBtn" onclick="galToggleSelectMode()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.33" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"></circle><polyline points="8 12 11 15 16 9"></polyline></svg>
            <span>选择</span>
          </button>
          <button class="gal-cover-nav-btn gal-date-btn" onclick="galToggleDateNav()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
          </button>
          <button class="gal-cover-nav-btn gal-more-btn" onclick="galShowMoreMenu()">
            <svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"></circle><circle cx="12" cy="12" r="2"></circle><circle cx="19" cy="12" r="2"></circle></svg>
          </button>
        </div>
      </div>

      <!-- 滚动后白色导航栏 -->
      <div class="gal-sticky-nav" id="galStickyNav">
        <button class="gal-sticky-btn gal-sticky-back" onclick="galBackToHome()">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
        </button>
        <div class="gal-sticky-title" id="galStickyTitle">班级相册</div>
        <div style="display:flex;gap:4px;">
          <button class="gal-sticky-btn" onclick="galToggleSelectMode()">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"></circle><polyline points="8 12 11 15 16 9"></polyline></svg>
          </button>
          <button class="gal-sticky-btn gal-sticky-date" onclick="galToggleDateNav()">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
          </button>
          <button class="gal-sticky-btn" onclick="galShowMoreMenu()">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"></circle><circle cx="12" cy="12" r="2"></circle><circle cx="19" cy="12" r="2"></circle></svg>
          </button>
        </div>
      </div>

      <!-- 相册信息栏 -->
      <div class="gal-info-bar">
        <div class="gal-info-bar-left">
          <div class="gal-info-name" id="galInfoName">班级相册</div>
          <div class="gal-info-meta">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
            <span id="galInfoCount">0张</span>
          </div>
        </div>
      </div>

      <!-- 下拉外层容器（分离下拉和滚动） -->
      <div class="gal-pull-wrapper" id="galPullWrapper">
        <!-- 下拉刷新提示（纯圆圈） -->
        <div class="gal-pull-indicator" id="galPullIndicator">
          <div class="gal-pull-circle" id="galPullCircle"></div>
        </div>

        <!-- 照片滚动区 -->
        <div class="gal-sticky-date-el" id="galStickyDate"></div>
      <div class="gal-photos-wrapper" id="galPhotosWrapper">
        <div class="gal-photos-container" id="galPhotosContainer"></div>
      </div>
      </div><!-- /gal-pull-wrapper -->

      <!-- 选择模式顶部栏 -->
      <div class="gal-select-bar" id="galSelectBar" style="display:none;">
        <button class="gal-cancel" onclick="galToggleSelectMode()">取消</button>
        <span class="gal-select-title" id="galSelectTitle">选择照片</span>
        <button class="gal-select-all" id="galSelectAllBtn" onclick="galSelectAll()">全选</button>
      </div>

      <!-- 选择模式底部操作栏：下载、移动、删除 -->
      <div class="gal-select-actions" id="galSelectActions" style="display:none;">
        <button class="gal-action-btn" id="galDownloadBtn" onclick="galDownloadSelected()" disabled>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
          下载
        </button>
        <button class="gal-action-btn" id="galMoveBtn" onclick="galShowMoveModal()" disabled>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 3 21 3 21 8"></polyline><line x1="4" y1="20" x2="21" y2="3"></line><polyline points="21 16 21 21 16 21"></polyline><line x1="15" y1="15" x2="21" y2="21"></line><line x1="4" y1="4" x2="9" y2="9"></line></svg>
          移动
        </button>
        <button class="gal-action-btn" id="galDeleteBtn" onclick="galDeleteSelected()" disabled>
          <svg viewBox="0 0 1024 1024" fill="currentColor" style="width:34px;height:34px;"><path d="M227.555556 312.888889m17.066666 0l534.755556 0q17.066667 0 17.066666 17.066667l0 0q0 17.066667-17.066666 17.066666l-534.755556 0q-17.066667 0-17.066666-17.066666l0 0q0-17.066667 17.066666-17.066667Z"/><path d="M420.977778 233.244444m17.066666 0l147.911112 0q17.066667 0 17.066666 17.066667l0 0q0 17.066667-17.066666 17.066667l-147.911112 0q-17.066667 0-17.066667-17.066667l0 0q0-17.066667 17.066667-17.066667Z"/><path d="M472.177778 455.111111m0 17.066667l0 142.222222q0 17.066667-17.066667 17.066667l0 0q-17.066667 0-17.066667-17.066667l0-142.222222q0-17.066667 17.066667-17.066667l0 0q17.066667 0 17.066667 17.066667Z"/><path d="M585.955556 455.111111m0 17.066667l0 142.222222q0 17.066667-17.066667 17.066667l0 0q-17.066667 0-17.066667-17.066667l0-142.222222q0-17.066667 17.066667-17.066667l0 0q17.066667 0 17.066667 17.066667Z"/><path d="M318.577778 335.644444v328.533334c0 49.737956 49.533156 91.517156 112.389689 92.427378l2.0992 0.017066h157.866666c63.146667 0 113.379556-41.233067 114.471823-90.794666l0.017066-1.649778V335.644444h34.133334v328.533334c0 69.961956-65.820444 125.457067-146.181689 126.560711l-2.440534 0.017067h-157.866666c-80.645689 0-147.279644-54.795378-148.599467-124.461512L284.444444 664.177778V335.644444h34.133334z"/></svg>
          删除
        </button>
      </div>

      <!-- 日期导航面板 -->
      <div class="gal-date-nav-mask" id="galDateNavMask" onclick="galToggleDateNav()"></div>
      <div class="gal-date-nav-panel" id="galDateNavPanel">
        <div style="font-size:16px;font-weight:600;color:#1c1c1e;margin-bottom:8px;padding-left:4px;">按日期浏览</div>
        <div id="galDateNavList"></div>
      </div>
    </div>

    <!-- 浮动+按钮 -->
    <button class="gal-fab" id="galFab" onclick="galShowUploadMenu()">+</button>

  </div>

  <!-- ===== 大图查看 ===== -->
  <div class="gal-lightbox" id="galLightbox">
    <div class="gal-lightbox-nav">
      <button onclick="galCloseLightbox()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="0.87" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
      </button>
      <div class="gal-lightbox-header">
        <div class="gal-lightbox-album" id="galLightboxAlbum">相册(1/1)</div>
        <div class="gal-lightbox-meta">
          <span id="galLightboxDate"></span>
          <button class="gal-lightbox-info-btn" onclick="galShowPhotoInfo()">
            <svg viewBox="0 0 1024 1024" fill="currentColor"><path d="M555.3 716c12.1-11.8 18.1-26.1 18.1-43 0-16.7-6.1-31.2-18.1-43.3-12.1-12.1-26.6-18.2-43.3-18.2-16.7 0-31.2 6.1-43.3 18.2-12.1 12.1-18.1 26.6-18.1 43.3 0 16.8 6.1 31.1 18.1 43 9.3 9 20 14.6 31.9 16.7 3.8 0.2 7.5 0.3 11.4 0.3 3.9 0 7.6-0.1 11.4-0.3 12-2.1 22.6-7.6 31.9-16.7zM541.4 574.7c8-85.4 32-202.8 32-218.8 0-18.6-5.7-34-17.2-46.4-11.5-12.3-26.2-18.5-44.1-18.5-17.9 0-32.6 6.3-44.2 18.8-11.5 12.4-17.2 27.8-17.2 46.1 0 16 26 133.4 33 218.8h57.7z"></path><path d="M512 960.5c-60.5 0-119.3-11.9-174.6-35.3-53.4-22.6-101.4-54.9-142.5-96.1-41.2-41.1-73.5-89.1-96.1-142.5C75.4 631.3 63.5 572.5 63.5 512s11.9-119.3 35.3-174.6c22.6-53.4 54.9-101.4 96.1-142.6 41.2-41.2 89.1-73.5 142.6-96.1 55.2-23.3 114-35.2 174.5-35.2s119.3 11.9 174.6 35.3c53.4 22.6 101.4 54.9 142.6 96.1 41.2 41.2 73.5 89.1 96.1 142.6 23.4 55.3 35.3 114.1 35.3 174.6s-11.9 119.3-35.3 174.6c-22.7 53.3-55 101.3-96.2 142.4-41.2 41.2-89.1 73.5-142.6 96.1-55.2 23.4-114 35.3-174.5 35.3z m0-832c-211.5 0-383.5 172-383.5 383.5s172 383.5 383.5 383.5 383.5-172 383.5-383.5-172-383.5-383.5-383.5z"></path></svg>
          </button>
        </div>
      </div>
    </div>
    <div class="gal-lightbox-body" id="galLightboxBody"></div>
    <!-- 右下角更多按钮 -->
    <button class="gal-lightbox-more-fab" onclick="galShowLightboxMore()">
      <svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"></circle><circle cx="12" cy="12" r="2"></circle><circle cx="19" cy="12" r="2"></circle></svg>
    </button>
    <div class="gal-lightbox-info">
      <div class="gal-lightbox-caption" id="galLightboxCaption" contenteditable="true" spellcheck="false" placeholder="添加描述..." onblur="galSaveCaption()" onkeydown="if(event.key==='Enter'){event.preventDefault();this.blur();}" onfocus="var self=this;setTimeout(function(){var r=document.createRange();r.selectNodeContents(self);var s=window.getSelection();s.removeAllRanges();s.addRange(r);},0);"></div>
    </div>
  </div>

  <!-- 大图信息面板 -->
  <div class="gal-photo-info" id="galPhotoInfo" onclick="if(event.target===this)galClosePhotoInfo()">
    <div class="gal-photo-info-sheet">
      <div class="gal-photo-info-handle"></div>
      <div class="gal-photo-info-row">
        <div class="gal-photo-info-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
        </div>
        <div class="gal-photo-info-text" id="galPhotoInfoDate">--</div>
      </div>
      <div class="gal-photo-info-divider"></div>
      <div class="gal-photo-info-row">
        <div class="gal-photo-info-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
        </div>
        <div class="gal-photo-info-text" id="galPhotoInfoSize">--</div>
      </div>
    </div>
  </div>

  <!-- 大图操作菜单 -->
  <div class="gal-lightbox-actions" id="galLightboxActions" onclick="if(event.target===this)galCloseLightboxActions()">
    <div class="gal-lightbox-actions-sheet">
      <div class="gal-lightbox-actions-header">
        <div class="gal-lightbox-actions-title">分享至</div>
        <button class="gal-lightbox-actions-close" onclick="galCloseLightboxActions()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
        </button>
      </div>
      <div class="gal-lightbox-actions-grid">
        <div class="gal-lightbox-action-item" onclick="galSharePhoto('wechat')">
          <div class="gal-lightbox-action-icon">
            <svg viewBox="0 0 1024 1024"><path d="M664.250054 368.541681c10.015098 0 19.892049 0.732687 29.67281 1.795902-26.647917-122.810047-159.358451-214.077703-310.826188-214.077703-169.353083 0-308.085774 114.232694-308.085774 259.274068 0 83.708494 46.165436 152.460344 123.281791 205.78483l-30.80868 91.730191 107.688651-53.455469c38.558178 7.53665 69.459978 15.308661 107.924012 15.308661 9.66308 0 19.230993-0.470721 28.752858-1.225921-6.025227-20.36584-9.521864-41.723264-9.521864-63.862493C402.328693 476.632491 517.908058 368.541681 664.250054 368.541681zM498.62897 285.87389c23.200398 0 38.557154 15.120372 38.557154 38.061874 0 22.846334-15.356756 38.156018-38.557154 38.156018-23.107277 0-46.260603-15.309684-46.260603-38.156018C452.368366 300.994262 475.522716 285.87389 498.62897 285.87389zM283.016307 362.090758c-23.107277 0-46.402843-15.309684-46.402843-38.156018 0-22.941502 23.295566-38.061874 46.402843-38.061874 23.081695 0 38.46301 15.120372 38.46301 38.061874C321.479317 346.782098 306.098002 362.090758 283.016307 362.090758zM945.448458 606.151333c0-121.888048-123.258255-221.236753-261.683954-221.236753-146.57838 0-262.015505 99.348706-262.015505 221.236753 0 122.06508 115.437126 221.200938 262.015505 221.200938 30.66644 0 61.617359-7.609305 92.423993-15.262612l84.513836 45.786813-23.178909-76.17082C899.379213 735.776599 945.448458 674.90216 945.448458 606.151333zM598.803483 567.994292c-15.332197 0-30.807656-15.096836-30.807656-30.501688 0-15.190981 15.47546-30.477129 30.807656-30.477129 23.295566 0 38.558178 15.286148 38.558178 30.477129C637.361661 552.897456 622.099049 567.994292 598.803483 567.994292zM768.25071 567.994292c-15.213493 0-30.594809-15.096836-30.594809-30.501688 0-15.190981 15.381315-30.477129 30.594809-30.477129 23.107277 0 38.558178 15.286148 38.558178 30.477129C806.808888 552.897456 791.357987 567.994292 768.25071 567.994292z" fill="#39ed24"/></svg>
          </div>
          <span>微信好友</span>
        </div>
        <div class="gal-lightbox-action-item" onclick="galSharePhoto('moments')">
          <div class="gal-lightbox-action-icon">
            <svg viewBox="0 0 1024 1024"><path d="M512 954.24A442.24 442.24 0 1 0 69.76 512 442.08 442.08 0 0 0 512 954.24z m0-30.88a401.12 401.12 0 0 1-137.12-21.92V621.6l274.24 276.64A356 356 0 0 1 512 923.36z m285.28-119.68a400 400 0 0 1-112 81.28L487.2 687.04l389.44 1.92a359.52 359.52 0 0 1-79.2 114.72z m118.24-289.28a400 400 0 0 1-21.92 136.96H613.76l276.8-273.92a355.04 355.04 0 0 1 25.12 136.96z m-232.8-368a355.68 355.68 0 0 1 114.56 79.04 402.88 402.88 0 0 1 81.44 112L680.96 535.52zM512 653.6A141.6 141.6 0 1 1 653.6 512 141.6 141.6 0 0 1 512 653.6z m0-548.32A400 400 0 0 1 649.12 128v280L375.04 130.4A356.32 356.32 0 0 1 512 105.28z m-285.28 119.84a405.44 405.44 0 0 1 112-81.44l198.4 198.08-389.44-2.08a355.68 355.68 0 0 1 79.04-114.56zM108.64 514.4a400 400 0 0 1 21.92-136.96h279.84L133.6 651.36a357.92 357.92 0 0 1-24.96-136.96z m234.72-21.12l-1.92 389.44a357.12 357.12 0 0 1-114.72-79.04 401.76 401.76 0 0 1-81.28-112z" fill="#FFFFFF"/><path d="M649.12 128A400 400 0 0 0 512 105.28a356.32 356.32 0 0 0-137.12 25.12l274.08 276.8z" fill="#FC6B4F"/><path d="M797.44 225.12a355.68 355.68 0 0 0-114.56-79.04l-1.92 389.44 197.92-198.08a402.88 402.88 0 0 0-81.44-112.32z" fill="#7838F2"/><path d="M893.76 651.36a400 400 0 0 0 21.92-136.96 355.04 355.04 0 0 0-25.12-136.96l-276.8 273.92z" fill="#5698F3"/><path d="M685.12 884.96a400 400 0 0 0 112-81.28 359.52 359.52 0 0 0 79.2-114.72l-389.44-1.92z" fill="#20E9F4"/><path d="M375.04 901.44A401.12 401.12 0 0 0 512 923.36a356 356 0 0 0 136.96-25.12L375.04 621.6z" fill="#00FD60"/><path d="M341.44 882.72l1.92-389.44L145.44 691.2a401.76 401.76 0 0 0 81.28 112 357.12 357.12 0 0 0 114.72 79.52z" fill="#ABFB5B"/><path d="M130.56 377.44a400 400 0 0 0-21.92 136.96 357.92 357.92 0 0 0 24.96 136.96l276.8-273.92z" fill="#F0E254"/><path d="M339.04 144a405.44 405.44 0 0 0-112 81.44 355.68 355.68 0 0 0-79.04 114.56l389.44 2.08z" fill="#F6B351"/></svg>
          </div>
          <span>朋友圈</span>
        </div>
        <div class="gal-lightbox-action-item" onclick="galSavePhoto()">
          <div class="gal-lightbox-action-icon">
            <svg viewBox="0 0 48 48"><rect width="48" height="48" rx="12" fill="#fff"/><path d="M39 30v6a3 3 0 0 1-3 3H12a3 3 0 0 1-3-3v-6" stroke="#1c1c1e" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/><polyline points="17,20 24,27 31,20" stroke="#1c1c1e" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/><line x1="24" y1="27" x2="24" y2="9" stroke="#1c1c1e" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </div>
          <span>保存到手机</span>
        </div>
        <div class="gal-lightbox-action-item" onclick="galDeletePhoto()">
          <div class="gal-lightbox-action-icon">
            <svg viewBox="0 0 48 48"><rect width="48" height="48" rx="12" fill="#fff"/><g transform="translate(-5.7,-2.9) scale(0.06)" fill="#000000"><path d="M227.555556 312.888889m17.066666 0l534.755556 0q17.066667 0 17.066666 17.066667l0 0q0 17.066667-17.066666 17.066666l-534.755556 0q-17.066667 0-17.066666-17.066666l0 0q0-17.066667 17.066666-17.066667Z"/><path d="M420.977778 233.244444m17.066666 0l147.911112 0q17.066667 0 17.066666 17.066667l0 0q0 17.066667-17.066666 17.066667l-147.911112 0q-17.066667 0-17.066667-17.066667l0 0q0-17.066667 17.066667-17.066667Z"/><path d="M472.177778 455.111111m0 17.066667l0 142.222222q0 17.066667-17.066667 17.066667l0 0q-17.066667 0-17.066667-17.066667l0-142.222222q0-17.066667 17.066667-17.066667l0 0q17.066667 0 17.066667 17.066667Z"/><path d="M585.955556 455.111111m0 17.066667l0 142.222222q0 17.066667-17.066667 17.066667l0 0q-17.066667 0-17.066667-17.066667l0-142.222222q0-17.066667 17.066667-17.066667l0 0q17.066667 0 17.066667 17.066667Z"/><path d="M318.577778 335.644444v328.533334c0 49.737956 49.533156 91.517156 112.389689 92.427378l2.0992 0.017066h157.866666c63.146667 0 113.379556-41.233067 114.471823-90.794666l0.017066-1.649778V335.644444h34.133334v328.533334c0 69.961956-65.820444 125.457067-146.181689 126.560711l-2.440534 0.017067h-157.866666c-80.645689 0-147.279644-54.795378-148.599467-124.461512L284.444444 664.177778V335.644444h34.133334z"/></g></svg>
          </div>
          <span>删除</span>
        </div>
      </div>
    </div>
  </div>

  <!-- ===== 上传选项弹窗 ===== -->
  <!-- 已停用：上传改为直接调用系统文件选择器，不再使用自定义菜单
  <div class="gal-modal-mask" id="galUploadMask" onclick="if(event.target===this)galCloseModal('galUploadMask')">
    <div class="gal-modal-sheet" style="max-height:50vh;">
      <div class="gal-modal-header">
        <div class="gal-modal-title">上传</div>
        <button class="gal-modal-close" onclick="galCloseModal('galUploadMask')">✕</button>
      </div>
      <div class="gal-modal-body" style="padding:8px 0 calc(8px + env(safe-area-inset-bottom));">
        <div class="gal-action-sheet-item" onclick="galTriggerUpload('image')">
          <span style="color:#007AFF;">📷 拍照</span>
        </div>
        <div class="gal-action-sheet-item" onclick="galTriggerUpload('gallery')">
          <span style="color:#007AFF;">🖼️ 从相册选择照片</span>
        </div>
        <div class="gal-action-sheet-item" onclick="galTriggerUpload('video')">
          <span style="color:#007AFF;">🎬 从相册选择视频</span>
        </div>
        <div class="gal-action-sheet-cancel" onclick="galCloseModal('galUploadMask')">取消</div>
      </div>
    </div>
  </div>
  -->

  <!-- ===== 新建相册弹窗 ===== -->
  <div class="gal-modal-mask" id="galNewCategoryMask" onclick="if(event.target===this)galCloseModal('galNewCategoryMask')">
    <div class="gal-modal-sheet" style="max-height:60vh;">
      <div class="gal-modal-header">
        <div class="gal-modal-title">新建相册</div>
        <button class="gal-modal-close" onclick="galCloseModal('galNewCategoryMask')">✕</button>
      </div>
      <div class="gal-modal-body">
        <div style="margin-bottom:16px;">
          <label style="font-size:13px;color:#8e8e93;display:block;margin-bottom:6px;">相册名称</label>
          <input type="text" class="gal-input" id="galNewCatName" placeholder="输入相册名称" maxlength="20" oninput="galCheckNewCatBtn()">
        </div>
        <div style="margin-bottom:20px;">
          <label style="font-size:13px;color:#8e8e93;display:block;margin-bottom:6px;">描述（可选）</label>
          <input type="text" class="gal-input" id="galNewCatDesc" placeholder="输入描述" maxlength="50">
        </div>
        <button class="gal-btn primary" id="galNewCatBtn" onclick="galCreateCategory()" disabled>创建</button>
      </div>
    </div>
  </div>

  <!-- ===== 移动到相册弹窗 ===== -->
  <div class="gal-modal-mask" id="galMoveMask" onclick="if(event.target===this)galCloseModal('galMoveMask')">
    <div class="gal-modal-sheet" style="max-height:70vh;">
      <div class="gal-modal-header">
        <div class="gal-modal-title">移动到相册</div>
        <button class="gal-modal-close" onclick="galCloseModal('galMoveMask')">✕</button>
      </div>
      <div class="gal-modal-body" id="galMoveList"></div>
    </div>
  </div>

  <!-- ===== 更多操作弹窗 ===== -->
  <!-- 更多操作（iOS Action Sheet） -->
  <div class="gal-sheet-mask" id="galMoreMask" onclick="if(event.target===this)galCloseModal('galMoreMask')">
    <div class="gal-sheet">
      <div class="gal-sheet-group">
        <div class="gal-sheet-item" onclick="galEditCategory()">编辑相册</div>
        <div class="gal-sheet-item" onclick="galShareCategory()">分享相册</div>
        <div class="gal-sheet-item danger" onclick="galDeleteCategory()">删除相册</div>
      </div>
      <div class="gal-sheet-cancel" onclick="galCloseModal('galMoreMask')">取消</div>
    </div>
  </div>

  <!-- ===== 编辑相册弹窗 ===== -->
  <!-- 编辑相册（iOS设置页） -->
  <div class="gal-edit-page" id="galEditPage">
    <div class="gal-edit-nav">
      <button class="cancel" onclick="galCancelEdit()">取消</button>
      <div class="gal-edit-title">编辑相册</div>
      <button class="done" onclick="galSaveEditCategory()">完成</button>
    </div>
    <div class="gal-edit-body">
      <div class="gal-edit-group">
        <div class="gal-edit-row">
          <span class="gal-edit-row-label">相册名</span>
          <div class="gal-edit-row-value">
            <input type="text" id="galEditCatName" maxlength="20" placeholder="未命名">
          </div>
        </div>
        <div class="gal-edit-row">
          <span class="gal-edit-row-label">描述</span>
          <div class="gal-edit-row-value">
            <input type="text" id="galEditCatDesc" maxlength="50" placeholder="添加描述">
          </div>
        </div>
        <div class="gal-edit-row clickable" onclick="galChangeCover()">
          <span class="gal-edit-row-label">封面</span>
          <div class="gal-edit-row-value">
            <img class="gal-edit-row-thumb" id="galEditCoverThumb" src="" alt="">
            <span class="gal-edit-row-arrow"></span>
          </div>
        </div>
        <div class="gal-edit-row">
          <div style="display:flex;align-items:center;gap:2px;min-width:0;">
            <span class="gal-edit-row-label">相册置顶</span>
            <span class="gal-edit-row-note">（其他置顶相册将被替换）</span>
          </div>
          <label class="gal-switch">
            <input type="checkbox" id="galEditTopSwitch">
            <span class="gal-switch-slider"></span>
          </label>
        </div>
      </div>
    </div>
  </div>

  <!-- 选择封面（从相册内照片选择） -->
  <div class="gal-modal-mask" id="galCoverPickerMask" onclick="if(event.target===this)galCloseCoverPicker()">
    <div class="gal-modal-sheet" style="max-height:70vh;">
      <div class="gal-modal-header">
        <div class="gal-modal-title">选择封面</div>
        <button class="gal-modal-close" onclick="galCloseCoverPicker()">✕</button>
      </div>
      <div class="gal-modal-body" style="padding:8px 8px calc(8px + env(safe-area-inset-bottom));">
        <div class="gal-cover-picker-grid" id="galCoverPickerGrid"></div>
      </div>
    </div>
  </div>

  <!-- 隐藏的文件输入 -->
  <input type="file" class="gal-file-input" id="galFileInput" accept="image/*,video/*" multiple onchange="galHandleUpload(event,'image')">
  <input type="file" class="gal-file-input" id="galCameraInput" accept="image/*,video/*" capture="environment" onchange="galHandleUpload(event,'image')">
  <input type="file" class="gal-file-input" id="galVideoInput" accept="video/*" multiple onchange="galHandleUpload(event,'video')">

  <!-- Toast -->
  <div class="gal-toast" id="galToast"></div>
</div>


<!-- 创建相册弹窗 -->
<div id="albumCategoryModal" class="modal">
  <div class="modal-content">
    <div class="ios-modal-header">
      <button onclick="document.getElementById('albumCategoryModal').classList.remove('show')" class="ios-modal-btn cancel">取消</button>
      <span class="ios-modal-title">新建相册</span>
      <button onclick="saveNewCategory()" class="ios-modal-btn done" id="albumCreateBtn" disabled>创建</button>
    </div>
    <div class="modal-body-scroll">
      <div style="padding:16px;">
        <input type="text" id="newCatName" class="ios-input" placeholder="相册名称" maxlength="20" oninput="checkCreateBtn()" style="margin-bottom:12px;">
        <textarea id="newCatDesc" class="ios-textarea" placeholder="描述（可选）" maxlength="50"></textarea>
      </div>
    </div>
  </div>
</div>

<!-- 上传选项弹窗 -->
<div id="albumUploadMenu" class="modal">
  <div class="modal-content" style="max-width:400px;margin:auto;border-radius:16px 16px 0 0;position:absolute;bottom:0;left:0;right:0;">
    <div class="album-upload-menu">
      <div class="album-upload-item" onclick="triggerUpload('camera')">
        <div class="album-upload-icon" style="background:#e8f5e9;"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#34c759" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path><circle cx="12" cy="13" r="4"></circle></svg></div>
        <span>拍摄照片</span>
      </div>
      <div class="album-upload-divider"></div>
      <div class="album-upload-item" onclick="triggerUpload('camcorder')">
        <div class="album-upload-icon" style="background:#fff3e0;"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#ff9500" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M23 7l-7 5 7 5V7z"></path><rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect></svg></div>
        <span>拍摄视频</span>
      </div>
      <div class="album-upload-divider"></div>
      <div class="album-upload-item" onclick="triggerUpload('image')">
        <div class="album-upload-icon" style="background:#e3f2fd;"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#007aff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg></div>
        <span>从相册选择照片</span>
      </div>
      <div class="album-upload-divider"></div>
      <div class="album-upload-item" onclick="triggerUpload('video')">
        <div class="album-upload-icon" style="background:#fce4ec;"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#ff2d55" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polygon points="23 7 16 12 23 17 23 7"></polygon><rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect></svg></div>
        <span>从相册选择视频</span>
      </div>
    </div>
    <div class="album-upload-cancel" onclick="closeUploadMenu()">取消</div>
  </div>
</div>

<!-- 更多菜单弹窗 -->
<div id="albumMoreMenu" class="ios-actionsheet">
  <div class="ios-actionsheet-content">
    <div class="ios-actionsheet-group">
      <div class="ios-actionsheet-item" onclick="openAlbumEditModal()">编辑相册</div>
      <div class="ios-actionsheet-item danger" onclick="deleteCurrentAlbum()">删除相册</div>
    </div>
    <div class="ios-actionsheet-cancel" onclick="closeAlbumMoreMenu()">取消</div>
  </div>
</div>

<!-- 编辑相册弹窗 -->
<div id="albumEditModal" class="modal">
  <div class="modal-content">
    <div class="ios-modal-header">
      <button onclick="closeAlbumEditModal()" class="ios-modal-btn cancel">取消</button>
      <span class="ios-modal-title">编辑相册</span>
      <button onclick="saveAlbumEdit()" class="ios-modal-btn done">完成</button>
    </div>
    <div class="modal-body-scroll">
      <div class="ios-list-group">
        <div class="ios-list-row" onclick="focusEditName()">
          <span class="ios-list-label">相册名</span>
          <input type="text" id="editCatName" class="ios-list-input" maxlength="20" placeholder="输入相册名">
          <span class="ios-list-arrow">&#8250;</span>
        </div>
        <div class="ios-list-row" onclick="focusEditDesc()">
          <span class="ios-list-label">描述</span>
          <input type="text" id="editCatDesc" class="ios-list-input" maxlength="50" placeholder="添加描述">
          <span class="ios-list-arrow">&#8250;</span>
        </div>
        <div class="ios-list-row" onclick="openAlbumCoverPicker()">
          <span class="ios-list-label">封面</span>
          <div class="ios-list-thumb" id="editCatCover"></div>
          <span class="ios-list-arrow">&#8250;</span>
        </div>
        <div class="ios-list-row">
          <span class="ios-list-label">相册置顶</span>
          <label class="ios-switch">
            <input type="checkbox" id="editCatPinned">
            <span class="ios-switch-slider"></span>
          </label>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- 封面选择弹窗 -->
<div id="albumCoverPickerModal" class="modal">
  <div class="modal-content">
    <div class="ios-modal-header">
      <button onclick="closeAlbumCoverPicker()" class="ios-modal-btn cancel">取消</button>
      <span class="ios-modal-title">选择封面</span>
      <span style="width:44px;"></span>
    </div>
    <div class="ios-cover-grid" id="albumCoverPickerGrid"></div>
  </div>
</div>

<!-- 相册大图查看 -->
<div id="albumLightbox" class="album-lightbox">
  <!-- 顶部导航栏（QQ空间风格） -->
  <div class="alb-topbar">
    <button class="alb-back" onclick="closeAlbumLightbox()">
      <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"></polyline></svg>
    </button>
    <div class="alb-title">
      <h1 id="albCatName">班级相册</h1>
      <p><span id="albDate"></span> <svg class="alb-info" onclick="togglePhotoInfo()" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg></p>
    </div>
  </div>

  <!-- 左右滑动图片区域 -->
  <div class="alb-slider" id="albSlider">
    <div class="alb-track" id="albTrack"></div>
  </div>

  <!-- 底部右下角更多按钮 -->
  <button class="album-lightbox-more" onclick="toggleAlbumLightboxMenu()">···</button>
</div>

<!-- 照片信息面板 -->
<div id="albPhotoInfo" class="alb-photo-info" onclick="event.stopPropagation()">
  <div class="alb-photo-info-handle"></div>
  <div class="alb-photo-info-row">
    <svg class="alb-photo-info-icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
    <span id="albInfoTime">--</span>
  </div>
  <div class="alb-photo-info-divider"></div>
  <div class="alb-photo-info-row">
    <svg class="alb-photo-info-icon" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
    <span id="albInfoResolution">--</span>
  </div>
</div>

<!-- 相册大图操作面板 -->
<div id="albumLightboxMenu" class="album-lightbox-menu" onclick="event.stopPropagation()">
  <div class="album-lightbox-menu-header">
    <span class="album-lightbox-menu-title">分享至</span>
    <button class="album-lightbox-menu-close" onclick="toggleAlbumLightboxMenu()">×</button>
  </div>
  <div class="album-lightbox-menu-grid">
    <div class="album-lightbox-menu-item" onclick="saveAlbumPhoto()">
      <div class="album-lightbox-menu-icon album-lightbox-icon-save">
        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#1c1c1e" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
      </div>
      <span>保存到手机</span>
    </div>
    <div class="album-lightbox-menu-item" onclick="shareAlbumToWechat()">
      <div class="album-lightbox-menu-icon album-lightbox-icon-wechat">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="#07c160"><path d="M8.691 2.188C3.891 2.188 0 5.476 0 9.53c0 2.212 1.17 4.203 3.002 5.55a.59.59 0 0 1 .213.665l-.39 1.48c-.019.07-.048.141-.048.213 0 .163.13.295.29.295a.326.326 0 0 0 .167-.054l1.903-1.114a.864.864 0 0 1 .717-.098 10.16 10.16 0 0 0 2.837.403c.276 0 .543-.027.811-.05-.857-2.578.157-4.972 1.932-6.446 1.703-1.415 3.882-1.98 5.853-1.838-.576-3.583-4.196-6.348-8.596-6.348zM5.785 5.991c.642 0 1.162.529 1.162 1.18a1.17 1.17 0 0 1-1.162 1.178A1.17 1.17 0 0 1 4.623 7.17c0-.651.52-1.18 1.162-1.18zm5.813 0c.642 0 1.162.529 1.162 1.18a1.17 1.17 0 0 1-1.162 1.178 1.17 1.17 0 0 1-1.162-1.178c0-.651.52-1.18 1.162-1.18zm5.34 2.867c-1.797-.052-3.746.512-5.28 1.786-1.72 1.428-2.687 3.72-1.78 6.22.942 2.453 3.666 4.229 6.884 4.229.826 0 1.622-.12 2.361-.336a.722.722 0 0 1 .598.082l1.584.926a.272.272 0 0 0 .14.047c.134 0 .24-.111.24-.247 0-.06-.023-.12-.038-.177l-.327-1.233a.582.582 0 0 1-.023-.156.49.49 0 0 1 .201-.398C23.024 18.48 24 16.82 24 14.98c0-3.21-2.931-5.837-6.656-6.088V8.89c-.135-.01-.27-.027-.407-.032zm-2.53 3.274c.535 0 .969.44.969.982a.976.976 0 0 1-.969.983.976.976 0 0 1-.969-.983c0-.542.434-.982.97-.982zm4.844 0c.535 0 .969.44.969.982a.976.976 0 0 1-.969.983.976.976 0 0 1-.969-.983c0-.542.434-.982.969-.982z"/></svg>
      </div>
      <span>微信好友</span>
    </div>
  </div>
</div>

<!-- 底部导航 -->
<nav class="fixed bottom-0 left-0 right-0 max-w-md mx-auto z-30">
  <div style="background:rgba(255,255,255,0.78);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);border-top:0.5px solid rgba(0,0,0,0.06);box-shadow:0 -2px 16px rgba(0,0,0,0.04);">
    <div class="grid grid-cols-4 text-center py-2 text-xs relative" style="padding-bottom:calc(8px + env(safe-area-inset-bottom));">
      <div class="tab-item tab-active flex flex-col items-center justify-center py-1.5 mx-1 rounded-xl transition-all duration-250" onclick="goPage('home')" data-tab="home">
        <span class="tab-icon mb-0.5 transition-transform duration-250">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>
        </span>
        <span class="font-medium text-[11px]">工作台</span>
      </div>
      <div class="tab-item flex flex-col items-center justify-center py-1.5 mx-1 rounded-xl transition-all duration-250" onclick="goPage('student')" data-tab="student">
        <span class="tab-icon mb-0.5 transition-transform duration-250">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
        </span>
        <span class="text-[11px]">学生</span>
      </div>
      <div class="tab-item flex flex-col items-center justify-center py-1.5 mx-1 rounded-xl transition-all duration-250" onclick="goPage('score')" data-tab="score">
        <span class="tab-icon mb-0.5 transition-transform duration-250">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="20" x2="18" y2="10"></line><line x1="12" y1="20" x2="12" y2="4"></line><line x1="6" y1="20" x2="6" y2="14"></line></svg>
        </span>
        <span class="text-[11px]">成绩</span>
      </div>
      <div class="tab-item flex flex-col items-center justify-center py-1.5 mx-1 rounded-xl transition-all duration-250" onclick="goPage('mine')" data-tab="mine">
        <span class="tab-icon mb-0.5 transition-transform duration-250">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
        </span>
        <span class="text-[11px]">我的</span>
      </div>
    </div>
  </div>
</nav>

<!-- 通用弹窗 -->
<div id="modal" class="modal">
  <div class="modal-content" id="modalBody"></div>
</div>

<!-- 地图选点独立弹窗（不占用modal，避免覆盖编辑表单） -->
<div id="mapPickerModal">
  <div id="mapPickerPanel">
    <div class="picker-header">
      <div class="picker-handle"></div>
      <span class="title">选择家庭位置</span>
      <span class="close" onclick="closeMapPicker()"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></span>
    </div>
    <div class="picker-body">
    <div class="picker-top-row">
      <div class="picker-city-btn" onclick="toggleCityPanel()">
        <span id="pickerCityName">南阳</span>
        <svg class="city-arrow" width="10" height="6" viewBox="0 0 10 6" fill="none"><path d="M1 1l4 4 4-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <input id="mapPickerSearch" placeholder="搜索小区/学校/大厦">
    </div>
    <div id="pickerCityPanel" class="picker-city-panel">
      <div id="pickerCityList" class="picker-city-list"></div>
    </div>
    <div id="mapPickerSearchList" class="picker-search-list"></div>
    <div class="picker-map-wrap">
      <div id="mapPickerMap"></div>
      <div class="picker-locate-btn" onclick="locateMe()">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M12 2v3M12 19v3M2 12h3M19 12h3"></path></svg>
      </div>
    </div>
    <input id="mapPickerAddrInput" class="picker-addr-input" placeholder="详细地址（可选，如12栋3单元）">
    <button class="picker-confirm-btn" onclick="confirmMapPicker()">确认选择</button>
    </div>
  </div>
</div>

<div id="printArea"></div>

<!-- 地图导航选择面板 -->
<div id="mapNavMask" class="map-nav-mask" onclick="closeMapNavSheet()"></div>
<div id="mapNavSheet" class="map-nav-sheet">
  <div class="map-nav-header">
    <div class="map-nav-handle"></div>
    <button class="map-nav-close" onclick="closeMapNavSheet()">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#8e8e93" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
    </button>
  </div>
  <div class="map-nav-body">
    <div class="map-nav-title">导航到学生家庭住址</div>
    <div class="map-nav-addr" id="mapNavAddr"></div>
    <div class="map-nav-grid">
      <div class="map-nav-option" onclick="doMapNavigate('amap')">
        <div class="map-nav-icon amap"><span style="font-size:22px;font-weight:800;color:#fff;letter-spacing:-1px;">高</span></div>
        <div class="map-nav-name">高德地图</div>
      </div>
      <div class="map-nav-option" onclick="doMapNavigate('bmap')">
        <div class="map-nav-icon bmap"><span style="font-size:22px;font-weight:800;color:#fff;">百</span></div>
        <div class="map-nav-name">百度地图</div>
      </div>
      <div class="map-nav-option" onclick="doMapNavigate('apple')">
        <div class="map-nav-icon apple"><svg viewBox="0 0 24 24" fill="#fff"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg></div>
        <div class="map-nav-name">苹果地图</div>
      </div>
    </div>
    <button class="map-nav-action" onclick="copyMapAddr()">复制地址</button>
    <button class="map-nav-action cancel" onclick="closeMapNavSheet()">取消</button>
  </div>
</div>
<div id="mapNavToast" class="map-nav-toast"></div>

<!-- 学生详情抽屉 -->
<div id="stuDrawer" class="drawer">
  <div class="sticky top-0 bg-white/95 backdrop-blur-xl border-b border-gray-100 px-4 py-3.5 flex justify-between items-center z-10">
    <button onclick="closeStuDrawer()" class="text-gray-500 text-sm font-medium">← 返回</button>
    <span class="font-semibold text-sm text-gray-800">学生详情</span>
    <button onclick="editStu()" class="text-green-500 text-sm font-medium">编辑</button>
  </div>
  <div class="p-4" id="stuDetail"></div>
</div>

<!-- 成绩录入抽屉 -->
<div id="scoreDrawer" class="drawer">
  <div class="sticky top-0 bg-white/95 backdrop-blur-xl border-b border-gray-100 px-4 py-3.5 flex justify-between items-center z-10">
    <button onclick="closeScoreDrawer()" class="text-gray-500 text-sm font-medium">← 返回</button>
    <span class="font-semibold text-sm text-gray-800" id="scoreTitle">成绩录入</span>
    <button onclick="saveScore()" class="text-green-500 text-sm font-semibold">保存</button>
  </div>
  <div class="p-4">
    <div class="flex justify-between items-center mb-4 text-xs">
      <span class="text-gray-500">满分：<span id="scoreFull" class="font-semibold text-gray-700">100</span></span>
      <span class="text-gray-500">已录入：<span id="scoreNum" class="font-semibold text-green-500">0/35</span></span>
    </div>
    <div id="scoreInputList" class="space-y-2"></div>
  </div>
</div>

<!-- 总分排名抽屉 -->
<div id="rankDrawer" class="drawer">
  <div class="sticky top-0 bg-white/95 backdrop-blur-xl border-b border-gray-100 px-4 py-3.5 flex justify-between items-center z-10">
    <button onclick="closeRankDrawer()" class="text-gray-500 text-sm font-medium">← 返回</button>
    <span class="font-semibold text-sm text-gray-800" id="rankDrawerTitle">总分排名</span>
    <button onclick="generateRankImage()" class="text-green-500 text-sm font-semibold">生成图片</button>
  </div>
  <div class="p-4" id="rankDrawerContent">
    <!-- 排名内容动态生成 -->
  </div>
</div>

<script>
// 服务端配置：由 PHP 输出，供 reference.js 通过 window.APP_CONFIG 读取
window.APP_CONFIG = <?php echo json_encode([
    'amapJsKey'      => $config['amap_js_key'],
    'amapWebKey'     => $config['amap_web_key'],
    'dataVersion'    => (int)$config['data_version'],
    'defaultClassNo' => $config['default_class_no'],
    'defaultTeacher' => $config['default_teacher'],
], JSON_UNESCAPED_UNICODE); ?>;
</script>
<script src="seed.js"></script>
<script src="reference.js"></script>
</body>
</html>
