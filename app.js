const config = window.FAMILY_STARS_CONFIG;
const api = createSupabaseApi(config);

const categories = ["学习", "吃饭", "睡觉", "情绪", "整理", "礼貌", "兄弟互动", "自理能力", "其他"];
const praiseReasons = {
  "皮皮": ["主动完成作业", "照顾小满", "整理书桌", "控制情绪", "认真阅读", "遵守约定"],
  "小满": ["自己吃饭", "自己穿鞋", "分享玩具", "好好刷牙", "用语言表达", "帮忙收拾"]
};
const improvementReasons = {
  "皮皮": ["没有遵守约定", "情绪爆发", "作业拖延", "没有收拾物品", "对家人不礼貌"],
  "小满": ["吃饭离开座位", "睡前跑出房间", "哭闹表达", "不愿收玩具", "抢玩具"]
};

let state = {
  session: null,
  family: loadLocal("family"),
  guardian: loadLocal("guardian"),
  view: "home",
  children: [],
  guardians: [],
  rewards: [],
  badges: [],
  childBadges: [],
  starRecords: [],
  redemptions: [],
  loading: false,
  error: "",
  form: {
    childId: "",
    type: "praise",
    stars: 1,
    category: "学习",
    reason: ""
  },
  customReward: {
    name: "",
    costStars: 10,
    description: ""
  },
  isCustomRewardOpen: false,
  customExchange: {
    name: "",
    costStars: 10,
    description: ""
  },
  isCustomExchangeOpen: false,
  selectedChildId: "",
  filters: {
    childId: "all",
    guardianId: "all",
    type: "all"
  }
};

const app = document.querySelector("#app");

init();

async function init() {
  renderBoot();
  try {
    state.session = await api.ensureSession();
  } catch (error) {
    state.error = humanError(error);
    renderEntry();
    return;
  }

  if (state.family?.family_id && state.guardian?.guardian_id) {
    await ensureCurrentMembership();
    await loadAll();
    renderApp();
  } else {
    renderEntry();
  }
}

function renderBoot() {
  app.innerHTML = `
    <div class="boot-screen">
      <div>
        <div class="orbit-loader"></div>
        <p>星球队正在集合...</p>
      </div>
    </div>
  `;
}

function renderEntry() {
  app.innerHTML = `
    <main class="entry-screen">
      <section class="entry-card">
        <div class="planet-mark"></div>
        <h1>皮皮小满星球探险队</h1>
        <p>选择操作人后进入家庭星球</p>
        ${state.error ? `<div class="error">${escapeHtml(state.error)}</div>` : ""}
        <form id="entryForm" class="form-grid">
          <div class="field">
            <label for="inviteCode">家庭邀请码</label>
            <input id="inviteCode" value="${escapeAttr(config.defaultInviteCode)}" autocomplete="off" />
          </div>
          <div class="field">
            <label for="guardianRole">操作人</label>
            <select id="guardianRole">
              <option value="dad">爸爸</option>
              <option value="mom">妈妈</option>
              <option value="grandma">奶奶</option>
            </select>
          </div>
          <button class="primary-btn" type="submit">进入星球队</button>
        </form>
      </section>
    </main>
  `;
  document.querySelector("#entryForm").addEventListener("submit", joinFamily);
}

async function joinFamily(event) {
  event.preventDefault();
  const inviteCode = document.querySelector("#inviteCode").value.trim();
  const role = document.querySelector("#guardianRole").value;
  state.error = "";
  setEntryBusy(true);

  const { data, error } = await api.rpc("join_family", {
    p_invite_code: inviteCode,
    p_guardian_role_key: role
  });

  setEntryBusy(false);

  if (error) {
    state.error = humanError(error);
    renderEntry();
    return;
  }

  state.family = {
    family_id: data.family_id,
    family_name: data.family_name
  };
  state.guardian = {
    guardian_id: data.guardian_id,
    guardian_name: data.guardian_name,
    guardian_role_key: data.guardian_role_key
  };
  saveLocal("family", state.family);
  saveLocal("guardian", state.guardian);

  await loadAll();
  renderApp();
}

function setEntryBusy(isBusy) {
  const button = document.querySelector("#entryForm button");
  if (button) {
    button.disabled = isBusy;
    button.textContent = isBusy ? "正在进入..." : "进入星球队";
  }
}

