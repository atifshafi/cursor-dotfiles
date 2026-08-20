# Polarion HTML Templates

Fixed HTML templates for Polarion import. Use exactly as specified -- Polarion requires this exact format.

---

## Critical Formatting Rules

| Rule | Correct | Wrong |
|------|---------|-------|
| No space after `;` in styles | `font-size:11pt;font-family:Arial` | `font-size: 11pt; font-family: Arial` |
| Bold text | `<span style="font-weight:bold;">Text</span>` | `<b>Text</b>` |
| Escape `&&` | `&amp;&amp;` | `&&` |
| Line break | `<br>` | `\n` |
| Links | `<a href="URL" target="_top">Text</a>` | Plain URL |
| No `<code>` tags | Use plain text, or `<pre>` blocks in Setup/Description only | `<code>text</code>` |
| No `<pre>` in step cells | Inline text with `<br>` and `&nbsp;` for CLI/YAML inside `<td>` | `<pre>` block inside a step `<td>` (breaks 50% column widths) |

---

## Base Span Style

Used in all text content:

```
font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;
```

---

## Setup Section Template

```html
<span style="font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;"><span style="font-weight:bold;">Prerequisites:</span><br>• Item 1<br>• Item 2<br><br><span style="font-weight:bold;">Test Environment:</span><br>• Hub: cluster-name<br>• Console: https://console-url<br></span>
```

---

## Code Blocks (CLI/YAML)

**Scope:** Use `<pre>` blocks ONLY in the Setup section and Description. Do NOT use `<pre>` inside test step table `<td>` cells -- they override the 50% column width and cause uneven rendering. For CLI commands inside steps, use inline text within the `<span>` with `<br>` for line breaks and `&nbsp;` for indentation.

```html
<pre style="font-family:Consolas,Monaco,monospace;font-size:10pt;background-color:#f5f5f5;padding:10px;border:1px solid #ccc;overflow-x:auto;">
# CLI commands or YAML here
oc get pods -n open-cluster-management
</pre>
```

---

## Test Steps Table Header

```html
<tbody><tr><th contenteditable="false" id="testStepKey:step" style="white-space:nowrap;height:12px;text-align:left;vertical-align:top;font-weight:bold;background-color:#F0F0F0;border:1px solid #CCCCCC;padding:5px;width:50%;">Step</th><th contenteditable="false" id="testStepKey:expectedResult" style="white-space:nowrap;height:12px;text-align:left;vertical-align:top;font-weight:bold;background-color:#F0F0F0;border:1px solid #CCCCCC;padding:5px;width:50%;">Expected Result</th></tr>
```

---

## Single Step Row Template

```html
<tr><td style="height:12px;text-align:left;vertical-align:top;line-height:18px;border:1px solid #CCCCCC;padding:5px;"><span style="font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;"><span style="font-weight:bold;">Step {{NUM}}: {{TITLE}}</span><br><br>{{ACTIONS}}</span></td><td style="height:12px;text-align:left;vertical-align:top;line-height:18px;border:1px solid #CCCCCC;padding:5px;"><span style="font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;">{{EXPECTED}}</span></td></tr>
```

Replace:
- `{{NUM}}` -- step number
- `{{TITLE}}` -- step title
- `{{ACTIONS}}` -- numbered actions separated by `<br>`
- `{{EXPECTED}}` -- expected results separated by `<br>` with `•` bullets

---

## Complete Test Steps Table Example

```html
<tbody><tr><th contenteditable="false" id="testStepKey:step" style="white-space:nowrap;height:12px;text-align:left;vertical-align:top;font-weight:bold;background-color:#F0F0F0;border:1px solid #CCCCCC;padding:5px;width:50%;">Step</th><th contenteditable="false" id="testStepKey:expectedResult" style="white-space:nowrap;height:12px;text-align:left;vertical-align:top;font-weight:bold;background-color:#F0F0F0;border:1px solid #CCCCCC;padding:5px;width:50%;">Expected Result</th></tr><tr><td style="height:12px;text-align:left;vertical-align:top;line-height:18px;border:1px solid #CCCCCC;padding:5px;"><span style="font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;"><span style="font-weight:bold;">Step 1: Navigate to Feature Page</span><br><br>1. Log into ACM console as kubeadmin<br>2. Navigate to Feature Area</span></td><td style="height:12px;text-align:left;vertical-align:top;line-height:18px;border:1px solid #CCCCCC;padding:5px;"><span style="font-size:11pt;font-family:Arial,Helvetica,sans-serif;color:#000000;line-height:1.5;">• Feature page loads successfully<br>• Expected elements are visible</span></td></tr></tbody>
```

---

## Bold Text in Steps

```html
<span style="font-weight:bold;">Step Title</span>
<span style="font-weight:bold;">Navigate to:</span>
<span style="font-weight:bold;">Expected:</span>
```

---

## Links

```html
<a href="https://issues.redhat.com/browse/ACM-XXXXX" target="_top">ACM-XXXXX</a>
```

---

## Bullet Lists in HTML

Use `•` character with `<br>` for line breaks:

```html
• First item<br>• Second item<br>• Third item
```

---

## Numbered Lists in HTML

```html
1. First action<br>2. Second action<br>3. Third action
```
