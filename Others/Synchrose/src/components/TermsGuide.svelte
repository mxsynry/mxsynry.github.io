<section
  class="terms-guide"
  id="terms"
  tabindex="-1"
  aria-labelledby="terms-title"
>
  <header>
    <div>
      <p class="eyebrow">
        Definitions / reviewed <time datetime="2026-11-22">22 Nov 2026</time>
      </p>
      <h2 id="terms-title">Executor terms &amp; tests</h2>
    </div>
    <a href="#catalog">Back to catalog ↑</a>
  </header>
  <p class="guide-intro">
    An executor runs scripts and exposes extra Roblox APIs.
  </p>

  <div class="term-list">
    <details>
      <summary>
        <strong>UNC</strong><span>Unified Naming Convention</span>
      </summary>
      <div class="term-copy">
        <p>
          Shared executor API names and behavior. Its checker tests availability
          and behavior; the original project was archived in May 2024.
        </p>
        <a
          href="https://github.com/unified-naming-convention/NamingStandard"
          target="_blank"
          rel="noreferrer"
        >
          Original specification and checker ↗
        </a>
      </div>
    </details>
    <details>
      <summary>
        <strong>sUNC</strong><span>senS’ Unified Naming Convention</span>
      </summary>
      <div class="term-copy">
        <p>
          A separate behavioral test suite. UNC and sUNC scores are not
          interchangeable. v2 uses an official testing experience and signed
          reports with suite version, build and date.
        </p>
        <a href="https://docs.sunc.io/" target="_blank" rel="noreferrer">
          Official documentation ↗
        </a>
        <a
          href="https://docs.sunc.io/About/test-results/"
          target="_blank"
          rel="noreferrer"
        >
          Result verification ↗
        </a>
      </div>
    </details>
    <details>
      <summary>
        <strong>debUNC</strong><span>debunk Unified Naming Convention</span>
      </summary>
      <div class="term-copy">
        <p>
          An executor function checker with passed, failed, skipped and missing
          results. Current feeds do not provide structured debUNC reports.
        </p>
        <a
          href="https://github.com/alyssagithub/debUNC"
          target="_blank"
          rel="noreferrer"
        >
          Project and test source ↗
        </a>
      </div>
    </details>
    <details>
      <summary>
        <strong>Myriad test</strong><span>General Validity Test</span>
      </summary>
      <div class="term-copy">
        <p>
          Checks executor API behavior (Standards) and protections
          (Vulnerabilities). Compare matching categories and suite versions.
        </p>
        <a
          href="https://github.com/Standard-2/Myriad"
          target="_blank"
          rel="noreferrer"
        >
          Official project ↗
        </a>
        <a
          href="https://github.com/Standard-2/Myriad/blob/main/docs/web-api/results.md"
          target="_blank"
          rel="noreferrer"
        >
          Result categories and metadata ↗
        </a>
      </div>
    </details>
    <details>
      <summary>
        <strong>Executor identification</strong><span>
          Reported name and version
        </span>
      </summary>
      <div class="term-copy">
        <p>
          <code>identifyexecutor</code> reports the environment's name and version.
          The value is self-reported.
        </p>
        <a
          href="https://docs.sunc.io/Miscellaneous/identifyexecutor/"
          target="_blank"
          rel="noreferrer"
        >
          Function reference ↗
        </a>
        <a
          href="https://docs.sunc.io/Miscellaneous/"
          target="_blank"
          rel="noreferrer"
        >
          Identification limits ↗
        </a>
      </div>
    </details>
    <details>
      <summary>
        <strong>Thread identity</strong><span>
          Permission context / “executor level”
        </span>
      </summary>
      <div class="term-copy">
        <p>
          <code>getthreadidentity</code> reports the Luau thread's numeric permission
          context, often called its executor level.
        </p>
        <a
          href="https://docs.sunc.io/Reflection/getthreadidentity/"
          target="_blank"
          rel="noreferrer"
        >
          Thread identity reference ↗
        </a>
        <a
          href="https://docs.sunc.io/Reflection/"
          target="_blank"
          rel="noreferrer"
        >
          Security context documentation ↗
        </a>
      </div>
    </details>
  </div>
  <p class="guide-footnote">
    Keep the suite version, platform, build, date and report with a score.
  </p>
</section>

<style>
  .terms-guide {
    scroll-margin-top: 88px;
    padding-bottom: 48px;
  }
  header {
    display: flex;
    flex-wrap: wrap;
    align-items: end;
    justify-content: space-between;
    gap: 16px;
  }
  h2 {
    margin: 8px 0 0;
    font-size: clamp(1.3rem, 3vw, 1.8rem);
    letter-spacing: -0.03em;
  }
  a {
    color: var(--violet-soft);
    text-underline-offset: 3px;
    font-size: 0.78rem;
  }
  .guide-intro,
  .guide-footnote {
    max-width: 86ch;
    color: #cbc3d4;
    font-size: 0.85rem;
    line-height: 1.7;
  }
  .guide-intro {
    margin: 16px 0 24px;
  }
  .guide-footnote {
    margin: 16px 0 0;
    color: var(--muted);
    font-size: 0.78rem;
  }
  .term-list {
    border-top: 1px solid var(--line-strong);
  }
  details {
    border-bottom: 1px solid var(--line);
  }
  summary {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 24px;
    min-height: 64px;
    padding: 16px 32px 16px 0;
    cursor: pointer;
    position: relative;
    list-style: none;
  }
  summary::-webkit-details-marker {
    display: none;
  }
  summary::after {
    content: "+";
    position: absolute;
    right: 4px;
    color: var(--violet-soft);
    font-size: 1.2rem;
  }
  details[open] summary::after {
    content: "−";
  }
  summary strong {
    min-width: 190px;
    font-size: 0.9rem;
  }
  summary span {
    color: var(--muted);
    font-size: 0.8rem;
  }
  .term-copy {
    max-width: 90ch;
    padding: 0 24px 24px 0;
    font-size: 0.85rem;
    line-height: 1.7;
    color: #cbc3d4;
  }
  .term-copy p {
    margin: 0 0 12px;
  }
  .term-copy a {
    display: inline-block;
    margin: 4px 20px 4px 0;
  }
  code {
    color: var(--violet-soft);
    overflow-wrap: anywhere;
  }
  @media (max-width: 760px) {
    summary {
      display: grid;
      gap: 6px;
    }
    summary strong {
      min-width: 0;
    }
  }
</style>