async function loadAll() {
  if (!state.family?.family_id) return;
  state.loading = true;
  renderApp();

  const familyId = state.family.family_id;
  const [
    childrenResult,
    guardiansResult,
    rewardsResult,
    badgesResult,
    childBadgesResult,
    starRecordsResult,
    redemptionsResult
  ] = await Promise.all([
    api.select("children", `family_id=eq.${familyId}&select=*&order=sort_order.asc`),
    api.select("guardians", `family_id=eq.${familyId}&is_active=eq.true&select=*&order=sort_order.asc`),
    api.select("rewards", `family_id=eq.${familyId}&is_active=eq.true&select=*&order=sort_order.asc`),
    api.select("badges", `family_id=eq.${familyId}&is_active=eq.true&select=*&order=sort_order.asc`),
    api.select("child_badges", `family_id=eq.${familyId}&select=*`),
    api.select("star_records", `family_id=eq.${familyId}&select=*,children(name),guardians(name)&order=created_at.desc&limit=80`),
    api.select("reward_redemptions", `family_id=eq.${familyId}&select=*,children(name),guardians(name)&order=created_at.desc&limit=80`)
  ]);

  const error = [
    childrenResult,
    guardiansResult,
    rewardsResult,
    badgesResult,
    childBadgesResult,
    starRecordsResult,
    redemptionsResult
  ].find((result) => result.error)?.error;

  state.loading = false;

  if (error) {
    state.error = humanError(error);
    renderApp();
    return;
  }

  state.children = childrenResult.data || [];
  state.guardians = guardiansResult.data || [];
  state.rewards = rewardsResult.data || [];
  state.badges = badgesResult.data || [];
  state.childBadges = childBadgesResult.data || [];
  state.starRecords = starRecordsResult.data || [];
  state.redemptions = redemptionsResult.data || [];

  if (!state.form.childId && state.children[0]) {
    state.form.childId = state.children[0].id;
    state.selectedChildId = state.children[0].id;
  }
}

function renderApp() {
  if (!state.family?.family_id) {
    renderEntry();
    return;
  }

  app.innerHTML = `
    <div class="app-shell">
      <header class="topbar">
        <h1>${escapeHtml(state.family.family_name || "皮皮小满星球探险队")}</h1>
        <div class="topbar-row">
          <span class="identity-pill">当前：${escapeHtml(state.guardian?.guardian_name || "未选择")}</span>
          <div class="topbar-actions">
            <button class="ghost-btn" id="settingsBtn" type="button">设置</button>
            <button class="ghost-btn" id="refreshBtn" type="button">刷新</button>
          </div>
        </div>
      </header>
      ${state.error ? `<div class="error">${escapeHtml(state.error)}</div>` : ""}
      ${state.loading ? `<div class="panel empty-state">正在同步星球数据...</div>` : renderView()}
    </div>
    ${renderNav()}
  `;

  bindCommonEvents();
  bindViewEvents();
}

function renderView() {
  if (state.view === "home") return renderHome();
  if (state.view === "stars") return renderStarsForm();
  if (state.view === "records") return renderRecords();
  if (state.view === "rewards") return renderRewards();
  if (state.view === "badges") return renderBadges();
  if (state.view === "settings") return renderSettings();
  return renderHome();
}

function renderHome() {
  return `
    <section class="section-title">
      <h2>星星罐</h2>
      <span>红色是表扬，黑色是改进</span>
    </section>
    <div class="child-grid">
      ${state.children.map(renderChildCard).join("") || `<div class="panel empty-state">还没有孩子数据</div>`}
    </div>
  `;
}

function renderChildCard(child) {
  const todayPraise = sumToday(child.id, "praise");
  const todayImprovement = sumToday(child.id, "improvement");
  const jarPercent = Math.min(100, Math.round((child.available_stars / 120) * 100));
  return `
    <article class="panel child-card">
      <div class="child-head">
        <div class="avatar ${escapeAttr(child.avatar_key)}" aria-hidden="true"></div>
        <div>
          <div class="child-name">
            <h3>${escapeHtml(child.name)}</h3>
            <span class="title-badge">${escapeHtml(child.current_title)}</span>
          </div>
          <div class="stars-line">
            <strong class="stars-number">${child.available_stars}</strong>
            <span class="stars-label">颗可用星星</span>
          </div>
          <div class="jar" aria-label="星星罐进度">
            <div class="jar-fill" style="width: ${jarPercent}%"></div>
          </div>
        </div>
      </div>
      <div class="stats-row">
        <div class="stat-box"><strong>${child.lifetime_stars}</strong><span>累计成长星</span></div>
        <div class="stat-box"><strong class="positive">+${todayPraise}</strong><span>今日表扬</span></div>
        <div class="stat-box"><strong class="negative">-${todayImprovement}</strong><span>今日改进</span></div>
      </div>
      <div class="quick-actions">
        <button class="primary-btn add-star-btn" data-child-id="${child.id}" type="button">给星星</button>
        <button class="secondary-btn reward-child-btn" data-child-id="${child.id}" type="button">兑换奖励</button>
      </div>
    </article>
  `;
}

