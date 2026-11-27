<script lang="ts"></script>

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
    An executor is third-party software that provides a script execution
    environment and extra APIs for Roblox. Compatibility, thread permissions,
    detection reports and software safety describe different things.
  </p>

  <div class="term-list">
    <details>
      <summary>
        <strong>UNC</strong><span>Unified Naming Convention</span>
      </summary>
      <div class="term-copy">
        <p>
          A community specification for shared executor function names and
          behavior, intended to help scripts work across implementations. The
          original environment checker includes behavioral assertions as well as
          checks for available functions; its coverage is limited.
        </p>
        <p>
          The original repository was archived in May 2024. A UNC percentage
          describes the checks in a particular run, rather than every API or
          every script.
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
          A separate test suite that checks executor functions against its
          expected behavior. Its coverage differs from the original UNC, so the
          two percentages are not interchangeable.
        </p>
        <p>
          The sUNC v2 documentation requires its official testing experience and
          describes signed result reports. Check the linked report’s
          verification status, suite version, executor build and date. A signed
          test result establishes provenance of the report; it does not certify
          a download’s safety.
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
          An open-source executor function test suite with its own checks,
          documented custom functions, and passed, failed, skipped and missing
          outcomes. The project’s spelling is debUNC.
        </p>
        <p>
          Keep its suite version and detailed results with a score. A debUNC
          result cannot be substituted for a UNC or sUNC result. Synchrose’s
          current feeds do not supply structured debUNC results.
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
          An open-source suite for executor standards, functionality and
          mitigation checks. <strong>Standards</strong> results describe API
          behavior; <strong>Vulnerabilities</strong> results describe the protections
          exercised by those checks.
        </p>
        <p>
          A bare “Myriad score” is incomplete without its category. Compare the
          same category and suite version, and review failures, exclusions and
          ambiguous results. Passing the included checks does not establish that
          software is malware-free.
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
          <code>identifyexecutor</code> reports the executor’s name and version. This
          is an informational value supplied by the environment, rather than a secure
          way to authenticate the program or its publisher.
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
          <code>getthreadidentity</code> reports the running Luau thread’s numeric
          security context, which relates to permissions and capabilities. This differs
          from the executor’s name and version.
        </p>
        <p>
          A claimed level is not a compatibility score, a performance measure or
          evidence of trust. Treat the number as context for permission
          behavior, rather than ranking products by the highest advertised
          identity.
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
    For any test result, keep the suite and version, result category, executor
    build, platform, run date and original report together. Synchrose displays
    catalog claims; it does not run these test suites or verify their reports.
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
