# Concept Library — WordPress 核心概念精華
# AK Threads Booster 格式：/draft 改寫時引用的洞察素材
# 來源：hostswp.com/blog/ 文章精華萃取

---

## SSL 憑證

**核心洞察：**
- 沒有 SSL，訪客表單填的個資是明文傳輸，等於寫在明信片上寄
- Chrome 顯示「不安全」= 跳出率暴增，不用等 Google 降權訪客就跑了
- 免費 Let's Encrypt 跟付費 SSL 加密強度一模一樣，大部分網站用免費就夠
- 2026 年全球前 10 萬大網站有 92.6% 用 HTTPS，沒裝 SSL 已是極少數
- 最常踩的坑：Cloudflare SSL 選「Flexible」→ 無限重新導向，要選「Full (Strict)」

**適合的故事切入點：**
- 「客戶說網站壞了，其實是 SSL 到期了」
- 「我花了 3 小時找無限重新導向的原因，最後發現是 Cloudflare 設定選錯」

---

## WordPress 更新 / PHP 版本

**核心洞察：**
- 2025 年 90% 被駭的 WordPress 網站是因為沒更新
- 每天約有 13,000 個 WordPress 網站被駭客入侵
- 「能跑就不要動」這個想法很危險，但「亂更新」更危險
- PHP 8.0 比 PHP 7.4 快 20-30%，升級 PHP 可能是最簡單的免費效能提升
- 更新後白畫面的最常見原因：外掛不相容，不是 WordPress 核心壞掉
- 正確做法：次版本（安全修補）快更，主版本等 3-5 天觀察社群反應

**適合的故事切入點：**
- 「客戶的 WordPress 從 6.3 更新到 6.5 後白畫面，結果是兩年沒更新的表單外掛」
- 「我建議客戶更新前先備份，他說太麻煩，後來修復花了更多時間」

---

## WordPress vs Shopify

**核心洞察：**
- 台灣做電商，70% 情況建議選 WordPress（在地金流綠界/藍新更成熟）
- 跨境電商做海外市場？Shopify 多幣別/國際金流更方便
- 三年持有成本：月營收 10 萬的電商，WordPress 約 3-5 萬，Shopify 約 8-11 萬（含手續費）
- Shopify 裝 3-5 個 App 之後，每月多 US$30-100 的 App 費累積很快
- 「選哪個沒有標準答案，只有哪個比較適合你」

**適合的故事切入點：**
- 「客戶問我 WordPress 還是 Shopify，我問他的主力市場在哪」
- 「有客戶算了三年成本後才發現，Shopify 的手續費已經超過架 WordPress 的費用」

---

## WordPress vs Wix

**核心洞察：**
- Wix 像租房子，WordPress 像買房子，想裝修就裝修
- 有客戶 Wix 架好後想加 SEO 部落格、購物功能、改版面，每件事都碰壁，最後花兩萬多搬到 WordPress
- Wix 免費方案的真正功能是「讓你嚐到甜頭，然後一步步推向付費方案」
- 2-3 年後，WordPress 總成本反而比 Wix 低
- 如果你要靠網站帶來生意，答案只有一個

**適合的故事切入點：**
- 「有一個客戶問我，Wix 不是很簡單嗎？我說，簡單跟能用是兩件事」
- 「我見過太多人被 Wix 免費方案吸引進去，兩年後搬家費比一開始就用 WordPress 還貴」

---

## WordPress vs Blogger

**核心洞察：**
- 全球 43% 的網站用 WordPress，Blogger 市佔率已遠低於此
- 同樣主題的文章，WordPress 版本排名平均比 Blogger 高 2-3 個位置
- 搜尋結果第一頁和第二頁的差距：流量差 10 倍
- Blogger 的資料存在 Google 伺服器，Google 有紀錄隨時關閉產品
- 「早知道一開始就用 WordPress，省得搬家還要重做 SEO」是客戶最常說的話

**適合的故事切入點：**
- 「用 Blogger 寫了兩年，搬到 WordPress 後流量多了 3 倍」
- 「有人問我 Blogger 不是免費嗎，我說免費的代價有時候比你想像的大」

---

## WordPress 架站費用

**核心洞察：**
- 標準 WordPress 網站年費約 $3,000-15,000，大部分人的最佳選擇是 $5,000-8,000 那段
- 主機是最重要的投資，便宜主機省下來的錢，SEO 排名和使用者體驗賠掉的更多
- 找人架站 vs 自己架：金錢成本 vs 時間成本，兩邊都有代價
- Cloudways 每月 $14 美元起，是性價比最好的主機選擇
- 「很多文章故意講得模糊，就是不給你一個明確的數字」

**適合的故事切入點：**
- 「客戶問架站要多少錢，我說看你想要哪個方案，便宜的也能跑，快的另一回事」
- 「有客戶選了最便宜的主機，結果網站速度超慢，SEO 跑了半年沒起色」

---

## WordPress 架站步驟

**核心洞察：**
- 架網站只需要三樣東西：網域（門牌）+ 主機（家）+ SSL（安全鎖）
- WordPress.org（自架）vs WordPress.com（託管）：正式用的選 .org
- 新手最常踩的坑：裝太多外掛拖累效能、忽略 SEO 基礎設定、沒有做定期備份
- WooCommerce 驅動全球 33.4% 的電商網站，生態系成熟
- 外掛超過 60,000 個，想做什麼功能幾乎都找得到

**適合的故事切入點：**
- 「我第一次架 WordPress 網站裝了 30 幾個外掛，網站慢到快崩潰」
- 「很多人不知道 WordPress.org 和 WordPress.com 是完全不同的東西」

---

## LINE Pay / WooCommerce 金流

**核心洞察：**
- 台灣 LINE 使用率達 2100 萬用戶，50 萬黏著會員
- LINE Pay 手續費 3%，七個工作天結清，接受各家銀行金融卡與信用卡
- 串接 LINE Pay = 可收台灣、日本、泰國用戶的款項
- 台灣電子支付使用人數 2025 年底達 3,765 萬，本地金流整合是必要條件

**適合的故事切入點：**
- 「客戶的 WooCommerce 電商沒有 LINE Pay，結帳流失率很高」
- 「很多人不知道 LINE Pay 還可以串 LINE 官方帳號機器人，讓客戶在聊天中直接付款」

---

## 發文前 Checklist（每次必做）

1. **用 `post_threads.ps1` 發文** — 禁止直接用 PowerShell string body，中文會亂碼
2. **排程時間帶時區** — `-ScheduleAt "2026-xx-xxT16:40:00+08:00"`
3. **LINE 預覽** — 排程前 1 小時發 LINE 給用戶確認
4. **字數控制** — 150-350 字，超過要刪

---

## 主題輪替清單（供 /draft 參考）
1. SSL 設定與 HTTPS 轉址
2. WordPress 安全更新策略
3. PHP 版本升級效能提升
4. WordPress vs Shopify 選擇指南
5. WordPress vs Wix 成本分析
6. WordPress vs Blogger SEO 差距
7. WordPress 架站費用完整拆解
8. WooCommerce 金流串接（綠界/藍新/LINE Pay）
9. 外掛選擇與效能優化
10. 主機搬家流程與注意事項
11. 備份策略（UpdraftPlus）
12. WordPress 被駭後的救援步驟
13. Elementor 排版常見問題
14. Cloudflare 搭配 WordPress 設定
15. WordPress 維護排程建議