function renderStarsForm() {
  const currentChild = state.children.find((child) => child.id === state.form.childId) || state.children[0];
  const reasons = state.form.type === "praise"
    ? praiseReasons[currentChild?.name] || []
    : improvementReasons[currentChild?.name] || [];
  const maxStars = state.form.type === "praise" ? 5 : 3;

  return `
    <section class="section-title">
      <h2>给星星</h2>
      <span>每次都要写原因</span>
    </section>
    <form id="starForm" class="panel form-card form-grid">
      <div class="field">
        <label>孩子</label>
        <div class="chips">
          ${state.children.map((child) => `
            <button class="chip child-chip ${child.id === state.form.childId ? "active" : ""}" data-child-id="${child.id}" type="button">${escapeHtml(child.name)}</button>
          `).join("")}
        </div>
      </div>
      <div class="field">
        <label>类型</label>
        <div class="segmented">
          <button class="chip praise ${state.form.type === "praise" ? "active" : ""}" data-type="praise" type="button">红色 + 表扬</button>
          <button class="chip improvement ${state.form.type === "improvement" ? "active" : ""}" data-type="improvement" type="button">黑色 - 改进</button>
        </div>
      </div>
      <div class="field">
        <label>星星数量</label>
        <div class="chips">
          ${Array.from({ length: maxStars }, (_, index) => index + 1).map((num) => `
            <button class="chip star-chip ${num === Number(state.form.stars) ? "active" : ""}" data-stars="${num}" type="button">${num} ⭐</button>
          `).join("")}
        </div>
      </div>
      <div class="field">
        <label for="category">行为分类</label>
        <select id="category">
          ${categories.map((category) => `<option ${category === state.form.category ? "selected" : ""}>${category}</option>`).join("")}
        </select>
      </div>
      <div class="field">
        <label>快捷原因</label>
        <div class="chips">
          ${reasons.map((reason) => `<button class="chip reason-chip" data-reason="${escapeAttr(reason)}" type="button">${escapeHtml(reason)}</button>`).join("")}
        </div>
      </div>
      <div class="field">
        <label for="reason">原因</label>
        <textarea id="reason" placeholder="写清楚发生了什么，方便以后回看">${escapeHtml(state.form.reason)}</textarea>
      </div>
      <button class="${state.form.type === "praise" ? "primary-btn" : "danger-btn"}" type="submit">
        ${state.form.type === "praise" ? `确认红色 +${state.form.stars} 星` : `确认黑色 -${state.form.stars} 星`}
      </button>
    </form>
  `;
}

function renderRecords() {
  const items = combinedRecords();
  const filtered = items.filter((item) => {
    if (state.filters.childId !== "all" && item.child_id !== state.filters.childId) return false;
    if (state.filters.guardianId !== "all" && item.guardian_id !== state.filters.guardianId) return false;
    if (state.filters.type !== "all" && item.kind !== state.filters.type) return false;
    return true;
  });

  return `
    <section class="section-title">
      <h2>行为记录</h2>
      <span>${filtered.length} 条</span>
    </section>
    <div class="panel form-card form-grid">
      <div class="field">
        <label>筛选孩子</label>
        <select id="filterChild">
          <option value="all">全部孩子</option>
          ${state.children.map((child) => `<option value="${child.id}" ${state.filters.childId === child.id ? "selected" : ""}>${escapeHtml(child.name)}</option>`).join("")}
        </select>
      </div>
      <div class="field">
        <label>筛选操作人</label>
        <select id="filterGuardian">
          <option value="all">全部操作人</option>
          ${state.guardians.map((guardian) => `<option value="${guardian.id}" ${state.filters.guardianId === guardian.id ? "selected" : ""}>${escapeHtml(guardian.name)}</option>`).join("")}
        </select>
      </div>
      <div class="field">
        <label>记录类型</label>
        <select id="filterType">
          <option value="all">全部类型</option>
          <option value="praise" ${state.filters.type === "praise" ? "selected" : ""}>表扬</option>
          <option value="improvement" ${state.filters.type === "improvement" ? "selected" : ""}>需要改进</option>
          <option value="redemption" ${state.filters.type === "redemption" ? "selected" : ""}>奖励兑换</option>
        </select>
      </div>
    </div>
    <section class="section-title">
      <h2>记录列表</h2>
    </section>
    <div class="record-list">
      ${filtered.map(renderRecordItem).join("") || `<div class="panel empty-state">暂时没有符合条件的记录</div>`}
    </div>
  `;
}

