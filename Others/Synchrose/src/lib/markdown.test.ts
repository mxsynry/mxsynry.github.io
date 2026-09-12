// @vitest-environment jsdom
import { it, expect } from "vitest";
import { renderMarkdown } from "./markdown";
it("renders Markdown structure while stripping executable HTML", () => {
  const html = renderMarkdown("## Notes\n\n**Bold** and `code`\n\n- One\n- Two\n\n[Source](https://example.com)\n\n<script>alert(1)</script><img src=x onerror=alert(1)>[bad](javascript:alert(1))");
  expect(html).toContain("<h2>Notes</h2>");
  expect(html).toContain("<strong>Bold</strong>");
  expect(html).toContain("<ul>");
  expect(html).toContain('href="https://example.com"');
  const wrapper = document.createElement("div");
  wrapper.innerHTML = html;
  expect(wrapper.querySelector("script,img,[onerror],a[href^='javascript:']")).toBeNull();
  expect(renderMarkdown("[bad](javascript:alert(1))")).not.toContain('href="javascript:');
});
