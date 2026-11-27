<script lang="ts"></script>

<section
  class="source-guide"
  id="source-guide"
  aria-labelledby="source-guide-title"
>
  <header>
    <p class="eyebrow">Read the evidence</p>
    <h2 id="source-guide-title">Check a claim before trusting it</h2>
  </header>
  <p class="guide-intro">
    Use catalogs to find a report, original documentation to understand a test,
    and dated evidence to assess a claim. A listing, community badge or clean
    scan cannot guarantee that an executor or script is safe.
  </p>
  <dl>
    <div>
      <dt>
        <a
          href="https://voxlis.net/wiki/roblox"
          target="_blank"
          rel="noreferrer"
        >
          Voxlis ↗
        </a>
      </dt>
      <dd>
        Executor and external listings with reported status, pricing and
        benchmarks. Synchrose retains Voxlis claims under its name; check the
        original entry for context and changes.
      </dd>
    </div>
    <div>
      <dt>
        <a
          href="https://bypass.tools/executors"
          target="_blank"
          rel="noreferrer"
        >
          bypass.tools ↗
        </a>
      </dt>
      <dd>
        A live catalog source in Synchrose, with reported status, platform,
        pricing and feature-based scores. Rows marked WEAO-synced reuse upstream
        data; agreement with WEAO is catalog coverage rather than an independent
        test.
      </dd>
    </div>
    <div>
      <dt>
        <a href="https://robloxscripts.com/" target="_blank" rel="noreferrer">
          RobloxScripts ↗
        </a>
      </dt>
      <dd>
        Script listings and project discovery. Follow a test listing back to its
        author’s repository and documentation. A listed or approved upload is
        not an independent security audit.
      </dd>
    </div>
    <div>
      <dt>
        <a href="https://scriptdumper.com/" target="_blank" rel="noreferrer">
          ScriptDumper ↗
        </a>
      </dt>
      <dd>
        The service describes sandbox analysis of script behavior, including
        attempted network calls and recovered code. It says results are not
        guaranteed. A clean script report does not authenticate an executor
        installer. Review its <a
          href="https://scriptdumper.com/privacy"
          target="_blank"
          rel="noreferrer"
        >
          submission privacy policy
        </a> before uploading code.
      </dd>
    </div>
    <div>
      <dt>
        <a
          href="https://www.reddit.com/r/robloxhackers/"
          target="_blank"
          rel="noreferrer"
        >
          r/robloxhackers ↗
        </a>
      </dt>
      <dd>
        Community discussion and incident reports. Check the post date, original
        evidence, build and domain involved. Treat recommendations and
        allegations as leads to investigate; older guides may refer to retired
        products.
      </dd>
    </div>
  </dl>
  <aside aria-label="Interpreting status and safety">
    <h3>Working, undetected and safe mean different things</h3>
    <p>
      <strong>Working</strong> is a source’s functionality or
      build-compatibility report. <strong>Undetected</strong> is a detection claim
      at a point in time. Neither establishes malware safety or prevents future account
      enforcement. A source’s “Verified” badge reflects that source’s criteria.
    </p>
    <p>
      Check the publisher and exact domain, inspect the original report, and
      keep device protections enabled. Avoid lookalike downloads and requests
      for account cookies or credentials. Roblox warns that exploiting violates
      its rules and that exploit downloads can contain malware. <a
        href="https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting"
        target="_blank"
        rel="noreferrer"
      >
        Read Roblox’s guidance ↗
      </a>
    </p>
  </aside>
</section>

<style>
  .source-guide {
    scroll-margin-top: 88px;
    padding: 0 0 48px;
  }
  h2 {
    margin: 8px 0 0;
    font-size: clamp(1.3rem, 3vw, 1.8rem);
    letter-spacing: -0.03em;
  }
  h3 {
    margin: 0 0 12px;
    color: var(--amber);
    font-size: 0.95rem;
  }
  a {
    color: var(--violet-soft);
    text-underline-offset: 3px;
  }
  .guide-intro {
    max-width: 86ch;
    margin: 16px 0 24px;
    color: #cbc3d4;
    font-size: 0.85rem;
    line-height: 1.7;
  }
  dl {
    margin: 0;
    border-top: 1px solid var(--line-strong);
  }
  dl > div {
    display: grid;
    grid-template-columns: 190px minmax(0, 1fr);
    gap: 24px;
    padding: 20px 0;
    border-bottom: 1px solid var(--line);
  }
  dt {
    margin: 0;
    font:
      600 0.85rem/1.7 Inter,
      sans-serif;
    text-transform: none;
    letter-spacing: normal;
  }
  dd {
    margin: 0;
    overflow: visible;
    white-space: normal;
    font:
      0.85rem/1.7 Inter,
      sans-serif;
    color: #cbc3d4;
  }
  aside {
    margin-top: 24px;
    padding: 24px;
    border-left: 2px solid var(--amber);
    background: var(--panel);
  }
  aside p {
    max-width: 90ch;
    margin: 12px 0 0;
    color: #cbc3d4;
    font-size: 0.85rem;
    line-height: 1.7;
  }
  @media (max-width: 760px) {
    dl > div {
      grid-template-columns: 1fr;
      gap: 8px;
    }
    aside {
      padding: 20px;
    }
  }
</style>