function renderRecordItem(item) {
  if (item.kind === "redemption") {
    return `
      <article class="record-item">
        <div class="record-head">
          <strong>${escapeHtml(item.child_name)} 兑换奖励</strong>
          <span class="score negative">-${item.cost_stars} ⭐</span>
        </div>
        <div class="meta">${escapeHtml(item.guardian_name)}确认 · ${formatTime(item.created_at)}</div>
        <p class="reason">${escapeHtml(item.reward_name)}${item.note ? `：${escapeHtml(item.note)}` : ""}</p>
      </article>
    `;
  }

  const isPraise = item.type === "praise";
  return `
    <article class="record-item">
      <div class="record-head">
        <strong>${escapeHtml(item.child_name)}</strong>
        <span class="score ${isPraise ? "positive" : "negative"}">${isPraise ? "+" : "-"}${item.stars} ⭐</span>
      </div>
      <div class="meta">${escapeHtml(item.guardian_name)}记录 · ${escapeHtml(item.category)} · ${formatTime(item.created_at)}</div>
      <p class="reason">${escapeHtml(item.reason)}</p>
    </article>
  `;
}

function renderRewards() {
  const selectedChild = getSelectedChild();
  return `
    <section class="section-title">
      <h2>奖励中心</h2>
      <span>星星直接兑换</span>
    </section>
    <div class="panel form-card form-grid">
      <div class="field">
        <label>选择孩子</label>
        <div class="chips">
          ${state.children.map((child) => `
            <button class="chip select-reward-child ${child.id === state.selectedChildId ? "active" : ""}" data-child-id="${child.id}" type="button">${escapeHtml(child.name)}</button>
          `).join("")}
        </div>
      </div>
      <div class="stat-box">
        <strong>${selectedChild?.available_stars || 0} ⭐</strong>
        <span>${escapeHtml(selectedChild?.name || "")} 当前可用星星</span>
      </div>
    </div>
    ${renderCustomRewardPanel()}
    <section class="section-title">
      <h2>可兑换奖品</h2>
      <span>也可以临时添加后兑换</span>
    </section>
    <div class="reward-list">
      ${renderCustomExchangeItem(selectedChild)}
      ${state.rewards.map((reward) => renderRewardItem(reward, selectedChild)).join("") || `<div class="panel empty-state">还没有奖励配置</div>`}
    </div>
`;
}

function renderCustomRewardPanel() {
  return `
    <section class="section-title">
      <h2>奖励工具</h2>
      <span>按需展开</span>
    </section>
    <article class="panel reward-tool-card ${state.isCustomRewardOpen ? "is-open" : ""}">
      <button class="collapse-trigger" id="toggleRewardForm" type="button" aria-expanded="${state.isCustomRewardOpen}">
        <span class="tool-icon">＋</span>
        <span>
          <strong>添加长期奖励</strong>
          <small>设置标题、星星和条款说明，保存后长期出现在列表</small>
        </span>
        <span class="chevron">${state.isCustomRewardOpen ? "已展开 ▲" : "展开 ▼"}</span>
      </button>
      <form id="rewardForm" class="collapse-body form-grid ${state.isCustomRewardOpen ? "" : "hide"}">
        <div class="field">
          <label for="rewardName">奖励名称</label>
          <input id="rewardName" maxlength="30" placeholder="例如：周末去一次游乐场" value="${escapeAttr(state.customReward.name)}" />
        </div>
        <div class="field">
          <label for="rewardCost">所需星星</label>
          <input id="rewardCost" inputmode="numeric" type="number" min="1" max="999" value="${escapeAttr(state.customReward.costStars)}" />
        </div>
        <div class="field">
          <label for="rewardDescription">奖励说明</label>
          <textarea id="rewardDescription" maxlength="120" placeholder="可以写兑换范围、时间或家长约定">${escapeHtml(state.customReward.description)}</textarea>
        </div>
        <button class="primary-btn" type="submit">保存奖励</button>
      </form>
    </article>
  `;
}

function renderCustomExchangeItem(child) {
  return `
    <article class="reward-item custom-exchange-item ${state.isCustomExchangeOpen ? "is-open" : ""}">
      <button class="collapse-trigger" id="toggleExchangeForm" type="button" aria-expanded="${state.isCustomExchangeOpen}">
        <span class="tool-icon">★</span>
        <span>
          <strong>自定义奖品兑换</strong>
          <small>临时填写标题、星星和条款说明，确认后立即扣星</small>
        </span>
        <span class="chevron">${state.isCustomExchangeOpen ? "已展开 ▲" : "展开 ▼"}</span>
      </button>
      <form id="customExchangeForm" class="collapse-body inline-reward-form ${state.isCustomExchangeOpen ? "" : "hide"}">
        <div class="field">
          <label for="exchangeName">奖品标题</label>
          <input id="exchangeName" maxlength="30" placeholder="例如：今天选择晚餐水果" value="${escapeAttr(state.customExchange.name)}" />
        </div>
        <div class="field">
          <label for="exchangeCost">兑换星星</label>
          <input id="exchangeCost" inputmode="numeric" type="number" min="1" max="999" value="${escapeAttr(state.customExchange.costStars)}" />
        </div>
        <div class="field">
          <label for="exchangeDescription">奖品说明</label>
          <textarea id="exchangeDescription" maxlength="120" placeholder="写清楚这次兑换的具体内容">${escapeHtml(state.customExchange.description)}</textarea>
        </div>
        <button class="${child?.available_stars ? "secondary-btn" : "ghost-btn"}" type="submit">添加并兑换</button>
      </form>
    </article>
  `;
}

