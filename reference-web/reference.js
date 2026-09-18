/* App logic for the class-teacher workbench. Server-side config is provided by window.APP_CONFIG (injected in reference.php) before this file loads. */
// ========== 高德地图配置 ==========
// 填入你的高德地图 JS API Key（免费申请：https://console.amap.com/）
// 申请后启用"Web端(JS API)"服务，Key 粘贴到下面引号内
const AMAP_JS_KEY = window.APP_CONFIG.amapJsKey;
const AMAP_WEB_KEY = window.APP_CONFIG.amapWebKey;

// 数据版本号（由 PHP 配置注入）
const DATA_VERSION = window.APP_CONFIG.dataVersion;

// ========== 预置数据 ==========
// ===== 种子数据由 seed.js 提供（window.SEED_DATA），此处仅作只读别名，业务代码无需改动 =====
var SEED = window.SEED_DATA || {};
var DEF_STUDENTS      = SEED.students || [];
var DEF_SUBJECTS      = SEED.subjects || [];
var DEF_EXAMS         = SEED.exams || [];
var DEF_TODOS         = SEED.todos || [];
var DEF_TPLS          = SEED.tpls || {};
var DEF_SCHEDULE      = SEED.schedule || [];
var ALL_QUICK_ACTIONS = SEED.quickActions || [];
const EXAM_CATEGORIES = [
  {key:'单元测', icon:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg>', color:'#C4613F'},
  {key:'月考', icon:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>', color:'#d97706'},
  {key:'期中考', icon:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', color:'#D97757'},
  {key:'期末考', icon:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"></path><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"></path><path d="M4 22h16"></path><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"></path><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"></path><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"></path></svg>', color:'#C07060'}
];
function inferCategory(type) {
  if (!type) return "月考";
  if (type.indexOf("单元") >= 0) return "单元测";
  if (type.indexOf("月考") >= 0) return "月考";
  if (type.indexOf("期中") >= 0) return "期中考";
  if (type.indexOf("期末") >= 0) return "期末考";
  return "月考";
}
function getExams() {
  var exams = JSON.parse(localStorage.getItem(semExamKey(currentSemester)) || '[]');
  exams.forEach(function(e) {
    if (!e.category) e.category = inferCategory(e.type);
  });
  return exams;
}

// 保存成绩到当前学期
function saveExams(exams) {
  localStorage.setItem(semExamKey(currentSemester), JSON.stringify(exams));
}
const SCHEDULE_TIMES = ['08:00','08:55','10:00','10:55','14:00','14:55','15:50','16:45'];
const SCHEDULE_END_TIMES = ['08:45','09:40','10:45','11:40','14:45','15:40','16:35','17:30'];
function getQuickActions() {
  try {
    var saved = JSON.parse(localStorage.getItem('quickActions') || 'null');
    if (saved && Array.isArray(saved) && saved.length === ALL_QUICK_ACTIONS.length) {
      // 校验id是否都匹配
      var valid = saved.every(function(item) {
        return item && item.id && ALL_QUICK_ACTIONS.find(function(a){ return a.id === item.id; });
      });
      if (valid) return saved;
    }
  } catch(e) {}
  var def = ALL_QUICK_ACTIONS.map(function(a){ return {id:a.id, visible:true}; });
  localStorage.setItem('quickActions', JSON.stringify(def));
  return def;
}
function renderQuickActions() {
  var config = getQuickActions();
  var grid = document.getElementById('quickActionsGrid');
  if (!grid) return;
  var html = '';
  config.forEach(function(item) {
    if (!item.visible) return;
    var action = ALL_QUICK_ACTIONS.find(function(a){ return a.id === item.id; });
    if (!action) return;
    html += '<div class="quick-item flex flex-col items-center py-2" onclick="' + action.action + '">';
    html += '<div class="quick-icon flex items-center justify-center" style="background:' + action.bg + ';color:' + action.color + ';">' + (action.svg || action.icon) + '</div>';
    html += '<span class="text-gray-600">' + action.name + '</span>';
    html += '</div>';
  });
  grid.innerHTML = html;
}

// ========== 全局变量 ==========
var curPage = 'home';
var stuFilterVal = 'all';
var examFilterVal = '月考';
var curStuId = 0;
var curExamId = 0;
var _lastRankData = null;
var _lastRankSubjects = [];

// ========== 数据工具 ==========
function get(key) { return JSON.parse(localStorage.getItem(key) || '[]'); }
function set(key, val) { localStorage.setItem(key, JSON.stringify(val)); }

// ========== 学期系统（仅应用于成绩） ==========
var currentSemester = parseInt(localStorage.getItem('currentSemester')) || 1;

// 获取学期配置
function getSemesters() {
  var sems = JSON.parse(localStorage.getItem('semesters') || 'null');
  if (!sems) {
    sems = [
      {id:1, name:'第1学期', active:true},
      {id:2, name:'第2学期', active:false},
      {id:3, name:'第3学期', active:false},
      {id:4, name:'第4学期', active:false},
      {id:5, name:'第5学期', active:false},
      {id:6, name:'第6学期', active:false}
    ];
    localStorage.setItem('semesters', JSON.stringify(sems));
  }
  return sems;
}

// 成绩数据按学期存储的key
function semExamKey(semId) { return 'sem_' + semId + '_exams'; }

// 切换学期（仅切换成绩数据，不刷新整个页面）
function switchSemester(semId) {
  if (semId === currentSemester) {
    toggleSemesterPanel();
    return;
  }
  currentSemester = semId;
  localStorage.setItem('currentSemester', semId);
  var sems = getSemesters();
  sems.forEach(function(s){ s.active = (s.id === semId); });
  localStorage.setItem('semesters', JSON.stringify(sems));
  // 更新徽章
  updateSemesterBadge();
  // 关闭面板
  toggleSemesterPanel();
  // 更新header班级名称
  var headerName = document.getElementById('headerClassName');
  if (headerName) headerName.textContent = getClassName();
  // 只刷新成绩列表
  if (typeof renderExamList === 'function') renderExamList();
}

// 从旧数据迁移成绩到第1学期
function migrateOldExams() {
  var oldExams = localStorage.getItem('exams');
  if (oldExams && !localStorage.getItem(semExamKey(1))) {
    localStorage.setItem(semExamKey(1), oldExams);
    console.log('旧成绩数据已迁移到第1学期');
  }
}
migrateOldExams();

// ========== 学期切换 ==========
function toggleSemesterPanel() {
  var panel = document.getElementById('semesterPanel');
  var drawer = document.getElementById('semesterDrawer');
  if (!panel) return;
  if (panel.classList.contains('hidden')) {
    panel.classList.remove('hidden');
    renderSemesterGrid();
    // 延迟添加滑入动画
    setTimeout(function(){
      if (drawer) drawer.style.transform = 'translateY(0)';
    }, 10);
  } else {
    if (drawer) drawer.style.transform = 'translateY(100%)';
    setTimeout(function(){
      panel.classList.add('hidden');
    }, 280);
  }
}

// 获取年级名称配置
function getGradeNames() {
  var names = JSON.parse(localStorage.getItem('gradeNames') || 'null');
  if (!names) {
    names = ['高一', '高二', '高三'];
    localStorage.setItem('gradeNames', JSON.stringify(names));
  }
  return names;
}

// 根据学期ID获取年级索引（0=高一, 1=高二, 2=高三）
function getGradeIndex(semId) {
  return Math.floor((semId - 1) / 2);
}

// 根据学期ID获取建议名称
function getSuggestedSemName(semId) {
  var grades = getGradeNames();
  var gradeIdx = getGradeIndex(semId);
  var isFirst = (semId % 2 === 1);
  var grade = grades[gradeIdx] || ('年级' + (gradeIdx + 1));
  return grade + (isFirst ? '上学期' : '下学期');
}

function renderSemesterGrid() {
  var sems = getSemesters();
  var grid = document.getElementById('semesterGrid');
  if (!grid) return;
  var grades = getGradeNames();
  var html = '';
  
  // 按年级分组
  for (var g = 0; g < 3; g++) {
    var gradeSems = sems.filter(function(s){ return getGradeIndex(s.id) === g; });
    if (gradeSems.length === 0) continue;
    
    // 年级标题
    html += '<div class="flex items-center gap-2 mb-2.5 mt-1">';
    html += '<div class="w-1 h-4 rounded-full" style="background:linear-gradient(180deg,#D97757,#C06050);"></div>';
    html += '<span class="text-sm font-bold text-gray-500">' + grades[g] + '</span>';
    html += '<span class="text-xs text-gray-300">— — — — — — — —</span>';
    html += '</div>';
    
    gradeSems.forEach(function(sem) {
      var isActive = sem.id === currentSemester;
      var examCount = 0;
      try {
        var exams = JSON.parse(localStorage.getItem('sem_' + sem.id + '_exams') || '[]');
        examCount = exams.length;
      } catch(e) {}
      
      if (isActive) {
        html += '<div onclick="switchSemester(' + sem.id + ')" class="cursor-pointer p-3.5 rounded-2xl mb-2.5 transition-all active:scale-98 relative overflow-hidden" style="background:linear-gradient(135deg,#FDF5F2,#F8E8E0);border:1.5px solid #EED5CC;">'
          + '<div class="flex items-center justify-between">'
          + '<div class="flex items-center gap-3">'
          + '<div class="w-9 h-9 rounded-xl flex items-center justify-center text-white font-bold text-sm" style="background:linear-gradient(135deg,#D97757,#C06050);box-shadow:0 3px 10px rgba(217,119,87,0.3);">' + sem.id + '</div>'
          + '<div>'
          + '<div class="font-semibold text-[15px]" style="color:#8B4A3A;">' + sem.name + '</div>'
          + '<div class="text-[11px] mt-0.5" style="color:#B08070;">' + examCount + ' 次考试</div>'
          + '</div>'
          + '</div>'
          + '<div class="w-5 h-5 rounded-full flex items-center justify-center" style="background:#D97757;">'
          + '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>'
          + '</div>'
          + '</div>'
          + '</div>';
      } else {
        html += '<div onclick="switchSemester(' + sem.id + ')" class="cursor-pointer p-3.5 rounded-2xl mb-2.5 transition-all active:scale-98" style="background:#FAFAFA;border:1.5px solid #F0F0F0;">'
          + '<div class="flex items-center justify-between">'
          + '<div class="flex items-center gap-3">'
          + '<div class="w-9 h-9 rounded-xl flex items-center justify-center font-bold text-sm" style="background:#F0F0F0;color:#999;">' + sem.id + '</div>'
          + '<div>'
          + '<div class="font-semibold text-[15px] text-gray-700">' + sem.name + '</div>'
          + '<div class="text-[11px] mt-0.5 text-gray-400">' + examCount + ' 次考试</div>'
          + '</div>'
          + '</div>'
          + '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#CCC" stroke-width="2" stroke-linecap="round"><polyline points="9 18 15 12 9 6"></polyline></svg>'
          + '</div>'
          + '</div>';
      }
    });
  }
  
  grid.innerHTML = html;
}

function updateSemesterBadge() {
  var sems = getSemesters();
  var cur = sems.find(function(s){ return s.id === currentSemester; });
  if (!cur) return;
  var badgeText = document.getElementById('scoreSemesterBadgeText');
  if (badgeText) badgeText.textContent = cur.name;
}

function showNewSemesterModal() {
  var sems = getSemesters();
  var newId = sems.length + 1;
  if (newId > 6) {
    alert('最多支持6个学期（3年）');
    return;
  }
  var suggestedName = getSuggestedSemName(newId);
  var name = prompt('请输入学期名称：', suggestedName);
  if (!name || !name.trim()) return;
  sems.push({id:newId, name:name.trim(), active:false});
  localStorage.setItem('semesters', JSON.stringify(sems));
  renderSemesterGrid();
  alert('学期「' + name.trim() + '」已创建，点击即可切换');
}

// 页面加载时更新学期徽章
setTimeout(updateSemesterBadge, 100);
// 班级名称：年级前缀（自动）+ 班级编号（固定）
function getClassNo() { return localStorage.getItem('classNo') || window.APP_CONFIG.defaultClassNo; }
function setClassNo(no) { localStorage.setItem('classNo', no); }

// 根据当前学期获取年级
function getCurrentGrade() {
  var grades = getGradeNames();
  var gradeIdx = getGradeIndex(currentSemester);
  return grades[gradeIdx] || grades[0] || '高一';
}

function getClassName() {
  // 兼容旧数据：如果有完整className且没有classNo，自动拆分
  var oldName = localStorage.getItem('className');
  var classNo = localStorage.getItem('classNo');
  if (oldName && !classNo) {
    // 尝试拆分年级前缀
    var grades = ['高一','高二','高三','初一','初二','初三'];
    for (var i = 0; i < grades.length; i++) {
      if (oldName.indexOf(grades[i]) === 0) {
        classNo = oldName.substring(grades[i].length);
        localStorage.setItem('classNo', classNo);
        localStorage.removeItem('className');
        break;
      }
    }
    if (!classNo) {
      classNo = oldName;
      localStorage.setItem('classNo', classNo);
      localStorage.removeItem('className');
    }
  }
  return getCurrentGrade() + (classNo || window.APP_CONFIG.defaultClassNo);
}
function setClassName(name) {
  // 手动设置时，提取班级编号部分
  var grades = getGradeNames();
  for (var i = 0; i < grades.length; i++) {
    if (name.indexOf(grades[i]) === 0) {
      setClassNo(name.substring(grades[i].length));
      return;
    }
  }
  setClassNo(name);
}
function getTeacherName() { return localStorage.getItem('teacherName') || window.APP_CONFIG.defaultTeacher; }
function setTeacherName(name) { localStorage.setItem('teacherName', name); }

function init() {
  if (localStorage.getItem('dataVersion') != DATA_VERSION) {
    var keys = [];
    for (var i = 0; i < localStorage.length; i++) {
      keys.push(localStorage.key(i));
    }
    keys.forEach(function(k) { localStorage.removeItem(k); });
    localStorage.setItem('dataVersion', DATA_VERSION);
  }

  if (!localStorage.getItem('students')) localStorage.setItem('students', JSON.stringify(DEF_STUDENTS));
  // 给没有坐标的学生补全默认真实坐标
  (function(){
    var list = JSON.parse(localStorage.getItem('students') || '[]');
    var changed = false;
    // 建立地址→坐标映射
    var coordMap = {};
    DEF_STUDENTS.forEach(function(d) {
      if (d.lng && d.lat) coordMap[d.address] = {lng: d.lng, lat: d.lat};
    });
    list.forEach(function(s) {
      if ((s.lng === undefined || s.lat === undefined) && coordMap[s.address]) {
        s.lng = coordMap[s.address].lng;
        s.lat = coordMap[s.address].lat;
        changed = true;
      }
      if (s.sortOrder === undefined) {
        s.sortOrder = Math.random();
        changed = true;
      }
    });
    if (changed) localStorage.setItem('students', JSON.stringify(list));
  })();
  // 一次性：随机洗牌后分配学号，实现男女不规则错开（非严格交替）
  if (!localStorage.getItem('stuIdShuffled')) {
    var listS = JSON.parse(localStorage.getItem('students') || '[]');
    // Fisher-Yates 洗牌
    for (var iS = listS.length - 1; iS > 0; iS--) {
      var jS = Math.floor(Math.random() * (iS + 1));
      var tempS = listS[iS];
      listS[iS] = listS[jS];
      listS[jS] = tempS;
    }
    // 按打乱后的顺序分配学号1,2,3...
    listS.forEach(function(s, idx){ s.id = idx + 1; s.seat = idx + 1; });
    localStorage.setItem('students', JSON.stringify(listS));
    localStorage.setItem('stuIdShuffled', '1');
  }
  if (!localStorage.getItem('subjects')) localStorage.setItem('subjects', JSON.stringify(DEF_SUBJECTS));
  if (!localStorage.getItem('exams')) {
    localStorage.setItem('exams', JSON.stringify(DEF_EXAMS));
  }
  if (!localStorage.getItem('seatMap')) {
    var map = {};
    DEF_STUDENTS.forEach(function(s){ map[s.seat] = s.id; });
    localStorage.setItem('seatMap', JSON.stringify(map));
  }
  if (!localStorage.getItem('todos')) localStorage.setItem('todos', JSON.stringify(DEF_TODOS));
  if (!localStorage.getItem('tpls')) localStorage.setItem('tpls', JSON.stringify(DEF_TPLS));
  if (!localStorage.getItem('dutyGroup')) localStorage.setItem('dutyGroup', '2');
  if (!localStorage.getItem('seatCols')) localStorage.setItem('seatCols', '6');
  if (!localStorage.getItem('nextExamId')) localStorage.setItem('nextExamId', '55');
  if (!localStorage.getItem('albumCategories')) {
    localStorage.setItem('albumCategories', JSON.stringify(SEED.albumCategories || []));
  }
  if (!localStorage.getItem('albumPhotos')) {
    localStorage.setItem('albumPhotos', '[]');
  }
  if (!localStorage.getItem('noticeLogs')) localStorage.setItem('noticeLogs', JSON.stringify(SEED.noticeLogs || []));
  if (!localStorage.getItem('homeLayout')) localStorage.setItem('homeLayout', JSON.stringify({stats:true, quick:true, duty:true, todo:true}));
  if (!localStorage.getItem('theme')) localStorage.setItem('theme', 'warm');
  applyTheme();
}

function updateHeader() {
  var now = new Date();
  var month = now.getMonth() + 1;
  var date = now.getDate();
  var weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  var week = weekDays[now.getDay()];
  var hour = now.getHours();
  var greeting = '';
  var tn = getTeacherName();
  if (hour < 6) greeting = '夜深了，' + tn;
  else if (hour < 9) greeting = '早上好，' + tn;
  else if (hour < 12) greeting = '上午好，' + tn;
  else if (hour < 14) greeting = '中午好，' + tn;
  else if (hour < 18) greeting = '下午好，' + tn;
  else if (hour < 22) greeting = '晚上好，' + tn;
  else greeting = '夜深了，' + tn;
  var dateEl = document.getElementById('headerDate');
  var weekEl = document.getElementById('headerWeek');
  var greetEl = document.getElementById('greetingText');
  if (dateEl) dateEl.textContent = month + '月' + date + '日';
  if (weekEl) weekEl.textContent = week;
  if (greetEl) greetEl.textContent = greeting;

  var cn = document.getElementById('homeClassName'); if (cn) cn.textContent = getClassName();
  var hcn = document.getElementById('headerClassName'); if (hcn) hcn.textContent = getClassName();var tnd = document.getElementById('teacherNameDisplay'); if (tnd) tnd.textContent = getTeacherName();}

// ========== 页面导航栈 ==========
var pageStack = ['page-home'];
function navigateTo(pageId) {
  pageStack.push(pageId);
  showFullPage(pageId);
}
function navigateBack() {
  if (pageStack.length > 1) {
    pageStack.pop();
    var prev = pageStack[pageStack.length - 1];
    document.querySelectorAll('.full-page').forEach(function(p){ p.classList.remove('active'); });
    if (prev.indexOf('page-') === 0) {
      document.querySelectorAll('.page').forEach(function(p){ p.classList.remove('active'); });
      var tgt = document.getElementById(prev);
      if (tgt) tgt.classList.add('active');
      document.querySelectorAll('.tab-item').forEach(function(t){ t.classList.remove('tab-active'); });
      var tabMap = {'page-home':0, 'page-student':1, 'page-score':2, 'page-mine':3};
      var tabs = document.querySelectorAll('.tab-item');
      if (tabMap[prev] !== undefined && tabs[tabMap[prev]]) tabs[tabMap[prev]].classList.add('tab-active');
      if (!document.getElementById('modal').classList.contains('show')) document.body.style.overflow = '';
      if (prev === 'page-student') renderStuList();
      if (prev === 'page-score') { renderExamFilter(); renderExamList(); }
      if (prev === 'page-home') updateStats();
      var hdr = document.querySelector('header');
      if (hdr) hdr.style.display = (prev === 'page-mine') ? 'none' : '';
    } else {
      showFullPage(prev);
    }
  } else {
    document.querySelectorAll('.full-page').forEach(function(p){ p.classList.remove('active'); });
    if (!document.getElementById('modal').classList.contains('show')) document.body.style.overflow = '';
  }
}
function showFullPage(pageId) {
  document.querySelectorAll('.full-page').forEach(function(p){ p.classList.remove('active'); });
  var target = document.getElementById(pageId);
  if (target) target.classList.add('active');
  // 全屏页面锁定body滚动，tab页恢复
  if (target && target.classList.contains('full-page')) {
    document.body.style.overflow = 'hidden';
  } else {
    if (!document.getElementById('modal').classList.contains('show')) {
      document.body.style.overflow = '';
    }
  }
  // 滚动到顶部
  var body = target ? target.querySelector('.page-body') : null;
  if (body) body.scrollTop = 0;
}
function switchTab(pageId) {
  pageStack = [pageId];
  // 关闭所有全屏页面
  document.querySelectorAll('.full-page').forEach(function(p){ p.classList.remove('active'); });
  // 切换tab页面
  document.querySelectorAll('.page').forEach(function(p){ p.classList.remove('active'); });
  document.getElementById(pageId).classList.add('active');
  // 更新底部tab
  document.querySelectorAll('.tab-item').forEach(function(t){ t.classList.remove('tab-active'); });
  var tabMap = {'page-home':0, 'page-student':1, 'page-score':2, 'page-mine':3};
  var tabs = document.querySelectorAll('.tab-item');
  if (tabMap[pageId] !== undefined && tabs[tabMap[pageId]]) {
    tabs[tabMap[pageId]].classList.add('tab-active');
  }
  var titles = {home:'工作台', student:'学生名册', score:'成绩管理', mine:'我的', stumap:'学生分布地图'};
  var shortId = pageId.replace('page-','');
  var pt = document.getElementById("pageTitle");
  if (titles[shortId] && pt) pt.textContent = titles[shortId];
  if (shortId === 'student') renderStuList();
  if (shortId === 'score') { renderExamFilter(); renderExamList(); }
  if (shortId === 'home') updateStats();
  if (shortId === 'mine') { var mc=document.getElementById('mineClassName'); if(mc) mc.textContent=getClassName(); }
  if (shortId === 'stumap') { setTimeout(function(){ initStuMap(); if(_stuMap){ setTimeout(function(){_stuMap.invalidateSize();}, 150); } }, 100); }
  // 我的页面和地图页面隐藏header，其他页面显示
  var header = document.querySelector('header');
  if (header) {
    if (shortId === 'mine' || shortId === 'stumap') {
      header.style.display = 'none';
    } else {
      header.style.display = '';
    }
  }
}

// ========== 页面切换 ==========
function goPage(page) {
  curPage = page;
  switchTab('page-' + page);
}

// ========== 首页 ==========
function updateStats() {
  var students = get('students');
  var exams = get('exams');
  var subjects = get('subjects');
  var pending = 0;
  exams.forEach(function(e) {
    var cat = e.category || inferCategory(e.type);
    // 只统计大考（月考+期中+期末），单元测不计入待办
    if (cat === '单元测') return;
    if (Object.keys(e.scores).length < students.length) pending++;
  });
  document.getElementById('stat-student').textContent = students.length;
  document.getElementById('stat-exam').textContent = pending;
  document.getElementById('stat-subject').textContent = subjects.length;
}

function getDutyGroupByDay() {
  var day = new Date().getDay(); // 0=周日, 1-5=周一到周五, 6=周六
  if (day >= 1 && day <= 5) return day; // 周一第1组...周五第5组
  return 0; // 周末
}
function renderDuty() {
  var dayNames = ['周日','周一','周二','周三','周四','周五','周六'];
  var day = new Date().getDay();
  var group = getDutyGroupByDay();
  var titleEl = document.getElementById('dutyTitle');
  if (titleEl) titleEl.textContent = '今日值日 · ' + dayNames[day];
  if (group === 0) {
    var nextStudents = get('students').filter(function(s){ return s.dutyGroup == 1; });
    var nextNames = nextStudents.map(function(s){ return s.name; }).join('、');
    if (titleEl) titleEl.textContent = '下周一值日';
    document.getElementById('dutyText').innerHTML = '<span class="font-semibold text-green-600">第1组</span> · ' + nextNames;
    return;
  }
  var students = get('students').filter(function(s){ return s.dutyGroup == group; });
  var names = students.map(function(s){ return s.name; }).join('、');
  document.getElementById('dutyText').innerHTML = '<span class="font-semibold text-green-600">第' + group + '组</span> · ' + names;
}
var _dutyPreviewGroup = 0;
function switchDuty() {
  var cur = _dutyPreviewGroup || getDutyGroupByDay() || 1;
  var next = cur >= 5 ? 1 : cur + 1;
  _dutyPreviewGroup = next;
  var students = get('students').filter(function(s){ return s.dutyGroup == next; });
  var names = students.map(function(s){ return s.name; }).join('、');
  var dayNames = ['周一','周二','周三','周四','周五'];
  var titleEl = document.getElementById('dutyTitle');
  if (titleEl) titleEl.textContent = dayNames[next-1] + '值日';
  var textEl = document.getElementById('dutyText');
  if (textEl) textEl.innerHTML = '<span class="font-semibold text-green-600">第' + next + '组</span> · ' + names;
}

// ========== 复制电话 ==========
function copyPhone(phone) {
  if (navigator.clipboard) {
    navigator.clipboard.writeText(phone).then(function(){ alert('号码已复制'); });
  } else {
    var input = document.createElement('input');
    input.value = phone;
    document.body.appendChild(input);
    input.select();
    document.execCommand('copy');
    document.body.removeChild(input);
    alert('号码已复制');
  }
}

// ========== 今日课程（仅显示我的科目） ==========
function renderTodaySchedule() {
  var schedule = getScheduleData();
  var content = document.getElementById('todayScheduleContent');
  var tagEl = document.getElementById('todayScheduleTag');
  if (!content) return;
  var day = new Date().getDay();
  var dayNames = ['周日','周一','周二','周三','周四','周五','周六'];
  var targetDayIdx = (day === 0 || day === 6) ? 0 : day - 1;
  var targetDayName = (day === 0 || day === 6) ? '下周一' : dayNames[day];
  var mySubs = getMySubjects();
  var classList = [];
  for (var i = 0; i < schedule.length; i++) {
    var subject = schedule[i][targetDayIdx];
    if (subject && subject.trim() && mySubs.indexOf(subject) >= 0) classList.push({idx: i, subject: subject});
  }
  tagEl.textContent = targetDayName + ' · 我的课' + classList.length + '节';
  if (classList.length === 0) {
    content.innerHTML = '<p class="text-center py-3 text-sm" style="color:var(--text3,#B8AEA4);">' + targetDayName + '没有我的课</p>';
    return;
  }
  var html = '<div class="space-y-1.5">';
  classList.forEach(function(item) {
    var i = item.idx;
    var subj = item.subject;
    html += '<div class="flex items-center gap-2.5 p-2.5 rounded-xl" style="background:var(--input-bg,#F5F0E8);border-left:3px solid var(--primary,#D97757);">'
      + '<span class="text-xs font-semibold flex-shrink-0" style="color:var(--primary,#D97757);min-width:72px;">' + SCHEDULE_TIMES[i] + '-' + SCHEDULE_END_TIMES[i] + '</span>'
      + '<span class="text-sm font-bold flex-1" style="color:var(--text,#3A322C);">' + subj + '</span>'
      + '<span class="text-[11px] flex-shrink-0" style="color:var(--text3,#B8AEA4);">第' + (i+1) + '节</span>'
      + '</div>';
  });
  html += '</div>';
  content.innerHTML = html;
}

function renderTodos() {
  var todos = get('todos');
  var html = '';
  todos.forEach(function(t) {
    html += '<div class="todo-item flex items-center gap-3 text-sm ' + (t.done?'done':'') + '" style="padding: 10px 12px; border-radius: 12px;">'
      + '<label class="todo-check-wrap" style="width:20px;height:20px;flex-shrink:0;cursor:pointer;position:relative;display:inline-flex;align-items:center;justify-content:center;">'
      + '<input type="checkbox" ' + (t.done?'checked':'') + ' onchange="toggleTodo(' + t.id + ')" style="position:absolute;opacity:0;width:100%;height:100%;cursor:pointer;margin:0;">'
      + '<span class="todo-check-box" style="width:20px;height:20px;border-radius:6px;border:2px solid var(--text3,#B8AEA4);display:inline-flex;align-items:center;justify-content:center;transition:all 0.2s;' + (t.done?'background:var(--primary,#D97757);border-color:var(--primary,#D97757);':'') + '">'
      + (t.done ? '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>' : '')
      + '</span></label>'
      + '<span class="flex-1" style="color:var(--text,#3A322C);">' + t.text + '</span>'
      + '<button class="text-sm" style="color:var(--text3,#B8AEA4);" onclick="delTodo(' + t.id + ')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button>'
      + '</div>';
  });
  document.getElementById('todoList').innerHTML = html;
}

function toggleTodo(id) {
  var todos = get('todos');
  todos.forEach(function(t) { if (t.id === id) t.done = !t.done; });
  set('todos', todos);
  renderTodos();
}

function addTodo() {
  var text = prompt('输入待办事项：');
  if (!text) return;
  var todos = get('todos');
  todos.push({id: Date.now(), text:text, done:false});
  set('todos', todos);
  renderTodos();
}

function delTodo(id) {
  var todos = get('todos').filter(function(t){ return t.id !== id; });
  set('todos', todos);
  renderTodos();
}

// ========== 学生管理 ==========
function printStudents() {
  var students = get('students');
  var html = '<table class="print-table"><thead><tr><th style="width:50px;">序号</th><th>姓名</th><th style="width:45px;">性别</th><th>职务</th><th style="width:70px;">小组</th><th>联系电话</th></tr></thead><tbody>';
  students.slice().sort(function(a,b){return a.id-b.id;}).forEach(function(s) {
    html += '<tr><td>' + s.id + '</td><td>' + s.name + '</td><td>' + s.gender + '</td><td>' + (s.duty||'') + '</td><td>第' + s.dutyGroup + '组</td><td>' + (s.phone||'') + '</td></tr>';
  });
  html += '</tbody></table>';
  printContent('学生名册', html, getClassName() + ' · 共' + students.length + '人');
}
// 座位号转"X排X座"（联动座位表列数）
function getSeatLabel(seat) {
  if (!seat) return '未排座';
  var cols = parseInt(localStorage.getItem('seatCols') || '6');
  var row = Math.floor((seat - 1) / cols) + 1;
  var col = (seat - 1) % cols + 1;
  return row + '排' + col + '座';
}
function renderStuList() {
  var students = get('students');
  var kw = document.getElementById('stuSearch').value.toLowerCase();
  var list = students.filter(function(s){ return s.name.indexOf(kw) >= 0 || s.id.toString().indexOf(kw) >= 0 || (s.phone && s.phone.indexOf(kw) >= 0) || (s.contact && s.contact.indexOf(kw) >= 0); });
  if (stuFilterVal !== 'all') {
    var cols = parseInt(localStorage.getItem('seatCols') || '6');
    list = list.filter(function(s){ return Math.floor((s.seat - 1) / cols) + 1 === stuFilterVal; });
  }
  // 按学号从1往后排（学号已随机洗牌分配，男女不规则错开）
  list.sort(function(a, b) { return a.id - b.id; });
  if (!list.length) {
    document.getElementById('stuList').innerHTML = '<div class="text-center py-12" style="color:var(--text3,#B8AEA4);"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="margin:0 auto 8px;opacity:0.5;"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg><p class="text-sm">未找到匹配的学生</p></div>';
    document.getElementById('stuCount').textContent = '共 0 人';
    return;
  }
  var html = '<div style="padding:4px 0;">';
  list.forEach(function(s, idx) {
    var dutyTag = s.duty ? '<span class="duty-tag">' + s.duty + '</span>' : '';
    var callIcon = s.phone ? '<span class="stu-call-icon" onclick="event.stopPropagation();window.location.href=\'tel:' + s.phone + '\';"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#D97757" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg></span>' : '';
    html += '<div class="stu-card-v2" onclick="openStuDetail(' + s.id + ')">'
      + '<div class="stu-avatar-v2">' + s.name.charAt(0) + '</div>'
      + '<div class="flex-1 min-w-0">'
      + '<div class="flex items-center gap-1.5">'
      + '<span class="stu-name-v2" style="font-size:16px;font-weight:600;color:#1c1c1e;">' + s.name + '</span>'
      + dutyTag
      + '</div>'
      + '<div class="flex items-center gap-1.5 mt-0.5">'
      + '<span style="font-size:12px;color:var(--primary,#D97757);font-weight:600;">#' + s.id + '</span>'
      + '<span style="font-size:11px;color:#c7c7cc;">·</span>'
      + '<span style="font-size:12px;color:#8e8e93;">' + getSeatLabel(s.seat) + '</span>'
      + '</div></div>'
      + callIcon
      + '</div>';
  });
  html += '</div>';
  document.getElementById('stuList').innerHTML = html;
  var countEl = document.getElementById('stuCount');
  if (countEl) countEl.textContent = '共 ' + list.length + ' 人';
}

function filterStu(g) {
  stuFilterVal = g;
  document.querySelectorAll('.stu-filter-btn').forEach(function(b){ b.classList.remove('stu-filter-active'); });
  var btns = document.querySelectorAll('.stu-filter-btn');
  var idx = g === 'all' ? 0 : g;
  if (btns[idx]) btns[idx].classList.add('stu-filter-active');
  var btns = document.querySelectorAll('.stu-filter');
  btns.forEach(function(b) {
    b.style.background = '#f9f9fb';
    b.style.color = '#8e8e93';
  });
  event.target.style.background = 'linear-gradient(135deg, #F0FBF5, #E8EEF2)';
  event.target.style.color = '#C4613F';
  renderStuList();
}

document.getElementById('stuSearch').addEventListener('input', function() {
  renderStuList();
});

function openStuDetail(id) {
  curStuId = id;
  window._curStuId = id;
  var s = get('students').find(function(x){ return x.id === id; });
  var exams = get('exams');
  var avatarBg = s.gender === '男' 
    ? 'background: linear-gradient(135deg, #E8EEF2, #D0DEE6); color: #C4613F;'
    : 'background: linear-gradient(135deg, #F5E6E0, #F0D8D0); color: #C07060;';
  var tagsHtml = '';
  if (s.tags && s.tags.length) {
    s.tags.forEach(function(t) {
      tagsHtml += '<span class="tag mr-1.5 mb-1" style="background: linear-gradient(135deg, #F0FBF5, #E8EEF2); color: #C4613F;">' + t + '</span>';
    });
  }
  var stuExams = exams.filter(function(e) { return e.scores[id] !== undefined; });
  
  // 按一级分类分组
  var groups = {};
  stuExams.forEach(function(e) {
    var cat = e.category || inferCategory(e.type);
    if (!groups[cat]) groups[cat] = [];
    groups[cat].push(e);
  });
  
  var catOrder = ['单元测', '月考', '期中考', '期末考'];
  var sortedCats = catOrder.filter(function(c){ return groups[c]; });
  
  var scoresHtml = '';
  sortedCats.forEach(function(cat) {
    var catExams = groups[cat];
    var catRate = Math.round(catExams.reduce(function(sum, e) { return sum + (e.scores[id] / e.fullScore * 100); }, 0) / catExams.length);
    var rateColor = catRate >= 85 ? '#10b981' : catRate >= 70 ? '#D97757' : catRate >= 60 ? '#f59e0b' : '#ef4444';
    var catInfo = EXAM_CATEGORIES.find(function(c){ return c.key === cat; });
    var icon = catInfo ? catInfo.icon : '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>';
    var expanded = cat !== '单元测';
    var groupId = 'stu-exam-' + cat.replace(/测|考/g, '');
    
    scoresHtml += '<div class="mb-1.5">'
      + '<div class="flex items-center justify-between py-2.5 px-2 cursor-pointer rounded-lg hover:bg-gray-50" onclick="toggleStuExamGroup(\'' + groupId + '\', this)">'
      + '<span class="text-xs font-semibold text-gray-600 flex items-center gap-1.5">'
      + '<span class="stu-exam-arrow text-gray-400 text-xs transition-transform" style="display:inline-block;' + (expanded?'transform:rotate(90deg);':'') + '">▶</span>'
      + icon + ' ' + cat + '</span>'
      + '<span class="text-xs font-medium" style="color:' + rateColor + ';">得分率 ' + catRate + '% · ' + new Set(catExams.map(function(e){return e.type;})).size + '场</span>'
      + '</div>'
      + '<div id="' + groupId + '" class="stu-exam-content" style="display:' + (expanded?'block':'none') + ';padding-left:8px;">';
    
    var typeGroups = {};
    catExams.forEach(function(e) {
      if (!typeGroups[e.type]) typeGroups[e.type] = [];
      typeGroups[e.type].push(e);
    });
    Object.keys(typeGroups).forEach(function(typeName, tIdx) {
      var typeExams = typeGroups[typeName];
      var typeTotal = typeExams.reduce(function(sum, e) { return sum + e.scores[id]; }, 0);
      var typeFull = typeExams.reduce(function(sum, e) { return sum + e.fullScore; }, 0);
      var typeRate = Math.round(typeTotal / typeFull * 100);
      var typeRateColor = typeRate >= 85 ? '#10b981' : typeRate >= 70 ? '#D97757' : typeRate >= 60 ? '#f59e0b' : '#ef4444';
      var typeId = groupId + '-t' + tIdx;
      scoresHtml += '<div class="mt-1.5">'
        + '<div class="flex items-center justify-between py-1.5 px-1.5 cursor-pointer rounded hover:bg-gray-50" onclick="toggleStuExamType(\'' + typeId + '\', this)">'
        + '<span class="text-xs font-medium text-gray-500 flex items-center gap-1">'
        + '<span class="stu-type-arrow text-gray-300 text-xs transition-transform" style="display:inline-block;">▶</span>'
        + typeName
        + '</span>'
        + '<span class="text-xs font-medium" style="color:' + typeRateColor + ';">' + typeTotal + '/' + typeFull + ' · ' + typeRate + '%</span>'
        + '</div>'
        + '<div id="' + typeId + '" class="stu-type-content" style="display:none;padding-left:14px;">';
      typeExams.forEach(function(e) {
        var pct = Math.round(e.scores[id] / e.fullScore * 100);
        var color = pct >= 80 ? '#10b981' : pct >= 60 ? '#f59e0b' : '#ef4444';
        scoresHtml += '<div class="flex justify-between items-center py-1.5 border-b border-gray-50 last:border-0">'
          + '<span class="text-sm text-gray-600">' + e.subject + '</span>'
          + '<span class="font-bold" style="color:' + color + ';">' + e.scores[id] + '分</span></div>';
      });
      scoresHtml += '</div></div>';
    });
    
    scoresHtml += '</div></div>';
  });
  
  if (!sortedCats.length) {
    scoresHtml = '<p class="text-gray-400 text-sm text-center py-4">暂无成绩</p>';
  }
  document.getElementById('stuDetailContent').innerHTML =
    '<div class="flex items-center gap-4 mb-5">'
    + '<div class="w-16 h-16 rounded-2xl flex items-center justify-center text-2xl font-bold" style="' + avatarBg + '">'
    + s.name.charAt(0) + '</div>'
    + '<div><h3 class="text-lg font-bold text-gray-800">' + s.name + '</h3>'
    + '<p class="text-gray-500 text-xs mt-0.5">序号' + s.id + ' · 座位' + getSeatLabel(s.seat) + '</p>'
    + '</div></div>'
    + '<div class="card mb-4"><h4 class="font-semibold text-sm mb-3 text-gray-700">基本信息</h4>'
    + '<div class="space-y-2.5 text-sm">'
    + '<div class="flex justify-between items-center"><span class="text-gray-500">性别</span><span class="text-gray-800 font-medium">' + s.gender + '</span></div>'
    + '<div class="flex justify-between items-center"><span class="text-gray-500">职务</span><span class="text-gray-800 font-medium">' + (s.duty || '无') + '</span></div>'
    + '<div class="flex justify-between items-center"><span class="text-gray-500">值日小组</span><span class="text-gray-800 font-medium">第' + s.dutyGroup + '组</span></div>'
    + '</div></div>'
    + '<div class="card mb-4"><h4 class="font-semibold text-sm mb-3 text-gray-700">家校联系</h4>'
    + '<div class="space-y-2.5 text-sm">'
    + '<div class="flex justify-between items-center"><span class="text-gray-500">联系人</span><span class="text-gray-800 font-medium">' + s.contact + '</span></div>'
    + '<div class="flex justify-between items-center"><span class="text-gray-500">电话</span><span class="text-gray-800 font-medium flex items-center gap-1.5" style="cursor:pointer;" onclick="copyPhone(\'' + s.phone + '\')"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect></svg><span>' + s.phone + '</span></span></div>'
    + '<div class="addr-nav-row" onclick="openMapNavSheet(' + s.id + ')"><span class="text-gray-500 text-xs">家庭住址 ' + (s.lng && s.lat ? '<span style="color:#16a34a;">· 已定位</span>' : '<span style="color:#f97316;">· 未定位</span>') + '</span><div class="flex items-center justify-between mt-1"><p class="text-sm text-gray-700 flex-1 pr-2">' + s.address + '</p><span class="addr-nav-btn"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg>导航</span></div></div>'
    + '<a href="tel:' + s.phone + '" class="block w-full mt-3 py-2.5 rounded-xl text-sm font-medium" style="background: linear-gradient(135deg, #d1fae5, #B8D0C0); color: #B85A3A; display:flex; align-items:center; justify-content:center; gap:6px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>拨打家长电话</a>'
    + '</div></div>'
    + (function(){
      var subs = getStuSubjects(id);
      if (subs.indexOf('语文') >= 0) curStuChartSubject = '语文';
      else if (subs.length) curStuChartSubject = subs[0];
      var tabs = subs.map(function(sub){
        return '<button class="stu-chart-tab' + (curStuChartSubject===sub?' active':'') + '" data-subject="' + sub + '" onclick="switchStuChart(\'' + sub + '\')">' + sub + '</button>';
      }).join('');
      return '<div class="card mb-4" onclick="event.stopPropagation()">'
        + '<h4 id="stuChartTitle" class="font-semibold text-sm mb-3 text-gray-700">成绩趋势 · ' + curStuChartSubject + ' <span class="text-xs text-gray-400 font-normal">（满分' + (function(){var e=getExams().find(function(x){return x.subject===curStuChartSubject;});return e?e.fullScore:100;})() + '分）</span></h4>'
        + '<div class="flex gap-1.5 mb-3 overflow-x-auto pb-1">' + tabs + '</div>'
        + '<div id="stuChartContainer">' + renderStuScoreChart(id, curStuChartSubject) + '</div>'
        + '</div>';
    })()
    + '<div class="card mb-4"><h4 class="font-semibold text-sm mb-3 text-gray-700">考试记录</h4>' + scoresHtml + '</div>'
    + '<div class="card"><h4 class="font-semibold text-sm mb-3 text-gray-700">私密备注</h4>'
    + '<textarea id="remarkInput" class="input-field" rows="3" placeholder="记录学生的特殊情况...">' + (s.remark || '') + '</textarea>'
    + '<button onclick="saveRemark()" class="w-full btn-primary mt-3">保存备注</button>'
    + '</div>';
  navigateTo('page-stu-detail');
  setTimeout(drawStuChart, 100);
}

function closeStuDrawer() {
  navigateBack();
}

function saveRemark() {
  var students = get('students');
  var s = students.find(function(x){ return x.id === curStuId; });
  s.remark = document.getElementById('remarkInput').value;
  set('students', students);
  alert('备注已保存');
}

function editStu() {
  var s = get('students').find(function(x){ return x.id === curStuId; });
  if (!s) return;
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">编辑学生</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<div><label class="text-xs text-gray-500 block mb-1">姓名</label><input id="editStuName" class="input-field" value="' + s.name + '"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">性别</label><select id="editStuGender" class="input-field"><option ' + (s.gender==='男'?'selected':'') + '>男</option><option ' + (s.gender==='女'?'selected':'') + '>女</option></select></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">家长姓名</label><input id="editStuContact" class="input-field" value="' + (s.contact||'') + '"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">联系电话</label><input id="editStuPhone" class="input-field" value="' + (s.phone||'') + '"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">家庭住址</label>'
    + '<div class="flex gap-2">'
    + '<input id="editStuAddr" class="input-field flex-1" value="' + (s.address||'') + '" placeholder="输入地址后点地图选点">'
    + '<button onclick="openMapPicker()" class="btn-primary px-3 whitespace-nowrap" style="font-size:13px;display:inline-flex;align-items:center;gap:4px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>选点</button>'
    + '</div>'
    + '<input type="hidden" id="editStuLng" value="' + (s.lng!==undefined?s.lng:'') + '">'
    + '<input type="hidden" id="editStuLat" value="' + (s.lat!==undefined?s.lat:'') + '">'
    + (s.lng && s.lat ? '<p class="text-xs text-green-600 mt-1"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:3px;"><polyline points="20 6 9 17 4 12"/></svg>已定位：' + s.lng.toFixed(6) + ', ' + s.lat.toFixed(6) + '</p>' : '<p class="text-xs text-orange-500 mt-1"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:3px;"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>未定位，导航可能不准确，建议点地图选点</p>')
    + '</div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">职务</label><input id="editStuDuty" class="input-field" value="' + (s.duty||'') + '" placeholder="如：班长"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">值日小组</label><select id="editStuDutyGroup" class="input-field">'
    + [1,2,3,4,5].map(function(g){return '<option value="'+g+'" '+(s.dutyGroup==g?'selected':'')+'>第'+g+'组</option>';}).join('')
    + '</select></div>'
    + '<button onclick="saveStuEdit()" class="w-full btn-primary">保存</button>'
    + '<button onclick="deleteStu()" class="w-full btn-secondary" style="color:#ef4444;">删除该学生</button>'
    + '</div>'
  );
}
function saveStuEdit() {
  var students = get('students');
  var s = students.find(function(x){ return x.id === curStuId; });
  if (!s) return;
  s.name = document.getElementById('editStuName').value.trim() || s.name;
  s.gender = document.getElementById('editStuGender').value;
  s.contact = document.getElementById('editStuContact').value.trim();
  s.phone = document.getElementById('editStuPhone').value.trim();
  s.address = document.getElementById('editStuAddr').value.trim();
  var lngVal = document.getElementById('editStuLng').value;
  var latVal = document.getElementById('editStuLat').value;
  if (lngVal && latVal) {
    s.lng = parseFloat(lngVal);
    s.lat = parseFloat(latVal);
  } else {
    delete s.lng;
    delete s.lat;
  }
  s.duty = document.getElementById('editStuDuty').value.trim();
  s.dutyGroup = parseInt(document.getElementById('editStuDutyGroup').value);
  set('students', students);
  closeModal();
  openStuDetail(curStuId); // 重新渲染学生详情
  renderStuList();
  updateStats();
  alert('保存成功');
}
function deleteStu() {
  if (!confirm('确定删除该学生吗？相关成绩也会被清除。')) return;
  var students = get('students').filter(function(x){ return x.id !== curStuId; });
  set('students', students);
  // 清除该学生的成绩
  var exams = getExams();
  exams.forEach(function(e){ delete e.scores[curStuId]; });
  saveExams(exams);
  closeModal();
  navigateBack();
  renderStuList();
  updateStats();
  alert('删除成功');
}

function openStuManage() {
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">学生管理</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<button onclick="addStu()" class="w-full btn-primary">+ 添加学生</button>'
    + '<button onclick="batchImportStu()" class="w-full btn-secondary">批量导入</button>'
    + '</div>'
  );
}

function addStu() {
  var name = prompt('学生姓名：');
  if (!name) return;
  var gender = prompt('性别（男/女）：', '男');
  if (!gender) return;
  var students = get('students');
  var newId = students.length ? Math.max.apply(null, students.map(function(s){ return s.id; })) + 1 : 1;
  students.push({
    id: newId, name: name, gender: gender, seat: newId,
    group: 1, duty: '', dutyGroup: 1,
    contact: '', phone: '', address: '', remark: '', tags: [],
    sortOrder: Math.random()
  });
  set('students', students);
  var seatMap = JSON.parse(localStorage.getItem('seatMap') || '{}');
  seatMap[newId] = newId;
  localStorage.setItem('seatMap', JSON.stringify(seatMap));
  closeModal();
  renderStuList();
  updateStats();
  alert('添加成功');
}

function batchImportStu() {
  var text = prompt('批量导入（每行一个，格式：序号 姓名）：\n例如：\n36 张三\n37 李四');
  if (!text) return;
  var lines = text.trim().split('\n');
  var students = get('students');
  var count = 0;
  lines.forEach(function(line) {
    line = line.trim();
    if (!line) return;
    var parts = line.split(/\s+/);
    if (parts.length >= 2) {
      var id = parseInt(parts[0]);
      var name = parts[1];
      var gender = parts[2] || '男';
      students.push({
        id: id, name: name, gender: gender, seat: id,
        group: 1, duty: '', dutyGroup: 1,
        contact: '', phone: '', address: '', remark: '', tags: [],
        sortOrder: Math.random()
      });
      count++;
    }
  });
  set('students', students);
  closeModal();
  renderStuList();
  updateStats();
  alert('成功导入 ' + count + ' 名学生');
}


// ========== 成绩管理 ==========
function renderExamFilter() {
  var bar = document.getElementById('examFilter');
  var activeStyle = 'style="background: linear-gradient(135deg, #F0FBF5, #E8EEF2); color: #C4613F;"';
  var inactiveStyle = 'style="background: #f9f9fb; color: #8e8e93;"';
  var html = '<button class="exam-filter tag" ' + (examFilterVal==='all'?activeStyle:inactiveStyle) + ' onclick="filterExam(\'all\')">全部</button>';
  EXAM_CATEGORIES.forEach(function(cat) {
    html += '<button class="exam-filter tag" ' + (examFilterVal===cat.key?activeStyle:inactiveStyle) + ' onclick="filterExam(\'' + cat.key + '\')">' + cat.icon + ' ' + cat.key + '</button>';
  });
  bar.innerHTML = html;
}

function filterExam(category) {
  examFilterVal = category;
  renderExamFilter();
  renderExamList();
}

function renderExamList() {
  var exams = getExams();
  var students = get('students');
  var list = exams;
  if (examFilterVal !== 'all') {
    list = exams.filter(function(e){ return e.category === examFilterVal; });
  }

  // 按一级分类分组
  var groups = {};
  list.forEach(function(e) {
    if (!groups[e.category]) groups[e.category] = [];
    groups[e.category].push(e);
  });

  var html = '';
  EXAM_CATEGORIES.forEach(function(cat) {
    var catExams = groups[cat.key];
    if (!catExams || catExams.length === 0) return;

    // 按二级名称(type)聚合
    var typeGroups = {};
    catExams.forEach(function(e) {
      if (!typeGroups[e.type]) typeGroups[e.type] = [];
      typeGroups[e.type].push(e);
    });

    var catDone = 0;
    var catTotal = catExams.length;
    catExams.forEach(function(e) {
      if (Object.keys(e.scores).length === students.length) catDone++;
    });

    html += '<div class="mb-3">'
      + '<div class="flex items-center justify-between mb-2 px-1">'
      + '<h3 class="text-sm font-semibold text-gray-700 flex items-center gap-2">'
      + '<span style="display:inline-flex;align-items:center;">' + cat.icon + '</span>'
      + cat.key + '</h3>'
      + '<span class="text-xs text-gray-400">' + catDone + '/' + catTotal + ' 已完成</span>'
      + '</div>';

    Object.keys(typeGroups).forEach(function(typeName, tIdx) {
      var typeExams = typeGroups[typeName];
      var typeDone = typeExams.filter(function(e) {
        return Object.keys(e.scores).length === students.length;
      }).length;
      var typePct = Math.round(typeDone / typeExams.length * 100);
      var groupId = 'type-group-' + cat.key + '-' + tIdx;

      html += '<div class="card mb-2" style="padding:0;overflow:hidden;">'
        + '<div class="flex items-center justify-between p-3 cursor-pointer" onclick="toggleTypeGroup(\'' + groupId + '\', this)">'
        + '<div class="flex-1 min-w-0">'
        + '<div class="font-semibold text-gray-800 text-sm flex items-center gap-2">'
        + '<span class="type-arrow text-gray-400 text-xs transition-transform" style="display:inline-block;">▶</span>'
        + typeName
        + '</div>'
        + '<div class="text-xs text-gray-400 mt-1">' + typeExams.length + ' 个科目 · ' + typeDone + ' 已完成</div>'
        + '</div>'
        + '<div class="ml-3">'
        + '<button onclick="event.stopPropagation();handleCalcRank(this)" class="text-xs px-3 py-1.5 rounded-full font-medium flex-shrink-0" data-cat="' + cat.key + '" data-type="' + typeName.replace(/"/g, '&quot;') + '" style="background: linear-gradient(135deg, #F5E6E0, #F0D8D0); color: #C07060;">计算</button>'
        + '</div>'
        + '</div>'
        + '<div id="' + groupId + '" class="type-group-content" style="display:none;">';

      typeExams.forEach(function(e) {
        var filled = Object.keys(e.scores).length;
        var total = students.length;
        var pct = Math.round(filled / total * 100);
        var isDone = filled === total;
        html += '<div class="flex items-center justify-between p-3 border-b border-gray-50 last:border-0 cursor-pointer" onclick="openExamDetail(' + e.id + ')">'
          + '<div class="flex-1 min-w-0">'
          + '<div class="text-sm font-medium text-gray-700">' + e.subject + '</div>'
          + '<div class="text-xs text-gray-400 mt-0.5">' + e.date + ' · 满分' + e.fullScore + '</div>'
          + '</div>'
          + '<span class="tag" style="background: ' + (isDone ? 'linear-gradient(135deg, #d1fae5, #B8D0C0)' : 'linear-gradient(135deg, #fef3c7, #fde68a)') + '; color: ' + (isDone ? '#B85A3A' : '#d97706') + ';">'
          + filled + '/' + total + '</span>'
          + '</div>';
      });

      html += '</div></div>';
    });

    html += '</div>';
  });

  if (!html) {
    html = '<div class="text-center text-gray-400 text-sm py-12">暂无考试记录，点击右上角「+ 新建」添加</div>';
  }

  document.getElementById('examList').innerHTML = html;
}

// ========== 单次考试总分排名 ==========
window.handleCalcRank = function(btn) {
  var cat = btn.getAttribute('data-cat');
  var typeName = btn.getAttribute('data-type');
  doCalcExamTotalRank(cat, typeName);
};



function generateRankImage() {
  if (!_lastRankData || !_lastRankData.length) {
    alert('请先计算排名');
    return;
  }
  var subjects = _lastRankSubjects || [];
  var title = _lastRankTitle || '总分排名';
  var className = getClassName();
  
  // 创建隐藏的图片容器
  var container = document.createElement('div');
  container.style.cssText = 'position:fixed;left:-9999px;top:0;width:750px;background:linear-gradient(180deg,#f8f9fa 0%,#e9ecef 100%);padding:40px 30px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;';
  
  // 标题区域（统一字号）
  var headerHtml = '<div style="text-align:center;margin-bottom:28px;">'
    + '<div style="font-size:30px;font-weight:700;color:#212529;letter-spacing:1px;margin-bottom:8px;white-space:nowrap;">' + title + '</div>'
    + '<div style="font-size:14px;color:#6c757d;">' + className + ' · 共' + _lastRankData.length + '人 · ' + subjects.length + '科</div>'
    + '</div>';
  
  // 表格
  var tableHtml = '<div style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">';
  // 表头（统一字号15px）
  tableHtml += '<div style="display:flex;background:linear-gradient(135deg,#495057,#343a40);padding:14px 20px;color:#fff;font-weight:600;font-size:15px;">'
    + '<span style="width:80px;text-align:center;white-space:nowrap;">名次</span>'
    + '<span style="flex:1;white-space:nowrap;">姓名</span>';
  subjects.forEach(function(subj) {
    tableHtml += '<span style="width:70px;text-align:center;white-space:nowrap;">' + subj + '</span>';
  });
  tableHtml += '<span style="width:90px;text-align:right;white-space:nowrap;">总分</span></div>';
  
  // 排名行（统一普通样式，无特殊排名标识）
  _lastRankData.forEach(function(s, i) {
    var bgColor = i % 2 === 0 ? '#ffffff' : '#f8f9fa';
    
    tableHtml += '<div style="display:flex;align-items:center;padding:13px 20px;background:' + bgColor + ';border-bottom:1px solid #f1f3f5;font-size:15px;">'
      + '<span style="width:80px;text-align:center;font-weight:600;color:#495057;">' + (i + 1) + '</span>'
      + '<span style="flex:1;font-weight:600;color:#212529;white-space:nowrap;">' + s.name + '</span>';
    subjects.forEach(function(subj) {
      var score = s.scores && s.scores[subj] !== undefined ? s.scores[subj] : '-';
      tableHtml += '<span style="width:70px;text-align:center;color:#6c757d;white-space:nowrap;">' + score + '</span>';
    });
    tableHtml += '<span style="width:90px;text-align:right;font-weight:700;color:#212529;">' + s.total + '</span></div>';
  });
  tableHtml += '</div>';
  
  // 底部
  var footerHtml = '<div style="text-align:center;margin-top:24px;font-size:14px;color:#adb5bd;">'
    + '生成时间：' + new Date().toLocaleString('zh-CN')
    + '</div>';
  
  container.innerHTML = headerHtml + tableHtml + footerHtml;
  document.body.appendChild(container);
  
  // 显示加载提示
  var loadingToast = document.createElement('div');
  loadingToast.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:rgba(0,0,0,0.75);color:#fff;padding:16px 24px;border-radius:12px;font-size:15px;z-index:9999;';
  loadingToast.textContent = '正在生成图片...';
  document.body.appendChild(loadingToast);
  
  // 用html2canvas生成图片
  setTimeout(function() {
    html2canvas(container, {
      scale: 2,
      useCORS: true,
      backgroundColor: null
    }).then(function(canvas) {
      // 移除容器和加载提示
      document.body.removeChild(container);
      document.body.removeChild(loadingToast);
      
      // 转换为图片并下载
      var link = document.createElement('a');
      link.download = title + '_' + new Date().getTime() + '.png';
      link.href = canvas.toDataURL('image/png');
      link.click();
      
      // 提示保存成功
      var successToast = document.createElement('div');
      successToast.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:rgba(40,167,69,0.9);color:#fff;padding:16px 24px;border-radius:12px;font-size:15px;z-index:9999;';
      successToast.textContent = '图片已保存到下载目录';
      document.body.appendChild(successToast);
      setTimeout(function() { document.body.removeChild(successToast); }, 2000);
    }).catch(function(err) {
      document.body.removeChild(container);
      document.body.removeChild(loadingToast);
      alert('生成图片失败：' + err.message);
    });
  }, 100);
}

function printRank() {
  if (!_lastRankData || !_lastRankData.length) {
    alert('请先计算排名');
    return;
  }
  var subjects = _lastRankSubjects || [];
  var title = _lastRankTitle || '总分排名';
  // 根据科目数量调整字体大小，确保横排
  var fontSize = subjects.length > 7 ? '11px' : '13px';
  var html = '<table class="print-table" style="width:100%;border-collapse:collapse;font-size:' + fontSize + ';">';
  html += '<thead><tr style="background:#e5e5ea;">';
  html += '<th style="border:1px solid #999;padding:6px 3px;text-align:center;white-space:nowrap;">名次</th>';
  html += '<th style="border:1px solid #999;padding:6px 3px;text-align:center;white-space:nowrap;">姓名</th>';
  subjects.forEach(function(subj) {
    html += '<th style="border:1px solid #999;padding:6px 3px;text-align:center;white-space:nowrap;">' + subj + '</th>';
  });
  html += '<th style="border:1px solid #999;padding:6px 3px;text-align:center;white-space:nowrap;font-weight:bold;">总分</th>';
  html += '</tr></thead><tbody>';
  _lastRankData.forEach(function(s, i) {
    html += '<tr>';
    html += '<td style="border:1px solid #999;padding:5px 3px;text-align:center;">' + (i + 1) + '</td>';
    html += '<td style="border:1px solid #999;padding:5px 3px;text-align:center;white-space:nowrap;">' + s.name + '</td>';
    subjects.forEach(function(subj) {
      var score = s.scores && s.scores[subj] !== undefined ? s.scores[subj] : '-';
      html += '<td style="border:1px solid #999;padding:5px 3px;text-align:center;">' + score + '</td>';
    });
    html += '<td style="border:1px solid #999;padding:5px 3px;text-align:center;font-weight:bold;">' + s.total + '</td>';
    html += '</tr>';
  });
  html += '</tbody></table>';
  // 横向打印，确保科目名称横排
  printContent(title, html, getClassName() + ' · 共' + _lastRankData.length + '人 · ' + subjects.length + '科', true);
}

function openRankDrawer() {
  var drawer = document.getElementById('rankDrawer');
  if (drawer) {
    drawer.style.transform = 'translateX(0)';
    document.body.style.overflow = 'hidden';
  }
}

function closeRankDrawer() {
  var drawer = document.getElementById('rankDrawer');
  if (drawer) {
    drawer.style.transform = 'translateX(100%)';
    document.body.style.overflow = '';
  }
}

function doCalcExamTotalRank(cat, typeName) {
  var exams = getExams().filter(function(e) {
    return e.category === cat && e.type === typeName;
  });
  if (exams.length === 0) {
    alert('该考试没有科目数据');
    return;
  }

  var students = get('students');
  var subjectList = exams.map(function(e) { return e.subject; });

  // 计算每个学生的总分和各科成绩
  var rankList = students.map(function(student) {
    var total = 0;
    var count = 0;
    var scores = {};
    exams.forEach(function(exam) {
      if (exam.scores[student.id] !== undefined) {
        total += exam.scores[student.id];
        count++;
        scores[exam.subject] = exam.scores[student.id];
      }
    });
    return {
      id: student.id,
      name: student.name,
      total: total,
      count: count,
      scores: scores
    };
  }).filter(function(item) {
    return item.count > 0;
  }).sort(function(a, b) {
    return b.total - a.total;
  });

  // 保存数据供打印使用
  _lastRankData = rankList;
  _lastRankSubjects = subjectList;
  _lastRankTitle = typeName + '总分';

  // 设置标题
  document.getElementById('rankDrawerTitle').textContent = cat + ' · ' + typeName + ' 总分排名';

  // 生成规范的排名结果HTML（优化排版、字体、间距）
  var rankHtml = '<div style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">';
  // 表头
  rankHtml += '<div style="display:flex;background:linear-gradient(135deg,#f8f9fa,#e9ecef);padding:12px 16px;border-bottom:2px solid #dee2e6;font-weight:600;font-size:14px;color:#495057;">'
    + '<span style="width:50px;text-align:center;">名次</span>'
    + '<span style="flex:1;">姓名</span>'
    + '<span style="width:80px;text-align:right;">总分</span>'
    + '</div>';
  // 排名列表（统一普通样式，无特殊排名标识）
  rankList.forEach(function(item, index) {
    var bgColor = index % 2 === 0 ? '#ffffff' : '#f8f9fa';
    rankHtml += '<div style="display:flex;align-items:center;padding:14px 16px;background:' + bgColor + ';border-bottom:1px solid #f1f3f5;">'
      + '<span style="width:50px;text-align:center;font-weight:600;font-size:15px;color:#495057;">' + (index + 1) + '</span>'
      + '<span style="flex:1;font-size:15px;font-weight:500;color:#212529;white-space:nowrap;">' + item.name + '</span>'
      + '<span style="width:80px;text-align:right;font-size:16px;font-weight:700;color:#212529;">' + item.total + '</span>'
      + '</div>';
  });
  rankHtml += '</div>';
  document.getElementById('rankDrawerContent').innerHTML = rankHtml;
  openRankDrawer();
}


function toggleTypeGroup(id, headerEl) {
  var content = document.getElementById(id);
  var arrow = headerEl.querySelector('.type-arrow');
  if (content.style.display === 'none') {
    content.style.display = 'block';
    arrow.style.transform = 'rotate(90deg)';
  } else {
    content.style.display = 'none';
    arrow.style.transform = 'rotate(0deg)';
  }
}

function openExamDetail(id) {
  curExamId = id;
  var exam = getExams().find(function(e){ return e.id === id; });
  var students = get('students');
  var scores = [];
  students.forEach(function(s) {
    if (exam.scores[s.id] !== undefined) {
      scores.push({id: s.id, name: s.name, score: exam.scores[s.id]});
    }
  });
  scores.sort(function(a, b){ return b.score - a.score; });
  var avg = scores.length ? (scores.reduce(function(sum, s){ return sum + s.score; }, 0) / scores.length).toFixed(1) : 0;
  var max = scores.length ? Math.max.apply(null, scores.map(function(s){ return s.score; })) : 0;
  var min = scores.length ? Math.min.apply(null, scores.map(function(s){ return s.score; })) : 0;
  var rankHtml = '';
  if (scores.length) {
    scores.forEach(function(s, i) {
      var rankBg = i % 2 === 0 ? 'background: #f8f9fa; color: #1c1c1e;' : 'background: #ffffff; color: #1c1c1e;';
      rankHtml += '<div class="flex justify-between items-center p-3 rounded-xl mb-1.5" style="' + rankBg + '" onclick="openStuDetail(' + s.id + ');">'
        + '<span class="text-sm font-medium">' + (i+1) + '. ' + s.name + '</span>'
        + '<span class="font-bold text-green-600">' + s.score + '分</span></div>';
    });
  } else {
    rankHtml = '<p class="text-gray-400 text-center py-8 text-sm">暂无成绩</p>';
  }
  var title = (exam.category||'') + ' · ' + exam.type + ' · ' + exam.subject;
  document.getElementById('examDetailTitle').textContent = title;
  var html = ''
    + '<div class="grid grid-cols-3 gap-2.5 mb-4">'
    + '<div class="text-center p-3 rounded-xl" style="background: linear-gradient(135deg, #F0FBF5, #E8EEF2);"><div class="text-xl font-bold text-green-600">' + avg + '</div><div class="text-xs text-gray-500 mt-0.5">平均分</div></div>'
    + '<div class="text-center p-3 rounded-xl" style="background: linear-gradient(135deg, #d1fae5, #B8D0C0);"><div class="text-xl font-bold text-emerald-600">' + max + '</div><div class="text-xs text-gray-500 mt-0.5">最高分</div></div>'
    + '<div class="text-center p-3 rounded-xl" style="background: linear-gradient(135deg, #ffedd5, #fed7aa);"><div class="text-xl font-bold text-orange-600">' + min + '</div><div class="text-xs text-gray-500 mt-0.5">最低分</div></div>'
    + '</div>'
    + '<div class="grid grid-cols-2 gap-2.5 mb-4">'
    + '<div class="text-center p-3 rounded-xl bg-gray-50"><div class="text-lg font-bold text-gray-700" id="passRateVal">0%</div><div class="text-xs text-gray-500 mt-0.5">及格率</div></div>'
    + '<div class="text-center p-3 rounded-xl bg-gray-50"><div class="text-lg font-bold text-gray-700" id="goodRateVal">0%</div><div class="text-xs text-gray-500 mt-0.5">良好率</div></div>'
    + '</div>'
    + '<div class="card p-4 mb-4"><h4 class="font-semibold text-sm mb-3 text-gray-700">分数段分布</h4><div style="height:180px;"><canvas id="examDetailChart"></canvas></div></div>'
    + '<button onclick="openScoreInput();" class="w-full btn-primary mb-3" style="display:inline-flex;align-items:center;justify-content:center;gap:6px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>录入/编辑成绩</button>'
    + '<button onclick="deleteExam();" class="w-full mb-4 py-2.5 rounded-xl text-sm font-medium text-red-500 border border-red-200 bg-red-50 hover:bg-red-100 transition-colors" style="display:inline-flex;align-items:center;justify-content:center;gap:6px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>删除本次考试</button>'
    + '<h4 class="font-semibold text-sm mb-3 text-gray-700">成绩排名</h4>'
    + '<div class="space-y-1.5">' + rankHtml + '</div>';
  document.getElementById('examDetailContent').innerHTML = html;
  navigateTo('page-exam-detail');
  var full = exam.fullScore;
  var segs = [
    { label: '不及格\n<' + Math.round(full*0.6), min: 0, max: full*0.6, count: 0, color: '#ef4444' },
    { label: '及格\n' + Math.round(full*0.6) + '-' + Math.round(full*0.75), min: full*0.6, max: full*0.75, count: 0, color: '#f59e0b' },
    { label: '良好\n' + Math.round(full*0.75) + '-' + Math.round(full*0.85), min: full*0.75, max: full*0.85, count: 0, color: '#8AB06A' },
    { label: '优秀\n≥' + Math.round(full*0.85), min: full*0.85, max: full+1, count: 0, color: '#D97757' }
  ];
  scores.forEach(function(s) {
    segs.forEach(function(seg) {
      if (s.score >= seg.min && s.score < seg.max) seg.count++;
    });
  });
  var passCount = scores.filter(function(s){ return s.score >= full*0.6; }).length;
  var goodCount = scores.filter(function(s){ return s.score >= full*0.85; }).length;
  document.getElementById('passRateVal').textContent = scores.length ? Math.round(passCount/scores.length*100) + '%' : '0%';
  document.getElementById('goodRateVal').textContent = scores.length ? Math.round(goodCount/scores.length*100) + '%' : '0%';
  setTimeout(function() {
    var ctx = document.getElementById('examDetailChart');
    if (!ctx) return;
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: segs.map(function(s){ return s.label; }),
        datasets: [{
          data: segs.map(function(s){ return s.count; }),
          backgroundColor: segs.map(function(s){ return s.color; }),
          borderRadius: 8,
          hoverBackgroundColor: segs.map(function(s){ return s.color; })
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 400 },
        interaction: { mode: 'nearest', intersect: true },
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: true,
            displayColors: false,
            backgroundColor: 'rgba(30,41,59,0.92)',
            titleFont: { size: 12 },
            bodyFont: { size: 13, weight: 'bold' },
            padding: 10,
            cornerRadius: 8,
            animation: false,
            callbacks: {
              title: function(items) { return items[0].label; },
              label: function(ctx) { return ctx.parsed.y + ' 人'; }
            }
          }
        },
        scales: {
          y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.05)' } },
          x: { grid: { display: false } }
        }
      }
    });
  }, 250);
}
function printExam() {
  var exam = getExams().find(function(e){ return e.id === curExamId; });
  if (!exam) return;
  var students = get('students');
  var html = '<table class="print-table"><thead><tr><th>序号</th><th>姓名</th><th>分数</th></tr></thead><tbody>';
  var sorted = students.slice().sort(function(a,b){ return a.id - b.id; });
  sorted.forEach(function(s) {
    var score = exam.scores[s.id];
    if (score !== undefined) {
      html += '<tr><td>' + s.id + '</td><td>' + s.name + '</td><td>' + score + '</td></tr>';
    }
  });
  html += '</tbody></table>';
  var title = (exam.category||'') + ' · ' + exam.type + ' · ' + exam.subject;
  printContent(title + ' 成绩单', html, '满分：' + exam.fullScore + '分 · 考试日期：' + exam.date);
}

