import { useEffect, type ReactNode } from 'react';
import { POSTS, postBySlug, type Block, type Post } from './posts';
import { VIZ } from './Viz';
import './blog.css';

// The bank's journal: /blog lists the posts, /blog/<slug> is one article. Black on white in the EPRIS Daily manner
// (Cousine for headings, Nunito for text), its own scroll box because the bank's body never scrolls.

const FONTS = 'https://fonts.googleapis.com/css2?family=Cousine:wght@400;700&family=Nunito:ital,wght@0,400;0,500;0,600;0,700;1,400&display=swap';

const day = (iso: string) => new Date(iso + 'T12:00:00Z').toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }).toUpperCase();

function usePage(title: string, desc: string) {
  useEffect(() => {
    if (!document.querySelector(`link[href="${FONTS}"]`)) {
      const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = FONTS; document.head.appendChild(l);
    }
    document.title = title;
    const meta = (sel: string, attr: string, v: string) => { const m = document.querySelector<HTMLMetaElement>(sel); const old = m?.getAttribute(attr); m?.setAttribute(attr, v); return () => { if (m && old != null) m.setAttribute(attr, old); }; };
    const undo = [meta('meta[name="theme-color"]', 'content', '#ffffff'), meta('meta[name="color-scheme"]', 'content', 'light'), meta('meta[name="description"]', 'content', desc)];
    return () => undo.forEach(f => f());
  }, [title, desc]);
}

function Mark({ className }: { className?: string }) {
  return <img className={className} src="/icons/mark-white.svg" alt="" aria-hidden />;
}

function Head() {
  return (
    <header className="tb-head">
      <div className="tb-head-in">
        <a className="tb-back-site" href="/">Bank</a>
        <a className="tb-brand" href="/blog" aria-label="TaxTech blog"><span className="tb-brand-mark"><Mark /></span><span>blog</span></a>
        <a className="tb-open" href="/#register">Open account</a>
      </div>
    </header>
  );
}

function Foot() {
  return (
    <footer className="tb-foot">
      <div className="tb-foot-in">
        <a href="/" className="tb-lockup" aria-label="TaxTech">
          <Mark />
          <span><b>TaxTech</b></span>
        </a>
        <nav>
          <a href="/">Bank</a><a href="/roma">Roma Live</a><a href="/blog">Blog</a>
          <a href="https://apps.apple.com/ua/app/tax-tech-digital-finance-lab/id6830268604" target="_blank" rel="noreferrer">App Store</a>
        </nav>
        <p>© {new Date().getFullYear()} TaxTech</p>
      </div>
    </footer>
  );
}