function renderRewardItem(reward, child) {
  const canRedeem = child && child.available_stars >= reward.cost_stars;
  return `
    <article class="reward-item">
      <div class="reward-head">
        <div>
          <strong>${escapeHtml(reward.name)}</strong>
          <div class="meta">${escapeHtml(reward.description || "")}</div>
        </div>
        <span class="score">${reward.cost_stars} ⭐</span>
      </div>
      <button class="${canRedeem ? "secondary-btn" : "ghost-btn"} redeem-btn" data-reward-id="${reward.id}" ${canRedeem ? "" : "disabled"} type="button">
        ${canRedeem ? "兑换" : "星星不足"}
      </button>
    </article>
  `;
}

function renderBadges() {
  const selectedChild = getSelectedChild();
  const earnedIds = new Set(
    state.childBadges
      .filter((item) => item.child_id === selectedChild?.id)
      .map((item) => item.badge_id)
  );

  return `
    <section class="section-title">
      <h2>勋章墙</h2>
      <span>成长荣誉收藏</span>
    </section>
    <div class="panel form-card form-grid">
      <div class="field">
        <label>选择孩子</label>
        <div class="chips">
          ${state.children.map((child) => `
            <button class="chip select-reward-child ${child.id === state.selectedChildId ? "active" : ""}" data-child-id="${child.id}" type="button">${escapeHtml(child.name)}</button>
          `).join("")}
        </div>
      </div>
    </div>
    <section class="section-title">
      <h2>${escapeHtml(selectedChild?.name || "")} 的勋章</h2>
      <span>${earnedIds.size}/${state.badges.length}</span>
    </section>
    <div class="badge-grid">
      ${state.badges.map((badge) => `
        <article class="badge-item ${earnedIds.has(badge.id) ? "" : "locked"}">
          <div class="badge-icon">${earnedIds.has(badge.id) ? "★" : "?"}</div>
          <strong>${escapeHtml(badge.name)}</strong>
          <div class="meta">${escapeHtml(badge.description)}</div>
        </article>
      `).join("") || `<div class="panel empty-state">还没有勋章配置</div>`}
    </div>
  `;
}

function renderSettings() {
  return `
    <section class="section-title">
      <h2>设置</h2>
      <span>家庭空间</span>
    </section>
    <div class="panel form-card form-grid">
      <div class="stat-box">
        <strong>${escapeHtml(state.family.family_name)}</strong>
        <span>当前家庭</span>
      </div>
      <div class="field">
        <label>当前操作人</label>
        <select id="switchGuardian">
          ${state.guardians.map((guardian) => `
            <option value="${guardian.role_key}" ${guardian.id === state.guardian.guardian_id ? "selected" : ""}>${escapeHtml(guardian.name)}</option>
          `).join("")}
        </select>
      </div>
      <button class="primary-btn" id="switchGuardianBtn" type="button">切换操作人</button>
      <button class="ghost-btn" id="leaveFamilyBtn" type="button">重新输入邀请码</button>
    </div>
  `;
}

function renderNav() {
  const items = [
    ["home", "⌂", "首页"],
    ["stars", "+", "给星"],
    ["records", "≡", "记录"],
    ["rewards", "★", "奖励"],
    ["badges", "◇", "勋章"]
  ];
  return `
    <nav class="bottom-nav">
      ${items.map(([view, icon, label]) => `
        <button class="nav-btn ${state.view === view ? "active" : ""}" data-view="${view}" type="button">
          <strong>${icon}</strong><span>${label}</span>
        </button>
      `).join("")}
    </nav>
  `;
}

function bindCommonEvents() {
  document.querySelector("#refreshBtn")?.addEventListener("click", async () => {
    state.error = "";
    await loadAll();
    renderApp();
    toast("数据已刷新");
  });

  document.querySelector("#settingsBtn")?.addEventListener("click", () => {
    state.view = "settings";
    state.error = "";
    renderApp();
  });

  document.querySelectorAll(".nav-btn").forEach((button) => {
    button.addEventListener("click", () => {
      state.view = button.dataset.view;
      state.error = "";
      renderApp();
    });
  });
}

function bindViewEvents() {
  document.querySelectorAll(".add-star-btn").forEach((button) => {
    button.addEventListener("click", () => {
      state.form.childId = button.dataset.childId;
      state.view = "stars";
      renderApp();
    });
  });

  document.querySelectorAll(".reward-child-btn").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedChildId = button.dataset.childId;
      state.view = "rewards";
      renderApp();
    });
  });

  bindStarFormEvents();
  bindRecordEvents();
  bindRewardEvents();
  bindSettingsEvents();
}