function addExam() {
  var subjects = get('subjects');
  var subjOptions = subjects.map(function(s){ return '<option value="' + s.name + '">' + s.name + '</option>'; }).join('');
  var catOptions = EXAM_CATEGORIES.map(function(c){ return '<option value="' + c.key + '">' + c.icon + ' ' + c.key + '</option>'; }).join('');
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">新建考试</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<div><label class="text-xs text-gray-500 block mb-1">考试类型（一级）</label><select id="newExamCat" class="input-field" onchange="onCatChange()">' + catOptions + '</select></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">考试名称（二级）</label><input id="newExamType" type="text" class="input-field" placeholder="如：第一次月考 / 第1单元测" value="第一次月考"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">科目</label><select id="newExamSubj" class="input-field">' + subjOptions + '</select></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">日期</label><input id="newExamDate" type="date" class="input-field" value="' + new Date().toISOString().slice(0,10) + '"></div>'
    + '<button onclick="doAddExam()" class="w-full btn-primary">创建</button>'
    + '</div>'
  );
}
function onCatChange() {
  var cat = document.getElementById('newExamCat').value;
  var input = document.getElementById('newExamType');
  var exams = getExams();
  if (cat === '月考') {
    var month = new Date().getMonth() + 1;
    input.value = month + '月月考';
  } else if (cat === '单元测') {
    var unitCount = exams.filter(function(e){ return (e.category||inferCategory(e.type)) === '单元测'; }).length;
    input.value = '第' + (unitCount + 1) + '单元测';
  } else if (cat === '期中考') {
    input.value = '期中考试';
  } else if (cat === '期末考') {
    input.value = '期末考试';
  } else {
    input.value = '';
  }
}
function doAddExam() {
  var category = document.getElementById('newExamCat').value;
  var type = document.getElementById('newExamType').value;
  var subject = document.getElementById('newExamSubj').value;
  var date = document.getElementById('newExamDate').value;
  if (!type) { alert('请输入考试名称'); return; }
  var subjects = get('subjects');
  var subj = subjects.find(function(s){ return s.name === subject; });
  var fullScore = subj ? subj.fullScore : 100;
  var exams = get('exams');
  var nextId = parseInt(localStorage.getItem('nextExamId') || '13');
  exams.push({id: nextId, subject: subject, category: category, type: type, date: date, fullScore: fullScore, scores: {}});
  localStorage.setItem('nextExamId', nextId + 1);
  saveExams(exams);
  closeModal();
  renderExamList();
  updateStats();
  alert('创建成功');
}