// a small highlighter for the SQL and pseudo-code snippets: keywords, strings, numbers, comments
const KW = /\b(UPDATE|SET|WHERE|AND|SELECT|FROM|INSERT|INTO|VALUES|RETURNING|IF|THEN|ELSE|NOT|NULL|new|processing|replay|conflict)\b/g;
function hl(code: string): ReactNode[] {
  return code.split('\n').flatMap((line, li, all) => {
    const m = line.match(/^(.*?)(--.*|#.*)?$/) as RegExpMatchArray;
    const parts: ReactNode[] = [];
    m[1].split(/('[^']*'|\b\d+(?:\.\d+)?\b|\b[A-Za-z]+\b)/).forEach((tok, i) => {
      if (/^'/.test(tok)) parts.push(<span key={i} className="s">{tok}</span>);
      else if (/^\d/.test(tok)) parts.push(<span key={i} className="n">{tok}</span>);
      else if (new RegExp(KW.source).test(tok) && /^[A-Za-z]+$/.test(tok) && tok === tok.toUpperCase()) parts.push(<span key={i} className="k">{tok}</span>);
      else parts.push(tok);
    });
    if (m[2]) parts.push(<span key="c" className="c">{m[2]}</span>);
    if (li < all.length - 1) parts.push('\n');
    return parts;
  });
}

function Body({ blocks }: { blocks: Block[] }) {
  return (
    <>
      {blocks.map((b, i) => {
        if ('p' in b) return <p key={i} className="tb-p">{b.p}</p>;
        if ('h2' in b) return <h2 key={i} className="tb-h2">{b.h2}</h2>;
        if ('quote' in b) return <blockquote key={i} className="tb-quote"><p>“{b.quote}”</p>{b.by && <cite>{b.by}</cite>}</blockquote>;
        if ('ul' in b) return <ul key={i} className="tb-ul">{b.ul.map((x, j) => <li key={j}>{x}</li>)}</ul>;
        if ('code' in b) return <pre key={i} className="tb-code"><code>{hl(b.code)}</code></pre>;
        if ('viz' in b) { const V = VIZ[b.viz]; return V ? <V key={i} /> : null; }
        if ('table' in b) return (
          <table key={i} className="tb-table"><thead><tr>{b.table.head.map(h => <th key={h}>{h}</th>)}</tr></thead>
            <tbody>{b.table.rows.map((r, j) => <tr key={j}>{r.map((c, k) => <td key={k}>{c}</td>)}</tr>)}</tbody></table>
        );
        if ('callout' in b) return <aside key={i} className="tb-callout"><b>{b.callout[0]}</b>{b.callout[1]}</aside>;
        if ('phones' in b) return (
          <figure key={i} className="tb-fig tb-phones">
            <div>{b.phones.map(ph => <div key={ph.img} className="tb-phone"><img src={ph.img} alt={ph.cap} loading="lazy" decoding="async" /><span>{ph.cap}</span></div>)}</div>
            <figcaption>{b.cap}</figcaption>
          </figure>
        );
        return (
          <figure key={i} className={`tb-fig${b.wide ? ' tb-wide' : ''}`}>
            <img src={b.img} alt={b.cap} loading="lazy" decoding="async" />
            <figcaption>{b.cap}</figcaption>
          </figure>
        );
      })}
    </>
  );
}

function Article({ post }: { post: Post }) {
  usePage(`${post.title} | TaxTech Blog`, post.dek);
  return (
    <article className="tb-article">
      <div className="tb-bar"><a className="tb-pill" href="/blog"><span aria-hidden>←</span> Back</a></div>
      <figure className="tb-cover">
        <img src={post.cover} alt={post.coverCap} fetchPriority="high" />
      </figure>
      <div className="tb-meta"><span>{day(post.date)}</span><i /><span>Viacheslav Munister</span><i /><span className="tb-sec">{post.section}</span></div>
      <h1 className="tb-h1">{post.title}</h1>
      <p className="tb-dek">{post.dek}</p>
      <ul className="tb-tags">{post.tags.map(t => <li key={t}>{t}</li>)}</ul>
      <div className="tb-body"><Body blocks={post.body} /></div>
      <div className="tb-end">
        <span className="tb-end-mark"><Mark /></span>
        <p>Viacheslav Munister is the product architect and developer of TaxTech.</p>
        <a className="tb-pill tb-pill-dark" href="/#register">Open an account <span aria-hidden>↗</span></a>
      </div>
    </article>
  );
}

function Index() {
  usePage('Blog | TaxTech', 'Notes from the people who build TaxTech: design, the card, Rome and the bank underneath.');
  return (
    <main className="tb-index">
      <p className="tb-eyebrow">TaxTech / journal</p>
      <h2 className="tb-index-h">Articles</h2>
      <ul className="tb-list">
        {POSTS.map(p => (
          <li key={p.slug}>
            <a className="tb-row" href={`/blog/${p.slug}`}>
              <span className="tb-row-img"><img src={p.thumb ?? p.cover} alt="" decoding="async" /></span>
              <span className="tb-row-text">
                <span className="tb-eyebrow">{p.section} · {day(p.date)}</span>
                <span className="tb-row-h">{p.title}</span>
                <span className="tb-row-dek">{p.dek}</span>
                <span className="tb-eyebrow tb-by">By Viacheslav Munister</span>
                <span className="tb-pill">Read article <span aria-hidden>↗</span></span>
              </span>
            </a>
          </li>
        ))}
      </ul>
    </main>
  );
}

export default function Blog({ slug }: { slug?: string }) {
  const post = slug ? postBySlug(slug) : undefined;
  return (
    <div className="tb">
      <Head />
      {slug && !post
        ? <main className="tb-index"><p className="tb-eyebrow">404</p><h2 className="tb-index-h">Not found</h2><p className="tb-p"><a className="tb-pill" href="/blog">All articles</a></p></main>
        : post ? <Article post={post} /> : <Index />}
      <Foot />
    </div>
  );
}