function bindStarFormEvents() {
  const form = document.querySelector("#starForm");
  if (!form) return;

  document.querySelectorAll(".child-chip").forEach((button) => {
    button.addEventListener("click", () => {
      state.form.childId = button.dataset.childId;
      state.form.reason = "";
      renderApp();
    });
  });

  document.querySelectorAll("[data-type]").forEach((button) => {
    button.addEventListener("click", () => {
      state.form.type = button.dataset.type;
      state.form.stars = 1;
      state.form.reason = "";
      renderApp();
    });
  });

  document.querySelectorAll(".star-chip").forEach((button) => {
    button.addEventListener("click", () => {
      state.form.stars = Number(button.dataset.stars);
      renderApp();
    });
  });

  document.querySelectorAll(".reason-chip").forEach((button) => {
    button.addEventListener("click", () => {
      const textarea = document.querySelector("#reason");
      const text = button.dataset.reason;
      textarea.value = textarea.value ? `${textarea.value}；${text}` : text;
      state.form.reason = textarea.value;
    });
  });

  document.querySelector("#category")?.addEventListener("change", (event) => {
    state.form.category = event.target.value;
  });

  document.querySelector("#reason")?.addEventListener("input", (event) => {
    state.form.reason = event.target.value;
  });

  form.addEventListener("submit", submitStarRecord);
}

async function submitStarRecord(event) {
  event.preventDefault();
  state.form.category = document.querySelector("#category").value;
  state.form.reason = document.querySelector("#reason").value.trim();

  if (!state.form.reason) {
    toast("请先填写原因");
    return;
  }

  const button = event.submitter;
  button.disabled = true;
  button.textContent = "正在记录...";

  const { error } = await api.rpc("add_star_record", {
    p_family_id: state.family.family_id,
    p_child_id: state.form.childId,
    p_guardian_id: state.guardian.guardian_id,
    p_type: state.form.type,
    p_stars: Number(state.form.stars),
    p_category: state.form.category,
    p_reason: state.form.reason
  });

  if (error) {
    button.disabled = false;
    state.error = humanError(error);
    renderApp();
    return;
  }

  const score = state.form.type === "praise"
    ? `红色 +${state.form.stars} 星`
    : `黑色 -${state.form.stars} 星`;
  state.form.reason = "";
  await loadAll();
  state.view = "home";
  renderApp();
  toast(`${score} 已记录`);
}

function bindRecordEvents() {
  document.querySelector("#filterChild")?.addEventListener("change", (event) => {
    state.filters.childId = event.target.value;
    renderApp();
  });
  document.querySelector("#filterGuardian")?.addEventListener("change", (event) => {
    state.filters.guardianId = event.target.value;
    renderApp();
  });
  document.querySelector("#filterType")?.addEventListener("change", (event) => {
    state.filters.type = event.target.value;
    renderApp();
  });
}

function bindRewardEvents() {
  document.querySelector("#toggleRewardForm")?.addEventListener("click", () => {
    state.isCustomRewardOpen = !state.isCustomRewardOpen;
    renderApp();
  });

  document.querySelector("#toggleExchangeForm")?.addEventListener("click", () => {
    state.isCustomExchangeOpen = !state.isCustomExchangeOpen;
    renderApp();
  });

  const rewardForm = document.querySelector("#rewardForm");
  if (rewardForm) {
    const nameInput = document.querySelector("#rewardName");
    const costInput = document.querySelector("#rewardCost");
    const descriptionInput = document.querySelector("#rewardDescription");

    nameInput?.addEventListener("input", (event) => {
      state.customReward.name = event.target.value;
    });
    costInput?.addEventListener("input", (event) => {
      state.customReward.costStars = event.target.value;
    });
    descriptionInput?.addEventListener("input", (event) => {
      state.customReward.description = event.target.value;
    });
    rewardForm.addEventListener("submit", submitCustomReward);
  }

  const customExchangeForm = document.querySelector("#customExchangeForm");
  if (customExchangeForm) {
    const exchangeName = document.querySelector("#exchangeName");
    const exchangeCost = document.querySelector("#exchangeCost");
    const exchangeDescription = document.querySelector("#exchangeDescription");

    exchangeName?.addEventListener("input", (event) => {
      state.customExchange.name = event.target.value;
    });
    exchangeCost?.addEventListener("input", (event) => {
      state.customExchange.costStars = event.target.value;
    });
    exchangeDescription?.addEventListener("input", (event) => {
      state.customExchange.description = event.target.value;
    });
    customExchangeForm.addEventListener("submit", submitCustomExchange);
  }

  document.querySelectorAll(".select-reward-child").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedChildId = button.dataset.childId;
      renderApp();
    });
  });

  document.querySelectorAll(".redeem-btn").forEach((button) => {
    button.addEventListener("click", async () => {
      if (!state.selectedChildId) return;
      button.disabled = true;
      button.textContent = "兑换中...";

      const { error } = await api.rpc("redeem_reward", {
        p_family_id: state.family.family_id,
        p_child_id: state.selectedChildId,
        p_guardian_id: state.guardian.guardian_id,
        p_reward_id: button.dataset.rewardId,
        p_note: null
      });

      if (error) {
        state.error = humanError(error);
        renderApp();
        return;
      }

      await loadAll();
      renderApp();
      toast("奖励已兑换");
    });
  });
}

