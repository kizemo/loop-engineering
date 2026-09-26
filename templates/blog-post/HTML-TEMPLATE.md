# HTML 模板约束 · Loop Engineering 博文

> 所有 loop engineering 主题博文的 HTML 版本必须遵循同一模板,确保视觉一致。

---

## 一、模板约束(yingdao 紫 #4f46e5)

### 1.1 配色

| 用途 | 颜色 |
|---|---|
| **主色** | `#4f46e5`(yingdao 紫,已在 workspace 中复核) |
| 文字主色 | `#1f2937`(深灰) |
| 文字次色 | `#6b7280`(中灰) |
| 背景 | `#ffffff`(白) |
| 卡片背景 | `#f9fafb`(极浅灰) |
| 表格边框 | `#e5e7eb`(浅灰) |
| 引用块左边框 | `#4f46e5`(主色) |
| 代码块背景 | `#f3f4f6`(浅灰) |
| 警告/红框 | `#dc2626`(red-600) |

### 1.2 字体

| 用途 | 字体 |
|---|---|
| 中文 | `"PingFang SC", "Microsoft YaHei", sans-serif` |
| 英文/代码 | `Menlo, Monaco, Consolas, "Courier New", monospace` |
| 正文 | 16px / 1.7 line-height |
| 标题 | 1.5x-2.0x 倍率递增 |

### 1.3 容器

- 最大宽度:`800px`(正文区)
- 边距:`24px`(卡片内)/ `48px`(章节间)
- 圆角:`8px`(卡片)/ `4px`(小元素)
- 阴影:`0 1px 3px rgba(0,0,0,0.1)`(卡片)

---

## 二、HTML 结构(从 md 渲染时遵守)

### 2.1 frontmatter 转 HTML

```html
<header class="post-header">
    <h1 class="post-title"><标题></h1>
    <blockquote class="post-summary"><80 字摘要></blockquote>
    <div class="post-keywords">
        <strong>关键词:</strong><span class="keyword">关键词 1</span>、...
    </div>
</header>
```

### 2.2 章节结构

```html
<article class="post-content">
    <section id="section-1">
        <h2>一、章节标题</h2>
        <p>段落正文</p>
        <blockquote>引用块</blockquote>
        <pre><code class="language-bash">代码块</code></pre>
        <table>表格</table>
    </section>
    <section id="section-2">...</section>
</article>
```

### 2.3 表格样式

```css
table {
    width: 100%;
    border-collapse: collapse;
    margin: 24px 0;
}
th {
    background: #4f46e5;
    color: white;
    padding: 12px;
    text-align: left;
}
td {
    padding: 12px;
    border-bottom: 1px solid #e5e7eb;
}
tr:nth-child(even) {
    background: #f9fafb;
}
```

### 2.4 引用块样式

```css
blockquote {
    border-left: 4px solid #4f46e5;
    background: #f9fafb;
    padding: 16px 20px;
    margin: 24px 0;
    color: #1f2937;
    font-style: italic;
}
```

### 2.5 代码块样式

```css
pre {
    background: #f3f4f6;
    border-radius: 4px;
    padding: 16px;
    overflow-x: auto;
}
code {
    font-family: Menlo, Monaco, Consolas, monospace;
    font-size: 14px;
}
:not(pre) > code {
    background: #f3f4f6;
    padding: 2px 6px;
    border-radius: 3px;
    color: #4f46e5;
}
```

---

## 三、生成 HTML 的工具

### 3.1 推荐工具

| 工具 | 适用场景 |
|---|---|
| **`pandoc` + 自定义 CSS** | 最灵活,推荐(已用 2 篇) |
| **Obsidian Export** | 已用 Obsidian 写 md 时的便利选项 |
| **Hugo / Jekyll** | 长期博客站(超出本项目范围) |

### 3.2 pandoc 命令

```bash
pandoc -f markdown -t html5 \
    --standalone \
    --css=post.css \
    --metadata title="<标题>" \
    -o post.html \
    post.md
```

### 3.3 CSS 文件

CSS 文件路径:`assets/post.css`,模板已包含(在 workspace 中维护)。

---

## 四、HTML 标题锚点

每个 `<h2>` 自动生成 id(从中文标题转拼音/英文 slug):

```javascript
// 渲染时加入(可选)
document.querySelectorAll('h2').forEach(h => {
    h.id = h.textContent.replace(/[一二三四五六七八九十、. ]/g, '').toLowerCase();
});
```

或者手动指定:`<h2 id="section-overview">一、概览</h2>`

---

## 五、移动端适配

- 容器宽度:`max-width: 800px`(桌面) → `100%; padding: 16px`(移动)
- 表格:横向滚动(`overflow-x: auto`)
- 代码块:横向滚动(同上)
- 字号:正文 16px(桌面) → 15px(移动)

---

## 六、SEO 与 meta

每篇 HTML head 必含:

```html
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="<80 字摘要>">
<meta name="keywords" content="<10 个关键词,英文逗号>">
<meta name="author" content="loop-engineering contributors">
<title><标题></title>
```

---

## 七、参考实现

已发布的 2 篇 loop engineering 博文 HTML 可作为模板参考:

- `loopx-让AI-Agents连续工作200小时还不跑偏的开源控制面.html`
- `loop-engineering-in-cc-haha-2026-09-25.html`

均在 `E:\办公文件\H AI\项目研究\` 目录下,样式严格遵循本规范。