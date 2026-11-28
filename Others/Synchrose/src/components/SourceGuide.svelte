<section
  class="source-guide"
  id="source-guide"
  aria-labelledby="source-guide-title"
>
  <header>
    <p class="eyebrow">Sources</p>
    <h2 id="source-guide-title">Source notes</h2>
  </header>
  <p class="guide-intro">
    Catalogs report status; linked test reports provide the details.
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
      <dd>Status, pricing, platform variants and test reports.</dd>
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
        Status, pricing and features. WEAO-synced entries reuse WEAO data.
      </dd>
    </div>
    <div>
      <dt>
        <a href="https://robloxscripts.com/" target="_blank" rel="noreferrer">
          RobloxScripts ↗
        </a>
      </dt>
      <dd>
        Script listings. Check the author's repository for source and
        documentation.
      </dd>
    </div>
    <div>
      <dt>
        <a href="https://scriptdumper.com/" target="_blank" rel="noreferrer">
          ScriptDumper ↗
        </a>
      </dt>
      <dd>
        Script sandbox reports. Check the <a
          href="https://scriptdumper.com/privacy"
          target="_blank"
          rel="noreferrer"
        >
          submission policy
        </a> before uploading private code.
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
      <dd>Community reports. Check the date, build and domain discussed.</dd>
    </div>
  </dl>
  <aside aria-label="Interpreting status and safety">
    <h3>Status and safety</h3>
    <p>
      Working describes compatibility. Undetected is a dated detection claim.
      Neither verifies malware safety. Avoid lookalike domains and requests for
      account cookies. <a
        href="https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting"
        target="_blank"
        rel="noreferrer"
      >
        Roblox guidance
      </a>.
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