async function submitCustomExchange(event) {
  event.preventDefault();
  const child = getSelectedChild();
  const name = document.querySelector("#exchangeName").value.trim();
  const description = document.querySelector("#exchangeDescription").value.trim();
  const costStars = Number(document.querySelector("#exchangeCost").value);

  state.customExchange = {
    name,
    costStars: Number.isFinite(costStars) ? costStars : "",
    description
  };

  if (!child) {
    toast("请先选择孩子");
    return;
  }

  if (!name) {
    toast("请填写奖品标题");
    return;
  }

  if (!Number.isInteger(costStars) || costStars < 1 || costStars > 999) {
    toast("兑换星星请填写 1 到 999");
    return;
  }

  if (child.available_stars < costStars) {
    toast(`${child.name} 当前星星不足`);
    return;
  }

  const button = event.submitter;
  button.disabled = true;
  button.textContent = "兑换中...";

  const nextSortOrder = Math.max(0, ...state.rewards.map((reward) => Number(reward.sort_order) || 0)) + 1;
  const { data: createdRewards, error: createError } = await api.insert("rewards", {
    family_id: state.family.family_id,
    name,
    description,
    cost_stars: costStars,
    is_active: true,
    sort_order: nextSortOrder
  });

  if (createError) {
    state.error = humanError(createError);
    renderApp();
    return;
  }

  const rewardId = Array.isArray(createdRewards) ? createdRewards[0]?.id : createdRewards?.id;
  if (!rewardId) {
    state.error = "自定义奖品已创建，但没有返回奖品编号，请刷新后再兑换。";
    renderApp();
    return;
  }

  const { error: redeemError } = await api.rpc("redeem_reward", {
    p_family_id: state.family.family_id,
    p_child_id: child.id,
    p_guardian_id: state.guardian.guardian_id,
    p_reward_id: rewardId,
    p_note: description || "自定义奖品兑换"
  });

  if (redeemError) {
    state.error = humanError(redeemError);
    renderApp();
    return;
  }

  state.customExchange = {
    name: "",
    costStars: 10,
    description: ""
  };
  await loadAll();
  renderApp();
  toast("自定义奖品已兑换");
}

async function submitCustomReward(event) {
  event.preventDefault();
  const name = document.querySelector("#rewardName").value.trim();
  const description = document.querySelector("#rewardDescription").value.trim();
  const costStars = Number(document.querySelector("#rewardCost").value);

  state.customReward = {
    name,
    costStars: Number.isFinite(costStars) ? costStars : "",
    description
  };

  if (!name) {
    toast("请填写奖励名称");
    return;
  }

  if (!Number.isInteger(costStars) || costStars < 1 || costStars > 999) {
    toast("星星数量请填写 1 到 999");
    return;
  }

  const button = event.submitter;
  button.disabled = true;
  button.textContent = "保存中...";

  const nextSortOrder = Math.max(0, ...state.rewards.map((reward) => Number(reward.sort_order) || 0)) + 1;
  const { error } = await api.insert("rewards", {
    family_id: state.family.family_id,
    name,
    description,
    cost_stars: costStars,
    is_active: true,
    sort_order: nextSortOrder
  });

  if (error) {
    state.error = humanError(error);
    renderApp();
    return;
  }

  state.customReward = {
    name: "",
    costStars: 10,
    description: ""
  };
  await loadAll();
  renderApp();
  toast("自定义奖励已保存");
}

function bindSettingsEvents() {
  document.querySelector("#switchGuardianBtn")?.addEventListener("click", async () => {
    const role = document.querySelector("#switchGuardian").value;
    const { data, error } = await api.rpc("join_family", {
      p_invite_code: config.defaultInviteCode,
      p_guardian_role_key: role
    });

    if (error) {
      state.error = humanError(error);
      renderApp();
      return;
    }

    state.guardian = {
      guardian_id: data.guardian_id,
      guardian_name: data.guardian_name,
      guardian_role_key: data.guardian_role_key
    };
    saveLocal("guardian", state.guardian);
    await loadAll();
    renderApp();
    toast("操作人已切换");
  });

  document.querySelector("#leaveFamilyBtn")?.addEventListener("click", () => {
    localStorage.removeItem("family-stars-family");
    localStorage.removeItem("family-stars-guardian");
    state.family = null;
    state.guardian = null;
    state.view = "home";
    renderEntry();
  });
}