function deleteExam() {
  if (!curExamId) return;
  var exam = getExams().find(function(e){ return e.id === curExamId; });
  if (!exam) return;
  if (!confirm('确定要删除「' + (exam.category||'') + ' · ' + exam.type + ' · ' + exam.subject + '」吗？\n删除后不可恢复。')) return;
  var exams = getExams().filter(function(e){ return e.id !== curExamId; });
  save('exams', exams);
  curExamId = 0;
  renderExamList();
  navigateTo('page-score');
}

function openScoreInput() {
  var exam = getExams().find(function(e){ return e.id === curExamId; });
  var students = get('students');
  document.getElementById('scoreInputTitle').textContent = exam.subject + ' · 成绩录入';
  document.getElementById('scoreInputMeta').innerHTML =
    '<span class="text-gray-500">考试：' + (exam.category||'') + ' · ' + exam.type + '</span>'
    + '<span class="text-gray-500">满分：<span class="font-semibold text-gray-700">' + exam.fullScore + '</span></span>';
  document.getElementById('scoreInputTotal').textContent = students.length;
  var html = '';
  students.sort(function(a,b){ return a.id - b.id; }).forEach(function(s) {
    html += '<div class="flex items-center gap-3 p-3 bg-white rounded-xl border border-gray-100 shadow-sm">'
      + '<span class="text-xs text-gray-500 w-20 font-medium">' + s.id + '号 ' + s.name + '</span>'
      + '<input type="number" class="flex-1 input-field py-1.5 score-input" oninput="updateScoreCount()" '
      + 'data-id="' + s.id + '" value="' + (exam.scores[s.id] || '') + '" placeholder="分数" max="' + exam.fullScore + '">'
      + '</div>';
  });
  document.getElementById('scoreInputListNew').innerHTML = html;
  navigateTo('page-score-input');
  updateScoreCount();
}

function updateScoreCount() {
  var inputs = document.querySelectorAll('#scoreInputListNew .score-input');
  var n = 0;
  inputs.forEach(function(i){ if (i.value.trim() !== '') n++; });
  var el = document.getElementById('scoreInputCount');
  if (el) el.textContent = n;
}

function clearScoreInput() {
  if (!confirm('确定清空所有已输入的分数吗？')) return;
  document.querySelectorAll('#scoreInputListNew .score-input').forEach(function(i){ i.value = ''; });
  updateScoreCount();
}

function saveScore() {
  var exams = get('exams');
  var exam = exams.find(function(e){ return e.id === curExamId; });
  var inputs = document.querySelectorAll('.score-input');
  inputs.forEach(function(input) {
    var id = parseInt(input.dataset.id);
    var val = input.value.trim();
    if (val) exam.scores[id] = parseFloat(val);
    else delete exam.scores[id];
  });
  saveExams(exams);
  navigateBack();
  renderExamList();
  updateStats();
  // 如果上一页是考试详情，重新渲染
  if (curExamId) { setTimeout(function(){ openExamDetail(curExamId); }, 50); }
  alert('保存成功');
}

function closeScoreDrawer() {
  navigateBack();
}


function openImportScore() {
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">批量导入成绩</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">'
    + '<p class="text-xs text-gray-500 mb-2">粘贴格式（每行一个）：</p>'
    + '<p class="text-xs text-gray-400 mb-3">序号 分数<br>例如：<br>1 95<br>2 88</p>'
    + '<textarea id="importScoreText" class="input-field" rows="8" placeholder="1 95&#10;2 88&#10;3 92"></textarea>'
    + '<button onclick="doImportScore()" class="w-full btn-primary mt-3">导入</button>'
    + '</div>'
  );
}

function doImportScore() {
  var text = document.getElementById('importScoreText').value.trim();
  if (!text) { alert('请输入成绩数据'); return; }
  var exam = get('exams').find(function(e){ return e.id === curExamId; });
  var lines = text.split('\n');
  var count = 0;
  lines.forEach(function(line) {
    line = line.trim();
    if (!line) return;
    var parts = line.split(/\s+/);
    if (parts.length >= 2) {
      var id = parseInt(parts[0]);
      var score = parseFloat(parts[1]);
      if (id && !isNaN(score)) {
        exam.scores[id] = score;
        count++;
      }
    }
  });
  var exams = get('exams');
  var idx = exams.findIndex(function(e){ return e.id === curExamId; });
  exams[idx] = exam;
  saveExams(exams);
  closeModal();
  renderExamList();
  updateStats();
  if (curExamId) { setTimeout(function(){ openExamDetail(curExamId); }, 50); }
  alert('成功导入 ' + count + ' 条成绩');
}

function openSubjManage() {
  var subjects = get('subjects');
  var html = '';
  subjects.forEach(function(s, i) {
    html += '<div class="flex items-center gap-3 p-3 rounded-xl mb-2" style="background:var(--input-bg,#F5F0E8);">'
      + '<div class="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" style="background:var(--primary,#D97757);color:white;">'
      + '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path></svg></div>'
      + '<div class="flex-1 min-w-0">'
      + '<div class="text-sm font-medium" style="color:var(--text,#3A322C);">' + s.name + '</div>'
      + '<div class="text-xs mt-0.5" style="color:var(--text2,#8C8279);">满分 ' + s.fullScore + ' 分</div>'
      + '</div>'
      + '<button onclick="delSubj(' + i + ')" class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style="color:#EF4444;">'
      + '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg></button>'
      + '</div>';
  });
  if (!subjects.length) html = '<p class="text-center text-sm py-6" style="color:var(--text3,#B8AEA4);">暂无科目，点击下方添加</p>';
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">科目管理</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">'
    + html
    + '<div class="flex gap-2 mt-4">'
    + '<input id="newSubjName" type="text" class="flex-1 input-field" placeholder="科目名">'
    + '<input id="newSubjScore" type="number" class="w-20 input-field" placeholder="满分" value="100">'
    + '</div>'
    + '<button onclick="addSubj()" class="w-full btn-primary mt-3">+ 添加科目</button>'
    + '</div>'
  );
}

function addSubj() {
  var name = document.getElementById('newSubjName').value.trim();
  var fullScore = parseInt(document.getElementById('newSubjScore').value) || 100;
  if (!name) { alert('请输入科目名'); return; }
  var subjects = get('subjects');
  subjects.push({name: name, fullScore: fullScore});
  set('subjects', subjects);
  renderExamFilter();
  updateStats();
  openSubjManage();
}

function delSubj(idx) {
  if (!confirm('确定删除这个科目吗？')) return;
  var subjects = get('subjects');
  subjects.splice(idx, 1);
  set('subjects', subjects);
  openSubjManage();
  renderExamFilter();
  updateStats();
}

// 学生成绩趋势图（按科目）
var curStuChartSubject = '语文';
var curStuId = 0;
function getStuSubjects(studentId) {
  var exams = getExams();
  var subjects = [];
  exams.forEach(function(e) {
    if (e.scores[studentId] !== undefined && subjects.indexOf(e.subject) < 0) {
      subjects.push(e.subject);
    }
  });
  return subjects;
}
function renderStuScoreChart(studentId, subject) {
  subject = subject || curStuChartSubject || '语文';
  var exams = getExams();
  var stuExams = exams.filter(function(e) {
    return e.scores[studentId] !== undefined && e.subject === subject;
  });
  stuExams.sort(function(a, b) { return new Date(a.date) - new Date(b.date); });
  if (stuExams.length === 0) return '<p class="text-gray-400 text-sm text-center py-6">该科目暂无成绩数据</p>';
  window._stuChartData = {
    labels: stuExams.map(function(e){
      var cat = e.category || inferCategory(e.type);
      if (cat === '期中考') return '期中';
      if (cat === '期末考') return '期末';
      if (cat === '月考') {
        var n = e.type.match(/第(.)次/);
        return '月考' + (n ? n[1] : '');
      }
      if (cat === '单元测') {
        var n2 = e.type.match(/第(\d+)单元/);
        return '单元' + (n2 ? n2[1] : '');
      }
      return e.type.slice(0,4);
    }),
    scores: stuExams.map(function(e){return e.scores[studentId];}),
    color: '#D97757',
    fullScore: stuExams[0].fullScore
  };
  return '<canvas id="stuScoreChart" height="200" style="width:100%;"></canvas>';
}
function switchStuChart(subject) {
  curStuChartSubject = subject;
  document.querySelectorAll('.stu-chart-tab').forEach(function(b){
    b.classList.toggle('active', b.dataset.subject === subject);
  });
  var titleEl = document.getElementById('stuChartTitle');
  var exams = getExams();
  var subjExam = exams.find(function(e){ return e.subject === subject; });
  var fullScore = subjExam ? subjExam.fullScore : 100;
  if (titleEl) titleEl.innerHTML = '成绩趋势 · ' + subject + ' <span class="text-xs text-gray-400 font-normal">（满分' + fullScore + '分）</span>';
  var container = document.getElementById('stuChartContainer');
  if (container && curStuId) {
    container.innerHTML = renderStuScoreChart(curStuId, subject);
    drawStuChart();
  }
}

var _stuChartInstance = null;
function drawStuChart() {
  setTimeout(function() {
    var ctx = document.getElementById('stuScoreChart');
    if (!ctx || !window._stuChartData) return;
    if (_stuChartInstance) { _stuChartInstance.destroy(); _stuChartInstance = null; }
    _stuChartInstance = new Chart(ctx, {
      type: 'line',
      data: {
        labels: window._stuChartData.labels,
        datasets: [{
          label: '成绩',
          data: window._stuChartData.scores,
          borderColor: window._stuChartData.color || '#D97757',
          backgroundColor: 'rgba(217, 119, 87, 0.1)',
          fill: true,
          tension: 0.4,
          pointRadius: 6,
          pointHoverRadius: 8,
          pointHitRadius: 24,
          pointBackgroundColor: window._stuChartData.color || '#D97757',
          pointBorderColor: '#fff',
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 400 },
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            enabled: true,
            displayColors: false,
            backgroundColor: 'rgba(30,41,59,0.92)',
            titleFont: { size: 12 },
            bodyFont: { size: 13, weight: 'bold' },
            padding: 10,
            cornerRadius: 8,
            animation: false,
            callbacks: {
              title: function(items) { return items[0].label; },
              label: function(ctx) { return ctx.parsed.y + ' 分'; }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: false,
            grid: { color: 'rgba(0,0,0,0.05)' },
            max: window._stuChartData.fullScore ? window._stuChartData.fullScore + 5 : undefined
          },
          x: { grid: { display: false } }
        }
      }
    });
  }, 200);
}
function toggleStuExamGroup(id, headerEl) {
  var el = document.getElementById(id);
  var arrow = headerEl.querySelector('.stu-exam-arrow');
  if (el.style.display === 'none') {
    el.style.display = 'block';
    arrow.style.transform = 'rotate(90deg)';
  } else {
    el.style.display = 'none';
    arrow.style.transform = 'rotate(0deg)';
  }
}
function toggleStuExamType(id, headerEl) {
  var el = document.getElementById(id);
  var arrow = headerEl.querySelector('.stu-type-arrow');
  if (el.style.display === 'none') {
    el.style.display = 'block';
    arrow.style.transform = 'rotate(90deg)';
  } else {
    el.style.display = 'none';
    arrow.style.transform = 'rotate(0deg)';
  }
}


function openSeat() {
  var cols = parseInt(localStorage.getItem('seatCols') || 6);
  var students = get('students');
  var rows = Math.ceil(students.length / cols);
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<div class="flex items-baseline gap-2"><span class="font-semibold text-sm">班级座位表</span>'
    + '<span class="text-xs text-gray-400">' + rows + '排' + cols + '列 · ' + students.length + '人</span></div>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">'
    + '<div class="flex gap-2 mb-3">'
    + '<button onclick="seatByNum()" class="flex-1 py-2 btn-secondary btn-xs" style="display:inline-flex;align-items:center;justify-content:center;gap:4px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg> 按序号排</button>'
    + '<button onclick="randomSeat()" class="flex-1 py-2 btn-secondary btn-xs" style="display:inline-flex;align-items:center;justify-content:center;gap:4px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 3 21 3 21 8"></polyline><line x1="4" y1="20" x2="21" y2="3"></line><polyline points="21 16 21 21 16 21"></polyline><line x1="15" y1="15" x2="21" y2="21"></line><line x1="4" y1="4" x2="9" y2="9"></line></svg> 随机排座</button>'
    + '<button onclick="setSeatCols()" class="flex-1 py-2 btn-secondary btn-xs" style="display:inline-flex;align-items:center;justify-content:center;gap:4px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg> 列数设置</button>'
    + '</div>'
    + '<div class="flex gap-2 mb-4">'
    + '<button onclick="exportSeat()" class="flex-1 py-2 btn-primary btn-xs" style="display:inline-flex;align-items:center;justify-content:center;gap:4px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path><circle cx="12" cy="13" r="4"></circle></svg> 导出图片</button>'
    + '</div>'
    + '<div class="text-center text-xs text-gray-400 mb-3 font-medium">—— 讲 台 ——</div>'
    + '<div id="seatGrid" class="grid gap-1.5 mb-4" style="grid-template-columns: repeat(' + cols + ', 1fr);"></div>'
    + '<p class="text-xs text-gray-400 text-center">点击查看详情 · 长按拖动换座</p>'
    + '</div>'
  );
  renderSeatGrid();
}

function renderSeatGrid() {
  var students = get('students');
  var map = JSON.parse(localStorage.getItem('seatMap') || '{}');
  var grid = document.getElementById('seatGrid');
  if (!grid) return;
  grid.innerHTML = '';
  var cols = parseInt(localStorage.getItem('seatCols') || 6);
  var totalSeats = Math.ceil(students.length / cols) * cols;
  for (var i = 1; i <= totalSeats; i++) {
    var cell = document.createElement('div');
    cell.className = 'seat-cell';
    var row = Math.ceil(i / cols);
    var col = ((i - 1) % cols) + 1;
    var seatLabel = row + '排' + col + '座';
    var sid = map[i];
    if (sid) {
      var s = students.find(function(x){ return x.id === sid; });
      if (s) {
        cell.classList.add('has-stu');
        if (s.gender === '男') {
          cell.style.background = 'linear-gradient(135deg, #E8EEF2, #D0DEE6)';
          cell.style.borderColor = '#A5BCC8';
          cell.style.color = '#4A6B7A';
        } else {
          cell.style.background = 'linear-gradient(135deg, #F5E6E0, #F0D8D0)';
          cell.style.borderColor = '#E0B8A8';
          cell.style.color = '#A06050';
        }
        cell.innerHTML = '<div style="font-size: 12px; font-weight: 600;">' + s.name + '</div>'
          + '<div style="font-size: 9px; opacity: 0.7;">' + seatLabel + '</div>';
        (function(id){
          cell.onclick = function() {
            if (cell._justDragged) { cell._justDragged = false; return; }
            closeModal(); openStuDetail(id);
          };
        })(sid);
      }
    } else {
      cell.innerHTML = '<div style="font-size: 10px; color: #d1d1d6;">' + seatLabel + '</div>';
      cell.style.borderStyle = 'dashed';
    }
    grid.appendChild(cell);
    // 长按拖动排座
    if (sid && s) {
      (function(cellEl, seatNum, studentId) {
        var pressTimer = null;
        var isDragging = false;
        var startX = 0, startY = 0;
        var dragClone = null;
        var targetCell = null;

        function startDrag(clientX, clientY) {
          isDragging = true;
          if (navigator.vibrate) navigator.vibrate(30);
          // 创建拖动克隆
          var rect = cellEl.getBoundingClientRect();
          dragClone = cellEl.cloneNode(true);
          dragClone.style.position = 'fixed';
          dragClone.style.left = rect.left + 'px';
          dragClone.style.top = rect.top + 'px';
          dragClone.style.width = rect.width + 'px';
          dragClone.style.zIndex = '9999';
          dragClone.style.pointerEvents = 'none';
          dragClone.style.opacity = '0.9';
          dragClone.style.transform = 'scale(1.08)';
          dragClone.style.boxShadow = '0 8px 24px rgba(0,0,0,0.2)';
          dragClone.style.borderRadius = '10px';
          document.body.appendChild(dragClone);
          cellEl.style.opacity = '0.3';
          startX = clientX;
          startY = clientY;
        }

        function moveDrag(clientX, clientY) {
          if (!isDragging || !dragClone) return;
          var rect = cellEl.getBoundingClientRect();
          dragClone.style.left = (rect.left + (clientX - startX)) + 'px';
          dragClone.style.top = (rect.top + (clientY - startY)) + 'px';
          // 检测目标格子
          dragClone.style.display = 'none';
          var elBelow = document.elementFromPoint(clientX, clientY);
          dragClone.style.display = '';
          var cellBelow = elBelow ? elBelow.closest('.seat-cell') : null;
          document.querySelectorAll('.seat-cell').forEach(function(sc) { sc.style.outline = ''; });
          if (cellBelow && cellBelow !== cellEl && cellBelow.classList.contains('has-stu')) {
            cellBelow.style.outline = '2px dashed var(--primary,#D97757)';
            cellBelow.style.outlineOffset = '2px';
            targetCell = cellBelow;
          } else {
            targetCell = null;
          }
        }

        function endDrag() {
          if (!isDragging) return;
          isDragging = false;
          if (dragClone) { dragClone.remove(); dragClone = null; }
          cellEl.style.opacity = '';
          document.querySelectorAll('.seat-cell').forEach(function(sc) { sc.style.outline = ''; });
          if (targetCell) {
            // 交换座位
            var targetSeatNum = parseInt(targetCell.dataset.seat);
            swapSeats(seatNum, targetSeatNum);
          }
          targetCell = null;
        }

        cellEl.dataset.seat = seatNum;
        cellEl.dataset.student = studentId;

        // 触摸事件
        cellEl.addEventListener('touchstart', function(e) {
          var t = e.touches[0];
          pressTimer = setTimeout(function() { startDrag(t.clientX, t.clientY); }, 500);
        }, {passive: true});

        cellEl.addEventListener('touchmove', function(e) {
          if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
          if (isDragging) {
            e.preventDefault();
            var t = e.touches[0];
            moveDrag(t.clientX, t.clientY);
          }
        }, {passive: false});

        cellEl.addEventListener('touchend', function(e) {
          if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
          if (isDragging) { e.preventDefault(); endDrag(); }
        });

        // 鼠标事件（桌面端）
        cellEl.addEventListener('mousedown', function(e) {
          pressTimer = setTimeout(function() { startDrag(e.clientX, e.clientY); }, 500);
        });
        document.addEventListener('mousemove', function(e) {
          if (isDragging) moveDrag(e.clientX, e.clientY);
        });
        document.addEventListener('mouseup', function() {
          if (pressTimer) { clearTimeout(pressTimer); pressTimer = null; }
          if (isDragging) endDrag();
        });
      })(cell, i, sid);
    }
  }
}

function swapSeats(seatA, seatB) {
  var map = JSON.parse(localStorage.getItem('seatMap') || '{}');
  var idA = map[seatA];
  var idB = map[seatB];
  if (idA) map[seatB] = idA; else delete map[seatB];
  if (idB) map[seatA] = idB; else delete map[seatA];
  localStorage.setItem('seatMap', JSON.stringify(map));
  // 同步学生 seat 字段
  var students = get('students');
  students.forEach(function(s) {
    for (var k in map) {
      if (map[k] === s.id) { s.seat = parseInt(k); break; }
    }
  });
  set('students', students);
  renderSeatGrid();
}

function randomSeat() {
  var students = get('students');
  var ids = students.map(function(s){ return s.id; }).sort(function(){ return Math.random() - 0.5; });
  var map = {};
  ids.forEach(function(id, i) {
    map[i+1] = id;
    students.find(function(s){ return s.id === id; }).seat = i+1;
  });
  set('students', students);
  localStorage.setItem('seatMap', JSON.stringify(map));
  renderSeatGrid();
}

function seatByNum() {
  var students = get('students');
  var map = {};
  students.sort(function(a,b){ return a.id - b.id; }).forEach(function(s, i) {
    map[i+1] = s.id;
    s.seat = i+1;
  });
  set('students', students);
  localStorage.setItem('seatMap', JSON.stringify(map));
  renderSeatGrid();
}

function setSeatCols() {
  var cols = prompt('设置列数（5-8列）：', '6');
  if (!cols) return;
  cols = parseInt(cols);
  if (cols < 5 || cols > 8) { alert('列数范围5-8'); return; }
  localStorage.setItem('seatCols', cols);
  closeModal();
  openSeat();
}

function exportSeat() {
  var students = get('students');
  var seatMap = JSON.parse(localStorage.getItem('seatMap') || '{}');
  var cols = parseInt(localStorage.getItem('seatCols') || 6);
  var rows = Math.ceil(students.length / cols);
  var container = document.createElement('div');
  container.style.cssText = 'position:fixed;left:-9999px;top:0;width:720px;padding:44px 40px;background:#fff;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;';
  var title = document.createElement('div');
  title.style.cssText = 'text-align:center;font-size:26px;font-weight:700;color:#333;margin-bottom:10px;';
  title.textContent = getClassName() + ' 班级座位表';
  container.appendChild(title);
  var sub = document.createElement('div');
  sub.style.cssText = 'text-align:center;font-size:14px;color:#999;margin-bottom:32px;';
  sub.textContent = '共' + students.length + '人 · ' + new Date().toLocaleDateString('zh-CN');
  container.appendChild(sub);
  var podium = document.createElement('div');
  podium.style.cssText = 'text-align:center;font-size:15px;color:#aaa;letter-spacing:8px;margin-bottom:28px;font-weight:500;';
  podium.textContent = '—— 讲 台 ——';
  container.appendChild(podium);
  var grid = document.createElement('div');
  grid.style.cssText = 'display:grid;grid-template-columns:repeat(' + cols + ',1fr);gap:12px;';
  var totalSeats = rows * cols;
  var cellSize = Math.floor((640 - (cols - 1) * 12) / cols);
  for (var i = 1; i <= totalSeats; i++) {
    var cell = document.createElement('div');
    var row = Math.ceil(i / cols);
    var col = ((i - 1) % cols) + 1;
    var sid = seatMap[i];
    var s = sid ? students.find(function(x){ return x.id === sid; }) : null;
    if (s) {
      var color = s.gender === '男' ? '#4A6B7A' : '#B06050';
      cell.style.cssText = 'width:' + cellSize + 'px;height:' + cellSize + 'px;border-radius:16px;background:#EEF2F0;border:1px solid #E0E8E4;box-sizing:border-box;display:table;';
      cell.innerHTML = '<div style="display:table-cell;vertical-align:middle;text-align:center;">'
        + '<div style="transform:translateY(-5px);">'
        + '<div style="font-size:20px;font-weight:700;color:' + color + ';line-height:1;">' + s.name + '</div>'
        + '<div style="font-size:13px;opacity:0.6;color:' + color + ';line-height:1;margin-top:10px;">' + row + '排' + col + '座</div>'
        + '</div></div>';
    } else {
      cell.style.cssText = 'width:' + cellSize + 'px;height:' + cellSize + 'px;border-radius:16px;background:#F2F5F3;border:1px dashed #D8E0DC;box-sizing:border-box;display:table;';
      cell.innerHTML = '<div style="display:table-cell;vertical-align:middle;text-align:center;"><div style="transform:translateY(-3px);font-size:13px;color:#C0C8C4;line-height:1;">' + row + '排' + col + '座</div></div>';
    }
    grid.appendChild(cell);
  }
  container.appendChild(grid);
  document.body.appendChild(container);
  html2canvas(container, {scale:2,backgroundColor:'#ffffff',useCORS:true}).then(function(canvas) {
    document.body.removeChild(container);
    var imgData = canvas.toDataURL('image/png');
    showModal(
      '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
      + '<span class="font-semibold text-sm">座位表图片</span>'
      + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
      + '<div class="p-4 text-center">'
      + '<img src="' + imgData + '" style="width:100%;border-radius:12px;box-shadow:0 2px 12px rgba(0,0,0,0.1);" />'
      + '<p class="text-xs text-gray-400 mt-3">长按图片保存到相册，或点击下方按钮下载</p>'
      +  '<a href="' + imgData + '" download="' + getClassName() + '_座位表.png" class="btn-primary btn-xs mt-3" style="text-decoration:none;display:inline-flex;align-items:center;justify-content:center;gap:6px;"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>下载图片</a>'
      + '</div>'
    );
  }).catch(function(err) {
    if (container.parentNode) document.body.removeChild(container);
    alert('图片生成失败：' + err.message);
  });
}

