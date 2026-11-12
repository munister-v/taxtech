import { useEffect, useState } from 'react';
import { api, returnHere, type ApiErr, type Me, type PayRes, type QrInvoice } from './cityApi';
import { initialLandingLang, landingText } from '../landingLang';
import './payqr.css';

// /pay/<code>: what a phone opens after scanning a Roma Live QR. The place, the amount, the payer's account; one
// confirmation (plus 3-D Secure from 1000 TAX) and the payment goes through the bank's POS pipeline. The screen that
// shows the code sees it paid within a couple of seconds.

const CAT_NAME: Record<string, [string, string]> = {
  cafe: ['Кава', 'Coffee'], food: ['Ресторан', 'Restaurant'], bar: ['Бар', 'Bar'], shop: ['Крамниця', 'Shop'],
  stay: ['Готель', 'Hotel'], culture: ['Культура', 'Culture'], money: ['Банк', 'Bank'], health: ['Аптека', 'Pharmacy'],
};
const fmt = (n: number) => n.toLocaleString('uk-UA', { maximumFractionDigits: 2 }).replace(/\s/g, ' ');

type Step = 'loading' | 'review' | 'otp' | 'paying' | 'done' | 'closed' | 'missing';

export default function PayQR({ code }: { code: string }) {
  const lang = initialLandingLang();
  const t = (uk: string, en: string) => landingText(lang, uk, en);
  const [inv, setInv] = useState<QrInvoice | null>(null);
  const [me, setMe] = useState<Me | null | undefined>(undefined);
  const [step, setStep] = useState<Step>('loading');
  const [otp, setOtp] = useState({ challenge: '', code: '', hint: '', phone: '' });
  const [res, setRes] = useState<PayRes & { status?: string } | null>(null);
  const [err, setErr] = useState('');
  const [left, setLeft] = useState(0);

  useEffect(() => { document.title = 'TaxTech · Pay'; }, []);
  useEffect(() => {
    api<QrInvoice>(`/api/city/qr/${encodeURIComponent(code)}`).then(q => {
      setInv(q); setLeft(q.expires_in);
      setStep(q.status === 'pending' ? 'review' : q.status === 'paid' || q.status === 'declined' ? 'done' : 'closed');
    }).catch(() => setStep('missing'));
    api<Me>('/api/city/me').then(setMe).catch(() => setMe(null));
  }, [code]);
  useEffect(() => {
    if (step !== 'review' && step !== 'otp') return;
    const iv = window.setInterval(() => setLeft(x => { if (x <= 1) { setStep('closed'); return 0; } return x - 1; }), 1000);
    return () => clearInterval(iv);
  }, [step]);

  const confirm = async (tds?: string) => {
    if (!inv) return;
    setErr(''); setStep('paying');
    try {
      const d = await api<PayRes & QrInvoice>(`/api/city/qr/${encodeURIComponent(code)}/confirm`, { card_id: me?.card_id || undefined, tds_session: tds });
      if (d.outcome === 'sca_required') {
        const ch = await api<{ challenge_id: string; demo_otp: string; masked_phone?: string }>('/api/3ds/challenge', { amount: inv.amount, recipient: `Roma · ${inv.name}` });
        setOtp({ challenge: ch.challenge_id, code: '', hint: ch.demo_otp, phone: ch.masked_phone || '' });
        setStep('otp');
        return;
      }
      if (d.outcome === 'closed') { setInv(d); setStep(d.status === 'paid' ? 'done' : 'closed'); return; }
      setInv(d); setRes(d); setStep('done');
      if (typeof d.new_balance === 'number') setMe(m => (m ? { ...m, balance: d.new_balance! } : m));
    } catch (e) {
      const x = e as ApiErr;
      if (x.status === 401) setMe(null);
      setErr(x.message); setStep('review');
    }
  };
  const verify = async () => {
    setErr(''); setStep('paying');
    try {
      const v = await api<{ session_token: string }>('/api/3ds/verify', { challenge_id: otp.challenge, otp_code: otp.code });
      await confirm(v.session_token);
    } catch (e) { setErr((e as Error).message); setStep('otp'); }
  };

  const mmss = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
  const paid = inv?.status === 'paid';

  return (
    <div className="pq">
      <header className="pq-top">
        <img src="/icons/mark-white.svg" alt="TaxTech" />
        <span>TaxTech <b>Pay</b></span>
      </header>

      {step === 'loading' && <div className="pq-wait"><i /></div>}
      {step === 'missing' && <section className="pq-card"><h1>{t('Код не знайдено', 'Code not found')}</h1><a className="pq-btn ghost" href="/roma">Roma Live</a></section>}

      {inv && step !== 'missing' && step !== 'loading' && (
        <section className={`pq-card${step === 'done' ? (paid ? ' ok' : ' no') : ''}`}>
          <span className="pq-kind">{t(...(CAT_NAME[inv.cat] || ['Місце', 'Place']))}{inv.rione ? ` · ${inv.rione}` : ''} · Roma</span>
          <h1>{inv.name}</h1>
          <div className="pq-amount"><b>{fmt(inv.amount)}</b><small>TAX</small></div>

          {step === 'done' ? (
            <div className="pq-result">
              <div className="pq-mark">{paid ? <svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg> : <svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18" /></svg>}</div>
              <h2>{paid ? t('Оплачено', 'Paid') : t('Відхилено', 'Declined')}</h2>
              <dl>
                {inv.auth_code && <div><dt>{t('Код авторизації', 'Auth code')}</dt><dd>{inv.auth_code}</dd></div>}
                {inv.rrn && <div><dt>RRN</dt><dd>{inv.rrn}</dd></div>}
                {inv.response_code && <div><dt>{t('Відповідь', 'Response')}</dt><dd>{inv.response_code}{res?.message ? ` · ${res.message}` : ''}</dd></div>}
                {inv.three_ds && <div><dt>SCA</dt><dd>3-D Secure</dd></div>}
                {typeof res?.fee === 'number' && paid && <div><dt>MDR</dt><dd>{fmt(res.fee)} TAX</dd></div>}
                {me && <div><dt>{t('Баланс', 'Balance')}</dt><dd>{fmt(me.balance)} TAX</dd></div>}
              </dl>
              <a className="pq-btn ghost" href="/roma">{t('Дивитися на карті', 'See it on the map')}</a>
            </div>
          ) : step === 'closed' ? (
            <div className="pq-result">
              <h2>{inv.status === 'cancelled' ? t('Скасовано', 'Cancelled') : t('Час вийшов', 'Expired')}</h2>
              <p className="pq-note">{t('Попросіть новий код.', 'Ask for a new code.')}</p>
            </div>
          ) : me === null ? (
            <div className="pq-act">
              <a className="pq-btn" href="/#login" onClick={() => returnHere()}>{t('Увійти й оплатити', 'Sign in to pay')}</a>
              <a className="pq-btn ghost" href="/#register" onClick={() => returnHere()}>{t('Відкрити рахунок', 'Open an account')}</a>
              <p className="pq-note">{t('Дійсний ще', 'Valid for')} {mmss}</p>
            </div>
          ) : me && (step === 'review' || step === 'paying') ? (
            <div className="pq-act">
              <div className="pq-from">
                <span>{t('З рахунку', 'From')}</span>
                <b>{me.name} · {me.card_last4 ? `•••• ${me.card_last4}` : me.who}</b>
                <em>{fmt(me.balance)} TAX</em>
              </div>
              {me.balance < inv.amount && <p className="pq-warn">{t('Бракує коштів на рахунку.', 'Not enough on the account.')}</p>}
              <button type="button" className="pq-btn" disabled={step === 'paying'} onClick={() => confirm()}>
                {step === 'paying' ? t('Авторизація…', 'Authorising…') : `${t('Підтвердити', 'Confirm')} · ${fmt(inv.amount)} TAX`}
              </button>
              {inv.sca && <p className="pq-note">{t('Від 1000 TAX потрібен 3-D Secure.', '3-D Secure from 1000 TAX.')}</p>}
              <p className="pq-note">{t('Дійсний ще', 'Valid for')} {mmss}</p>
            </div>
          ) : step === 'otp' ? (
            <form className="pq-act" onSubmit={e => { e.preventDefault(); verify(); }}>
              <div className="pq-otp-h"><b>3-D Secure</b><span>{otp.phone}</span></div>
              <input className="pq-otp" autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={otp.code}
                onChange={e => setOtp(o => ({ ...o, code: e.target.value.replace(/\D/g, '') }))} placeholder="••••••" />
              <p className="pq-note">{t('Демо-код', 'Demo code')}: <code>{otp.hint}</code></p>
              <button type="submit" className="pq-btn" disabled={otp.code.length < 6}>{t('Підтвердити', 'Confirm')}</button>
            </form>
          ) : <div className="pq-wait"><i /></div>}
          {err && <p className="pq-warn">{err}</p>}
        </section>
      )}
      <footer className="pq-foot">{t('Навчальний банк · TAX не є грошима', 'Training bank · TAX is not money')}</footer>
    </div>
  );
}