function getSelectedChild() {
  if (!state.selectedChildId && state.children[0]) {
    state.selectedChildId = state.children[0].id;
  }
  return state.children.find((child) => child.id === state.selectedChildId) || state.children[0];
}

function sumToday(childId, type) {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  return state.starRecords
    .filter((record) => record.child_id === childId && record.type === type && new Date(record.created_at) >= start)
    .reduce((sum, record) => sum + Number(record.stars), 0);
}

function combinedRecords() {
  const starItems = state.starRecords.map((record) => ({
    ...record,
    kind: record.type,
    child_name: record.children?.name || "孩子",
    guardian_name: record.guardians?.name || "家长"
  }));
  const redemptionItems = state.redemptions.map((item) => ({
    ...item,
    kind: "redemption",
    child_name: item.children?.name || "孩子",
    guardian_name: item.guardians?.name || "家长"
  }));
  return [...starItems, ...redemptionItems].sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
}

function formatTime(value) {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function toast(message) {
  const old = document.querySelector(".toast");
  if (old) old.remove();
  const node = document.createElement("div");
  node.className = "toast";
  node.textContent = message;
  document.body.appendChild(node);
  window.setTimeout(() => node.remove(), 2200);
}

function humanError(error) {
  const message = error?.message || String(error);
  if (message.includes("Failed to fetch")) return "连接 Supabase 失败，请检查网络或项目地址。";
  if (message.includes("function") && message.includes("does not exist")) return "数据库函数不存在，请先运行 supabase/schema.sql。";
  return message;
}

function loadLocal(key) {
  try {
    const value = localStorage.getItem(`family-stars-${key}`);
    return value ? JSON.parse(value) : null;
  } catch {
    return null;
  }
}

function saveLocal(key, value) {
  localStorage.setItem(`family-stars-${key}`, JSON.stringify(value));
}

async function ensureCurrentMembership() {
  if (!state.guardian?.guardian_role_key) return;
  const { data, error } = await api.rpc("join_family", {
    p_invite_code: config.defaultInviteCode,
    p_guardian_role_key: state.guardian.guardian_role_key
  });

  if (error) {
    state.error = humanError(error);
    return;
  }

  state.family = {
    family_id: data.family_id,
    family_name: data.family_name
  };
  state.guardian = {
    guardian_id: data.guardian_id,
    guardian_name: data.guardian_name,
    guardian_role_key: data.guardian_role_key
  };
  saveLocal("family", state.family);
  saveLocal("guardian", state.guardian);
}

function createSupabaseApi({ supabaseUrl, supabaseAnonKey }) {
  const authKey = "family-stars-auth";

  async function ensureSession() {
    const saved = loadAuth();
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (saved?.access_token && saved?.expires_at && saved.expires_at > nowSeconds + 90) {
      return saved;
    }

    const response = await fetchWithTimeout(`${supabaseUrl}/auth/v1/signup`, {
      method: "POST",
      headers: {
        apikey: supabaseAnonKey,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ data: { app: "family-stars-h5" } })
    });
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.message || "匿名登录失败");
    }
    saveAuth(data);
    return data;
  }

  async function request(path, options = {}) {
    const session = await ensureSession();
    try {
      const response = await fetchWithTimeout(`${supabaseUrl}${path}`, {
        method: options.method || "GET",
        headers: {
          apikey: supabaseAnonKey,
          Authorization: `Bearer ${session.access_token}`,
          "Content-Type": "application/json",
          ...(options.headers || {})
        },
        body: options.body ? JSON.stringify(options.body) : undefined
      });
      const text = await response.text();
      const data = text ? JSON.parse(text) : null;
      if (!response.ok) {
        return { data: null, error: data || { message: `请求失败：${response.status}` } };
      }
      return { data, error: null };
    } catch (error) {
      return { data: null, error };
    }
  }

  function rpc(name, params) {
    return request(`/rest/v1/rpc/${name}`, {
      method: "POST",
      body: params
    });
  }

  function select(table, query) {
    return request(`/rest/v1/${table}?${query}`);
  }

  function insert(table, row) {
    return request(`/rest/v1/${table}`, {
      method: "POST",
      headers: {
        Prefer: "return=representation"
      },
      body: row
    });
  }

  function loadAuth() {
    try {
      const raw = localStorage.getItem(authKey);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function saveAuth(value) {
    localStorage.setItem(authKey, JSON.stringify(value));
  }

  return { ensureSession, rpc, select, insert };
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 12000) {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal
    });
  } catch (error) {
    if (error.name === "AbortError") {
      throw new Error("连接 Supabase 超时，请检查网络后重试。");
    }
    throw error;
  } finally {
    window.clearTimeout(timeout);
  }
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}