// ========== 班级课表 ==========
var scheduleEditMode = false;
var markMySubjectMode = false;
function getMySubjects() {
  try {
    var saved = JSON.parse(localStorage.getItem('mySubjects') || 'null');
    if (saved && Array.isArray(saved)) return saved;
  } catch(e) {}
  return ['语文'];
}
function isMySubject(subject) {
  return getMySubjects().indexOf(subject) >= 0;
}
function toggleMySubject(subject) {
  var list = getMySubjects();
  var idx = list.indexOf(subject);
  if (idx >= 0) list.splice(idx, 1);
  else list.push(subject);
  localStorage.setItem('mySubjects', JSON.stringify(list));
}
var SCHEDULE_COLORS = {
  '语文': '#fef3c7,#d97706', '数学': '#E8EEF2,#C4613F', '英语': '#d1fae5,#B85A3A',
  '物理': '#E8EEF2,#D97757', '化学': '#ffedd5,#ea580c', '生物': '#E8F0E3,#7BA05B',
  '政治': '#F5E6E0,#C07060', '历史': '#fef9c3,#ca8a04', '地理': '#cffafe,#0891b2',
  '体育': '#F5E6E0,#D08070', '音乐': '#fef3c7,#f59e0b', '美术': '#E8EEF2,#D97757',
  '信息': '#e0f2fe,#0284c7', '劳动': '#E8F0E3,#8AB06A',
  '自习': '#f9f9fb,#8e8e93', '班会': '#E8EEF2,#C4613F'
};
function getScheduleData() {
  return JSON.parse(localStorage.getItem('schedule') || JSON.stringify(DEF_SCHEDULE));
}
function openSchedule() {
  scheduleEditMode = false;
  document.getElementById('scheduleEditBtn').textContent = '编辑';
  renderSchedule();
  navigateTo('page-schedule');
}
function renderSchedule() {
  var schedule = getScheduleData();
  var days = ['周一','周二','周三','周四','周五'];
  var today = new Date().getDay(); // 0=周日, 1-5=周一到周五
  var todayIdx = (today >= 1 && today <= 5) ? today - 1 : -1;
  var now = new Date();
  var nowMin = now.getHours() * 60 + now.getMinutes();
  
  var html = '<div class="mb-3 text-xs text-gray-400 text-center">2026-2027学年 上学期</div>';
  html += '<div class="schedule-wrap"><table class="schedule-table"><thead><tr><th class="sched-time-col"></th>';
  days.forEach(function(d, idx){
    var isToday = idx === todayIdx;
    html += '<th class="' + (isToday ? 'sched-today' : '') + '">' + d + '</th>';
  });
  html += '</tr></thead><tbody>';
  
  for (var i = 0; i < schedule.length; i++) {
    // 上午/下午分隔
    if (i === 4) {
      html += '<tr class="sched-lunch-row"><td colspan="6"><span>午 休</span></td></tr>';
    }
    var startTime = SCHEDULE_TIMES[i] || '';
    var endTime = SCHEDULE_END_TIMES[i] || '';
    var startMin = parseInt(startTime.split(':')[0]) * 60 + parseInt(startTime.split(':')[1]);
    var endMin = parseInt(endTime.split(':')[0]) * 60 + parseInt(endTime.split(':')[1]);
    var isCurrent = nowMin >= startMin && nowMin <= endMin && todayIdx >= 0;
    
    html += '<tr>';
    html += '<td class="sched-time-cell' + (isCurrent ? ' sched-current-time' : '') + '">';
    html += '<div class="sched-period">第' + (i+1) + '节</div>';
    html += '<div class="sched-time">' + startTime + '-' + endTime + '</div>';
    html += '</td>';
    for (var j = 0; j < schedule[i].length; j++) {
      var subject = schedule[i][j];
      var color = SCHEDULE_COLORS[subject] || '#f9f9fb,#8e8e93';
      var bg = color.split(',')[0];
      var text = color.split(',')[1];
      var isTodayCell = j === todayIdx;
      var isCurrentCell = isCurrent && isTodayCell;
      var mySubj = isMySubject(subject);
      var cellClass = 'sched-cell' + (isTodayCell ? ' sched-today-cell' : '') + (isCurrentCell ? ' sched-current-cell' : '') + (mySubj ? ' sched-mine-cell' : '');
      var cellStyle = 'background:' + bg + ';color:' + text + ';';
      var clickAction = markMySubjectMode ? 'markSchedCell(' + i + ',' + j + ')' : 'editScheduleCell(' + i + ',' + j + ')';
      var starIcon = mySubj ? '<span class="sched-mine-star"><svg width="9" height="9" viewBox="0 0 24 24" fill="currentColor" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg></span>' : '';
      html += '<td class="' + cellClass + '" style="' + cellStyle + '" onclick="' + clickAction + '">' + starIcon + subject + '</td>';
    }
    html += '</tr>';
  }
  html += '</tbody></table></div>';
  
  // 图例
  html += '<div class="sched-legend">';
  var legendSubs = ['语文','数学','英语','物理','化学','生物','政治','历史','地理','体育','音乐','美术','自习'];
  legendSubs.forEach(function(sub) {
    var c = SCHEDULE_COLORS[sub];
    if (c) {
      html += '<span class="sched-legend-item"><span class="sched-legend-dot" style="background:' + c.split(',')[0] + ';"></span>' + sub + '</span>';
    }
  });
  html += '</div>';
  
  document.getElementById('scheduleContent').innerHTML = html;
}
function printSchedule() {
  var schedule = getScheduleData();
  var days = ['周一','周二','周三','周四','周五'];
  var subjColors = {
    '语文':'#fef3c7','数学':'#E8EEF2','英语':'#d1fae5','物理':'#E8EEF2',
    '化学':'#ffedd5','生物':'#E8F0E3','政治':'#F5E6E0','历史':'#fef9c3',
    '地理':'#cffafe','体育':'#F5E6E0','音乐':'#fef3c7','美术':'#E8EEF2',
    '信息':'#e0f2fe','劳动':'#E8F0E3','自习':'#f9f9fb','班会':'#E8EEF2'
  };
  var html = '<table class="print-schedule"><thead><tr><th class="time-col">节次</th>';
  days.forEach(function(d){ html += '<th>' + d + '</th>'; });
  html += '</tr></thead><tbody>';
  for (var i = 0; i < schedule.length; i++) {
    if (i === 4) {
      html += '<tr><td colspan="6" class="lunch">午 休 ' + (SCHEDULE_END_TIMES[3]||'') + '-' + (SCHEDULE_TIMES[4]||'') + '</td></tr>';
    }
    html += '<tr><td class="time-col">第' + (i+1) + '节<br>' + (SCHEDULE_TIMES[i]||'') + '-' + (SCHEDULE_END_TIMES[i]||'') + '</td>';
    for (var j = 0; j < schedule[i].length; j++) {
      var subj = schedule[i][j];
      html += '<td>' + subj + '</td>';
    }
    html += '</tr>';
  }
  html += '</tbody></table>';
  printContent('班级课表', html, getClassName() + ' · 2026-2027学年上学期', true);
}
function toggleScheduleEdit() {
  scheduleEditMode = !scheduleEditMode;
  if (scheduleEditMode) { markMySubjectMode = false; var mb=document.getElementById('scheduleMarkBtn'); if(mb) mb.textContent='标记'; }
  document.getElementById('scheduleEditBtn').textContent = scheduleEditMode ? '完成' : '编辑';
  renderSchedule();
}
function toggleMarkMode() {
  markMySubjectMode = !markMySubjectMode;
  if (markMySubjectMode) { scheduleEditMode = false; var eb=document.getElementById('scheduleEditBtn'); if(eb) eb.textContent='编辑'; }
  var btn = document.getElementById('scheduleMarkBtn');
  if (btn) btn.textContent = markMySubjectMode ? '完成' : '标记';
  renderSchedule();
}
function editScheduleCell(row, col) {
  if (!scheduleEditMode) return;
  var schedule = getScheduleData();
  var subs = Object.keys(SCHEDULE_COLORS);
  var html = '<div class="sched-picker-mask" onclick="closeSchedPicker()"></div>';
  html += '<div class="sched-picker">';
  html += '<div class="sched-picker-header"><div class="sched-picker-handle"></div><button class="sched-picker-close" onclick="closeSchedPicker()"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#8e8e93" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>';
  html += '<div class="sched-picker-body">';
  html += '<div class="sched-picker-title">选择课程 · 第' + (row+1) + '节</div>';
  html += '<div class="sched-picker-grid">';
  subs.forEach(function(sub) {
    var c = SCHEDULE_COLORS[sub];
    html += '<button class="sched-picker-btn" style="background:' + c.split(',')[0] + ';color:' + c.split(',')[1] + ';" onclick="setSchedCell(' + row + ',' + col + ',\'' + sub + '\')">' + sub + '</button>';
  });
  html += '</div>';
  html += '<button class="sched-picker-cancel" onclick="closeSchedPicker()">取消</button>';
  html += '</div>';
  var div = document.createElement('div');
  div.id = 'schedPickerOverlay';
  div.innerHTML = html;
  document.body.appendChild(div);
  document.body.style.overflow = 'hidden';
}
function setSchedCell(row, col, subject) {
  var schedule = getScheduleData();
  schedule[row][col] = subject;
  localStorage.setItem('schedule', JSON.stringify(schedule));
  closeSchedPicker();
  renderSchedule();
}
function markSchedCell(row, col) {
  var schedule = getScheduleData();
  var subject = schedule[row][col];
  if (!subject || !subject.trim()) return;
  toggleMySubject(subject);
  renderSchedule();
}
function closeSchedPicker() {
  var el = document.getElementById('schedPickerOverlay');
  if (el) el.remove();
  if (!document.querySelector('.full-page.active') && !document.getElementById('modal').classList.contains('show')) {
    document.body.style.overflow = '';
  }
}

// ========== 值日表页面 ==========
var dutyEditMode = false;
function openDutyPage() {
  dutyEditMode = false;
  document.querySelector('#page-duty .nav-btn.right').textContent = '编辑';
  renderDutyPage();
  navigateTo('page-duty');
}
function renderDutyPage() {
  var students = get('students');
  var today = new Date().getDay();
  var dayNames = ['周一','周二','周三','周四','周五'];
  var groupStyles = [
    {bg:'#F0FBF5',border:'#D0DEE6',badge:'#E8EEF2',text:'#C4613F'},
    {bg:'#f0fdf4',border:'#C5DCC0',badge:'#E8F0E3',text:'#7BA05B'},
    {bg:'#fffbeb',border:'#fde68a',badge:'#fef3c7',text:'#d97706'},
    {bg:'#faf5ff',border:'#D0DEE6',badge:'#E8EEF2',text:'#D97757'},
    {bg:'#fdf2f8',border:'#F0D8D0',badge:'#F5E6E0',text:'#C07060'}
  ];
  var html = '<div class="duty-page-header">';
  html += '<div class="duty-page-title">本周值日安排</div>';
  html += '<div class="duty-page-sub">周一至周五 · 每天一组轮流' + (dutyEditMode ? ' · 点击学生可调整小组' : '') + '</div>';
  html += '</div>';
  
  for (var d = 0; d < 5; d++) {
    var group = d + 1;
    var groupStus = students.filter(function(s){ return s.dutyGroup == group; });
    var isToday = (d + 1) === today;
    var st = groupStyles[d];
    var cardClick = dutyEditMode ? '' : ' onclick="showDutyDetail(' + group + ')"';
    html += '<div class="duty-card' + (isToday ? ' duty-card-today' : '') + '" style="background:' + st.bg + ';border-color:' + st.border + ';"' + cardClick + '>';
    html += '<div class="duty-card-top">';
    html += '<div class="duty-card-day">';
    html += '<span class="duty-card-dayname">' + dayNames[d] + '</span>';
    if (isToday) html += '<span class="duty-card-today-tag">今天</span>';
    html += '</div>';
    html += '<span class="duty-card-group" style="background:' + st.badge + ';color:' + st.text + ';">第' + group + '组</span>';
    html += '</div>';
    html += '<div class="duty-card-tags">';
    if (groupStus.length === 0) {
      html += '<span class="duty-card-empty">暂无学生</span>';
    } else {
      groupStus.forEach(function(s) {
        if (dutyEditMode) {
          html += '<span class="duty-card-tag duty-tag-editable" onclick="showDutyGroupPicker(' + s.id + ')">' + s.name + ' · ' + s.dutyGroup + '组</span>';
        } else {
          html += '<span class="duty-card-tag">' + s.name + '</span>';
        }
      });
    }
    html += '</div>';
    html += '<div class="duty-card-count">' + groupStus.length + ' 人</div>';
    html += '</div>';
  }
  html += '<div class="duty-page-footer">周六、周日无值日安排</div>';
  document.getElementById('dutyPageContent').innerHTML = html;
}
function showDutyGroupPicker(stuId) {
  var students = get('students');
  var s = students.find(function(x){ return x.id === stuId; });
  if (!s) return;
  var groupColors = ['#E8EEF2,#C4613F','#E8F0E3,#7BA05B','#fef3c7,#d97706','#E8EEF2,#D97757','#F5E6E0,#C07060'];
  var html = '<div class="sched-picker-mask" onclick="closeDutyPicker()"></div>';
  html += '<div class="sched-picker">';
  html += '<div class="sched-picker-header"><div class="sched-picker-handle"></div><button class="sched-picker-close" onclick="closeDutyPicker()"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#8e8e93" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>';
  html += '<div class="sched-picker-body">';
  html += '<div class="sched-picker-title">' + s.name + ' · 调整值日小组</div>';
  html += '<div class="sched-picker-grid">';
  for (var g = 1; g <= 5; g++) {
    var c = groupColors[g-1].split(',');
    var count = students.filter(function(x){ return x.dutyGroup == g; }).length;
    var active = s.dutyGroup == g ? 'box-shadow:0 0 0 2px #D97757;' : '';
    html += '<button class="sched-picker-btn" style="background:' + c[0] + ';color:' + c[1] + ';' + active + '" onclick="setDutyGroup(' + stuId + ',' + g + ')">第' + g + '组<br><span style="font-size:10px;opacity:0.7;">' + count + '人</span></button>';
  }
  html += '</div>';
  html += '<button class="sched-picker-cancel" onclick="closeDutyPicker()">取消</button>';
  html += '</div>';
  var div = document.createElement('div');
  div.id = 'dutyPickerOverlay';
  div.innerHTML = html;
  document.body.appendChild(div);
  document.body.style.overflow = 'hidden';
}
function setDutyGroup(stuId, group) {
  var students = get('students');
  var s = students.find(function(x){ return x.id === stuId; });
  if (s) { s.dutyGroup = group; set('students', students); }
  closeDutyPicker();
  renderDutyPage();
}
function closeDutyPicker() {
  var el = document.getElementById('dutyPickerOverlay');
  if (el) el.remove();
  if (!document.querySelector('.full-page.active') && !document.getElementById('modal').classList.contains('show')) {
    document.body.style.overflow = '';
  }
}
function showDutyDetail(group) {
  var students = get('students').filter(function(s){ return s.dutyGroup == group; });
  var dayNames = ['周一','周二','周三','周四','周五'];
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">' + dayNames[group-1] + '值日 · 第' + group + '组</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">'
    + '<div class="text-sm text-gray-500 mb-3">共 ' + students.length + ' 人</div>'
    + '<div class="flex flex-wrap gap-2">'
    + students.map(function(s){
        var role = s.duty ? '<span class="text-xs text-amber-600 ml-1">(' + s.duty + ')</span>' : '';
        return '<span class="px-3 py-1.5 rounded-full text-sm font-medium" style="background:#f9f9fb;color:#3c3c43;">' + s.name + role + '</span>';
      }).join('')
    + '</div></div>'
  );
}
function printDuty() {
  var students = get('students');
  var dayNames = ['周一','周二','周三','周四','周五'];
  var groupColors = ['#D97757','#7BA05B','#d97706','#D97757','#C07060'];
  var html = '<table class="print-table"><thead><tr><th style="width:80px;">星期</th><th style="width:80px;">小组</th><th>值日学生</th><th style="width:60px;">人数</th></tr></thead><tbody>';
  for (var d = 0; d < 5; d++) {
    var group = d + 1;
    var groupStus = students.filter(function(s){ return s.dutyGroup == group; });
    var names = groupStus.map(function(s){ return s.name; }).join('、');
    html += '<tr><td style="font-weight:600;">' + dayNames[d] + '</td>';
    html += '<td>第' + group + '组</td>';
    html += '<td style="text-align:left;padding-left:10px;">' + names + '</td>';
    html += '<td>' + groupStus.length + '</td></tr>';
  }
  html += '</tbody></table>';
  printContent('值日表', html, getClassName() + ' · 周一至周五轮流值日');
}
function toggleDutyEdit() {
  dutyEditMode = !dutyEditMode;
  document.querySelector('#page-duty .nav-btn.right').textContent = dutyEditMode ? '完成' : '编辑';
  renderDutyPage();
}

// ========== 通知管理 ==========
function openNotice() {
  var tpls = get('tpls');
  var names = Object.keys(tpls);
  var options = '<option value="">自定义</option>';
  names.forEach(function(n) {
    options += '<option value="' + n + '">' + n + '</option>';
  });
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">发布通知</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<div><label class="text-xs text-gray-500 block mb-1">选择模板</label>'
    + '<select id="noticeTpl" class="input-field" onchange="loadTpl()">' + options + '</select></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1">通知内容</label>'
    + '<textarea id="noticeText" rows="6" class="input-field" placeholder="请输入通知内容..."></textarea></div>'
    + '<button onclick="copyNotice()" class="w-full btn-primary">复制到剪贴板</button>'
    + '</div>'
  );
}

function loadTpl() {
  var tpl = document.getElementById('noticeTpl').value;
  var tpls = get('tpls');
  document.getElementById('noticeText').value = tpl ? tpls[tpl] : '';
}

function copyNotice() {
  var text = document.getElementById('noticeText').value;
  if (!text) { alert('请输入通知内容'); return; }
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(function() {
      addNoticeLog(text);
      alert('已复制到剪贴板');
    });
  } else {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
    addNoticeLog(text);
    alert('已复制到剪贴板');
  }
}

function addNoticeLog(text) {
  var logs = JSON.parse(localStorage.getItem('noticeLogs') || '[]');
  logs.unshift({
    id: Date.now(),
    content: text,
    time: new Date().toLocaleString('zh-CN')
  });
  if (logs.length > 50) logs = logs.slice(0, 50);
  localStorage.setItem('noticeLogs', JSON.stringify(logs));
}

function openNoticeLog() {
  var logs = JSON.parse(localStorage.getItem('noticeLogs') || '[]');
  var html = '';
  if (logs.length === 0) {
    html = '<p class="text-gray-400 text-center py-8 text-sm">暂无通知记录</p>';
  } else {
    logs.forEach(function(log) {
      var preview = log.content.length > 50 ? log.content.slice(0, 50) + '...' : log.content;
      html += '<div class="p-3 bg-gray-50 rounded-lg mb-2">'
        + '<div class="text-xs text-gray-400 mb-1">' + log.time + '</div>'
        + '<div class="text-sm text-gray-700 whitespace-pre-wrap mb-2">' + preview + '</div>'
        + '<div class="flex gap-2">'
        + '<button onclick="copyLogNotice(' + log.id + ')" class="text-xs text-green-500">再次复制</button>'
        + '<button onclick="delLogNotice(' + log.id + ')" class="text-xs text-red-500">删除</button>'
        + '</div></div>';
    });
  }
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">通知发布记录</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">' + html + '</div>'
  );
}

function copyLogNotice(id) {
  var logs = JSON.parse(localStorage.getItem('noticeLogs') || '[]');
  var log = logs.find(function(l){ return l.id === id; });
  if (!log) return;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(log.content);
  } else {
    var textarea = document.createElement('textarea');
    textarea.value = log.content;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
  }
  alert('已复制到剪贴板');
}

function delLogNotice(id) {
  if (!confirm('确定删除这条记录吗？')) return;
  var logs = JSON.parse(localStorage.getItem('noticeLogs') || '[]');
  logs = logs.filter(function(l){ return l.id !== id; });
  localStorage.setItem('noticeLogs', JSON.stringify(logs));
  openNoticeLog();
}

function openTplManage() {
  var tpls = get('tpls');
  var names = Object.keys(tpls);
  var html = '';
  names.forEach(function(name) {
    html += '<div class="p-3 bg-gray-50 rounded-lg mb-2">'
      + '<div class="font-medium text-sm mb-1">' + name + '</div>'
      + '<div class="text-xs text-gray-500 mb-2">' + tpls[name].slice(0, 30) + '...</div>'
      + '<div class="flex gap-2">'
      + '<button onclick="editTpl(\'' + name + '\')" class="text-xs text-green-500">编辑</button>'
      + '<button onclick="delTpl(\'' + name + '\')" class="text-xs text-red-500">删除</button>'
      + '</div></div>';
  });
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">通知模板管理</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4">'
    + html
    + '<button onclick="addTpl()" class="w-full btn-primary mt-3">+ 新建模板</button>'
    + '</div>'
  );
}

function addTpl() {
  var name = prompt('模板名称：');
  if (!name) return;
  var content = prompt('模板内容：');
  if (content === null) return;
  var tpls = get('tpls');
  tpls[name] = content;
  set('tpls', tpls);
  openTplManage();
}

function editTpl(name) {
  var tpls = get('tpls');
  var newContent = prompt('修改模板内容：', tpls[name]);
  if (newContent === null) return;
  tpls[name] = newContent;
  set('tpls', tpls);
  openTplManage();
}

function delTpl(name) {
  if (!confirm('确定删除模板「' + name + '」吗？')) return;
  var tpls = get('tpls');
  delete tpls[name];
  set('tpls', tpls);
  openTplManage();
}

// ========== 首页布局设置 ==========
function editClassName() {
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">班级与老师设置</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<div><label class="text-xs text-gray-500 block mb-1.5">班级名称</label>'
    + '<input type="text" id="classNameInput" value="' + getClassName() + '" class="w-full input-field" placeholder="如：高一（2）班"></div>'
    + '<div><label class="text-xs text-gray-500 block mb-1.5">老师称呼</label>'
    + '<input type="text" id="teacherNameInput" value="' + getTeacherName() + '" class="w-full input-field" placeholder="如：王老师"></div>'
    + '<button onclick="saveClassName()" class="w-full btn-primary mt-2">保存</button>'
    + '</div>'
  );
  setTimeout(function(){ document.getElementById('classNameInput').focus(); }, 100);
}
function saveClassName() {
  var cn = document.getElementById('classNameInput').value.trim();
  var tn = document.getElementById('teacherNameInput').value.trim();
  if (!cn) { alert('请输入班级名称'); return; }
  if (!tn) { alert('请输入老师称呼'); return; }
  setClassName(cn);
  setTeacherName(tn);
  updateHeader();
  var mc = document.getElementById('mineClassName');
  if (mc) mc.textContent = cn;
  closeModal();
}
function openHomeLayout() {
  var layout = JSON.parse(localStorage.getItem('homeLayout') || '{"stats":true,"quick":true,"duty":true,"schedule":true,"todo":true}');
  showModal(
    '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">首页布局设置</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4 space-y-3">'
    + '<p class="text-xs text-gray-400 mb-1">开关控制首页模块显示，顺序固定：统计→快捷→值日→课程→待办</p>'
    + '<label class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">'
    + '<span class="text-sm">统计卡片</span>'
    + '<input type="checkbox" id="layout-stats" ' + (layout.stats?'checked':'') + '>'
    + '</label>'
    + '<label class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">'
    + '<span class="text-sm">快捷入口</span>'
    + '<input type="checkbox" id="layout-quick" ' + (layout.quick?'checked':'') + '>'
    + '</label>'
    + '<label class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">'
    + '<span class="text-sm">今日值日</span>'
    + '<input type="checkbox" id="layout-duty" ' + (layout.duty?'checked':'') + '>'
    + '</label>'
    + '<label class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">'
    + '<span class="text-sm">今日课程</span>'
    + '<input type="checkbox" id="layout-schedule" ' + (layout.schedule!==false?'checked':'') + '>'
    + '</label>'
    + '<label class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">'
    + '<span class="text-sm">今日待办</span>'
    + '<input type="checkbox" id="layout-todo" ' + (layout.todo?'checked':'') + '>'
    + '</label>'
    + '<button onclick="saveHomeLayout()" class="w-full btn-primary mt-3">保存</button>'
    + '</div>'
  );
}

var _qaDrag = { index: -1, el: null, placeholder: null, startY: 0, offsetY: 0, moved: false };

function openQuickActionsEdit() {
  var config = getQuickActions();
  var html = '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">';
  html += '<span class="font-semibold text-sm">常用功能管理</span>';
  html += '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>';
  html += '<div class="p-4">';
  html += '<div class="text-xs text-gray-400 mb-3">长按整行拖拽排序，开关控制显示</div>';
  html += '<div id="qaList">';
  config.forEach(function(item, i) {
    var action = ALL_QUICK_ACTIONS.find(function(a){ return a.id === item.id; });
    if (!action) return;
    html += '<div class="qa-item flex items-center gap-3 py-3 border-b border-gray-50" data-idx="' + i + '">';
    html += '<div class="w-8 h-8 rounded-lg flex items-center justify-center" style="background:' + action.bg + ';color:' + action.color + ';">' + (action.svg || action.icon || '') + '</div>';
    html += '<span class="flex-1 text-sm text-gray-700">' + action.name + '</span>';
    html += '<span class="qa-drag-hint text-gray-300 text-lg select-none">≡</span>';
    html += '<label class="relative inline-block w-10 h-6">';
    html += '<input type="checkbox" class="sr-only peer qa-toggle" ' + (item.visible?'checked':'') + ' onchange="toggleQuickAction(' + i + ',this.checked)">';
    html += '<span class="absolute inset-0 bg-gray-200 rounded-full peer-checked:bg-green-500 transition-colors cursor-pointer"></span>';
    html += '<span class="absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform peer-checked:translate-x-4"></span>';
    html += '</label>';
    html += '</div>';
  });
  html += '</div>';
  html += '<div class="mt-4 text-xs text-gray-400 text-center">已显示 ' + config.filter(function(c){return c.visible;}).length + ' / ' + config.length + ' 个功能</div>';
  html += '</div>';
  showModal(html);
  // 事件委托：绑定在列表上，不需要每次重新绑定
  setTimeout(function() {
    var list = document.getElementById('qaList');
    if (list) {
      list.addEventListener('touchstart', qaListTouchStart, {passive:false});
      list.addEventListener('touchmove', qaListTouchMove, {passive:false});
      list.addEventListener('touchend', qaListTouchEnd);
    }
  }, 50);
}

function qaListTouchStart(e) {
  // 点击开关不触发拖拽
  if (e.target.closest('.qa-toggle') || e.target.closest('label')) return;
  var item = e.target.closest('.qa-item');
  if (!item) return;
  e.preventDefault();
  var idx = parseInt(item.dataset.idx);
  _qaDrag.index = idx;
  _qaDrag.el = item;
  _qaDrag.moved = false;
  var touch = e.touches[0];
  var rect = item.getBoundingClientRect();
  _qaDrag.startY = touch.clientY;
  _qaDrag.offsetY = touch.clientY - rect.top;
  // 占位符
  var ph = document.createElement('div');
  ph.style.height = rect.height + 'px';
  ph.style.background = 'rgba(217, 119, 87, 0.08)';
  ph.style.borderRadius = '8px';
  _qaDrag.placeholder = ph;
  item.parentNode.insertBefore(ph, item);
  // 拖拽项固定
  item.style.position = 'fixed';
  item.style.left = rect.left + 'px';
  item.style.width = rect.width + 'px';
  item.style.top = rect.top + 'px';
  item.style.zIndex = '999';
  item.style.background = '#fff';
  item.style.boxShadow = '0 8px 24px rgba(0,0,0,0.18)';
  item.style.borderRadius = '10px';
  item.style.transform = 'scale(1.03)';
}

function qaListTouchMove(e) {
  if (_qaDrag.index < 0) return;
  e.preventDefault();
  _qaDrag.moved = true;
  var touch = e.touches[0];
  var y = touch.clientY - _qaDrag.offsetY;
  _qaDrag.el.style.top = y + 'px';
  // 计算插入位置
  var list = document.getElementById('qaList');
  var items = list.querySelectorAll('.qa-item');
  var insertBefore = null;
  items.forEach(function(it) {
    if (it === _qaDrag.el) return;
    var r = it.getBoundingClientRect();
    if (touch.clientY < r.top + r.height / 2) {
      if (!insertBefore) insertBefore = it;
    }
  });
  if (insertBefore) {
    list.insertBefore(_qaDrag.placeholder, insertBefore);
  } else {
    list.appendChild(_qaDrag.placeholder);
  }
}

function qaListTouchEnd() {
  if (_qaDrag.index < 0) return;
  var list = document.getElementById('qaList');
  // 归位
  if (_qaDrag.placeholder && _qaDrag.placeholder.parentNode) {
    _qaDrag.placeholder.parentNode.insertBefore(_qaDrag.el, _qaDrag.placeholder);
    _qaDrag.placeholder.remove();
  }
  var el = _qaDrag.el;
  el.style.position = '';
  el.style.left = '';
  el.style.width = '';
  el.style.top = '';
  el.style.zIndex = '';
  el.style.background = '';
  el.style.boxShadow = '';
  el.style.borderRadius = '';
  el.style.transform = '';
  // 保存新顺序（按DOM顺序）
  if (_qaDrag.moved) {
    var newOrder = [];
    var config = getQuickActions();
    list.querySelectorAll('.qa-item').forEach(function(it) {
      var idx = parseInt(it.dataset.idx);
      if (config[idx]) newOrder.push(config[idx]);
    });
    if (newOrder.length === config.length) {
      localStorage.setItem('quickActions', JSON.stringify(newOrder));
      renderQuickActions();
    }
  }
  _qaDrag = { index: -1, el: null, placeholder: null, startY: 0, offsetY: 0, moved: false };
}

function toggleQuickAction(index, visible) {
  var config = getQuickActions();
  config[index].visible = visible;
  localStorage.setItem('quickActions', JSON.stringify(config));
  renderQuickActions();
}

function saveHomeLayout() {
  var layout = {
    stats: document.getElementById('layout-stats').checked,
    quick: document.getElementById('layout-quick').checked,
    duty: document.getElementById('layout-duty').checked,
    schedule: document.getElementById('layout-schedule').checked,
    todo: document.getElementById('layout-todo').checked
  };
  localStorage.setItem('homeLayout', JSON.stringify(layout));
  initHomeLayout();
  closeModal();
  alert('保存成功');
}

function initHomeLayout() {
  var layout = JSON.parse(localStorage.getItem('homeLayout') || '{"stats":true,"quick":true,"duty":true,"schedule":true,"todo":true}');
  document.getElementById('homeStats').style.display = layout.stats !== false ? '' : 'none';
  document.getElementById('homeQuick').style.display = layout.quick !== false ? '' : 'none';
  document.getElementById('homeDuty').style.display = layout.duty !== false ? '' : 'none';
  document.getElementById('homeSchedule').style.display = layout.schedule !== false ? '' : 'none';
  document.getElementById('homeTodo').style.display = layout.todo !== false ? '' : 'none';
}

// ========== 数据管理 ==========
function exportAll() {
  var data = {
    students: get('students'),
    subjects: get('subjects'),
    exams: get('exams'),
    todos: get('todos'),
    tpls: get('tpls'),
    schedule: JSON.parse(localStorage.getItem('schedule') || 'null'),
    mySubjects: JSON.parse(localStorage.getItem('mySubjects') || 'null'),
    seatMap: JSON.parse(localStorage.getItem('seatMap') || '{}'),
    dutyGroup: localStorage.getItem('dutyGroup'),
    seatCols: localStorage.getItem('seatCols'),
    theme: localStorage.getItem('theme'),
    className: localStorage.getItem('className'),
    teacherName: localStorage.getItem('teacherName'),
    noticeLogs: JSON.parse(localStorage.getItem('noticeLogs') || '[]'),
    albumPhotos: JSON.parse(localStorage.getItem('albumPhotos') || '[]'),
    albumCategories: JSON.parse(localStorage.getItem('albumCategories') || '[]'),
    homeLayout: JSON.parse(localStorage.getItem('homeLayout') || '{}')
  };
  var blob = new Blob(['\ufeff' + JSON.stringify(data, null, 2)], {type: 'application/json;charset=utf-8'});
  var url = URL.createObjectURL(blob);
  var a = document.createElement('a');
  a.href = url;
  a.download = '班主任工作台数据备份_' + new Date().toISOString().slice(0,10) + '.json';
  a.click();
  URL.revokeObjectURL(url);
}

function clearAll() {
  if (!confirm('确定清空所有数据吗？此操作不可恢复！')) return;
  if (!confirm('再次确认：真的要清空所有数据吗？')) return;
  localStorage.clear();
  init();
  initHomeLayout();
  renderTodos();
  renderDuty();
  renderTodaySchedule();
  renderQuickActions();
  updateStats();
  renderStuList();
  renderExamFilter();
  renderExamList();
  alert('数据已清空');
}

function importAll() {
  var input = document.createElement('input');
  input.type = 'file';
  input.accept = '.json,application/json';
  input.onchange = function(e) {
    var file = e.target.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function(ev) {
      try {
        var data = JSON.parse(ev.target.result);
        if (!data.students) { alert('文件格式不正确'); return; }
        if (!confirm('导入将覆盖当前所有数据，确定继续吗？')) return;
        if (data.students) set('students', data.students);
        if (data.subjects) set('subjects', data.subjects);
        if (data.exams) saveExams(data.exams);
        if (data.todos) set('todos', data.todos);
        if (data.tpls) set('tpls', data.tpls);
        if (data.schedule) localStorage.setItem('schedule', JSON.stringify(data.schedule));
        if (data.mySubjects) localStorage.setItem('mySubjects', JSON.stringify(data.mySubjects));
        if (data.seatMap) localStorage.setItem('seatMap', JSON.stringify(data.seatMap));
        if (data.dutyGroup) localStorage.setItem('dutyGroup', data.dutyGroup);
        if (data.seatCols) localStorage.setItem('seatCols', data.seatCols);
        if (data.theme) localStorage.setItem('theme', data.theme);
        if (data.className) localStorage.setItem('className', data.className);
        if (data.teacherName) localStorage.setItem('teacherName', data.teacherName);
        if (data.noticeLogs) localStorage.setItem('noticeLogs', JSON.stringify(data.noticeLogs));
        if (data.albumPhotos) localStorage.setItem('albumPhotos', JSON.stringify(data.albumPhotos));
        if (data.albumCategories) localStorage.setItem('albumCategories', JSON.stringify(data.albumCategories));
        if (data.homeLayout) localStorage.setItem('homeLayout', JSON.stringify(data.homeLayout));
        location.reload();
      } catch(err) {
        alert('导入失败：' + err.message);
      }
    };
    reader.readAsText(file);
  };
  input.click();
}

// ========== 弹窗工具 ==========
function showModal(html) {
  document.getElementById('modalBody').innerHTML = '<div class="modal-handle"></div><div class="modal-body-scroll">' + html + '</div>';
  document.getElementById('modal').classList.add('show');
  document.body.style.overflow = 'hidden';
}
function printContent(title, html, subtitle, landscape) {
  var area = document.getElementById('printArea');
  var oldStyle = document.getElementById('printPageStyle');
  if (oldStyle) oldStyle.remove();
  if (landscape) {
    var style = document.createElement('style');
    style.id = 'printPageStyle';
    style.textContent = '@page { size: A4 landscape; margin: 8mm; }';
    document.head.appendChild(style);
  }
  var sub = subtitle ? '<div class="print-subtitle">' + subtitle + '</div>' : '';
  area.innerHTML = '<div class="print-title">' + title + '</div>' + sub + html;
  setTimeout(function(){ window.print(); }, 150);
}
// 打印后清理
window.onafterprint = function() {
  var s = document.getElementById('printPageStyle');
  if (s) s.remove();
  document.getElementById('printArea').innerHTML = '';
};

function closeModal() {
  document.getElementById('modal').classList.remove('show');
  // 没有其他弹出层时恢复滚动
  if (!document.querySelector('.full-page.active')) {
    document.body.style.overflow = '';
  }
}

document.getElementById('modal').addEventListener('click', function(e) {
  if (e.target === this) closeModal();
});
document.getElementById('albumCategoryModal').addEventListener('click', function(e) {
  if (e.target === this) this.classList.remove('show');
});
// 防止modal内容滚动到边界时穿透背景
document.getElementById('modalBody').addEventListener('touchmove', function(e) {
  var el = e.currentTarget;
  var scrollTop = el.scrollTop;
  var scrollHeight = el.scrollHeight;
  var clientHeight = el.clientHeight;
  var touch = e.touches[0];
  // 记录上次触摸位置用于判断方向
  if (el._lastTouchY === undefined) el._lastTouchY = touch.clientY;
  var dy = touch.clientY - el._lastTouchY;
  el._lastTouchY = touch.clientY;
  // 到顶部且继续向下滑，或到底部且继续向上滑，阻止默认
  if ((scrollTop <= 0 && dy > 0) || (scrollTop + clientHeight >= scrollHeight && dy < 0)) {
    e.preventDefault();
  }
}, {passive:false});


// ========== 主题配色系统 ==========
const THEMES = {
  warm: {
    name:'暖阳橙', primary:'#D97757', primaryDark:'#C4613F', primaryLight:'#F5E6DE',
    bg:'#FAF7F2', card:'#FFFFFF', text:'#3A322C', text2:'#8C8279', text3:'#B8AEA4',
    border:'#EDE7DF', inputBg:'#F5F0E8', maleBg:'#E8EEF2', femaleBg:'#F5E6E0',
    headerBg:'rgba(255,255,255,0.72)', navBg:'rgba(255,255,255,0.72)'
  },
  mint: {
    name:'薄荷绿', primary:'#5BA88A', primaryDark:'#4A9070', primaryLight:'#D8EDE3',
    bg:'#F0F7F4', card:'#FFFFFF', text:'#2D3A35', text2:'#7A8B82', text3:'#A8B5AD',
    border:'#D8E5DE', inputBg:'#E8F0EB', maleBg:'#E0EDE5', femaleBg:'#F0E0E0',
    headerBg:'rgba(255,255,255,0.72)', navBg:'rgba(255,255,255,0.72)'
  },
  haze: {
    name:'雾霾蓝', primary:'#6B8BA5', primaryDark:'#557090', primaryLight:'#D5E0EA',
    bg:'#EEF2F6', card:'#FFFFFF', text:'#2C3540', text2:'#7A8590', text3:'#A8B0BA',
    border:'#D5DCE3', inputBg:'#E8EDF2', maleBg:'#E0E8EF', femaleBg:'#EFE0E0',
    headerBg:'rgba(255,255,255,0.72)', navBg:'rgba(255,255,255,0.72)'
  },
  retro: {
    name:'复古棕', primary:'#A67B5B', primaryDark:'#8B6548', primaryLight:'#E8D8C8',
    bg:'#F5EFE6', card:'#FFFFFF', text:'#3D3025', text2:'#8A7B6B', text3:'#B5A898',
    border:'#E0D5C5', inputBg:'#EFE8DC', maleBg:'#E5E0D5', femaleBg:'#E8D5CC',
    headerBg:'rgba(255,255,255,0.72)', navBg:'rgba(255,255,255,0.72)'
  },
  grape: {
    name:'葡萄紫', primary:'#8B7AB8', primaryDark:'#7060A0', primaryLight:'#E0D8F0',
    bg:'#F2EFF8', card:'#FFFFFF', text:'#332D40', text2:'#7E7590', text3:'#A8A0B8',
    border:'#D8D0E5', inputBg:'#ECE8F2', maleBg:'#E0E0EF', femaleBg:'#EDE0E8',
    headerBg:'rgba(255,255,255,0.72)', navBg:'rgba(255,255,255,0.72)'
  },
  night: {
    name:'深夜黑', primary:'#E8A87C', primaryDark:'#D09060', primaryLight:'#3A3028',
    bg:'#1A1A1E', card:'#2A2A30', text:'#F0F0F0', text2:'#A0A0A8', text3:'#6A6A72',
    border:'#3A3A42', inputBg:'#25252B', maleBg:'#2A3035', femaleBg:'#352A2E',
    headerBg:'rgba(30,30,35,0.85)', navBg:'rgba(30,30,35,0.85)'
  }
};

function applyTheme() {
  var key = localStorage.getItem('theme') || 'warm';
  var t = THEMES[key] || THEMES.warm;
  var old = document.getElementById('theme-style');
  if (old) old.remove();
  var css = '';
  css += 'body{background:'+t.bg+'!important;color:'+t.text+'!important;}';
  css += '.card,.stat-card{background:'+t.card+'!important;}';
  css += '.btn-primary{background:'+t.primary+'!important;box-shadow:0 2px 10px '+t.primary+'44!important;}';
  css += '.btn-secondary{background:'+t.inputBg+'!important;color:'+t.text+'!important;}';
  css += '.btn-secondary:active{background:'+t.border+'!important;}';
  css += '.input-field{background:'+t.inputBg+'!important;color:'+t.text+'!important;}';
  css += '.input-field:focus{background:'+t.card+'!important;box-shadow:0 0 0 3px '+t.primary+'26!important;}';
  css += 'header{background:'+t.headerBg+'!important;border-bottom:0.5px solid '+t.border+'!important;}';
  css += 'header h1{color:'+t.text+'!important;}header p{color:'+t.text2+'!important;}';
  css += 'nav{background:'+t.navBg+'!important;border-top:0.5px solid '+t.border+'!important;}';
  css += '.tab-item{color:'+t.text3+'!important;}.tab-item.tab-active,.tab-active{color:'+t.primary+'!important;}';
  css += '.page-nav,.page-toolbar{background:'+t.navBg+'!important;border-color:'+t.border+'!important;}';
  css += '.page-nav .nav-btn{color:'+t.primary+'!important;}';
  css += '.page-nav .nav-title{color:'+t.text+'!important;}';
  css += '.full-page,.drawer{background:'+t.bg+'!important;}';
  css += '.modal-content{background:'+t.card+'!important;}';
  css += '.progress-bar{background:'+t.border+'!important;}';
  css += '.progress-fill{background:'+t.primary+'!important;}';
  css += '.stat-card .num{color:'+t.primary+'!important;}';
  css += '.stat-card .label{color:'+t.text2+'!important;}';
  css += 'input[type="checkbox"]{accent-color:'+t.primary+'!important;}';
  css += '.stu-chart-tab.active{background:'+t.primary+'!important;}';
  css += '.sched-today-cell{box-shadow:inset 0 0 0 2px '+t.primary+'!important;}';
  css += '.sched-current-cell{box-shadow:inset 0 0 0 2px '+t.primaryDark+'!important;}';
  css += '.sched-current-time .sched-period{color:'+t.primaryDark+'!important;}';
  css += '.sched-current-time .sched-time{color:'+t.primary+'!important;}';
  css += '.duty-card-today-tag{background:'+t.primary+'!important;}';
  css += '.duty-tag-editable{background:'+t.primary+'1F!important;color:'+t.primary+'!important;border-color:'+t.primary+'!important;}';
  css += '.print-btn{color:'+t.primary+'!important;}';
  css += 'h1,h2,h3,h4{color:'+t.text+'!important;}';
  css += '.schedule-table th,.sched-time-cell,.sched-legend{background:'+t.inputBg+'!important;color:'+t.text2+'!important;}';
  css += '.sched-picker-cancel{background:'+t.inputBg+'!important;color:'+t.text+'!important;}';
  css += '.todo-item:active,.qa-item:active{background:'+t.inputBg+'!important;}';
  css += '.seat-cell{background:'+t.inputBg+'!important;border-color:'+t.border+'!important;}';
  if (key === 'night') {
    css += '.card,.stat-card{box-shadow:0 1px 3px rgba(0,0,0,0.3)!important;}';
    css += '.modal{background:rgba(0,0,0,0.6)!important;}';
    css += 'input,textarea,select{color:'+t.text+'!important;}';
    css += '.sched-picker{background:'+t.card+'!important;}';
    css += '.sched-picker-title{color:'+t.text+'!important;}';
  }
  // 注入 CSS 变量供 header/nav 使用
  document.documentElement.style.setProperty('--primary', t.primary);
  document.documentElement.style.setProperty('--primary-dark', t.primaryDark);
  document.documentElement.style.setProperty('--text', t.text);
  document.documentElement.style.setProperty('--text2', t.text2);
  document.documentElement.style.setProperty('--text3', t.text3);
  document.documentElement.style.setProperty('--border', t.border);
  document.documentElement.style.setProperty('--header-bg', t.headerBg);
  document.documentElement.style.setProperty('--header-border', t.border + '80');
  document.documentElement.style.setProperty('--nav-bg', t.navBg);
  document.documentElement.style.setProperty('--nav-border', t.border + '80');
  document.documentElement.style.setProperty('--tab-active-bg', t.primary + '1A');
  var style = document.createElement('style');
  style.id = 'theme-style';
  style.textContent = css;
  document.head.appendChild(style);
  var mn = document.getElementById('mineThemeName');
  if (mn) mn.textContent = t.name;
}

function openThemeSettings() {
  var current = localStorage.getItem('theme') || 'warm';
  var html = '<div class="sticky top-0 bg-white border-b border-gray-100 px-4 py-3 flex justify-between items-center">'
    + '<span class="font-semibold text-sm">主题配色</span>'
    + '<button onclick="closeModal()" class="text-gray-400"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>'
    + '<div class="p-4"><div class="grid grid-cols-2 gap-3">';
  var keys = Object.keys(THEMES);
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    var t = THEMES[key];
    var active = key === current ? 'box-shadow:0 0 0 2px '+t.primary+';' : '';
    html += '<div onclick="selectTheme(\''+key+'\')" style="'+active+'border-radius:16px;padding:16px;cursor:pointer;background:'+t.bg+';border:1px solid '+t.border+';" class="transition-transform active:scale-95">'
      + '<div class="flex gap-1.5 mb-2">'
      + '<span style="width:24px;height:24px;border-radius:8px;background:'+t.primary+';display:inline-block;"></span>'
      + '<span style="width:24px;height:24px;border-radius:8px;background:'+t.primaryDark+';display:inline-block;"></span>'
      + '<span style="width:24px;height:24px;border-radius:8px;background:'+t.card+';border:1px solid '+t.border+';display:inline-block;"></span>'
      + '<span style="width:24px;height:24px;border-radius:8px;background:'+t.text+';display:inline-block;"></span>'
      + '</div>'
      + '<div style="font-size:14px;font-weight:600;color:'+t.text+';">'+t.name+'</div>'
      + '<div style="font-size:11px;color:'+t.text2+';margin-top:2px;">'+(key===current?'当前使用':'点击切换')+'</div>'
      + '</div>';
  }
  html += '</div><p class="text-xs text-gray-400 text-center mt-4">切换即时生效，自动保存偏好</p></div>';
  showModal(html);
}

function selectTheme(key) {
  localStorage.setItem('theme', key);
  applyTheme();
  closeModal();
}

// ========== 启动 ==========
init();
initHomeLayout();
updateHeader();
renderTodos();
renderDuty();
renderTodaySchedule();
renderQuickActions();
updateStats();


// ========== 家庭住址地图导航 ==========
var _mapNavStuId = 0;

// ========== 地图选点（编辑学生家庭位置） ==========
var _pickerMap = null;
var _pickerMarker = null;
var _pickerLng = null;
var _pickerLat = null;
var _pickerAddr = '';
var _pickerCity = '南阳';
var _placeSearchReady = false;
var _geocoderReady = false;

// 常用城市坐标
var CITY_COORDS = {
  '南阳': [112.5283, 33.0007],
  '郑州': [113.6253, 34.7466],
  '洛阳': [112.4540, 34.6197],
  '北京': [116.4074, 39.9042],
  '上海': [121.4737, 31.2304],
  '广州': [113.2644, 23.1291],
  '深圳': [114.0579, 22.5431],
  '武汉': [114.3055, 30.5928],
  '西安': [108.9398, 34.3416],
  '成都': [104.0668, 30.5728],
  '杭州': [120.1551, 30.2741],
  '南京': [118.7969, 32.0603]
};

// 全国城市数据（省→市）
var CITY_DATA = {
  '直辖市': ['北京','上海','天津','重庆'],
  '河北': ['石家庄','唐山','秦皇岛','邯郸','保定','张家口','承德','沧州','廊坊','衡水','邢台'],
  '山西': ['太原','大同','阳泉','长治','晋城','朔州','晋中','运城','忻州','临汾','吕梁'],
  '内蒙古': ['呼和浩特','包头','乌海','赤峰','通辽','鄂尔多斯','呼伦贝尔','巴彦淖尔','乌兰察布'],
  '辽宁': ['沈阳','大连','鞍山','抚顺','本溪','丹东','锦州','营口','阜新','辽阳','盘锦','铁岭','朝阳','葫芦岛'],
  '吉林': ['长春','吉林','四平','辽源','通化','白山','松原','白城','延边'],
  '黑龙江': ['哈尔滨','齐齐哈尔','鸡西','鹤岗','双鸭山','大庆','伊春','佳木斯','七台河','牡丹江','黑河','绥化'],
  '江苏': ['南京','无锡','徐州','常州','苏州','南通','连云港','淮安','盐城','扬州','镇江','泰州','宿迁'],
  '浙江': ['杭州','宁波','温州','嘉兴','湖州','绍兴','金华','衢州','舟山','台州','丽水'],
  '安徽': ['合肥','芜湖','蚌埠','淮南','马鞍山','淮北','铜陵','安庆','黄山','滁州','阜阳','宿州','六安','亳州','池州','宣城'],
  '福建': ['福州','厦门','莆田','三明','泉州','漳州','南平','龙岩','宁德'],
  '江西': ['南昌','景德镇','萍乡','九江','新余','鹰潭','赣州','吉安','宜春','抚州','上饶'],
  '山东': ['济南','青岛','淄博','枣庄','东营','烟台','潍坊','济宁','泰安','威海','日照','临沂','德州','聊城','滨州','菏泽'],
  '河南': ['郑州','开封','洛阳','平顶山','安阳','鹤壁','新乡','焦作','濮阳','许昌','漯河','三门峡','南阳','商丘','信阳','周口','驻马店'],
  '湖北': ['武汉','黄石','十堰','宜昌','襄阳','鄂州','荆门','孝感','荆州','黄冈','咸宁','随州'],
  '湖南': ['长沙','株洲','湘潭','衡阳','邵阳','岳阳','常德','张家界','益阳','郴州','永州','怀化','娄底'],
  '广东': ['广州','韶关','深圳','珠海','汕头','佛山','江门','湛江','茂名','肇庆','惠州','梅州','汕尾','河源','阳江','清远','东莞','中山','潮州','揭阳','云浮'],
  '广西': ['南宁','柳州','桂林','梧州','北海','防城港','钦州','贵港','玉林','百色','贺州','河池','来宾','崇左'],
  '海南': ['海口','三亚','三沙','儋州'],
  '四川': ['成都','自贡','攀枝花','泸州','德阳','绵阳','广元','遂宁','内江','乐山','南充','眉山','宜宾','广安','达州','雅安','巴中','资阳'],
  '贵州': ['贵阳','六盘水','遵义','安顺','毕节','铜仁'],
  '云南': ['昆明','曲靖','玉溪','保山','昭通','丽江','普洱','临沧'],
  '西藏': ['拉萨','日喀则','昌都','林芝','山南','那曲'],
  '陕西': ['西安','铜川','宝鸡','咸阳','渭南','延安','汉中','榆林','安康','商洛'],
  '甘肃': ['兰州','嘉峪关','金昌','白银','天水','武威','张掖','平凉','酒泉','庆阳','定西','陇南'],
  '青海': ['西宁','海东'],
  '宁夏': ['银川','石嘴山','吴忠','固原','中卫'],
  '新疆': ['乌鲁木齐','克拉玛依','吐鲁番','哈密']
};
var _amapLoaded = false;

function loadAMap(callback) {
  if (window.AMap) { callback(); return; }
  if (!AMAP_JS_KEY) {
    alert('请先在代码顶部配置 AMAP_JS_KEY（高德地图JS API Key，免费申请）\n申请地址：https://console.amap.com/');
    return;
  }
  if (_amapLoaded) {
    // 正在加载中，等加载完
    var check = setInterval(function() {
      if (window.AMap) { clearInterval(check); callback(); }
    }, 100);
    return;
  }
  _amapLoaded = true;
  var script = document.createElement('script');
  script.src = 'https://webapi.amap.com/maps?v=2.0&key=' + AMAP_JS_KEY + '&plugin=AMap.Geocoder';
  script.onload = function() { callback(); };
  script.onerror = function() { _amapLoaded = false; alert('高德地图加载失败，请检查网络或Key'); };
  document.head.appendChild(script);
}

function openMapPicker() {
  var addr = document.getElementById('editStuAddr').value || '';
  var lngVal = document.getElementById('editStuLng').value;
  var latVal = document.getElementById('editStuLat').value;
  _pickerLng = lngVal ? parseFloat(lngVal) : null;
  _pickerLat = latVal ? parseFloat(latVal) : null;
  _pickerAddr = addr;

  document.getElementById('mapPickerModal').classList.add('show');
  document.getElementById('mapPickerSearch').value = '';
  document.getElementById('mapPickerAddrInput').value = addr;
  document.getElementById('mapPickerSearchList').classList.remove('show');
  document.getElementById('pickerCityName').textContent = _pickerCity;

  loadAMap(function() {
    setTimeout(initMapPicker, 200);
  });
}

function toggleCityPanel() {
  var panel = document.getElementById('pickerCityPanel');
  if (panel.classList.contains('show')) {
    panel.classList.remove('show');
  } else {
    renderCityPanel();
    panel.classList.add('show');
  }
}

function renderCityPanel() {
  var container = document.getElementById('pickerCityList');
  var html = '';
  for (var province in CITY_DATA) {
    var cities = CITY_DATA[province];
    var isOpen = _openProvince === province;
    html += '<div class="city-province' + (isOpen ? ' open' : '') + '" onclick="toggleProvince(\'' + province + '\')">'
      + province + '<span class="arrow">▸</span></div>';
    html += '<div class="city-cities' + (isOpen ? ' show' : '') + '" id="cities-' + province + '">';
    cities.forEach(function(city) {
      var active = (city === _pickerCity) ? ' active' : '';
      html += '<span class="city-tag' + active + '" onclick="selectCityFromPanel(\'' + city + '\')">' + city + '</span>';
    });
    html += '</div>';
  }
  container.innerHTML = html;
}

var _openProvince = null;
function toggleProvince(province) {
  _openProvince = (_openProvince === province) ? null : province;
  renderCityPanel();
}

function selectCityFromPanel(city) {
  _pickerCity = city;
  document.getElementById('pickerCityName').textContent = city;
  document.getElementById('pickerCityPanel').classList.remove('show');
  _openProvince = null;
  // 移动地图到该城市
  if (_pickerMap) {
    if (CITY_COORDS[city]) {
      _pickerMap.setCenter(CITY_COORDS[city]);
      _pickerMap.setZoom(12);
    } else {
      var url = 'https://restapi.amap.com/v3/geocode/geo?address=' + encodeURIComponent(city)
        + '&key=' + AMAP_WEB_KEY + '&output=JSON';
      jsonpRequest(url, function(data) {
        if (data && data.status === '1' && data.geocodes && data.geocodes.length > 0 && _pickerMap) {
          var ll = data.geocodes[0].location.split(',');
          _pickerMap.setCenter([parseFloat(ll[0]), parseFloat(ll[1])]);
          _pickerMap.setZoom(12);
        }
      });
    }
  }
  if (_pickerMarker) { _pickerMarker.setMap(null); _pickerMarker = null; }
  _pickerLng = null; _pickerLat = null;
}

function closeMapPicker() {
  document.getElementById('mapPickerModal').classList.remove('show');
  if (_pickerMap) { _pickerMap.destroy(); _pickerMap = null; }
  _pickerMarker = null;
}

function initMapPicker() {
  var defaultCenter = CITY_COORDS[_pickerCity] || [112.5283, 33.0007];
  var center = (_pickerLng && _pickerLat) ? [_pickerLng, _pickerLat] : defaultCenter;

  _pickerMap = new AMap.Map('mapPickerMap', {
    zoom: 15,
    center: center
  });

  // 点击地图选点
  _pickerMap.on('click', function(e) {
    var lng = e.lnglat.getLng();
    var lat = e.lnglat.getLat();
    setPickerLocation(lng, lat);
    // 选点后隐藏搜索列表
    document.getElementById('mapPickerSearchList').classList.remove('show');
  });

  if (_pickerLng && _pickerLat) {
    setPickerLocation(_pickerLng, _pickerLat);
  }

  // 预加载 PlaceSearch 和 Geocoder 插件
  try {
    AMap.plugin(['AMap.PlaceSearch', 'AMap.Geocoder'], function() {
      _placeSearchReady = true;
      _geocoderReady = true;
    });
  } catch(e) {}

  // 绑定搜索框输入事件（防抖）
  var searchInput = document.getElementById('mapPickerSearch');
  var searchTimer = null;
  searchInput.addEventListener('input', function() {
    var kw = this.value.trim();
    clearTimeout(searchTimer);
    if (!kw) {
      document.getElementById('mapPickerSearchList').classList.remove('show');
      return;
    }
    searchTimer = setTimeout(function() {
      doAddressSearch(kw);
    }, 500);
  });
}

// JSONP 工具函数
function jsonpRequest(url, callback) {
  var cbName = 'amap_jsonp_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
  window[cbName] = function(data) {
    callback(data);
    delete window[cbName];
    if (script.parentNode) script.parentNode.removeChild(script);
  };
  var script = document.createElement('script');
  script.src = url + (url.indexOf('?') >= 0 ? '&' : '?') + 'callback=' + cbName;
  script.onerror = function() {
    callback(null);
    if (script.parentNode) script.parentNode.removeChild(script);
  };
  document.head.appendChild(script);
}

// 地址搜索（高德Web服务API，JSONP方式，不走JS插件）
function doAddressSearch(keyword) {
  var listEl = document.getElementById('mapPickerSearchList');
  listEl.innerHTML = '<div class="picker-search-empty">正在搜索：' + keyword + '...</div>';
  listEl.classList.add('show');

  var done = false;

  var globalTimer = setTimeout(function() {
    if (!done) {
      done = true;
      listEl.innerHTML = '<div class="picker-search-empty">搜索超时，请直接在地图上点击选点</div>';
    }
  }, 10000);

  function finish() { clearTimeout(globalTimer); }

  // 方式1：高德 Web 服务 API - 关键字搜索
  function doSearch(kw, isRetry) {
    // 先用输入提示API（返回楼栋级别结果，类似美团）
    var tipUrl = 'https://restapi.amap.com/v3/assistant/inputtips?keywords=' + encodeURIComponent(kw)
      + '&city=' + encodeURIComponent(_pickerCity) + '&key=' + AMAP_WEB_KEY
      + '&output=JSON&datatype=all';
    jsonpRequest(tipUrl, function(data) {
      if (done) return;
      if (data && data.status === '1' && data.tips && data.tips.length > 0) {
        // 过滤掉没有坐标的结果
        var validTips = data.tips.filter(function(t) { return t.location && t.location !== ','; });
        if (validTips.length > 0) {
          done = true;
          finish();
          renderTipResults(validTips);
          return;
        }
      }
      // 输入提示无结果，用place/text搜索
      var url = 'https://restapi.amap.com/v3/place/text?keywords=' + encodeURIComponent(kw)
        + '&city=' + encodeURIComponent(_pickerCity) + '&key=' + AMAP_WEB_KEY
        + '&output=JSON&offset=25&page=1&extensions=base';
      jsonpRequest(url, function(data2) {
        if (done) return;
        if (data2 && data2.status === '1' && data2.pois && data2.pois.length > 0) {
          if (data2.pois.length < 5 && !isRetry) {
            var simpleKw = kw.replace(/\d+\s*栋[^\s]*/g, '').replace(/\d+\s*号楼/g, '').replace(/\d+\s*单元/g, '').trim();
            if (simpleKw && simpleKw !== kw) {
              doSearch(simpleKw, true);
              return;
            }
          }
          done = true;
          finish();
          renderWebApiResults(data2.pois);
        } else if (data2 && data2.status === '1') {
          if (!isRetry) {
            var simpleKw2 = kw.replace(/\d+\s*栋[^\s]*/g, '').replace(/\d+\s*号楼/g, '').replace(/\d+\s*单元/g, '').trim();
            if (simpleKw2 && simpleKw2 !== kw) {
              doSearch(simpleKw2, true);
              return;
            }
          }
          tryGeocoder();
        } else {
          var errInfo = (data2 && data2.info) ? data2.info : '未知错误';
          listEl.innerHTML = '<div class="picker-search-empty">搜索失败(' + errInfo + ')，试地理编码...</div>';
          tryGeocoder();
        }
      });
    });
  }
  doSearch(keyword, false);

  // 方式2：高德 Web 服务 API - 地理编码
  function tryGeocoder() {
    if (done) return;
    var geoUrl = 'https://restapi.amap.com/v3/geocode/geo?address=' + encodeURIComponent(keyword)
      + '&city=' + encodeURIComponent(_pickerCity) + '&key=' + AMAP_WEB_KEY + '&output=JSON';
    jsonpRequest(geoUrl, function(data) {
      if (done) return;
      if (data && data.status === '1' && data.geocodes && data.geocodes.length > 0) {
        done = true;
        finish();
        renderWebApiGeocodes(data.geocodes);
      } else {
        done = true;
        finish();
        var errInfo = (data && data.info) ? data.info : '无结果';
        listEl.innerHTML = '<div class="picker-search-empty">未找到"' + keyword + '"(' + errInfo + ')<br>请直接在地图上点击选点</div>';
      }
    });
  }
}

function renderTipResults(tips) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  tips.forEach(function(tip) {
    if (!tip.location || tip.location === ',') return;
    var ll = tip.location.split(',');
    var lng = parseFloat(ll[0]);
    var lat = parseFloat(ll[1]);
    var name = (tip.name || '').replace(/'/g, "\\'");
    var addr = (tip.district || '') + (tip.address || '');
    addr = addr.replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + addr + '\')">'
      + '<div class="name">' + tip.name + '</div>'
      + '<div class="addr">' + (tip.district || '') + (tip.address || '') + '</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">未找到相关地点</div>';
}

function renderWebApiResults(pois) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  pois.forEach(function(poi) {
    if (!poi.location) return;
    var ll = poi.location.split(',');
    var lng = parseFloat(ll[0]);
    var lat = parseFloat(ll[1]);
    var name = (poi.name || '').replace(/'/g, "\\'");
    var addr = (poi.address || poi.pname + poi.cityname + poi.adname || '').replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + addr + '\')">'
      + '<div class="name">' + poi.name + '</div>'
      + '<div class="addr">' + (poi.address || poi.pname + poi.cityname + poi.adname) + '</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">未找到带坐标的地点</div>';
}

function renderWebApiGeocodes(geocodes) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  geocodes.forEach(function(g) {
    if (!g.location) return;
    var ll = g.location.split(',');
    var lng = parseFloat(ll[0]);
    var lat = parseFloat(ll[1]);
    var addr = g.formattedAddress || '地理编码结果';
    var name = addr.replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + name + '\')">'
      + '<div class="name">' + addr + '</div>'
      + '<div class="addr">地理编码结果</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">地理编码无结果</div>';
}

function renderPlaceSearchResults(pois) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  pois.forEach(function(poi) {
    if (!poi.location) return;
    var lng = poi.location.lng;
    var lat = poi.location.lat;
    var name = (poi.name || '').replace(/'/g, "\\'");
    var addr = (poi.address || poi.pname + poi.cityname + poi.adname || '').replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + addr + '\')">'
      + '<div class="name">' + poi.name + '</div>'
      + '<div class="addr">' + (poi.address || poi.pname + poi.cityname + poi.adname) + '</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">未找到带坐标的地点</div>';
}

function renderGeocoderResults(geocodes) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  geocodes.forEach(function(g) {
    if (!g.location) return;
    var lng = g.location.lng;
    var lat = g.location.lat;
    var addr = g.formattedAddress || '地理编码结果';
    var name = addr.replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + name + '\')">'
      + '<div class="name">' + addr + '</div>'
      + '<div class="addr">地理编码结果</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">地理编码无结果</div>';
}

function renderAmapResults(pois) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  pois.forEach(function(poi) {
    if (!poi.location) return;
    var ll = poi.location.split(',');
    var lng = parseFloat(ll[0]);
    var lat = parseFloat(ll[1]);
    var name = (poi.name || '').replace(/'/g, "\\'");
    var addr = (poi.address || poi.pname + poi.cityname + poi.adname || '').replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + addr + '\')">'
      + '<div class="name">' + poi.name + '</div>'
      + '<div class="addr">' + (poi.address || poi.pname + poi.cityname + poi.adname) + '</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">未找到带坐标的地点</div>';
}

function renderNominatimResults(items) {
  var listEl = document.getElementById('mapPickerSearchList');
  var html = '';
  items.forEach(function(item) {
    if (!item.lat || !item.lon) return;
    var lng = parseFloat(item.lon);
    var lat = parseFloat(item.lat);
    var name = (item.display_name || '').split(',')[0];
    var addr = item.display_name || '';
    name = name.replace(/'/g, "\\'");
    addr = addr.replace(/'/g, "\\'");
    html += '<div class="picker-search-item" onclick="selectSearchResult(' + lng + ',' + lat + ',\'' + name + '\',\'' + addr + '\')">'
      + '<div class="name">' + (item.display_name || '').split(',')[0] + '</div>'
      + '<div class="addr">' + (item.display_name || '') + '</div>'
      + '</div>';
  });
  listEl.innerHTML = html || '<div class="picker-search-empty">未找到相关地点</div>';
}

// 点击搜索结果
function selectSearchResult(lng, lat, name, addr) {
  setPickerLocation(lng, lat);
  // 地址只显示地名，不带门牌号等详细信息
  _pickerAddr = name;
  document.getElementById('mapPickerSearch').value = name;
  document.getElementById('mapPickerAddrInput').value = name;
  document.getElementById('mapPickerSearchList').classList.remove('show');
}

function locateMe() {
  if (!navigator.geolocation) {
    alert('当前浏览器不支持定位功能');
    return;
  }
  var btn = document.querySelector('.picker-locate-btn');
  if (btn) btn.style.opacity = '0.5';
  navigator.geolocation.getCurrentPosition(
    function(pos) {
      if (btn) btn.style.opacity = '1';
      var lng = pos.coords.longitude;
      var lat = pos.coords.latitude;
      // GPS坐标(WGS84)转高德坐标(GCJ02)
      var gcj = wgs84ToGcj02(lng, lat);
      setPickerLocation(gcj.lng, gcj.lat);
    },
    function(err) {
      if (btn) btn.style.opacity = '1';
      var msg = '定位失败';
      if (err.code === 1) msg = '请允许定位权限';
      else if (err.code === 2) msg = '位置不可用';
      else if (err.code === 3) msg = '定位超时';
      alert(msg);
    },
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
  );
}

// WGS84(GPS) 转 GCJ02(高德) 坐标
function wgs84ToGcj02(lng, lat) {
  var a = 6378245.0;
  var ee = 0.00669342162296594323;
  function outOfChina(lng, lat) {
    return (lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271);
  }
  function transformLat(x, y) {
    var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
    ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin(y / 3.0 * Math.PI)) * 2.0 / 3.0;
    ret += (160.0 * Math.sin(y / 12.0 * Math.PI) + 320 * Math.sin(y * Math.PI / 30.0)) * 2.0 / 3.0;
    return ret;
  }
  function transformLng(x, y) {
    var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
    ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
    ret += (20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin(x / 3.0 * Math.PI)) * 2.0 / 3.0;
    ret += (150.0 * Math.sin(x / 12.0 * Math.PI) + 300.0 * Math.sin(x / 30.0 * Math.PI)) * 2.0 / 3.0;
    return ret;
  }
  if (outOfChina(lng, lat)) return {lng: lng, lat: lat};
  var dLat = transformLat(lng - 105.0, lat - 35.0);
  var dLng = transformLng(lng - 105.0, lat - 35.0);
  var radLat = lat / 180.0 * Math.PI;
  var magic = Math.sin(radLat);
  magic = 1 - ee * magic * magic;
  var sqrtMagic = Math.sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI);
  dLng = (dLng * 180.0) / (a / sqrtMagic * Math.cos(radLat) * Math.PI);
  return {lng: lng + dLng, lat: lat + dLat};
}

function setPickerLocation(lng, lat) {
  _pickerLng = lng;
  _pickerLat = lat;
  if (_pickerMarker) {
    _pickerMarker.setPosition([lng, lat]);
  } else {
    _pickerMarker = new AMap.Marker({
      position: [lng, lat],
      map: _pickerMap
    });
  }
  _pickerMap.setCenter([lng, lat]);
  _pickerMap.setZoom(17);

  // 轻量尝试逆地理编码（Web服务API，新Key，3秒超时）
  var regeoUrl = 'https://restapi.amap.com/v3/geocode/regeo?location=' + lng + ',' + lat
    + '&key=' + AMAP_WEB_KEY + '&output=JSON';
  var regeoDone = false;
  var regeoTimer = setTimeout(function() { regeoDone = true; }, 3000);
  jsonpRequest(regeoUrl, function(data) {
    clearTimeout(regeoTimer);
    if (regeoDone) return;
    regeoDone = true;
    if (data && data.status === '1' && data.regeocode) {
      var regeo = data.regeocode;
      var comp = regeo.addressComponent || {};
      var city = comp.city || '';
      var district = comp.district || '';
      var addrInput = document.getElementById('mapPickerAddrInput');
      var currentAddr = addrInput.value.trim();
      if (currentAddr) {
        // 用户已有地址（搜索结果或手动输入），给它加上市和区前缀
        if (city && currentAddr.indexOf(city) < 0 && district && currentAddr.indexOf(district) < 0) {
          addrInput.value = city + district + currentAddr;
          _pickerAddr = addrInput.value;
        } else if (city && currentAddr.indexOf(city) < 0) {
          addrInput.value = city + currentAddr;
          _pickerAddr = addrInput.value;
        }
      } else {
        // 地址为空，用市+区+最近地名
        var poiName = '';
        if (regeo.pois && regeo.pois.length > 0) {
          poiName = regeo.pois[0].name || '';
        } else if (regeo.roads && regeo.roads.length > 0) {
          poiName = regeo.roads[0].name || '';
        }
        var simpleAddr = (city || '') + (district || '') + (poiName || '');
        if (!simpleAddr && regeo.formatted_address) simpleAddr = regeo.formatted_address;
        addrInput.value = simpleAddr;
        _pickerAddr = simpleAddr;
      }
    }
  });
}

function confirmMapPicker() {
  if (!_pickerLng || !_pickerLat) { alert('请先在地图上选择位置'); return; }
  var addr = document.getElementById('mapPickerAddrInput').value.trim() || _pickerAddr || '';
  document.getElementById('editStuAddr').value = addr;
  document.getElementById('editStuLng').value = _pickerLng;
  document.getElementById('editStuLat').value = _pickerLat;
  closeMapPicker();
  // 刷新编辑表单的定位状态提示
  var addrInput = document.getElementById('editStuAddr');
  if (addrInput) {
    var hint = addrInput.parentElement.parentElement.querySelector('.text-green-600, .text-orange-500');
    if (hint) hint.outerHTML = '<p class="text-xs text-green-600 mt-1"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:3px;"><polyline points="20 6 9 17 4 12"/></svg>已定位：' + _pickerLng.toFixed(6) + ', ' + _pickerLat.toFixed(6) + '</p>';
  }
}

function clearMapPicker() {
  if (!confirm('确定清除已定位的坐标吗？')) return;
  document.getElementById('editStuLng').value = '';
  document.getElementById('editStuLat').value = '';
  _pickerLng = null;
  _pickerLat = null;
  if (_pickerMarker) { _pickerMap.remove(_pickerMarker); _pickerMarker = null; }
  // 刷新编辑表单的定位状态提示
  var addrInput = document.getElementById('editStuAddr');
  if (addrInput) {
    var hint = addrInput.parentElement.parentElement.querySelector('.text-green-600, .text-orange-500');
    if (hint) hint.outerHTML = '<p class="text-xs text-orange-500 mt-1"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align:-1px;margin-right:3px;"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>未定位，导航可能不准确，建议点地图选点</p>';
  }
}

// GCJ-02 转 BD-09 (高德坐标 -> 百度坐标)
function gcj02ToBd09(lng, lat) {
  var x_PI = Math.PI * 3000.0 / 180.0;
  var z = Math.sqrt(lng * lng + lat * lat) + 0.00002 * Math.sin(lat * x_PI);
  var theta = Math.atan2(lat, lng) + 0.000003 * Math.cos(lng * x_PI);
  return { lng: z * Math.cos(theta) + 0.0065, lat: z * Math.sin(theta) + 0.006 };
}

function openMapNavSheet(stuId) {
  _mapNavStuId = stuId;
  var s = get('students').find(function(x){ return x.id === stuId; });
  if (!s) return;
  document.getElementById('mapNavAddr').textContent = s.address || '暂无地址';
  document.getElementById('mapNavMask').classList.add('active');
  document.getElementById('mapNavSheet').classList.add('active');
  document.body.style.overflow = 'hidden';
}

function closeMapNavSheet() {
  document.getElementById('mapNavMask').classList.remove('active');
  document.getElementById('mapNavSheet').classList.remove('active');
  if (!document.querySelector('.full-page.active') && !document.getElementById('modal').classList.contains('show')) {
    document.body.style.overflow = '';
  }
}

function doMapNavigate(type) {
  var s = get('students').find(function(x){ return x.id === _mapNavStuId; });
  if (!s || !s.address) { showMapNavToast('暂无地址信息'); return; }
  var addr = s.address;
  var name = s.name + '家';
  var city = '';
  var cityMatch = addr.match(/(.+?(?:市|州|盟|地区))/);
  if (cityMatch) city = cityMatch[1];
  if (!city) city = '南阳'; // 默认城市，提升搜索精准度
  var searchKeyword = addr; // 用完整地址搜索

  var hasCoord = s.lng && s.lat;
  var ua = navigator.userAgent;
  var isIOS = /iPhone|iPad|iPod/.test(ua);

  // 先关闭面板
  closeMapNavSheet();

  // 直接用window.location.href跳转URL Scheme唤起APP：
  // 【关键】必须在用户点击的同步调用栈中执行，绝不能用setTimeout包裹，
  // 否则iOS Safari会拦截异步跳转并报"网址无效"
  function launchApp(schemeUrl, mapName) {
    var launched = false;
    var timer = null;

    function onHide() {
      if (document.hidden) {
        launched = true;
        cleanup();
      }
    }
    function cleanup() {
      document.removeEventListener('visibilitychange', onHide);
      window.removeEventListener('pagehide', onHide);
      if (timer) clearTimeout(timer);
    }

    document.addEventListener('visibilitychange', onHide);
    window.addEventListener('pagehide', onHide);

    // 同步跳转，iOS装了APP一定能唤起
    window.location.href = schemeUrl;

    // 2.5秒后页面仍在前台 → 没装APP或用户点了取消
    timer = setTimeout(function() {
      cleanup();
      if (!launched && !document.hidden) {
        showMapNavToast('请先安装' + mapName + 'APP');
      }
    }, 2500);
  }

  // 【关键】同步执行跳转逻辑，不能包在setTimeout里！
  if (type === 'amap') {
    var scheme;
    if (hasCoord) {
      // 有经纬度：amapuri路径规划，直接跳导航
      scheme = 'amapuri://route/plan/?did=BGEOF&dlat=' + s.lat + '&dlon=' + s.lng
        + '&dname=' + encodeURIComponent(name) + '&dev=0&t=0';
    } else {
      // 无经纬度：用地址名称做路径规划（新版高德官方推荐scheme，不弹升级提示）
      scheme = 'amapuri://route/plan/?did=BGEOF&dname=' + encodeURIComponent(searchKeyword) + '&dev=0&t=0';
    }
    launchApp(scheme, '高德地图');
  } else if (type === 'bmap') {
    var scheme;
    if (hasCoord) {
      var bd = gcj02ToBd09(s.lng, s.lat);
      scheme = 'baidumap://map/direction?destination=latlng:' + bd.lat + ',' + bd.lng + '|name:' + encodeURIComponent(name) + '&mode=driving&src=teacherapp';
    } else {
      scheme = 'baidumap://map/search?query=' + encodeURIComponent(searchKeyword) + '&region=' + encodeURIComponent(city);
    }
    launchApp(scheme, '百度地图');
  } else if (type === 'apple') {
    // 苹果地图系统自带，https链接直接唤起APP，不会跳网页
    if (hasCoord) {
      window.location.href = 'https://maps.apple.com/?daddr=' + s.lat + ',' + s.lng + '&dirflg=d&q=' + encodeURIComponent(name);
    } else {
      window.location.href = 'https://maps.apple.com/?q=' + encodeURIComponent(searchKeyword) + '&dirflg=d';
    }
  }
}

// 从其他App返回时强制关闭导航面板（避免关闭动画被中断导致残留）
window.addEventListener('pageshow', function() {
  var mask = document.getElementById('mapNavMask');
  var sheet = document.getElementById('mapNavSheet');
  if (mask) mask.classList.remove('active');
  if (sheet) sheet.classList.remove('active');
  document.body.style.overflow = '';
});

function copyMapAddr() {
  var s = get('students').find(function(x){ return x.id === _mapNavStuId; });
  if (!s || !s.address) { showMapNavToast('暂无地址'); return; }
  if (navigator.clipboard) {
    navigator.clipboard.writeText(s.address).then(function(){ showMapNavToast('地址已复制'); });
  } else {
    var ta = document.createElement('textarea');
    ta.value = s.address;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); showMapNavToast('地址已复制'); }
    catch(e) { showMapNavToast('复制失败'); }
    document.body.removeChild(ta);
  }
}

var _mapNavToastTimer;
function showMapNavToast(msg) {
  var toast = document.getElementById('mapNavToast');
  toast.textContent = msg;
  toast.classList.add('show');
  clearTimeout(_mapNavToastTimer);
  _mapNavToastTimer = setTimeout(function(){ toast.classList.remove('show'); }, 2000);
}

// ========== 学生分布地图 ==========
var _stuMap = null;
var _stuMarkers = {};
var _stuMapLines = [];
var _selectedStuId = null;
var _detailPanelOpen = false;

// WGS84 转 GCJ02
function _transformLat(x, y) {
  var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
  ret += (20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin(y / 3.0 * Math.PI)) * 2.0 / 3.0;
  ret += (160.0 * Math.sin(y / 12.0 * Math.PI) + 320 * Math.sin(y * Math.PI / 30.0)) * 2.0 / 3.0;
  return ret;
}
function _transformLng(x, y) {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  ret += (20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0 / 3.0;
  ret += (20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin(x / 3.0 * Math.PI)) * 2.0 / 3.0;
  ret += (150.0 * Math.sin(x / 12.0 * Math.PI) + 300.0 * Math.sin(x / 30.0 * Math.PI)) * 2.0 / 3.0;
  return ret;
}
function wgs84ToGcj02(lng, lat) {
  var a = 6378245.0;
  var ee = 0.00669342162296594323;
  var dLat = _transformLat(lng - 105.0, lat - 35.0);
  var dLng = _transformLng(lng - 105.0, lat - 35.0);
  var radLat = lat / 180.0 * Math.PI;
  var magic = Math.sin(radLat);
  magic = 1 - ee * magic * magic;
  var sqrtMagic = Math.sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI);
  dLng = (dLng * 180.0) / (a / sqrtMagic * Math.cos(radLat) * Math.PI);
  return [lng + dLng, lat + dLat];
}
function getStuGcjCoord(s) {
  if (!s.lng || !s.lat) return null;
  return wgs84ToGcj02(s.lng, s.lat);
}

function initStuMap() {
  if (_stuMap) {
    _stuMap.invalidateSize();
    return;
  }
  var students = get('students').filter(function(s){ return s.lng && s.lat; });
  if (students.length === 0) return;

  var gcjCoords = students.map(function(s){ return getStuGcjCoord(s); });
  var avgLat = gcjCoords.reduce(function(sum,c){ return sum + c[1]; }, 0) / gcjCoords.length;
  var avgLng = gcjCoords.reduce(function(sum,c){ return sum + c[0]; }, 0) / gcjCoords.length;

  _stuMap = L.map('stuMapContainer', {
    center: [avgLat, avgLng],
    zoom: 14,
    zoomControl: false,
    attributionControl: true
  });

  L.tileLayer('https://wprd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=2&style=7&x={x}&y={y}&z={z}', {
    subdomains: ['1','2','3','4'],
    attribution: '&copy; 高德地图',
    maxZoom: 19,
    tileSize: 256,
    zoomOffset: 0,
    detectRetina: true
  }).addTo(_stuMap);

  renderStuMapMarkers();
  updateMapStats();

  setTimeout(function(){
    if (_stuMap && Object.keys(_stuMarkers).length) {
      var group = L.featureGroup(Object.values(_stuMarkers));
      _stuMap.fitBounds(group.getBounds().pad(0.1));
    }
  }, 200);

  _stuMap.on('click', function(e){
    if (e.originalEvent && e.originalEvent._stuClick) return;
    closeStuDetail();
  });
}

function renderStuMapMarkers() {
  if (!_stuMap) return;
  var students = get('students');
  students.forEach(function(s) {
    if (!s.lng || !s.lat) return;
    var coord = getStuGcjCoord(s);
    var genderClass = s.gender === '女' ? 'female' : 'male';
    var icon = L.divIcon({
      className: '',
      html: '<div class="stu-marker ' + genderClass + '" data-id="' + s.id + '">' + s.name.charAt(0) + '</div>',
      iconSize: [22, 22],
      iconAnchor: [11, 11]
    });
    var marker = L.marker([coord[1], coord[0]], { icon: icon }).addTo(_stuMap);
    marker.on('click', function(e){
      L.DomEvent.stopPropagation(e);
      onStuMarkerClick(s);
    });
    _stuMarkers[s.id] = marker;
  });
}

function updateMapStats() {
  var students = get('students');
  var located = students.filter(function(s){ return s.lng && s.lat; });
  var areas = {};
  located.forEach(function(s){
    var area = s.address.replace(/\d+号楼.*$/, '').replace(/\d+栋.*$/, '').replace(/[A-Z]座.*$/, '').trim();
    areas[area] = true;
  });
  var lc = document.getElementById('mapLocatedCount');
  var ac = document.getElementById('mapAreaCount');
  if (lc) lc.textContent = located.length;
  if (ac) ac.textContent = Object.keys(areas).length;
}

function calculateDistance(lat1, lng1, lat2, lng2) {
  var R = 6371;
  var dLat = (lat2 - lat1) * Math.PI / 180;
  var dLng = (lng2 - lng1) * Math.PI / 180;
  var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
          Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
          Math.sin(dLng/2) * Math.sin(dLng/2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function formatDistance(km) {
  if (km < 1) return Math.round(km * 1000) + 'm';
  return km.toFixed(1) + 'km';
}

function onStuMarkerClick(student) {
  clearStuMapSelection();
  _selectedStuId = student.id;

  var selectedEl = document.querySelector('.stu-marker[data-id="' + student.id + '"]');
  if (selectedEl) selectedEl.classList.add('selected');

  // 高亮就近3位同学
  var students = get('students').filter(function(s){
    return s.id !== student.id && s.lng && s.lat;
  });
  var withDist = students.map(function(s){
    return { student: s, distance: calculateDistance(student.lat, student.lng, s.lat, s.lng) };
  }).sort(function(a,b){ return a.distance - b.distance; });
  var nearby = withDist.slice(0, 3);

  nearby.forEach(function(item){
    var el = document.querySelector('.stu-marker[data-id="' + item.student.id + '"]');
    if (el) { el.classList.add('nearby'); el.style.background = '#22c55e'; }
  });

  // 画连线
  var fromCoord = getStuGcjCoord(student);
  nearby.forEach(function(item){
    var toCoord = getStuGcjCoord(item.student);
    var line = L.polyline(
      [[fromCoord[1], fromCoord[0]], [toCoord[1], toCoord[0]]],
      { color: '#22c55e', weight: 2, opacity: 0.5, dashArray: '6,4' }
    ).addTo(_stuMap);
    _stuMapLines.push(line);
  });

  showStuDetailPanel(student, nearby);
}

function showStuDetailPanel(student, nearby) {
  var panel = document.getElementById('stuDetailPanel');
  var content = document.getElementById('stuDetailPanelContent');
  if (!panel || !content) return;

  var bgColor = student.gender === '女' ? '#ec4899' : '#3b82f6';

  var nearbyHtml = '';
  if (nearby && nearby.length) {
    nearbyHtml = '<div style="margin-top:8px;"><div style="font-size:11px;font-weight:600;color:#8e8e93;margin-bottom:4px;">住得近的同学</div>';
    nearby.forEach(function(item){
      var s = item.student;
      var nbg = s.gender === '女' ? '#ec4899' : '#3b82f6';
      nearbyHtml += '<div style="display:flex;align-items:center;gap:8px;padding:4px 0;border-bottom:0.5px solid #f2f2f7;cursor:pointer;" onclick="closeStuDetail();setTimeout(function(){var m=_stuMarkers[' + s.id + '];if(m)m.fireEvent(\'click\');},100);">' +
        '<div style="width:28px;height:28px;border-radius:50%;background:' + nbg + ';color:#fff;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;flex-shrink:0;">' + s.name.charAt(0) + '</div>' +
        '<div style="flex:1;min-width:0;"><div style="font-size:12px;font-weight:600;color:#1c1c1e;line-height:1.2;">' + s.name + '</div><div style="font-size:10px;color:#8e8e93;margin-top:1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">' + s.address + '</div></div>' +
        '<div style="font-size:11px;font-weight:600;color:#D97757;background:#F5E6DE;padding:2px 7px;border-radius:6px;flex-shrink:0;">' + formatDistance(item.distance) + '</div>' +
        '</div>';
    });
    nearbyHtml += '</div>';
  }

  var dutyText = student.duty ? '<span style="display:inline-block;font-size:10px;background:#F5E6DE;color:#D97757;padding:1px 6px;border-radius:4px;font-weight:600;margin-left:4px;vertical-align:middle;">' + student.duty + '</span>' : '';
  var contactText = student.contact ? '<span style="font-size:11px;color:#8e8e93;margin-left:6px;">家长：' + student.contact + '</span>' : '';

  content.innerHTML =
    '<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">' +
      '<div style="width:36px;height:36px;border-radius:50%;background:' + bgColor + ';color:#fff;display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:700;flex-shrink:0;box-shadow:0 2px 6px rgba(0,0,0,0.12);">' + student.name.charAt(0) + '</div>' +
      '<div style="flex:1;min-width:0;">' +
        '<div style="font-size:15px;font-weight:700;color:#1c1c1e;line-height:1.2;">' + student.name + ' <span style="font-size:11px;color:#8e8e93;font-weight:400;">' + student.gender + '</span>' + dutyText + contactText + '</div>' +
      '</div>' +
    '</div>' +
    '<div style="background:#f9f9fb;border-radius:10px;padding:8px 10px;margin-bottom:6px;">' +
      '<div style="display:flex;align-items:center;gap:8px;">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#D97757" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>' +
        '<div style="flex:1;min-width:0;">' +
          '<span style="font-size:10px;color:#8e8e93;">家庭住址</span>' +
          '<span style="font-size:13px;color:#1c1c1e;font-weight:600;margin-left:6px;">' + student.address + '</span>' +
        '</div>' +
      '</div>' +
      (student.phone ? '<div style="display:flex;align-items:center;gap:8px;margin-top:6px;padding-top:6px;border-top:0.5px solid #e5e5ea;">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#D97757" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink:0;"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>' +
        '<div style="flex:1;min-width:0;">' +
          '<span style="font-size:10px;color:#8e8e93;">家长电话</span>' +
          '<span style="font-size:13px;color:#1c1c1e;font-weight:600;margin-left:6px;">' + student.phone + '</span>' +
        '</div>' +
      '</div>' : '') +
    '</div>' +
    '<div style="display:flex;gap:6px;margin-bottom:0;">' +
      '<button onclick="openMapNavSheet(' + student.id + ')" style="flex:1;padding:8px;border-radius:9px;border:none;background:#D97757;color:#fff;font-size:13px;font-weight:600;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:4px;">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"></polygon></svg>导航到他家' +
      '</button>' +
      (student.phone ? '<a href="tel:' + student.phone + '" style="padding:8px 14px;border-radius:9px;border:none;background:#f2f2f7;color:#3c3c43;font-size:13px;font-weight:600;cursor:pointer;text-decoration:none;display:flex;align-items:center;gap:4px;">' +
        '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg>打电话' +
      '</a>' : '') +
    '</div>' +
    nearbyHtml;

  panel.style.transform = 'translateY(0)';
  content.scrollTop = 0;
  _detailPanelOpen = true;
}

function toggleStuDetailPanel() {
  var panel = document.getElementById('stuDetailPanel');
  if (!panel) return;
  if (_detailPanelOpen) {
    panel.style.transform = 'translateY(calc(100% - 44px))';
    _detailPanelOpen = false;
  } else {
    panel.style.transform = 'translateY(0)';
    _detailPanelOpen = true;
  }
}

function closeStuDetail() {
  clearStuMapSelection();
  var panel = document.getElementById('stuDetailPanel');
  if (panel) panel.style.transform = 'translateY(calc(100% + 80px))';
  _detailPanelOpen = false;

}

function clearStuMapSelection() {
  document.querySelectorAll('.stu-marker.selected').forEach(function(el){ el.classList.remove('selected'); });
  document.querySelectorAll('.stu-marker.nearby').forEach(function(el){ 
    el.classList.remove('nearby'); 
    el.style.background = ''; 
  });
  _stuMapLines.forEach(function(line){ if (_stuMap) _stuMap.removeLayer(line); });
  _stuMapLines = [];
  _selectedStuId = null;
  if (_stuMap) _stuMap.closePopup();
}


/* ========== 班级相册 v2 - 模块化架构 ========== */
(function(){
  'use strict';

  // ===== 常量 =====
  var C = {
    LS_CATS: 'gal_categories',
    LS_PHOTOS: 'gal_photos',
    LS_INIT: 'gal_initialized',
    COVER_SIZE: 400,
    THUMB_SIZE: 300,
    MAX_IMG_SIZE: 1280,
    JPEG_QUALITY: 0.82,
    MONTHS: ['1月','2月','3月','4月','5月','6月','7月','8月','9月','10月','11月','12月']
  };

  // ===== IndexedDB 视频存储（避免localStorage 5MB限制）=====
  var IDB_DB = 'class_gallery_v1', IDB_STORE = 'videos', idb = null;
  function openIDB(cb){
    if(idb){ cb(idb); return; }
    try{
      var req = indexedDB.open(IDB_DB, 1);
      req.onupgradeneeded = function(e){
        var db = e.target.result;
        if(!db.objectStoreNames.contains(IDB_STORE)) db.createObjectStore(IDB_STORE);
      };
      req.onsuccess = function(e){ idb = e.target.result; cb(idb); };
      req.onerror = function(){ cb(null); };
    }catch(e){ cb(null); }
  }
  function idbPut(key, blob, cb){
    openIDB(function(db){
      if(!db){ cb(false); return; }
      try{
        var tx = db.transaction(IDB_STORE, 'readwrite');
        tx.objectStore(IDB_STORE).put(blob, key);
        tx.oncomplete = function(){ cb(true); };
        tx.onerror = function(){ cb(false); };
      }catch(e){ cb(false); }
    });
  }
  function idbGet(key, cb){
    openIDB(function(db){
      if(!db){ cb(null); return; }
      try{
        var tx = db.transaction(IDB_STORE, 'readonly');
        var req = tx.objectStore(IDB_STORE).get(key);
        req.onsuccess = function(){ cb(req.result || null); };
        req.onerror = function(){ cb(null); };
      }catch(e){ cb(null); }
    });
  }
  function idbDel(key, cb){
    openIDB(function(db){
      if(!db){ cb && cb(); return; }
      try{
        var tx = db.transaction(IDB_STORE, 'readwrite');
        tx.objectStore(IDB_STORE).delete(key);
        tx.oncomplete = function(){ cb && cb(); };
      }catch(e){ cb && cb(); }
    });
  }
  function getVideoUrl(p, cb){
    if(p.idbKey){
      idbGet(p.idbKey, function(blob){
        if(blob){ cb(URL.createObjectURL(blob)); }
        else if(p.dataUrl){ cb(p.dataUrl); }
        else { cb(''); }
      });
    } else if(p.dataUrl){ cb(p.dataUrl); }
    else { cb(''); }
  }

  // ===== 状态 =====
  var S = {
    curCatId: null,
    selectMode: false,
    selected: {},
    lightboxPhotos: [],
    lightboxIndex: 0,
    dateNavOpen: false,
    // 下拉放大
    pulling: false,
    pullStartY: 0,
    pullDelta: 0,
    pullRefreshThreshold: 70,
    pullRefreshing: false,
    pullBound: false,
    changingCover: false,
    editingPhotoId: null,
    lbScale: 1,
    lbTranslateX: 0,
    lbTranslateY: 0
  };

  // ===== 工具函数 =====
  function $(id){ return document.getElementById(id); }
  function uuid(){ return Date.now() + '_' + Math.random().toString(36).slice(2,8); }
  function toast(msg, dur){
    var t = $('galToast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(t._timer);
    t._timer = setTimeout(function(){ t.classList.remove('show'); }, dur||1800);
  }
  function formatDate(d){
    var dt = new Date(d);
    return (dt.getMonth()+1) + '月' + dt.getDate() + '日';
  }
  function formatYearMonth(d){
    var dt = new Date(d);
    return dt.getFullYear() + '/' + (dt.getMonth()+1);
  }
  function dataUrlToBlob(dataUrl){
    var arr = dataUrl.split(',');
    var mime = arr[0].match(/:(.*?);/)[1];
    var bstr = atob(arr[1]);
    var n = bstr.length;
    var u8 = new Uint8Array(n);
    while(n--){ u8[n] = bstr.charCodeAt(n); }
    return new Blob([u8], {type:mime});
  }
  function downloadBlob(blob, filename){
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url; a.download = filename;
    document.body.appendChild(a); a.click();
    document.body.removeChild(a);
    setTimeout(function(){ URL.revokeObjectURL(url); }, 1000);
  }
  function compressImage(file, maxSize, quality, callback){
    var reader = new FileReader();
    reader.onload = function(e){
      var img = new Image();
      img.onload = function(){
        var w = img.width, h = img.height;
        var origW = w, origH = h;
        if(w > maxSize || h > maxSize){
          if(w > h){ h = Math.round(h * maxSize / w); w = maxSize; }
          else { w = Math.round(w * maxSize / h); h = maxSize; }
        }
        var canvas = document.createElement('canvas');
        canvas.width = w; canvas.height = h;
        var ctx = canvas.getContext('2d');
        // PNG保持透明，其他转JPEG
        var isPNG = file.type === 'image/png';
        if(!isPNG){ ctx.fillStyle = '#fff'; ctx.fillRect(0,0,w,h); }
        ctx.drawImage(img, 0, 0, w, h);
        var mime = isPNG ? 'image/png' : 'image/jpeg';
        var dataUrl = isPNG ? canvas.toDataURL(mime) : canvas.toDataURL(mime, quality);
        callback(dataUrl, origW, origH);
      };
      img.onerror = function(){ callback(null, 0, 0); };
      img.src = e.target.result;
    };
    reader.onerror = function(){ callback(null, 0, 0); };
    reader.readAsDataURL(file);
  }

  // ===== 数据层 =====
  var Data = {
    getCats: function(){
      try { return JSON.parse(localStorage.getItem(C.LS_CATS) || '[]'); }
      catch(e){ return []; }
    },
    saveCats: function(cats){ 
      try {
        localStorage.setItem(C.LS_CATS, JSON.stringify(cats)); 
        return true;
      } catch(e) {
        toast('存储空间不足，封面保存失败');
        return false;
      }
    },
    getPhotos: function(){
      try {
        var photos = JSON.parse(localStorage.getItem(C.LS_PHOTOS) || '[]');
        photos.forEach(function(p){
          if(!p.createdAt) p.createdAt = p.date || '';
          // 补充时间部分（精确到分钟）
          if(p.createdAt && p.createdAt.split(' ').length === 1){
            var h = 8 + (p.id % 12);
            var m = (p.id * 7) % 60;
            p.createdAt += ' ' + (h<10?'0':'') + h + ':' + (m<10?'0':'') + m;
          }
          if(!p.width) p.width = 400;
          if(!p.height) p.height = 400;
        });
        return photos;
      }
      catch(e){ return []; }
    },
    savePhotos: function(photos){ 
      try {
        localStorage.setItem(C.LS_PHOTOS, JSON.stringify(photos)); 
        return true;
      } catch(e) {
        toast('存储空间不足，请删除一些照片后重试');
        return false;
      }
    },
    getCatById: function(id){ return this.getCats().find(function(c){ return c.id === id; }); },
    getPhotosByCat: function(catId){
      return this.getPhotos().filter(function(p){ return p.categoryId === catId; });
    },
    // 数据修复：清理旧版本中缩略图存了完整视频的异常数据
    repairData: function(){
      var photos = this.getPhotos();
      var changed = false;
      var DEFAULT_THUMB = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300"><rect width="300" height="300" fill="#e5e5ea"/><circle cx="150" cy="150" r="50" fill="rgba(0,0,0,0.3)"/><polygon points="135,125 135,175 175,150" fill="#fff"/></svg>')));
      photos.forEach(function(p){
        if(p.type === 'video' && p.thumbnail && p.thumbnail.indexOf('data:video') === 0){
          p.thumbnail = DEFAULT_THUMB;
          changed = true;
        }
      });
      if(changed){
        this.savePhotos(photos);
      }
      return changed;
    },

    // 模拟数据初始化：3年，每年3个月
    initMock: function(){
      var hasInit = localStorage.getItem(C.LS_INIT);
      var hasCats = (JSON.parse(localStorage.getItem(C.LS_CATS) || '[]')).length > 0;
      var hasPhotos = (JSON.parse(localStorage.getItem(C.LS_PHOTOS) || '[]')).length > 0;
      if(hasInit && hasCats && hasPhotos) return;
      if(hasInit && (!hasCats || !hasPhotos)) {
        localStorage.removeItem(C.LS_INIT);
      }
      var colors = [
        ['#FF6B6B','#FFE66D'], ['#4ECDC4','#44A08D'], ['#667eea','#764ba2'],
        ['#f093fb','#f5576c'], ['#4facfe','#00f2fe'], ['#43e97b','#38f9d7'],
        ['#fa709a','#fee140'], ['#30cfd0','#330867'], ['#a8edea','#fed6e3']
      ];
      var labels = ['开学第一课','运动会','春游','秋游','毕业典礼','元旦晚会','军训','研学旅行','百日誓师','期中考试','期末考试','家长会'];
      var cats = [
        {id:1, name:'班级活动', cover:null, description:'记录班级精彩瞬间', isTop:true, createdAt:'2024/3/1'},
        {id:2, name:'学习日常', cover:null, description:'课堂与作业', isTop:false, createdAt:'2024/3/1'},
        {id:3, name:'荣誉墙', cover:null, description:'班级荣誉', isTop:false, createdAt:'2024/6/1'}
      ];
      var photos = [];
      var pid = 1;
      // 3年：2024, 2025, 2026；每年3个月：3月、6月、9月
      var years = [2024, 2025, 2026];
      var months = [2, 5, 8]; // 3月、6月、9月（0-based）
      years.forEach(function(year, yi){
        months.forEach(function(month, mi){
          var day = 5 + Math.floor(Math.random()*20);
          var dateStr = year + '/' + (month+1) + '/' + day;
          var catId = cats[(yi*3+mi) % 3].id;
          var count = 5 + Math.floor(Math.random()*4); // 5-8张
          for(var i=0; i<count; i++){
            var ci = (yi*9 + mi*3 + i) % colors.length;
            var li = (yi*9 + mi*3 + i) % labels.length;
            var c1 = colors[ci][0], c2 = colors[ci][1];
            var hour = 8 + Math.floor(Math.random()*12); // 8-19点
            var minute = Math.floor(Math.random()*60);
            var timeStr = (hour<10?'0':'') + hour + ':' + (minute<10?'0':'') + minute;
            var fullDate = dateStr + ' ' + timeStr;
            var w = 1200 + Math.floor(Math.random()*1200); // 1200-2400
            var h = 1600 + Math.floor(Math.random()*1200); // 1600-2800
            var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400"><defs><linearGradient id="g'+pid+'" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:'+c1+'"/><stop offset="100%" style="stop-color:'+c2+'"/></linearGradient></defs><rect width="400" height="400" fill="url(#g'+pid+')"/><text x="200" y="190" text-anchor="middle" fill="rgba(255,255,255,0.9)" font-size="28" font-weight="bold" font-family="sans-serif">'+labels[li]+'</text><text x="200" y="230" text-anchor="middle" fill="rgba(255,255,255,0.7)" font-size="16" font-family="sans-serif">'+dateStr+'</text></svg>';
            var dataUrl = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svg)));
            photos.push({
              id: pid,
              dataUrl: dataUrl,
              thumbnail: dataUrl,
              type: 'image',
              duration: '',
              caption: labels[li],
              date: dateStr,
              createdAt: fullDate,
              width: w,
              height: h,
              categoryId: catId
            });
            pid++;
          }
        });
      });
      // 设置封面
      cats.forEach(function(cat){
        var catPhotos = photos.filter(function(p){ return p.categoryId === cat.id; });
        if(catPhotos.length > 0) cat.cover = catPhotos[catPhotos.length-1].id;
      });
      this.saveCats(cats);
      this.savePhotos(photos);
      localStorage.setItem(C.LS_INIT, '1');
    }
  };

  // ===== 视图层 =====
  var View = {
    renderHome: function(){
      var cats = Data.getCats();
      var photos = Data.getPhotos();
      var totalImg = photos.filter(function(p){ return p.type==='image'; }).length;
      var totalVid = photos.filter(function(p){ return p.type==='video'; }).length;
      $('galHomeSummary').textContent = cats.length + '相册 ' + totalImg + '图片' + (totalVid?' '+totalVid+'视频':'');

      var grid = $('galCategoryGrid');
      var html = '';
      // 新建相册卡片（第一个）
      html += '<div class="gal-category-card new" onclick="galShowNewCategory()">'
        + '<div class="gal-new-text"><div class="gal-new-icon"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="13" height="13" rx="2.5" opacity="0.5"/><rect x="6" y="6" width="13" height="13" rx="2.5"/></svg></div>新建相册</div></div>';
      // 置顶的排前面
      var sorted = cats.slice().sort(function(a,b){ return (b.isTop?1:0) - (a.isTop?1:0); });
      sorted.forEach(function(cat){
        var catPhotos = Data.getPhotosByCat(cat.id);
        var coverSrc = null;
        if(cat.cover){
          if(typeof cat.cover === 'string' && cat.cover.indexOf('data:') === 0){
            coverSrc = cat.cover;
          } else {
            var cp = photos.find(function(p){ return p.id === cat.cover; });
            if(cp) coverSrc = cp.dataUrl;
          }
        }
        if(!coverSrc && catPhotos.length) coverSrc = catPhotos[catPhotos.length-1].dataUrl;
        var coverHtml = coverSrc
          ? '<img src="'+coverSrc+'" alt="">'
          : '<div class="gal-category-cover-placeholder">📷</div>';
        var topBadge = cat.isTop ? '<div class="gal-category-top-badge">顶</div>' : '';
        var countBadge = catPhotos.length ? '<div class="gal-category-cover-count">'+catPhotos.length+'张</div>' : '';
        html += '<div class="gal-category-card" onclick="galOpenCategory('+cat.id+')">'
          + '<div class="gal-category-cover">'+coverHtml+topBadge+countBadge+'</div>'
          + '<div class="gal-category-name">'+cat.name+'</div></div>';
      });
      grid.innerHTML = html;
    },

    renderDetail: function(catId){
      var cat = Data.getCatById(catId);
      if(!cat){ galBackToHome(); return; }
      var photos = Data.getPhotosByCat(catId);

      // 封面
      var coverEl = $('galCover');
      var coverSrc = null;
      if(cat.cover){
        if(typeof cat.cover === 'string' && cat.cover.indexOf('data:') === 0){
          coverSrc = cat.cover;
        } else {
          var cp = Data.getPhotos().find(function(p){ return p.id === cat.cover; });
          if(cp) coverSrc = cp.dataUrl;
        }
      }
      if(!coverSrc && photos.length) coverSrc = photos[photos.length-1].dataUrl;
      coverEl.innerHTML = '';
      if(coverSrc){
        var img = document.createElement('img');
        img.src = coverSrc;
        coverEl.appendChild(img);
      } else {
        var ph = document.createElement('div');
        ph.className = 'gal-cover-placeholder';
        ph.textContent = '📷';
        coverEl.appendChild(ph);
      }
      var overlay = document.createElement('div');
      overlay.className = 'gal-cover-overlay';
      coverEl.appendChild(overlay);

      // 信息栏
      $('galInfoName').textContent = cat.name;
      $('galInfoCount').textContent = photos.length + '张';
      $('galStickyTitle').textContent = cat.name;

      // 照片网格（按日期分组）
      var container = $('galPhotosContainer');
      if(photos.length === 0){
        container.innerHTML = '<div class="gal-empty-state"><div class="gal-empty-icon">📷</div><div class="gal-empty-text">这个相册还没有照片</div><div class="gal-empty-sub">点击右下角 + 号上传</div></div>';
        this.renderDateNav([]);
        return;
      }
      var groups = {};
      photos.forEach(function(p){
        var ym = formatYearMonth(p.date);
        if(!groups[ym]) groups[ym] = [];
        groups[ym].push(p);
      });
      var html = '';
      var sortedKeys = Object.keys(groups).sort(function(a,b){
        var da = new Date(a + '/1'), db = new Date(b + '/1');
        return db.getTime() - da.getTime();
      });
      sortedKeys.forEach(function(ym){
        var dt = new Date(ym + '/1');
        var groupPhotos = groups[ym];
        var days = groupPhotos.map(function(p){
          var parts = (p.date||'').split('/');
          return parts.length === 3 ? parseInt(parts[2]) : 0;
        }).filter(function(d){ return d > 0; }).sort(function(a,b){ return a-b; });
        var label;
        if(days.length > 0){
          var year = dt.getFullYear();
          var month = ('0'+(dt.getMonth()+1)).slice(-2);
          if(days[0] === days[days.length-1]){
            label = year + '年' + month + '月' + ('0'+days[0]).slice(-2) + '日';
          } else {
            label = year + '年' + month + '月' + ('0'+days[0]).slice(-2) + '日 - ' + ('0'+days[days.length-1]).slice(-2) + '日';
          }
        } else {
          label = dt.getFullYear() + '年' + (dt.getMonth()+1) + '月';
        }
        html += '<div class="gal-date-group" data-ym="'+ym+'">';
        html += '<div class="gal-date-header">'+label+'</div>';
        html += '<div class="gal-photo-grid">';
        groups[ym].forEach(function(p){
          var media = '<img src="'+(p.thumbnail||p.dataUrl)+'" alt="" loading="lazy">';
          var videoBadge = p.type==='video' ? '<div class="gal-video-badge">'+(p.duration||'')+'</div>' : '';
          var selectCircle = S.selectMode ? '<div class="gal-photo-select-circle'+(S.selected[p.id]?' selected':'')+'"></div>' : '';
          html += '<div class="gal-photo-item'+(S.selectMode?' select-mode':'')+'" onclick="'+(S.selectMode?'galToggleSelect('+p.id+')':'galOpenLightbox('+p.id+')')+'">'
            + media + videoBadge + selectCircle + '</div>';
        });
        html += '</div></div>';
      });
      container.innerHTML = html;
      this.renderDateNav(groups);
      // 重新渲染后更新吸顶日期，避免和正常日期标题重叠
      if(typeof Ctrl !== 'undefined' && Ctrl.updateStickyDate) Ctrl.updateStickyDate();
    },

    renderDateNav: function(groups){
      var list = $('galDateNavList');
      var keys = Object.keys(groups).sort(function(a,b){
        var da = new Date(a + '/1'), db = new Date(b + '/1');
        return db.getTime() - da.getTime();
      });
      if(keys.length === 0){ list.innerHTML = '<div style="padding:20px;text-align:center;color:#c7c7cc;font-size:14px;">暂无日期分组</div>'; return; }
      var html = '';
      var curYear = '';
      keys.forEach(function(ym){
        var dt = new Date(ym + '/1');
        var year = dt.getFullYear();
        if(year !== curYear){
          if(curYear) html += '</div>';
          curYear = year;
          html += '<div class="gal-date-year">'+year+'年</div>';
        }
        var count = groups[ym] ? groups[ym].length : 0;
        html += '<div class="gal-date-month" onclick="galScrollToDate(\''+ym+'\')">'+(dt.getMonth()+1)+'月<span class="gal-date-month-count">'+count+'张</span></div>';
      });
      if(curYear) html += '</div>';
      list.innerHTML = html;
    },

    updateSelectUI: function(){
      var count = Object.keys(S.selected).length;
      $('galSelectTitle').textContent = count > 0 ? '已选 '+count+' 张' : '选择照片';
      var has = count > 0;
      $('galDownloadBtn').disabled = !has;
      $('galMoveBtn').disabled = !has;
      $('galDeleteBtn').disabled = !has;
      // 选中状态通过 renderDetail 重新渲染更新
    },

    renderMoveList: function(){
      var cats = Data.getCats();
      var list = $('galMoveList');
      var html = '';
      cats.forEach(function(cat){
        if(cat.id === S.curCatId) return;
        var count = Data.getPhotosByCat(cat.id).length;
        html += '<div class="gal-list-item" onclick="galDoMove('+cat.id+')">'
          + '<span class="gal-list-label">'+cat.name+'</span>'
          + '<span class="gal-list-value">'+count+'张 <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg></span>'
          + '</div>';
      });
      if(!html) html = '<div style="padding:40px;text-align:center;color:#c7c7cc;font-size:14px;">没有其他相册</div>';
      list.innerHTML = html;
    },

    renderLightbox: function(){
      var body = $('galLightboxBody');
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p) return;
      var lbDateStr = p.createdAt || p.date || '';
      if(lbDateStr){
        var lbParts = lbDateStr.split(' ');
        $('galLightboxDate').textContent = lbParts[0] || lbDateStr;
      } else {
        $('galLightboxDate').textContent = '';
      }
      var capEl = $('galLightboxCaption');
      if(capEl){ capEl.textContent = p.caption || ''; capEl.setAttribute('data-photo-id', p.id); }
      var cat = Data.getCatById(S.curCatId);
      var albumName = cat ? cat.name : '班级相册';
      $('galLightboxAlbum').textContent = albumName + '(' + (S.lightboxIndex+1) + '/' + S.lightboxPhotos.length + ')';
      if(p.type === 'video'){
        body.innerHTML = '<div class="gal-lightbox-slide"><div style="color:#8e8e93;text-align:center;padding:40px;">加载中...</div></div>';
        getVideoUrl(p, function(url){
          body.innerHTML = '<div class="gal-lightbox-slide"><video src="'+url+'" controls autoplay playsinline preload="auto" style="max-width:100%;max-height:100%;"></video></div>';
          setTimeout(function(){
            var v = body.querySelector('video');
            if(v){ var pr = v.play(); if(pr && pr.catch) pr.catch(function(){}); }
          }, 100);
        });
      } else {
        body.innerHTML = '<div class="gal-lightbox-slide"><div class="gal-lightbox-zoom" id="galLightboxZoom"><img src="'+p.dataUrl+'" alt=""></div></div>';
      }
      // 重置缩放状态
      S.lbScale = 1; S.lbTranslateX = 0; S.lbTranslateY = 0;
      var zoomEl = $('galLightboxZoom');
      if(zoomEl) zoomEl.style.transform = 'scale(1) translate(0,0)';
    }
  };

  // ===== 控制器 =====
  var Ctrl = {
    // 导航
    openAlbum: function(){
      if(typeof navigateTo === 'function') navigateTo('page-album');
      Data.initMock();
      S.curCatId = null;
      S.selectMode = false;
      S.selected = {};
      S.dateNavOpen = false;
      $('galHome').style.display = 'flex';
      $('galDetail').style.display = 'none';
      $('galFab').style.display = 'flex';
      $('galSelectBar').style.display = 'none';
      $('galSelectActions').style.display = 'none';
      View.renderHome();
    },
    openCategory: function(catId){
      S.curCatId = catId;
      S.selectMode = false;
      S.selected = {};
      $('galHome').style.display = 'none';
      $('galDetail').style.display = 'flex';
      $('galPhotosWrapper').scrollTop = 0;
      View.renderDetail(catId);
      this.updateNavOnScroll();
      // 绑定下拉触摸事件到外层容器（只一次），分离下拉和滚动
      if(!S.pullBound){
        S.pullBound = true;
        var pw = $('galPullWrapper');
        pw.addEventListener('touchstart', this.onPullStart.bind(this), {passive:false});
        pw.addEventListener('touchmove', this.onPullMove.bind(this), {passive:false});
        pw.addEventListener('touchend', this.onPullEnd.bind(this), {passive:false});
        pw.addEventListener('touchcancel', this.onPullEnd.bind(this), {passive:false});
      }
    },
    backToHome: function(){
      if(S.selectMode){ this.toggleSelectMode(); return; }
      if(S.dateNavOpen){ this.toggleDateNav(); return; }
      $('galHome').style.display = 'flex';
      $('galDetail').style.display = 'none';
      View.renderHome();
    },

    // 滚动交互
    onScroll: function(){
      this.updateNavOnScroll();
      this.updateStickyDate();
    },
    updateNavOnScroll: function(){
      var wrapper = $('galPhotosWrapper');
      var coverNav = $('galCoverNav');
      var stickyNav = $('galStickyNav');
      var container = $('galPhotosContainer');
      if(!wrapper || !coverNav || !stickyNav) return;
      var scrollTop = wrapper.scrollTop;
      // 白色卡片顶部滑到导航栏位置时切换
      var switchPoint = container ? Math.max(container.offsetTop - 60, 0) : 40;
      if(scrollTop >= switchPoint){
        coverNav.style.opacity = '0';
        coverNav.style.pointerEvents = 'none';
        stickyNav.classList.add('show');
      } else {
        coverNav.style.opacity = '1';
        coverNav.style.pointerEvents = 'auto';
        stickyNav.classList.remove('show');
      }
    },
    updateStickyDate: function(){
      var wrapper = $('galPhotosWrapper');
      var stickyEl = $('galStickyDate');
      var stickyNav = $('galStickyNav');
      if(!wrapper || !stickyEl) return;
      var dates = wrapper.querySelectorAll('.gal-date-header');
      if(dates.length === 0){ stickyEl.style.display = 'none'; return; }
      // 用粘性导航栏底部作为吸顶位置，无缝贴合
      var stickyTop;
      var selectBar = $('galSelectBar');
      // 选择模式下用选择栏底部，普通模式下用粘性导航栏底部或固定值
      if(selectBar && selectBar.style.display !== 'none'){
        stickyTop = selectBar.getBoundingClientRect().bottom;
        // 动态设置吸顶元素top，紧贴选择栏底部
        stickyEl.style.top = stickyTop + 'px';
      } else if(stickyNav && stickyNav.classList.contains('show')){
        stickyTop = stickyNav.getBoundingClientRect().bottom;
        stickyEl.style.top = ''; // 恢复CSS默认值
      } else {
        var wrapperRect = wrapper.getBoundingClientRect();
        stickyTop = wrapperRect.top + stickyEl.offsetTop;
        stickyEl.style.top = '';
      }
      // 找到当前应该吸顶的日期标题（最后一个顶部<=stickyTop的）
      var currentIndex = -1;
      for(var i = 0; i < dates.length; i++){
        if(dates[i].getBoundingClientRect().top <= stickyTop) currentIndex = i;
        else break;
      }
      if(currentIndex < 0){ stickyEl.style.display = 'none'; return; }
      var current = dates[currentIndex];
      var next = dates[currentIndex + 1] || null;
      stickyEl.textContent = current.textContent;
      stickyEl.style.display = 'block';
      // 计算推挤偏移量：当前日期底部紧贴下一个日期顶部
      var currentHeight = current.getBoundingClientRect().height;
      var pushOffset = 0;
      if(next){
        var nextTop = next.getBoundingClientRect().top;
        var gap = nextTop - (stickyTop + currentHeight);
        if(gap < 0) pushOffset = gap;
      }
      stickyEl.style.transform = 'translateY(' + pushOffset + 'px)';
    },
    scrollToDate: function(ym){
      var group = document.querySelector('.gal-date-group[data-ym="'+ym+'"]');
      if(group){
        var wrapper = $('galPhotosWrapper');
        wrapper.scrollTo({ top: group.offsetTop - 10, behavior: 'smooth' });
      }
      this.toggleDateNav();
    },

    // ===== 下拉放大 & 刷新 =====
    onPullStart: function(e){
      if(S.pullRefreshing || S.selectMode) return;
      var wrapper = $('galPhotosWrapper');
      if(wrapper.scrollTop > 0) return; // 不在顶部不触发
      S.pulling = true;
      S.pullStartY = e.touches[0].clientY;
      S.pullDelta = 0;
      $('galDetail').classList.add('gal-pulling');
    },
    onPullMove: function(e){
      if(!S.pulling || S.pullRefreshing) return;
      var deltaY = e.touches[0].clientY - S.pullStartY;
      if(deltaY <= 0){
        // 向上滑，取消下拉
        S.pulling = false;
        $('galDetail').classList.remove('gal-pulling');
        this.applyPull(0);
        return;
      }
      e.preventDefault();
      // 阻尼：越拉越费劲（0.5基础阻尼 + 渐进阻尼）
      S.pullDelta = deltaY * (1 - deltaY / (deltaY + 250));
      this.applyPull(S.pullDelta);
    },
    onPullEnd: function(){
      if(!S.pulling || S.pullRefreshing) return;
      S.pulling = false;
      $('galDetail').classList.remove('gal-pulling');
      if(S.pullDelta >= S.pullRefreshThreshold){
        this.triggerPullRefresh();
      } else {
        this.resetPull();
      }
    },
    applyPull: function(delta){
      var cover = $('galCover');
      var coverImg = cover ? cover.querySelector('img') : null;
      var infoBar = document.querySelector('.gal-info-bar');
      var container = $('galPhotosContainer');
      var indicator = $('galPullIndicator');
      // 封面高度增大
      if(cover) cover.style.height = 'calc(30vh + ' + delta + 'px)';
      // 封面图放大：下拉500px放大到2倍
      if(coverImg){
        var scale = 1 + delta / 500;
        coverImg.style.transform = 'scale(' + scale + ')';
      }
      // 信息栏下移
      if(infoBar) infoBar.style.transform = 'translateY(' + delta + 'px)';
      // 白色卡片下移
      if(container) container.style.marginTop = 'calc(27.5vh + ' + delta + 'px)';
      // 刷新提示（纯圆圈）
      if(indicator){
        indicator.classList.toggle('show', delta > 8);
      }
    },
    resetPull: function(){
      this.applyPull(0);
      S.pullDelta = 0;
    },
    triggerPullRefresh: function(){
      S.pullRefreshing = true;
      var circle = $('galPullCircle');
      if(circle) circle.classList.add('spinning');
      // 保持在刷新位置
      var self = this;
      var refreshDelta = S.pullRefreshThreshold;
      setTimeout(function(){ self.applyPull(refreshDelta); }, 10);
      // 模拟刷新
      setTimeout(function(){
        S.pullRefreshing = false;
        if(circle) circle.classList.remove('spinning');
        var indicator = $('galPullIndicator');
        if(indicator) indicator.classList.remove('show');
        self.resetPull();
        View.renderDetail(S.curCatId);
        var wrapper = $('galPhotosWrapper');
        if(wrapper) wrapper.scrollTop = 0;
        toast('已刷新');
      }, 1200);
    },

    // 选择模式
    toggleSelectMode: function(){
      S.selectMode = !S.selectMode;
      S.selected = {};
      $('galSelectBar').style.display = S.selectMode ? 'flex' : 'none';
      $('galSelectActions').style.display = S.selectMode ? 'flex' : 'none';
      $('galFab').style.display = S.selectMode ? 'none' : 'flex';
      var coverNav = $('galCoverNav');
      var stickyNav = $('galStickyNav');
      if(coverNav) coverNav.style.display = S.selectMode ? 'none' : 'flex';
      if(stickyNav) stickyNav.style.display = S.selectMode ? 'none' : '';
      View.renderDetail(S.curCatId);
      View.updateSelectUI();
    },
    toggleSelect: function(id){
      if(S.selected[id]) delete S.selected[id];
      else S.selected[id] = true;
      View.renderDetail(S.curCatId);
      View.updateSelectUI();
    },
    selectAll: function(){
      var photos = Data.getPhotosByCat(S.curCatId);
      var allSelected = photos.every(function(p){ return S.selected[p.id]; });
      if(allSelected){
        S.selected = {};
      } else {
        photos.forEach(function(p){ S.selected[p.id] = true; });
      }
      View.renderDetail(S.curCatId);
      View.updateSelectUI();
    },

    // 删除
    deleteSelected: function(){
      var ids = Object.keys(S.selected);
      if(ids.length === 0) return;
      if(!confirm('确定删除选中的 '+ids.length+' 张照片？')) return;
      var photos = Data.getPhotos();
      // 收集被删照片的id和dataUrl，用于清理封面
      var deletedIds = {};
      var deletedUrls = {};
      var deletedVideoKeys = [];
      photos.forEach(function(p){
        if(S.selected[p.id]){
          deletedIds[p.id] = true;
          deletedUrls[p.dataUrl] = true;
          if(p.type === 'video' && p.idbKey) deletedVideoKeys.push(p.idbKey);
        }
      });
      photos = photos.filter(function(p){ return !S.selected[p.id]; });
      var ok = Data.savePhotos(photos);
      if(!ok){ toast('删除失败：存储空间不足'); return; }
      // 从IndexedDB删除被删视频
      deletedVideoKeys.forEach(function(k){ idbDel(k); });
      // 清理封面引用
      var cats = Data.getCats();
      var coverChanged = false;
      cats.forEach(function(c){
        if(c.cover && (deletedIds[c.cover] || deletedUrls[c.cover])){
          c.cover = null;
          coverChanged = true;
        }
      });
      if(coverChanged) Data.saveCats(cats);
      S.selected = {};
      toast('已删除 '+ids.length+' 张照片');
      View.renderDetail(S.curCatId);
      View.updateSelectUI();
    },

    // 下载
    downloadSelected: function(){
      var ids = Object.keys(S.selected);
      if(ids.length === 0) return;
      var photos = Data.getPhotos();
      var selected = photos.filter(function(p){ return S.selected[p.id]; });
      toast('开始下载 '+selected.length+' 张照片...');
      selected.forEach(function(p, i){
        setTimeout(function(){
          var blob = dataUrlToBlob(p.dataUrl);
          var ext = '.jpg';
          if(p.type === 'video') ext = '.mp4';
          else if(p.dataUrl.indexOf('image/svg+xml') >= 0) ext = '.svg';
          else if(p.dataUrl.indexOf('image/gif') >= 0) ext = '.gif';
          else if(p.dataUrl.indexOf('image/png') >= 0) ext = '.png';
          var name = 'photo_' + p.id + '_' + (p.date||'').replace(/\//g,'') + ext;
          downloadBlob(blob, name);
        }, i * 300);
      });
    },

    // 移动
    showMoveModal: function(){
      if(Object.keys(S.selected).length === 0) return;
      View.renderMoveList();
      $('galMoveMask').classList.add('show');
    },
    doMove: function(targetCatId){
      var ids = Object.keys(S.selected);
      if(ids.length === 0) return;
      var photos = Data.getPhotos();
      photos.forEach(function(p){
        if(S.selected[p.id]) p.categoryId = targetCatId;
      });
      var ok = Data.savePhotos(photos);
      if(!ok){ toast('移动失败：存储空间不足'); return; }
      var targetCat = Data.getCatById(targetCatId);
      toast('已移动 '+ids.length+' 张到「'+(targetCat?targetCat.name:'')+'」');
      this.closeModal('galMoveMask');
      S.selected = {};
      this.toggleSelectMode();
      // 同步刷新首页计数
      View.renderHome();
    },

    // 上传 - 直接调用系统文件选择器，不弹自定义菜单
    showUploadMenu: function(){
      if($('galDetail').style.display !== 'none' && S.curCatId){
        $('galFileInput').click();
      } else {
        this.showNewCategory();
      }
    },
    // triggerUpload 已废弃：showUploadMenu 直接调用系统选择器
    handleUpload: function(event, type){
      var files = event.target.files;
      if(!files || files.length === 0) return;
      // 更换封面
      if(S.changingCover){
        S.changingCover = false;
        var file = files[0];
        var reader = new FileReader();
        reader.onload = function(e){
          var cats = Data.getCats();
          var cat = cats.find(function(c){ return c.id === S.curCatId; });
          if(cat){
            cat.cover = e.target.result;
            Data.saveCats(cats);
            var thumb = $('galEditCoverThumb');
            if(thumb) thumb.src = e.target.result;
            toast('封面已更换');
          }
        };
        reader.readAsDataURL(file);
        event.target.value = '';
        return;
      }
      if(!S.curCatId){ toast('请先选择相册'); return; }
      // 上传前大小检测
      var MAX_IMG_BYTES = 15 * 1024 * 1024; // 15MB
      var MAX_VID_BYTES = 8 * 1024 * 1024;  // 8MB（base64膨胀后约10MB+）
      var oversized = [];
      for(var ci=0; ci<files.length; ci++){
        var f = files[ci];
        var limit = f.type.startsWith('video/') ? MAX_VID_BYTES : MAX_IMG_BYTES;
        if(f.size > limit){
          var mb = (f.size / 1024 / 1024).toFixed(1);
          oversized.push(f.name + '(' + mb + 'MB)');
        }
      }
      if(oversized.length > 0){
        toast('文件过大无法保存：' + oversized[0] + (oversized.length>1?'等'+oversized.length+'个':'') + '，请压缩后重试', 3000);
        event.target.value = '';
        return;
      }
      var photos = Data.getPhotos();
      var nextId = photos.length ? Math.max.apply(null, photos.map(function(p){return p.id;})) + 1 : 1;
      var added = 0;
      var total = files.length;
      var now = new Date();
      var uploadTime = now.getFullYear() + '/' + (now.getMonth()+1) + '/' + now.getDate() + ' ' + (now.getHours()<10?'0':'') + now.getHours() + ':' + (now.getMinutes()<10?'0':'') + now.getMinutes();
      toast('正在处理 '+total+' 个文件...');

      for(var i=0; i<files.length; i++){
        (function(file, idx){
          if(file.type.startsWith('video/')){
            var videoId = nextId + idx;
            var DEFAULT_VIDEO_THUMB = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300"><rect width="300" height="300" fill="#e5e5ea"/><circle cx="150" cy="150" r="50" fill="rgba(0,0,0,0.3)"/><polygon points="135,125 135,175 175,150" fill="#fff"/></svg>')));
            idbPut(videoId, file, function(idbOk){
              var video = document.createElement('video');
              video.preload = 'auto';
              video.muted = true;
              video.playsInline = true;
              var thumbReady = false;
              var durStr = '', vw = 1280, vh = 720;
              var objUrl = URL.createObjectURL(file);
              function pushVideo(thumbUrl){
                if(thumbReady) return;
                thumbReady = true;
                photos.push({
                  id: videoId,
                  dataUrl: idbOk ? '' : objUrl,
                  idbKey: idbOk ? videoId : null,
                  thumbnail: thumbUrl || DEFAULT_VIDEO_THUMB,
                  type: 'video',
                  duration: durStr || '',
                  caption: '',
                  date: uploadTime,
                  createdAt: uploadTime,
                  width: vw || 1280,
                  height: vh || 720,
                  categoryId: S.curCatId
                });
                added++;
                if(added === total) finishUpload();
                try{ video.pause(); video.src=''; video.load(); }catch(e){}
              }
              function tryCaptureFrame(){
                if(thumbReady) return;
                try{
                  var canvas = document.createElement('canvas');
                  var vw2 = video.videoWidth || 1280;
                  var vh2 = video.videoHeight || 720;
                  var thumbW = 300, thumbH = Math.round(thumbW * vh2 / vw2);
                  canvas.width = thumbW; canvas.height = thumbH;
                  var ctx = canvas.getContext('2d');
                  ctx.drawImage(video, 0, 0, thumbW, thumbH);
                  var thumbUrl = canvas.toDataURL('image/jpeg', 0.7);
                  if(thumbUrl && thumbUrl.length > 1000) pushVideo(thumbUrl);
                  else pushVideo(DEFAULT_VIDEO_THUMB);
                }catch(e){ pushVideo(DEFAULT_VIDEO_THUMB); }
              }
              video.onloadedmetadata = function(){
                var dur = video.duration;
                if(isFinite(dur)){
                  var mins = Math.floor(dur / 60);
                  var secs = Math.floor(dur % 60);
                  durStr = mins + ':' + (secs < 10 ? '0' : '') + secs;
                }
                vw = video.videoWidth || 1280;
                vh = video.videoHeight || 720;
                try{ video.currentTime = 0.1; }catch(e){}
              };
              video.onseeked = function(){ requestAnimationFrame(function(){ tryCaptureFrame(); }); };
              video.onloadeddata = function(){ if(!thumbReady){ try{ video.currentTime = 0.1; }catch(e){ tryCaptureFrame(); } } };
              video.onerror = function(){ pushVideo(DEFAULT_VIDEO_THUMB); };
              setTimeout(function(){ pushVideo(DEFAULT_VIDEO_THUMB); }, 5000);
              video.src = objUrl;
              try{ video.load(); }catch(e){}
            });
          } else if(file.type === 'image/gif'){
            // GIF保持原格式，不压缩（避免丢失动画）
            var gifReader = new FileReader();
            gifReader.onload = function(e){
              photos.push({
                id: nextId + idx,
                dataUrl: e.target.result,
                thumbnail: e.target.result,
                type: 'image',
                duration: '',
                caption: '',
                date: uploadTime,
                createdAt: uploadTime,
                width: 400,
                height: 400,
                categoryId: S.curCatId
              });
              added++;
              if(added === total) finishUpload();
            };
            gifReader.onerror = function(){ added++; if(added === total) finishUpload(); };
            gifReader.readAsDataURL(file);
          } else {
            compressImage(file, C.MAX_IMG_SIZE, C.JPEG_QUALITY, function(dataUrl, origW, origH){
              if(!dataUrl){ added++; if(added === total) finishUpload(); return; }
              compressImage(file, C.THUMB_SIZE, 0.7, function(thumb){
                photos.push({
                  id: nextId + idx,
                  dataUrl: dataUrl,
                  thumbnail: thumb || dataUrl,
                  type: 'image',
                  duration: '',
                  caption: '',
                  date: uploadTime,
                  createdAt: uploadTime,
                  width: origW,
                  height: origH,
                  categoryId: S.curCatId
                });
                added++;
                if(added === total) finishUpload();
              });
            });
          }
        })(files[i], i);
      }
      function finishUpload(){
        var ok = Data.savePhotos(photos);
        if(ok){
          View.renderDetail(S.curCatId);
          toast('已上传 '+added+' 个文件');
        } else {
          toast('上传失败：存储空间不足，请清理后重试');
        }
      }
      event.target.value = '';
    },

    // 相册管理
    showNewCategory: function(){
      $('galNewCatName').value = '';
      $('galNewCatDesc').value = '';
      this.checkNewCatBtn();
      $('galNewCategoryMask').classList.add('show');
    },
    checkNewCatBtn: function(){
      $('galNewCatBtn').disabled = !$('galNewCatName').value.trim();
    },
    createCategory: function(){
      var name = $('galNewCatName').value.trim();
      if(!name) return;
      var desc = $('galNewCatDesc').value.trim();
      var cats = Data.getCats();
      var now = new Date();
      var catTime = now.getFullYear() + '/' + (now.getMonth()+1) + '/' + now.getDate();
      var newCat = {
        id: cats.length ? Math.max.apply(null, cats.map(function(c){return c.id;})) + 1 : 1,
        name: name,
        cover: null,
        description: desc,
        isTop: false,
        createdAt: catTime
      };
      cats.push(newCat);
      Data.saveCats(cats);
      this.closeModal('galNewCategoryMask');
      toast('相册「'+name+'」已创建');
      View.renderHome();
    },
    showMoreMenu: function(){
      var cat = Data.getCatById(S.curCatId);
      var btn = $('galTopBtn');
      if(btn) btn.textContent = cat && cat.isTop ? '取消置顶' : '置顶相册';
      $('galMoreMask').classList.add('show');
    },
    toggleTop: function(){
      this.closeModal('galMoreMask');
      var cats = Data.getCats();
      var cat = cats.find(function(c){ return c.id === S.curCatId; });
      if(cat){
        cat.isTop = !cat.isTop;
        Data.saveCats(cats);
        toast(cat.isTop ? '已置顶' : '已取消置顶');
      }
    },
    editCategory: function(){
      this.closeModal('galMoreMask');
      var cat = Data.getCatById(S.curCatId);
      if(!cat) return;
      $('galEditCatName').value = cat.name;
      $('galEditCatDesc').value = cat.description || '';
      $('galEditTopSwitch').checked = !!cat.isTop;
      // 封面缩略图
      var thumb = null;
      if(cat.cover){
        if(typeof cat.cover === 'string' && cat.cover.indexOf('data:') === 0){
          thumb = cat.cover;
        } else {
          var cp = Data.getPhotos().find(function(p){ return p.id === cat.cover; });
          if(cp) thumb = cp.dataUrl;
        }
      }
      if(!thumb){
        var photos = Data.getPhotosByCat(S.curCatId);
        if(photos.length > 0){
          // 按日期降序取最后一张（与详情页fallback一致）
          var sorted = photos.slice().sort(function(a,b){
            var da = new Date(a.date || a.createdAt || 0);
            var db = new Date(b.date || b.createdAt || 0);
            return db.getTime() - da.getTime();
          });
          thumb = sorted[sorted.length-1].dataUrl;
        }
      }
      $('galEditCoverThumb').src = thumb || 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIzNiIgaGVpZ2h0PSIzNiI+PHJlY3Qgd2lkdGg9IjM2IiBoZWlnaHQ9IjM2IiBmaWxsPSIjZTVlNWVhIi8+PC9zdmc+';
      $('galEditPage').classList.add('show');
    },
    cancelEdit: function(){
      $('galEditPage').classList.remove('show');
    },
    saveEditCategory: function(){
      var name = $('galEditCatName').value.trim();
      if(!name){ toast('名称不能为空'); return; }
      var cats = Data.getCats();
      var cat = cats.find(function(c){ return c.id === S.curCatId; });
      if(cat){
        cat.name = name;
        cat.description = $('galEditCatDesc').value.trim();
        cat.isTop = $('galEditTopSwitch').checked;
        Data.saveCats(cats);
        toast('已保存');
        $('galEditPage').classList.remove('show');
        View.renderDetail(S.curCatId);
      }
    },
    changeCover: function(){
      this.closeModal('galMoreMask');
      var photos = Data.getPhotosByCat(S.curCatId);
      // 按日期降序排列（与详情页显示顺序一致）
      photos = photos.slice().sort(function(a,b){
        var da = new Date(a.date || a.createdAt || 0);
        var db = new Date(b.date || b.createdAt || 0);
        return db.getTime() - da.getTime();
      });
      if(photos.length === 0){ toast('相册内暂无照片'); return; }
      var grid = $('galCoverPickerGrid');
      grid.innerHTML = '';
      var self = this;
      photos.forEach(function(p){
        var item = document.createElement('div');
        item.className = 'gal-cover-picker-item';
        item.innerHTML = '<img src="' + (p.thumbnail || p.dataUrl) + '" alt="">';
        item.onclick = function(){
          var cats = Data.getCats();
          var cat = cats.find(function(c){ return c.id === S.curCatId; });
          if(cat){
            cat.cover = p.dataUrl;
            Data.saveCats(cats);
            View.renderDetail(S.curCatId);
            // 同步更新编辑页缩略图
            var editThumb = $('galEditCoverThumb');
            if(editThumb) editThumb.src = p.dataUrl;
            toast('封面已更换');
          }
          self.closeCoverPicker();
        };
        grid.appendChild(item);
      });
      $('galCoverPickerMask').classList.add('show');
    },
    closeCoverPicker: function(){
      $('galCoverPickerMask').classList.remove('show');
    },
    deleteCategory: function(){
      if(!confirm('确定删除此相册？相册内的所有照片也会被删除。')) return;
      var cats = Data.getCats().filter(function(c){ return c.id !== S.curCatId; });
      var photos = Data.getPhotos().filter(function(p){ return p.categoryId !== S.curCatId; });
      var ok1 = Data.saveCats(cats);
      var ok2 = Data.savePhotos(photos);
      if(!ok1 || !ok2){ toast('删除失败：存储空间不足'); return; }
      this.closeModal('galMoreMask');
      toast('相册已删除');
      this.backToHome();
    },

    // 日期导航
    toggleDateNav: function(){
      S.dateNavOpen = !S.dateNavOpen;
      $('galDateNavMask').classList.toggle('show', S.dateNavOpen);
      $('galDateNavPanel').classList.toggle('show', S.dateNavOpen);
    },

    // 大图查看
    openLightbox: function(photoId){
      var photos = Data.getPhotosByCat(S.curCatId);
      // 按日期降序排列（与 renderDetail 显示顺序一致，确保计数准确）
      var groups = {};
      photos.forEach(function(p){
        var ym = formatYearMonth(p.date);
        if(!groups[ym]) groups[ym] = [];
        groups[ym].push(p);
      });
      var sortedKeys = Object.keys(groups).sort(function(a,b){
        var da = new Date(a + '/1'), db = new Date(b + '/1');
        return db.getTime() - da.getTime();
      });
      var sortedPhotos = [];
      sortedKeys.forEach(function(ym){ groups[ym].forEach(function(p){ sortedPhotos.push(p); }); });
      S.lightboxPhotos = sortedPhotos;
      S.lightboxIndex = sortedPhotos.findIndex(function(p){ return p.id === photoId; });
      if(S.lightboxIndex < 0) S.lightboxIndex = 0;
      $('galLightbox').classList.add('show');
      View.renderLightbox();
    },
    closeLightbox: function(){
      $('galLightbox').classList.remove('show');
      var video = $('galLightbox').querySelector('video');
      if(video){ try{ video.pause(); video.src=''; video.load(); }catch(e){} }
      // 清空body释放内存
      var body = $('galLightboxBody');
      if(body) body.innerHTML = '';
    },
    showLightboxMore: function(){
      $('galLightboxActions').classList.add('show');
    },
    showPhotoInfo: function(){
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p) return;
      // 格式化时间：2024年8月9日 星期五 18:13
      var dateStr = p.createdAt || p.date || '';
      if(dateStr){
        var parts = dateStr.split(' ');
        var datePart = parts[0].replace(/\//g, '-');
        var dp = datePart.split('-');
        if(dp.length === 3){
          var y = parseInt(dp[0]), m = parseInt(dp[1]) - 1, d = parseInt(dp[2]);
          var dateObj = new Date(y, m, d);
          var weekdays = ['星期日','星期一','星期二','星期三','星期四','星期五','星期六'];
          var timePart = parts[1] ? ' ' + parts[1] : '';
          dateStr = y + '年' + (m+1) + '月' + d + '日 ' + weekdays[dateObj.getDay()] + timePart;
        }
      }
      $('galPhotoInfoDate').textContent = dateStr || '未知时间';
      // 图片尺寸
      var sizeStr = '--';
      if(p.width && p.height){
        sizeStr = p.width + ' × ' + p.height;
      } else {
        sizeStr = '400 × 400'; // SVG默认尺寸
      }
      $('galPhotoInfoSize').textContent = sizeStr;
      $('galPhotoInfo').classList.add('show');
    },
    closePhotoInfo: function(){
      $('galPhotoInfo').classList.remove('show');
    },
    closeLightboxActions: function(){
      $('galLightboxActions').classList.remove('show');
    },
    sharePhoto: function(type){
      this.closeLightboxActions();
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p) return;
      var title = p.caption || '照片分享';
      // 用系统级 Web Share API，调起系统分享面板（含微信好友/朋友圈）
      if(navigator.share){
        if(p.dataUrl.indexOf('data:image') === 0){
          // 图片转 blob 分享
          fetch(p.dataUrl).then(function(r){ return r.blob(); }).then(function(blob){
            var file = new File([blob], 'photo.jpg', {type:'image/jpeg'});
            navigator.share({ title: title, files: [file] }).catch(function(){});
          }).catch(function(){
            navigator.share({ title: title, text: title }).catch(function(){});
          });
        } else {
          navigator.share({ title: title, text: title }).catch(function(){});
        }
      } else {
        toast('当前浏览器不支持系统分享');
      }
    },
    savePhoto: function(){
      this.closeLightboxActions();
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p) return;
      try {
        var blob = dataUrlToBlob(p.dataUrl);
        var ext = '.jpg';
        if(p.type === 'video') ext = '.mp4';
        else if(p.dataUrl.indexOf('image/svg+xml') >= 0) ext = '.svg';
        else if(p.dataUrl.indexOf('image/gif') >= 0) ext = '.gif';
        else if(p.dataUrl.indexOf('image/png') >= 0) ext = '.png';
        downloadBlob(blob, 'photo_' + p.id + '_' + Date.now() + ext);
        toast('已保存到手机');
      } catch(e){
        // 降级方案
        var a = document.createElement('a');
        a.href = p.dataUrl;
        a.download = 'photo_' + Date.now() + '.jpg';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        toast('已保存到手机');
      }
    },
    deletePhoto: function(){
      this.closeLightboxActions();
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p) return;
      if(!confirm('确定删除这张照片？')) return;
      var photos = Data.getPhotos().filter(function(x){ return x.id !== p.id; });
      var ok = Data.savePhotos(photos);
      if(!ok){
        toast('删除失败：存储空间不足');
        return;
      }
      // 从IndexedDB删除视频Blob
      if(p.type === 'video' && p.idbKey){ idbDel(p.idbKey); }
      // 清理封面引用：被删照片若是某相册封面（ID或dataUrl匹配），清空封面
      var cats = Data.getCats();
      var coverChanged = false;
      cats.forEach(function(c){
        if(c.cover === p.id || c.cover === p.dataUrl){
          c.cover = null;
          coverChanged = true;
        }
      });
      if(coverChanged) Data.saveCats(cats);
      // 更新大图列表
      S.lightboxPhotos = S.lightboxPhotos.filter(function(x){ return x.id !== p.id; });
      if(S.lightboxPhotos.length === 0){
        this.closeLightbox();
      } else {
        if(S.lightboxIndex >= S.lightboxPhotos.length) S.lightboxIndex = S.lightboxPhotos.length - 1;
        View.renderLightbox();
      }
      View.renderDetail(S.curCatId);
      toast('已删除');
    },
    saveCaption: function(){
      var el = $('galLightboxCaption');
      if(!el) return;
      var photoId = el.getAttribute('data-photo-id');
      if(photoId !== null && photoId !== '') photoId = parseInt(photoId);
      var newCap = el.textContent.trim();
      // 在 lightboxPhotos 中找对应照片
      var p = S.lightboxPhotos.find(function(x){ return x.id === photoId; });
      if(!p){
        // fallback：用当前 index
        p = S.lightboxPhotos[S.lightboxIndex];
      }
      if(!p) return;
      if(newCap === (p.caption||'')) return;
      var photos = Data.getPhotos();
      var photo = photos.find(function(x){ return x.id === p.id; });
      if(photo){
        photo.caption = newCap;
        var ok = Data.savePhotos(photos);
        if(!ok){ toast('保存失败：存储空间不足'); return; }
        p.caption = newCap;
        toast('描述已保存');
      }
    },
    shareCategory: function(){
      this.closeModal('galMoreMask');
      var cat = Data.getCatById(S.curCatId);
      var title = cat ? cat.name : '班级相册';
      if(navigator.share){
        navigator.share({ title: title, text: '快来看看' + title, url: window.location.href }).catch(function(){});
      } else {
        toast('分享功能开发中');
      }
    },

    // 弹窗
    closeModal: function(id){ $(id).classList.remove('show'); }
  };

  // ===== 绑定全局函数（供HTML onclick调用） =====
  window.galOpenAlbum = function(){ Ctrl.openAlbum(); };
  window.galGoHome = function(){ Ctrl.backToHome(); };
  window.galOpenCategory = function(id){ Ctrl.openCategory(id); };
  window.galBackToHome = function(){ Ctrl.backToHome(); };
  window.galToggleSelectMode = function(){ Ctrl.toggleSelectMode(); };
  window.galToggleSelect = function(id){ Ctrl.toggleSelect(id); };
  window.galSelectAll = function(){ Ctrl.selectAll(); };
  window.galDeleteSelected = function(){ Ctrl.deleteSelected(); };
  window.galDownloadSelected = function(){ Ctrl.downloadSelected(); };
  window.galShowMoveModal = function(){ Ctrl.showMoveModal(); };
  window.galDoMove = function(id){ Ctrl.doMove(id); };
  window.galShowUploadMenu = function(){ Ctrl.showUploadMenu(); };
  window.galHandleUpload = function(e, type){ Ctrl.handleUpload(e, type); };
  window.galShowNewCategory = function(){ Ctrl.showNewCategory(); };
  window.galCheckNewCatBtn = function(){ Ctrl.checkNewCatBtn(); };
  window.galCreateCategory = function(){ Ctrl.createCategory(); };
  window.galShowMoreMenu = function(){ Ctrl.showMoreMenu(); };
  window.galEditCategory = function(){ Ctrl.editCategory(); };
  window.galSaveEditCategory = function(){ Ctrl.saveEditCategory(); };
  window.galCancelEdit = function(){ Ctrl.cancelEdit(); };
  window.galCloseCoverPicker = function(){ Ctrl.closeCoverPicker(); };
  window.galChangeCover = function(){ Ctrl.changeCover(); };
  window.galDeleteCategory = function(){ Ctrl.deleteCategory(); };
  window.galShareCategory = function(){ Ctrl.shareCategory(); };
  window.galToggleTop = function(){ Ctrl.toggleTop(); };
  window.galToggleDateNav = function(){ Ctrl.toggleDateNav(); };
  window.galScrollToDate = function(ym){ Ctrl.scrollToDate(ym); };
  window.galOpenLightbox = function(id){ Ctrl.openLightbox(id); };
  window.galCloseLightbox = function(){ Ctrl.closeLightbox(); };
  window.galShowLightboxMore = function(){ Ctrl.showLightboxMore(); };
  window.galShowPhotoInfo = function(){ Ctrl.showPhotoInfo(); };
  window.galClosePhotoInfo = function(){ Ctrl.closePhotoInfo(); };
  window.galCloseLightboxActions = function(){ Ctrl.closeLightboxActions(); };
  window.galSharePhoto = function(type){ Ctrl.sharePhoto(type); };
  window.galSavePhoto = function(){ Ctrl.savePhoto(); };
  window.galDeletePhoto = function(){ Ctrl.deletePhoto(); };
  window.galSaveCaption = function(){ Ctrl.saveCaption(); };
  window.galCloseModal = function(id){ Ctrl.closeModal(id); };

  // ===== 初始化 =====
  document.addEventListener('DOMContentLoaded', function(){
    // 页面加载时初始化模拟数据并渲染首页
    Data.initMock();
    Data.repairData();
    View.renderHome();
    var wrapper = $('galPhotosWrapper');
    if(wrapper){
      wrapper.addEventListener('scroll', function(){ Ctrl.onScroll(); }, {passive:true});
    }
    // 键盘左右切换大图
    document.addEventListener('keydown', function(e){
      if(!$('galLightbox').classList.contains('show')) return;
      if(e.key === 'ArrowLeft' && S.lightboxIndex > 0){
        S.lightboxIndex--; View.renderLightbox();
      } else if(e.key === 'ArrowRight' && S.lightboxIndex < S.lightboxPhotos.length-1){
        S.lightboxIndex++; View.renderLightbox();
      } else if(e.key === 'Escape'){
        Ctrl.closeLightbox();
      }
    });
    // 大图触摸交互：点击返回、双指缩放、双击缩放、缩放拖动、左右滑动
    var lbTouch = { mode:'none', startX:0, startY:0, startDist:0, startScale:1, lastTapTime:0, tapTimeout:null, moved:false, startTime:0, lastDx:0, animating:false };
    function lbApplyTransform(){
      var el = $('galLightboxZoom');
      if(!el) return;
      el.style.transform = 'translate('+S.lbTranslateX+'px,'+S.lbTranslateY+'px) scale('+S.lbScale+')';
    }
    function lbResetScale(animate){
      S.lbScale = 1; S.lbTranslateX = 0; S.lbTranslateY = 0;
      var el = $('galLightboxZoom');
      if(el){
        if(animate){ el.style.transition='transform 0.2s ease'; lbApplyTransform(); setTimeout(function(){ if(el) el.style.transition=''; },200); }
        else lbApplyTransform();
      }
    }
    // 滑动切换：当前图片滑出 + 新图片从反方向滑入
    function lbSwipeTo(direction, currentSlide){
      if(lbTouch.animating) return;
      // 边界检查
      if(direction === 'next' && S.lightboxIndex >= S.lightboxPhotos.length - 1) return;
      if(direction === 'prev' && S.lightboxIndex <= 0) return;
      lbTouch.animating = true;
      if(direction === 'next') S.lightboxIndex++;
      else S.lightboxIndex--;
      var p = S.lightboxPhotos[S.lightboxIndex];
      if(!p){
        // 越界恢复
        if(direction === 'next') S.lightboxIndex--;
        else S.lightboxIndex++;
        lbTouch.animating = false;
        return;
      }
      // 创建新幻灯片
      var newSlide = document.createElement('div');
      newSlide.className = 'gal-lightbox-slide';
      if(p.type === 'video'){
        if(p.type === 'video'){
          newSlide.innerHTML = '<div style="color:#8e8e93;text-align:center;padding:40px;">加载中...</div>';
          (function(slide){
            getVideoUrl(p, function(url){
              slide.innerHTML = '<video src="'+url+'" controls autoplay playsinline preload="auto" style="max-width:100%;max-height:100%;"></video>';
            });
          })(newSlide);
        } else {
          newSlide.innerHTML = '<video src="'+p.dataUrl+'" controls autoplay playsinline preload="auto" style="max-width:100%;max-height:100%;"></video>';
        }
      } else {
        newSlide.innerHTML = '<div class="gal-lightbox-zoom" id="galLightboxZoom"><img src="'+p.dataUrl+'" alt=""></div>';
      }
      var startX = direction === 'next' ? '100%' : '-100%';
      newSlide.style.transform = 'translateX(' + startX + ')';
      currentSlide.parentNode.appendChild(newSlide);
      // 更新顶部信息
      var cat = Data.getCatById(S.curCatId);
      var albumName = cat ? cat.name : '班级相册';
      $('galLightboxAlbum').textContent = albumName + '(' + (S.lightboxIndex+1) + '/' + S.lightboxPhotos.length + ')';
      var capEl2 = $('galLightboxCaption');
      if(capEl2){ capEl2.textContent = p.caption || ''; capEl2.setAttribute('data-photo-id', p.id); }
      var lbDateStr = p.createdAt || p.date || '';
      if(lbDateStr){
        var lbParts = lbDateStr.split(' ');
        $('galLightboxDate').textContent = lbParts[0] || '';
      }
      // 强制重排后同时滑动
      newSlide.offsetHeight;
      var outX = direction === 'next' ? '-100%' : '100%';
      currentSlide.style.transform = 'translateX(' + outX + ')';
      newSlide.style.transform = 'translateX(0)';
      var settled = false;
      var onEnd = function(e){
        if(e.propertyName !== 'transform' || settled) return;
        settled = true;
        newSlide.removeEventListener('transitionend', onEnd);
        // 释放旧幻灯片中的视频
        var oldVideo = currentSlide.querySelector('video');
        if(oldVideo){ try{ oldVideo.pause(); oldVideo.src=''; oldVideo.load(); }catch(e){} }
        if(currentSlide.parentNode) currentSlide.parentNode.removeChild(currentSlide);
        newSlide.style.transform = '';
        // 重置缩放
        S.lbScale = 1; S.lbTranslateX = 0; S.lbTranslateY = 0;
        var zoomEl = newSlide.querySelector('.gal-lightbox-zoom');
        if(zoomEl) zoomEl.style.transform = 'scale(1) translate(0,0)';
        lbTouch.animating = false;
      };
      newSlide.addEventListener('transitionend', onEnd);
      // 超时保护：350ms后强制结束，防止transitionend不触发
      setTimeout(function(){ if(!settled) onEnd({propertyName:'transform'}); }, 350);
    }

    $('galLightbox').addEventListener('touchstart', function(e){
      if(e.touches.length === 2){
        lbTouch.mode = 'zoom';
        var dx = e.touches[0].clientX - e.touches[1].clientX;
        var dy = e.touches[0].clientY - e.touches[1].clientY;
        lbTouch.startDist = Math.sqrt(dx*dx + dy*dy);
        lbTouch.startScale = S.lbScale;
        lbTouch.moved = true;
      } else if(e.touches.length === 1){
        // 如果点击的是视频控件，不进入滑动/缩放状态
        var tsTarget = e.touches[0].target;
        if(tsTarget && tsTarget.closest && tsTarget.closest('video')){
          lbTouch.mode = 'none';
          return;
        }
        lbTouch.startX = e.touches[0].clientX;
        lbTouch.startY = e.touches[0].clientY;
        lbTouch.startTime = Date.now();
        lbTouch.moved = false;
        lbTouch.mode = S.lbScale > 1.01 ? 'pan' : 'swipe';
        if(lbTouch.mode === 'swipe' && !lbTouch.animating){
          var slide = document.querySelector('.gal-lightbox-slide');
          if(slide){ slide.classList.add('swiping'); slide.style.transform = ''; }
        }
      }
    }, {passive:false});
    $('galLightbox').addEventListener('touchmove', function(e){
      if(e.touches.length === 2 && lbTouch.mode === 'zoom'){
        e.preventDefault();
        var dx = e.touches[0].clientX - e.touches[1].clientX;
        var dy = e.touches[0].clientY - e.touches[1].clientY;
        var dist = Math.sqrt(dx*dx + dy*dy);
        var scale = lbTouch.startScale * (dist / lbTouch.startDist);
        S.lbScale = Math.max(1, Math.min(4, scale));
        lbApplyTransform();
        lbTouch.moved = true;
      } else if(e.touches.length === 1 && lbTouch.mode === 'pan'){
        e.preventDefault();
        var dx = e.touches[0].clientX - lbTouch.startX;
        var dy = e.touches[0].clientY - lbTouch.startY;
        S.lbTranslateX += dx;
        S.lbTranslateY += dy;
        lbTouch.startX = e.touches[0].clientX;
        lbTouch.startY = e.touches[0].clientY;
        lbApplyTransform();
        lbTouch.moved = true;
      } else if(e.touches.length === 1 && lbTouch.mode === 'swipe' && !lbTouch.animating){
        e.preventDefault();
        var dx = e.touches[0].clientX - lbTouch.startX;
        var dy = e.touches[0].clientY - lbTouch.startY;
        if(Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > 10) return;
        var dampDx = dx;
        if(S.lightboxIndex === 0 && dx > 0) dampDx = dx * 0.3;
        if(S.lightboxIndex === S.lightboxPhotos.length - 1 && dx < 0) dampDx = dx * 0.3;
        var slide = document.querySelector('.gal-lightbox-slide');
        if(slide) slide.style.transform = 'translateX(' + dampDx + 'px)';
        lbTouch.moved = true;
        lbTouch.lastDx = dx;
      }
    }, {passive:false});
    $('galLightbox').addEventListener('touchend', function(e){
      if(lbTouch.mode === 'zoom' || lbTouch.mode === 'pan'){
        if(S.lbScale < 1.01) lbResetScale(true);
        lbTouch.mode = 'none';
        return;
      }
      var dx = e.changedTouches[0].clientX - lbTouch.startX;
      var dy = e.changedTouches[0].clientY - lbTouch.startY;
      var dist = Math.sqrt(dx*dx + dy*dy);
      var touchTarget = e.changedTouches[0].target;
      var slide = document.querySelector('.gal-lightbox-slide');
      if(touchTarget && touchTarget.closest && touchTarget.closest('.gal-lightbox-nav, .gal-lightbox-info, .gal-lightbox-more-fab, video')){
        if(slide){ slide.classList.remove('swiping'); slide.style.transform = ''; }
        lbTouch.mode = 'none';
        return;
      }
      if(dist < 10 && !lbTouch.moved){
        if(slide){ slide.classList.remove('swiping'); slide.style.transform = ''; }
        var now = Date.now();
        if(now - lbTouch.lastTapTime < 300){
          clearTimeout(lbTouch.tapTimeout);
          lbTouch.lastTapTime = 0;
          if(S.lbScale > 1.01){ lbResetScale(true); }
          else {
            S.lbScale = 2; S.lbTranslateX = 0; S.lbTranslateY = 0;
            var el = $('galLightboxZoom');
            if(el){ el.style.transition='transform 0.2s ease'; lbApplyTransform(); setTimeout(function(){ if(el) el.style.transition=''; },200); }
          }
        } else {
          lbTouch.lastTapTime = now;
          lbTouch.tapTimeout = setTimeout(function(){ Ctrl.closeLightbox(); }, 300);
        }
      } else if(lbTouch.mode === 'swipe' && S.lbScale <= 1.01 && slide && !lbTouch.animating){
        slide.classList.remove('swiping');
        var dt = Date.now() - lbTouch.startTime;
        var velocity = dt > 0 ? dx / dt : 0;
        var shouldSwitch = Math.abs(dx) > 50 || Math.abs(velocity) > 0.4;
        var direction = dx < 0 ? 'next' : 'prev';
        var canSwitch = (direction === 'next' && S.lightboxIndex < S.lightboxPhotos.length - 1) || (direction === 'prev' && S.lightboxIndex > 0);
        if(shouldSwitch && canSwitch){
          lbSwipeTo(direction, slide);
        } else {
          slide.style.transform = 'translateX(0)';
        }
      }
      lbTouch.mode = 'none';
    }, {passive:true});
  });

  // 暴露给外部调用（主页功能卡片入口）
  window.openAlbum = function(){ Ctrl.openAlbum(); };

})();


