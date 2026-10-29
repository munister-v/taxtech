import markSvg from './assets/mark.svg?raw';
import BankLanding from './BankLanding';
import { initialLandingLang, saveLandingLang, type LandingLang } from './landingLang';
import { setTrLang, tr, trLang } from './appI18n';
import React, { useState, Fragment, useEffect, createContext, useContext, Component, useRef, useMemo, useId } from 'react';
import { startRegistration, startAuthentication } from '@simplewebauthn/browser';
import { createPortal } from 'react-dom';
const florenceCardImage = '';
const veniceCardImage = '';
const tuscanyVillaCardImage = '';
const veniceCityImage = '';
const florenceDuomoImage = '';
const valdorciaChapelImage = '';
const sicilyEmblemImage = '';

export class ErrorBoundary extends React.Component<{ children: React.ReactNode }, { error: string | null }> {
  override state = { error: null } as { error: string | null };
  static getDerivedStateFromError(err: Error): { error: string | null } { return { error: err.message }; }
  render() {
    if (this.state.error) {
      const tt = translations[getStoredLanguage()];
      return (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: '#000', color: '#d8d8d8', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, padding: 24, fontFamily: 'sans-serif' }}>
          <div style={{ fontSize: 20 }}>{tt.error_boundary_title}</div>
          <div style={{ fontSize: 13, color: 'rgba(215,215,215, 0.6)', maxWidth: 400, textAlign: 'center' }}>{this.state.error}</div>
          <button onClick={() => window.location.reload()} style={{ marginTop: 8, padding: '10px 20px', borderRadius: 10, background: gold, color: text.primary, border: 'none', cursor: 'pointer', fontWeight: 600 }}>{tt.error_boundary_refresh}</button>
        </div>
      );
    }
    return this.props.children;
  }
}

// ─── Design tokens ────────────────────────────────────────────
// Champagne-platinum palette — muted, private-banking feel
const gold        = '#FFD400';   // сигнальний жовтий - колір токена TAX
const goldDark    = '#C9A800';
const goldLight   = '#FFE566';
// Apple dark system palette: black canvas, #1c1c1e tiles, no hairlines on tiles.
const bg = {
  card:   '#1c1c1e',
  card2:  '#161617',
  border: 'transparent',
  hover:  '#2c2c2e',
};
const text = {
  primary:   '#f5f5f7',
  secondary: '#e8e8ed',
  muted:     '#8e8e93',
  dim:       '#5c5c61',
  gold:      gold,
};
const radius = { sm: 10, md: 12, lg: 18, xl: 22, '2xl': 28 };
const fontFamily = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro Display', 'Onest', 'Segoe UI', Roboto, sans-serif";
const mobileTabBarOffset = 'calc(74px + env(safe-area-inset-bottom, 0px))';
const mobileDockInset = `calc(${mobileTabBarOffset} + 8px)`;
const mobileDockInsetCompact = `calc(${mobileTabBarOffset} - 6px)`;

// ─── Type scale helpers ───────────────────────────────────────
const T = {
  /** 36px display — balance hero */
  hero:    { fontSize: 40, fontWeight: 600, letterSpacing: -1.4, lineHeight: 1.08 } as React.CSSProperties,
  /** 28px screen title */
  h1:      { fontSize: 34, fontWeight: 700, letterSpacing: -0.9, lineHeight: 1.12 } as React.CSSProperties,
  /** 22px section heading */
  h2:      { fontSize: 24, fontWeight: 600, letterSpacing: -0.5, lineHeight: 1.2 } as React.CSSProperties,
  /** 17px card/panel title */
  h3:      { fontSize: 19, fontWeight: 600, letterSpacing: -0.35, lineHeight: 1.25 } as React.CSSProperties,
  /** 15px body large */
  bodyLg:  { fontSize: 17, fontWeight: 400, lineHeight: 1.45, letterSpacing: -0.2 } as React.CSSProperties,
  /** 14px body default */
  body:    { fontSize: 15, fontWeight: 400, lineHeight: 1.45, letterSpacing: -0.1 } as React.CSSProperties,
  /** 13px small */
  sm:      { fontSize: 13, fontWeight: 400, lineHeight: 1.45 } as React.CSSProperties,
  /** 11px caption — uppercase labels */
  caption: { fontSize: 13, fontWeight: 600, lineHeight: 1.25 } as React.CSSProperties,
  /** tabular numbers */
  num:     { fontFeatureSettings: '"tnum" 1, "kern" 1' } as React.CSSProperties,
};

// ─── Liquid glass card ────────────────────────────────────────
const glassCard = (extra?: React.CSSProperties): React.CSSProperties => {
  if (typeof window !== 'undefined' && window.innerWidth >= 768) {
    // Десктоп: та сама плоска поверхня, що й `.kp-card`; фон і тінь із виклику ігноруються
    const { background: _bg, boxShadow: _sh, backdropFilter: _bf, WebkitBackdropFilter: _wbf, ...rest } = extra || {};
    return {
      ...ENGRAVED_FRAME,
      borderRadius: radius.xl,
      ...rest,
    };
  }
  return glassCardMobile(extra);
};
// Поверхня панелі: м'який вертикальний градієнт, світлий верхній край і глибока тінь замість обводки
const ENGRAVED_FRAME: React.CSSProperties = {
  border: '1px solid rgba(255,255,255,0.05)',
  background: 'linear-gradient(180deg, #222225 0%, #19191b 100%)',
  boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08), 0 14px 30px -16px rgba(0,0,0,0.75)',
};
const glassCardMobile = (extra?: React.CSSProperties): React.CSSProperties => ({
  ...extra,
  ...ENGRAVED_FRAME,
  backdropFilter: 'none',
  WebkitBackdropFilter: 'none',
  borderRadius: radius.xl,
});

function BrandMark({
  size,
  radiusValue,
  elevated = false,
}: {
  size: number;
  radiusValue: number;
  elevated?: boolean;
}) {
  return (
    <div style={{
      width: size,
      height: size,
      borderRadius: radiusValue,
      flexShrink: 0,
      background: '#000000',
      border: '1px solid transparent',
      display: 'grid',
      placeItems: 'center',
      color: '#ffffff',
    }}>
      <div
        aria-label="TaxTech"
        style={{ width: '58%', height: '58%', display: 'grid', placeItems: 'center' }}
        dangerouslySetInnerHTML={{ __html: markSvg.replace('<svg ', '<svg style="width:100%;height:100%" ') }}
      />
    </div>
  );
}

// ─── Shared section-label style ───────────────────────────────
const sectionLabel: React.CSSProperties = {
  ...T.caption, fontWeight: 500, letterSpacing: '0.08em', textTransform: 'uppercase', color: text.dim, padding: '0 6px 10px',
};

// Brand mark for the sign-in screens.
function RomanSeal({ size }: { size: number }) {
  return <BrandMark size={size * 1.25} radiusValue={size / 3} />;
}

// Кнопка-таблетка для виписки й експорту: іконка + підпис
const docPill: React.CSSProperties = {
  display: 'inline-flex', alignItems: 'center', gap: 7, height: 38, padding: '0 16px', borderRadius: 100,
  background: 'rgba(255,255,255,0.06)',
  border: '1px solid rgba(255,255,255,0.14)',
  color: gold, fontSize: 13, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer', whiteSpace: 'nowrap',
};

// Заголовок панелі на десктопі
const dkTitle: React.CSSProperties = { ...T.h3, fontSize: 18, color: text.primary };

// ─── Layout context ───────────────────────────────────────────
const LayoutCtx = createContext<'mobile' | 'desktop'>('mobile');
const useLayout = () => useContext(LayoutCtx);

// ─── App context (logout + navigation + toast + user + data) ─
type TabKey = 'overview' | 'operations' | 'cards' | 'market' | 'profile';
type TransferMode = 'topup' | 'by_card' | 'by_account';
interface UserInfo { id: number; full_name: string; phone: string; email: string; bank_account_number?: string; }
interface AccountInfo { id: number; account_number: string; balance: number; currency?: string; }
interface TxItem { id: number; tx_type: string; direction: 'in' | 'out' | string; amount: number; description: string; created_at: string; related_account?: string | null; note?: string | null; }
interface CardInfo { id: number; masked_number?: string; expiry_display?: string; card_type?: string; design?: string; status?: string; holder_name?: string; display_balance?: number; is_primary?: boolean; }
interface AppCtxType {
  logout: () => void; goTo: (tab: TabKey) => void; toast: (msg: string) => void;
  user: UserInfo | null; account: AccountInfo | null;
  transactions: TxItem[]; cards: CardInfo[]; refreshDashboard: () => void;
  openTransfer: (mode: TransferMode) => void;
  setTabBarHidden: (hidden: boolean) => void;
}
const AppCtx = createContext<AppCtxType>({
  logout: () => {},
  goTo: () => {},
  toast: () => {},
  user: null,
  account: null,
  transactions: [],
  cards: [],
  refreshDashboard: () => {},
  openTransfer: () => {},
  setTabBarHidden: () => {},
});
const useApp = () => useContext(AppCtx);

interface PreferencesCtxType {
  profilePhoto: string;
  setProfilePhotoValue: (value: string) => void;
  lang: AppLang;
  setLang: (lang: AppLang) => void;
  t: (key: TranslationKey) => string;
}

const PreferencesCtx = createContext<PreferencesCtxType>({
  profilePhoto: '',
  setProfilePhotoValue: () => {},
  lang: 'uk',
  setLang: () => {},
  t: (key: TranslationKey) => translations.uk[key],
});
const usePreferences = () => useContext(PreferencesCtx);

type ApiUser = {
  id: number;
  full_name: string;
  phone: string;
  email: string;
  role?: string;
};

type ApiAccount = {
  id: number;
  account_number: string;
  balance: number;
  currency?: string;
};

type ApiCard = {
  id: number;
  masked_number?: string;
  expiry_display?: string;
  card_type?: string;
  status?: string;
  design?: string;
};

type ApiTransaction = {
  id: number;
  tx_type: string;
  direction: 'in' | 'out' | string;
  amount: number;
  description: string;
  related_account?: string | null;
  created_at: string;
  note?: string | null;
};

type ApiNotification = {
  id: number;
  title: string;
  body: string;
  icon: string;
  type: string;
  is_read: boolean;
  created_at: string;
};

type BalancePoint = { day: string; balance: number };

type Achievement = { id: string; title: string; desc: string; icon: string; done: boolean };

type SpendingInsight = { icon: string; text: string };

type TopRecipient = { related_account: string; total_sent: number; tx_count: number };

type ApiAnalyticsByType = {
  tx_type: string;
  direction: string;
  total: number;
  cnt?: number;
};

type ApiAnalytics = {
  current_month?: {
    total_in?: number;
    total_out?: number;
    tx_count?: number;
  };
  prev_month?: {
    total_in?: number;
    total_out?: number;
    tx_count?: number;
  };
  by_type?: ApiAnalyticsByType[];
  monthly?: { month: string; total_in: number; total_out: number }[];
};

interface BankDataCtxType {
  loading: boolean;
  refreshing: boolean;
  error: string;
  user: ApiUser | null;
  account: ApiAccount | null;
  cards: ApiCard[];
  transactions: ApiTransaction[];
  analytics: ApiAnalytics | null;
  refresh: () => Promise<void>;
  mutateCard: (cardId: number, action: 'block' | 'close') => Promise<void>;
  issueCard: () => Promise<void>;
}

const BankDataCtx = createContext<BankDataCtxType>({
  loading: true,
  refreshing: false,
  error: '',
  user: null,
  account: null,
  cards: [],
  transactions: [],
  analytics: null,
  refresh: async () => {},
  mutateCard: async () => {},
  issueCard: async () => {},
});
const useBankData = () => useContext(BankDataCtx);

const API_BASE = (typeof window !== 'undefined' && (window as { ARMY_BANK_BASE?: string }).ARMY_BANK_BASE) || '';

function localeForLang(lang: AppLang): string {
  return lang === 'en' ? 'en-US'
    : lang === 'it' ? 'it-IT'
    : lang === 'de' ? 'de-DE'
    : lang === 'ru' ? 'ru-RU'
    : 'uk-UA';
}

function formatUah(value: number, lang: AppLang = getStoredLanguage()): string {
  // валюта - навчальний токен TAX, не гривня
  return `${new Intl.NumberFormat(localeForLang(lang), {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number.isFinite(value) ? value : 0)}\u00a0TAX`;
}

function apiUrl(url: string): string {
  return (url.startsWith('http') || url.startsWith('//')) ? url : `${API_BASE}${url}`;
}

function analyticsChangeLabel(analytics?: ApiAnalytics | null): string {
  const lang = getStoredLanguage();
  const tt = translations[lang];
  if (!analytics?.current_month || !analytics?.prev_month) return tt.no_dynamics;
  const curIn = Number(analytics.current_month.total_in || 0);
  const curOut = Number(analytics.current_month.total_out || 0);
  const prevIn = Number(analytics.prev_month.total_in || 0);
  const prevOut = Number(analytics.prev_month.total_out || 0);
  const curNet = curIn - curOut;
  const prevNet = prevIn - prevOut;
  if (Math.abs(prevNet) < 0.01) return curNet === 0 ? tt.no_change : tt.new_cash_flow;
  const pct = ((curNet - prevNet) / Math.abs(prevNet)) * 100;
  const sign = pct > 0 ? '+' : '';
  return `${sign}${pct.toFixed(1)}% ${tt.analytics_prev_month_suffix}`;
}

function initials(fullName?: string | null): string {
  const parts = String(fullName || '').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return 'AB';
  return (parts[0].charAt(0) + (parts[1]?.charAt(0) || '')).toUpperCase();
}

function shortName(fullName?: string | null): string {
  const parts = String(fullName || '').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return translations[getStoredLanguage()].user_fallback;
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[1].charAt(0)}.`;
}

function cardTail(masked?: string): string {
  const digits = String(masked || '').replace(/\D/g, '');
  return digits.length >= 4 ? digits.slice(-4) : '----';
}

const CARD_INDEX_STORAGE_KEY = 'army_bank_selected_card_idx';
const PROFILE_PHOTO_STORAGE_KEY = 'army_bank_profile_photo';
const ACTIVE_TAB_STORAGE_KEY = 'army_bank_active_tab';
const MARKET_TAB_STORAGE_KEY = 'army_bank_market_tab';
const APP_CONTINUATION_STORAGE_KEY = 'army_bank_recently_active';

// The same five languages as the landing, and the same saved choice (landingLang.ts).
type AppLang = LandingLang;

const translations = {
  uk: {
    user_fallback: 'Користувач',
    greeting_morning: 'Доброго ранку',
    greeting_day: 'Добрий день',
    greeting_evening: 'Доброго вечора',
    greeting_night: 'Доброї ночі',
    tabs_overview: 'Огляд',
    tabs_operations: 'Операції',
    tabs_cards: 'Картки',
    tabs_market: 'Магазин',
    tabs_profile: 'Профіль',
    quick_topup: 'Поповнити',
    quick_by_card: 'На картку',
    quick_by_account: 'За рахунком',
    quick_market: 'Магазин',
    balance_total: 'Загальний баланс',
    cards_mine: 'Мої картки',
    all: 'Усі',
    quick_actions: 'Швидкі дії',
    recent_activity: 'Остання активність',
    history: 'Історія',
    no_transactions_yet: 'Транзакцій ще немає',
    topup_or_transfer: 'Поповніть рахунок або зробіть переказ',
    profile_verified: 'Верифікований',
    profile_name: 'Ім\'я',
    profile_phone: 'Телефон',
    profile_email: 'Email',
    profile_account: 'Рахунок',
    profile_security: 'Безпека',
    profile_password: 'Пароль',
    profile_change_photo: 'Змінити фото',
    profile_remove_photo: 'Видалити',
    profile_change_password: 'Змінити пароль',
    profile_current_password: 'Поточний пароль',
    profile_new_password: 'Новий пароль',
    profile_save: 'Зберегти',
    profile_logout: 'Вийти з акаунту',
    settings_language: 'Мова',
    settings_language_sub: 'Інтерфейс застосунку',
    settings_notifications: 'Сповіщення',
    settings_notif_tx: 'Транзакції',
    settings_notif_security: 'Безпека',
    settings_notif_promo: 'Акції та пропозиції',
    settings_limits: 'Бюджетні ліміти',
    settings_limits_sub: 'Місячний ліміт витрат за категорією',
    settings_limit_add: 'Додати ліміт',
    settings_limit_spent: 'витрачено',
    settings_limit_of: 'з',
    settings_pin: 'PIN-код',
    settings_pin_sub: 'Для підтвердження операцій',
    settings_pin_set: 'Встановити PIN',
    settings_pin_change: 'Змінити PIN',
    settings_pin_clear: 'Видалити PIN',
    settings_pin_active: 'PIN встановлено',
    settings_app_info: 'Про застосунок',
    settings_version: 'Версія',
    settings_api_status: 'Статус API',
    settings_support: 'Підтримка',
    dep_title: 'Депозити',
    dep_open: 'Відкрити депозит',
    dep_amount: 'Сума депозиту',
    dep_term: 'Строк',
    dep_rate: 'Ставка',
    dep_monthly: 'міс.',
    dep_interest: 'Нарахування',
    dep_maturity: 'Дата закінчення',
    dep_days_left: 'днів залишилось',
    dep_auto_renew: 'Авто-пролонгація',
    dep_close: 'Закрити депозит',
    dep_close_early: 'Дострокове закриття (без відсотків)',
    dep_status_active: 'Активний',
    dep_status_matured: 'Завершено',
    dep_status_closed: 'Закрито',
    dep_status_early: 'Закрито достроково',
    dep_no_items: 'У вас немає активних депозитів',
    dep_min_amount: 'Мінімальна сума — 500 TAX',
    dep_accrued: 'Нараховано',
    dep_total_payout: 'До виплати',
    lang_uk: 'Українська',
    lang_en: 'English',
    lang_it: 'Italiano',
    lang_de: 'Deutsch',
    lang_ru: 'Русский',
    personal_cabinet: 'Особистий кабінет',
    face_id_unavailable: 'Недоступно на цьому пристрої',
    push_notifications: 'Push-сповіщення',
    unavailable: 'Недоступно',
    no_change: 'Без змін',
    new_cash_flow: 'Новий рух коштів',
    no_dynamics: 'Без динаміки',
    receipt_opened: 'Чек відкрито',
    request_error: 'Помилка запиту.',
    transfer_topup_title: 'Поповнити рахунок',
    transfer_by_card_title: 'Переказ на картку',
    transfer_by_account_title: 'Переказ за рахунком',
    transfer_card_number: 'Номер картки',
    transfer_account_number: 'Номер рахунку',
    transfer_optional_desc: 'Опис (опційно)',
    transfer_comment: 'Коментар',
    amount_label: 'Сума (TAX)',
    enter_amount: 'Вкажіть суму',
    enter_recipient: 'Вкажіть отримувача',
    session_expired: 'Сесія завершилась. Увійдіть повторно.',
    operation_error: 'Помилка операції',
    topup_success: 'Рахунок поповнено на',
    transfer_success: 'Переказ виконано на',
    cards_not_issued: 'Картки ще не випущено',
    cards_issue_hint: 'Перейдіть у розділ «Картки», щоб випустити першу картку.',
    open_cards: 'Відкрити картки',
    spending_this_month: 'Витрати цього місяця',
    insufficient_spend_data: 'Недостатньо даних для розподілу витрат.',
    spend_transfer: 'Перекази',
    spend_food: 'Їжа',
    spend_transport: 'Транспорт',
    spend_utility: 'Комунальні',
    spend_shopping: 'Покупки',
    spend_subscription: 'Підписки',
    cards_title: 'Мої картки',
    card_not_found: 'Картку не знайдено.',
    pin_change_error: 'Помилка зміни PIN',
    pin_saved: 'PIN картки змінено',
    card_blocked: 'Картку заморожено',
    card_unblocked: 'Картку розморожено',
    card_closed: 'Картку закрито',
    card_active_status: 'Активна',
    card_frozen_status: 'Заморожена',
    card_design_error: 'Помилка дизайну картки',
    card_details: 'Деталі',
    account_label: 'Рахунок',
    new_pin_4_digits: 'Новий PIN (4 цифри)',
    saving: 'Збереження…',
    save_pin: 'Зберегти PIN',
    operations_title: 'Операції',
    download_csv: 'Завантажити CSV',
    search_transactions: 'Пошук транзакцій...',
    nothing_found_for: 'Нічого не знайдено за',
    download_receipt: 'Завантажити чек',
    receipt_download_error: 'Помилка завантаження чека',
    download_error: 'Помилка завантаження',
    export_error: 'Помилка експорту',
    statement_error: 'Помилка виписки',
    face_id_on: 'Face ID увімкнено',
    face_id_off: 'Face ID вимкнено',
    password_changed: 'Пароль змінено успішно',
    pick_image: 'Оберіть зображення',
    photo_too_large: 'Фото завелике (до 3MB)',
    photo_read_error: 'Не вдалося прочитати фото',
    photo_updated: 'Фото профілю оновлено',
    photo_upload_error: 'Не вдалося завантажити фото',
    photo_removed: 'Фото видалено',
    profile_photo_alt: 'Фото профілю',
    market_out_of_stock: 'Немає в наявності',
    add_to_cart: 'Додати до кошика',
    cart_title: 'Кошик',
    delivery_title: 'Доставка',
    cart_empty: 'Кошик порожній',
    added_to_cart: 'додано до кошика',
    checkout_success: 'Замовлення оформлено!',
    checkout_error: 'Помилка оформлення',
    orders_tab: 'Замовлення',
    invoices_tab: 'Інвойси',
    market_title: 'Магазин',
    loading: 'Завантаження…',
    market_empty: 'Магазин порожній',
    try_another_query: 'Спробуй інший запит',
    no_results: 'Нічого не знайдено',
    products_not_added: 'Товари ще не додано.',
    orders_empty: 'Замовлень ще немає',
    invoices_empty: 'Інвойсів ще немає',
    invoices_after_orders: 'Інвойси з\'являться після оформлення замовлень.',
    invoice_label: 'Інвойс',
    order_label: 'Замовлення',
    login_tab: 'Вхід',
    register_tab: 'Реєстрація',
    wait_processing: 'Обробка…',
    login_with_face_id: 'Увійти з Face ID',
    full_name_label: 'Повне ім\'я',
    email_label: 'Email',
    phone_or_email: 'Телефон або Email',
    phone_or_email_placeholder: 'Телефон або email',
    password_label: 'Пароль',
    forgot_password: 'Забули пароль?',
    confirm_password: 'Підтвердити пароль',
    repeat_password: 'Повторіть пароль',
    sign_in: 'Увійти',
    create_account: 'Створити акаунт',
    issue_card: 'Випустити',
    creating: 'Створення...',
    invalid_credentials: 'Невірні дані',
    registration_error: 'Помилка реєстрації',
    verification_error: 'Помилка верифікації',
    face_id_error: 'Помилка Face ID',
    loading_data: 'Завантаження даних...',
    change_pin: 'Змінити PIN',
    choose_card_design: 'Оберіть дизайн картки',
    issue_new_card: 'Випуск нової картки',
    applying: 'Застосування…',
    apply_design: 'Застосувати дизайн',
    issue_card_full: 'Випустити картку',
    face_id_transfer_sub: 'Вхід та підтвердження переказів',
    in_stock: 'Є в наявності',
    next_delivery: 'Далі → Доставка',
    cart_items_count: 'товарів',
    total_label: 'Разом',
    recipient_label: 'Отримувач',
    delivery_phone: 'Телефон',
    delivery_address: 'Адреса доставки',
    pay_total: 'До оплати',
    place_order: 'Оформити замовлення',
    checkout_processing: 'Оформлення…',
    catalog_tab: 'Каталог',
    product_search: 'Пошук товарів…',
    catalog_first_order_hint: 'Оформіть перше замовлення в каталозі.',
    receipt_short: 'Чек',
    last_items: 'Останніх',
    card_physical: 'Фізична',
    card_virtual: 'Віртуальна',
    card_valid_until: 'до',
    card_design_label: 'Дизайн',
    change_label: 'Змінити',
    account_activity_month: 'Активність рахунку за місяць',
    operations_short: 'оп.',
    spent_label: 'витрат',
    account_balance_label: 'Баланс рахунку',
    design_action: 'Дизайн',
    freeze_card: 'Заморозити',
    unfreeze_card: 'Розморозити',
    close_card: 'Закрити',
    error_boundary_title: 'Щось пішло не так',
    error_boundary_refresh: 'Оновити сторінку',
    analytics_prev_month_suffix: 'до минулого місяця',
    api_health_temporarily_unavailable: 'API тимчасово недоступне. Спробуйте через кілька секунд.',
    api_health_status_unavailable: 'API статус недоступний.',
    api_health_no_connection: 'Немає зʼєднання з API. Перевірте мережу або спробуйте пізніше.',
    design_subtitle_gold: 'TaxTech',
    design_subtitle_forest: 'Глибокий зелений',
    design_subtitle_slate: 'Світлий металік',
    design_subtitle_dark: 'Темний мінімал',
    design_subtitle_florence: 'Купол і старе місто',
    design_subtitle_venice: 'Канали та площа',
    design_subtitle_tuscany_hills: 'Тосканські поля',
    design_subtitle_tuscany_villa: 'Теплий пейзаж',
    today_label: 'Сьогодні',
    yesterday_label: 'Вчора',
    no_new_notifications: 'Нових сповіщень немає',
    demo_pin_unavailable: 'Демо-режим: зміна PIN недоступна',
    demo_api_unavailable: 'Демо-режим: API не підключено',
    no_card_for_design_change: 'Немає картки для зміни дизайну',
    card_design_update_failed: 'Не вдалося оновити дизайн',
    card_design_updated: 'Дизайн картки оновлено',
    card_issue_failed: 'Не вдалося випустити картку',
    new_card_issued: 'Нову картку випущено',
    card_short_label: 'Картка',
    confirm_pin: 'Підтвердити PIN',
    pin_mismatch: 'PIN-коди не збігаються',
    choose_style_then_issue: 'Оберіть стиль, потім випустіть віртуальну картку',
    selected_label: 'Обрано',
    cancel_label: 'Скасувати',
    period_week_short: 'Т',
    period_month_short: 'М',
    period_year_short: 'Р',
    statement_pdf: 'Виписка PDF',
    copy_success: 'Скопійовано',
    copy_failed: 'Не вдалось скопіювати',
    last_items_badge: 'ОСТАННІ',
    shipping_name_placeholder: 'Прізвище Ім\'я По-батькові',
    shipping_address_placeholder: 'м. Київ, вул. Хрещатик 1, кв. 5',
    order_items_suffix: 'поз.',
    due_prefix: 'до',
    passwords_do_not_match: 'Паролі не збігаються',
    forgot_password_contact_support: 'Зверніться до підтримки для відновлення пароля',
    full_name_placeholder: 'Іван Петренко',
    data_load_failed: 'Не вдалося завантажити дані.',
    active_cards_metric: 'Активні картки',
    cardholder_label: 'Cardholder',
    valid_label: 'Valid',
    transfer_placeholder_card: '4721 •••• •••• ••••',
    transfer_placeholder_account: 'AB-100011',
    filter_all: 'Всі',
    filter_income: 'Надходження',
    filter_outcome: 'Витрати',
    notifications_center: 'Сповіщення',
    balance_history_title: 'Динаміка балансу',
    achievements_title: 'Досягнення',
    achievements_progress: 'виконано',
    insights_title: 'Аналітика',
    tx_note_label: 'Нотатка',
    tx_note_placeholder: 'Додати нотатку...',
    tx_note_saved: 'Нотатку збережено',
    top_recipients_title: 'Часті отримувачі',
    mark_all_read: 'Прочитати всі',
    sent_label: 'переказів',
    sort_newest: 'Нові',
    sort_oldest: 'Старі',
    sort_amount: 'Сума',
    dk_search: 'Пошук і команди',
    dk_search_ph: 'Знайти сторінку, дію чи операцію…',
    dk_group_go: 'Перейти',
    dk_group_actions: 'Дії',
    dk_group_tx: 'Операції',
    dk_no_results: 'Нічого не знайдено',
    dk_collapse: 'Згорнути меню',
    dk_expand: 'Розгорнути меню',
    dk_copy_account: 'Скопіювати номер рахунку',
    dk_copied: 'Номер рахунку скопійовано',
    dk_days_short: 'д',
    dk_this_month: 'за місяць',
    dk_hide_balance: 'Сховати баланс',
    dk_show_balance: 'Показати баланс',
    dk_total: 'Разом',
    dk_to_navigate: 'навігація',
    dk_to_open: 'відкрити',
    dk_to_close: 'закрити',
    dk_menu: 'Меню',
    dk_history_chart: 'Динаміка балансу',
    dk_open: 'Відкрити',
    dk_cat_payment: 'Оплати',
    dk_cat_savings: 'Накопичення',
    dk_cat_marketplace: 'Магазин',
    dk_cat_marketplace_invoice: 'Рахунки магазину',
    dk_cat_donation: 'Донати',
    dk_cat_credit: 'Кредити',
    dk_cat_topup: 'Поповнення',
    dk_cat_other: 'Інше',
    dk_login_title: 'Навчальний банк для віртуальних фінансів',
    dk_login_p1: 'Картки, перекази й депозити — на токенах TAX',
    dk_login_p2: 'Антифрод і 3-D Secure, як у справжньому банку',
    dk_login_p3: 'Жодних реальних грошей: усе для навчання й досліджень',
  },
  en: {
    user_fallback: 'User',
    greeting_morning: 'Good morning',
    greeting_day: 'Good afternoon',
    greeting_evening: 'Good evening',
    greeting_night: 'Good night',
    tabs_overview: 'Overview',
    tabs_operations: 'Activity',
    tabs_cards: 'Cards',
    tabs_market: 'Store',
    tabs_profile: 'Profile',
    quick_topup: 'Top up',
    quick_by_card: 'To card',
    quick_by_account: 'By account',
    quick_market: 'Store',
    balance_total: 'Total balance',
    cards_mine: 'My cards',
    all: 'All',
    quick_actions: 'Quick actions',
    recent_activity: 'Recent activity',
    history: 'History',
    no_transactions_yet: 'No transactions yet',
    topup_or_transfer: 'Top up your account or make a transfer',
    profile_verified: 'Verified',
    profile_name: 'Name',
    profile_phone: 'Phone',
    profile_email: 'Email',
    profile_account: 'Account',
    profile_security: 'Security',
    profile_password: 'Password',
    profile_change_photo: 'Change photo',
    profile_remove_photo: 'Remove',
    profile_change_password: 'Change password',
    profile_current_password: 'Current password',
    profile_new_password: 'New password',
    profile_save: 'Save',
    profile_logout: 'Sign out',
    settings_language: 'Language',
    settings_language_sub: 'App interface',
    settings_notifications: 'Notifications',
    settings_notif_tx: 'Transactions',
    settings_notif_security: 'Security',
    settings_notif_promo: 'Offers & Promotions',
    settings_limits: 'Budget Limits',
    settings_limits_sub: 'Monthly spending limit by category',
    settings_limit_add: 'Add limit',
    settings_limit_spent: 'spent',
    settings_limit_of: 'of',
    settings_pin: 'PIN code',
    settings_pin_sub: 'To confirm operations',
    settings_pin_set: 'Set PIN',
    settings_pin_change: 'Change PIN',
    settings_pin_clear: 'Remove PIN',
    settings_pin_active: 'PIN is set',
    settings_app_info: 'About',
    settings_version: 'Version',
    settings_api_status: 'API Status',
    settings_support: 'Support',
    dep_title: 'Deposits',
    dep_open: 'Open deposit',
    dep_amount: 'Deposit amount',
    dep_term: 'Term',
    dep_rate: 'Rate',
    dep_monthly: 'mo.',
    dep_interest: 'Interest',
    dep_maturity: 'Maturity date',
    dep_days_left: 'days left',
    dep_auto_renew: 'Auto-renew',
    dep_close: 'Close deposit',
    dep_close_early: 'Early withdrawal (no interest)',
    dep_status_active: 'Active',
    dep_status_matured: 'Matured',
    dep_status_closed: 'Closed',
    dep_status_early: 'Early closed',
    dep_no_items: 'No active deposits',
    dep_min_amount: 'Minimum — 500 TAX',
    dep_accrued: 'Accrued',
    dep_total_payout: 'Total payout',
    lang_uk: 'Ukrainian',
    lang_en: 'English',
    lang_it: 'Italian',
    lang_de: 'German',
    lang_ru: 'Russian',
    personal_cabinet: 'Personal banking',
    face_id_unavailable: 'Unavailable on this device',
    push_notifications: 'Push notifications',
    unavailable: 'Unavailable',
    no_change: 'No change',
    new_cash_flow: 'New cash flow',
    no_dynamics: 'No dynamics',
    receipt_opened: 'Receipt opened',
    request_error: 'Request error.',
    transfer_topup_title: 'Top up account',
    transfer_by_card_title: 'Transfer to card',
    transfer_by_account_title: 'Transfer by account',
    transfer_card_number: 'Card number',
    transfer_account_number: 'Account number',
    transfer_optional_desc: 'Description (optional)',
    transfer_comment: 'Comment',
    amount_label: 'Amount (TAX)',
    enter_amount: 'Enter amount',
    enter_recipient: 'Enter recipient',
    session_expired: 'Session expired. Sign in again.',
    operation_error: 'Operation error',
    topup_success: 'Account topped up by',
    transfer_success: 'Transfer completed for',
    cards_not_issued: 'No cards issued yet',
    cards_issue_hint: 'Go to the Cards section to issue your first card.',
    open_cards: 'Open cards',
    spending_this_month: 'Spending this month',
    insufficient_spend_data: 'Not enough data to break down spending.',
    spend_transfer: 'Transfers',
    spend_food: 'Food',
    spend_transport: 'Transport',
    spend_utility: 'Utilities',
    spend_shopping: 'Shopping',
    spend_subscription: 'Subscriptions',
    cards_title: 'My cards',
    card_not_found: 'Card not found.',
    pin_change_error: 'PIN change error',
    pin_saved: 'Card PIN updated',
    card_blocked: 'Card frozen',
    card_unblocked: 'Card unfrozen',
    card_closed: 'Card closed',
    card_active_status: 'Active',
    card_frozen_status: 'Frozen',
    card_design_error: 'Card design error',
    card_details: 'Details',
    account_label: 'Account',
    new_pin_4_digits: 'New PIN (4 digits)',
    saving: 'Saving…',
    save_pin: 'Save PIN',
    operations_title: 'Operations',
    download_csv: 'Download CSV',
    search_transactions: 'Search transactions...',
    nothing_found_for: 'Nothing found for',
    download_receipt: 'Download receipt',
    receipt_download_error: 'Receipt download error',
    download_error: 'Download error',
    export_error: 'Export error',
    statement_error: 'Statement error',
    face_id_on: 'Face ID enabled',
    face_id_off: 'Face ID disabled',
    password_changed: 'Password changed successfully',
    pick_image: 'Choose an image',
    photo_too_large: 'Photo is too large (up to 3MB)',
    photo_read_error: 'Could not read photo',
    photo_updated: 'Profile photo updated',
    photo_upload_error: 'Could not upload photo',
    photo_removed: 'Photo removed',
    profile_photo_alt: 'Profile photo',
    market_out_of_stock: 'Out of stock',
    add_to_cart: 'Add to cart',
    cart_title: 'Cart',
    delivery_title: 'Delivery',
    cart_empty: 'Cart is empty',
    added_to_cart: 'added to cart',
    checkout_success: 'Order placed!',
    checkout_error: 'Checkout error',
    orders_tab: 'Orders',
    invoices_tab: 'Invoices',
    market_title: 'Store',
    loading: 'Loading…',
    market_empty: 'Store is empty',
    try_another_query: 'Try another query',
    no_results: 'Nothing found',
    products_not_added: 'Products have not been added yet.',
    orders_empty: 'No orders yet',
    invoices_empty: 'No invoices yet',
    invoices_after_orders: 'Invoices will appear after orders are placed.',
    invoice_label: 'Invoice',
    order_label: 'Order',
    login_tab: 'Sign in',
    register_tab: 'Register',
    wait_processing: 'Processing…',
    login_with_face_id: 'Sign in with Face ID',
    full_name_label: 'Full name',
    email_label: 'Email',
    phone_or_email: 'Phone or Email',
    phone_or_email_placeholder: 'Phone or email',
    password_label: 'Password',
    forgot_password: 'Forgot password?',
    confirm_password: 'Confirm password',
    repeat_password: 'Repeat password',
    sign_in: 'Sign in',
    create_account: 'Create account',
    issue_card: 'Issue card',
    creating: 'Creating...',
    invalid_credentials: 'Invalid credentials',
    registration_error: 'Registration error',
    verification_error: 'Verification error',
    face_id_error: 'Face ID error',
    loading_data: 'Loading data...',
    change_pin: 'Change PIN',
    choose_card_design: 'Choose card design',
    issue_new_card: 'Issue new card',
    applying: 'Applying…',
    apply_design: 'Apply design',
    issue_card_full: 'Issue card',
    face_id_transfer_sub: 'Sign-in and transfer confirmation',
    in_stock: 'In stock',
    next_delivery: 'Next → Delivery',
    cart_items_count: 'items',
    total_label: 'Total',
    recipient_label: 'Recipient',
    delivery_phone: 'Phone',
    delivery_address: 'Delivery address',
    pay_total: 'To pay',
    place_order: 'Place order',
    checkout_processing: 'Placing order…',
    catalog_tab: 'Catalog',
    product_search: 'Search products…',
    catalog_first_order_hint: 'Place your first order in the catalog.',
    receipt_short: 'Receipt',
    last_items: 'Last',
    card_physical: 'Physical',
    card_virtual: 'Virtual',
    card_valid_until: 'until',
    card_design_label: 'Design',
    change_label: 'Change',
    account_activity_month: 'Monthly account activity',
    operations_short: 'ops',
    spent_label: 'spent',
    account_balance_label: 'Account balance',
    design_action: 'Design',
    freeze_card: 'Freeze',
    unfreeze_card: 'Unfreeze',
    close_card: 'Close',
    error_boundary_title: 'Something went wrong',
    error_boundary_refresh: 'Reload page',
    analytics_prev_month_suffix: 'vs previous month',
    api_health_temporarily_unavailable: 'API is temporarily unavailable. Please try again in a few seconds.',
    api_health_status_unavailable: 'API status is unavailable.',
    api_health_no_connection: 'No connection to API. Check your network or try again later.',
    design_subtitle_gold: 'TaxTech',
    design_subtitle_forest: 'Deep green tone',
    design_subtitle_slate: 'Light metallic',
    design_subtitle_dark: 'Dark minimal look',
    design_subtitle_florence: 'Dome and old city',
    design_subtitle_venice: 'Canals and square',
    design_subtitle_tuscany_hills: 'Tuscan fields',
    design_subtitle_tuscany_villa: 'Warm landscape',
    today_label: 'Today',
    yesterday_label: 'Yesterday',
    no_new_notifications: 'No new notifications',
    demo_pin_unavailable: 'Demo mode: PIN change unavailable',
    demo_api_unavailable: 'Demo mode: API is not connected',
    no_card_for_design_change: 'No card available for design change',
    card_design_update_failed: 'Failed to update design',
    card_design_updated: 'Card design updated',
    card_issue_failed: 'Failed to issue card',
    new_card_issued: 'New card issued',
    card_short_label: 'Card',
    confirm_pin: 'Confirm PIN',
    pin_mismatch: 'PIN codes do not match',
    choose_style_then_issue: 'Choose a style, then issue a virtual card',
    selected_label: 'Selected',
    cancel_label: 'Cancel',
    period_week_short: 'W',
    period_month_short: 'M',
    period_year_short: 'Y',
    statement_pdf: 'PDF statement',
    copy_success: 'Copied',
    copy_failed: 'Failed to copy',
    last_items_badge: 'LAST',
    shipping_name_placeholder: 'Full name',
    shipping_address_placeholder: 'Kyiv, Khreshchatyk St 1, apt. 5',
    order_items_suffix: 'items',
    due_prefix: 'due',
    passwords_do_not_match: 'Passwords do not match',
    forgot_password_contact_support: 'Contact support to recover your password',
    full_name_placeholder: 'John Doe',
    data_load_failed: 'Failed to load data.',
    active_cards_metric: 'Active cards',
    cardholder_label: 'Cardholder',
    valid_label: 'Valid',
    transfer_placeholder_card: '4721 •••• •••• ••••',
    transfer_placeholder_account: 'AB-100011',
    filter_all: 'All',
    filter_income: 'Income',
    filter_outcome: 'Expenses',
    notifications_center: 'Notifications',
    balance_history_title: 'Balance History',
    achievements_title: 'Achievements',
    achievements_progress: 'completed',
    insights_title: 'Insights',
    tx_note_label: 'Note',
    tx_note_placeholder: 'Add a note...',
    tx_note_saved: 'Note saved',
    top_recipients_title: 'Frequent Recipients',
    mark_all_read: 'Mark all read',
    sent_label: 'transfers',
    sort_newest: 'Newest',
    sort_oldest: 'Oldest',
    sort_amount: 'Amount',
    dk_search: 'Search and commands',
    dk_search_ph: 'Find a page, action or transaction…',
    dk_group_go: 'Go to',
    dk_group_actions: 'Actions',
    dk_group_tx: 'Transactions',
    dk_no_results: 'Nothing found',
    dk_collapse: 'Collapse menu',
    dk_expand: 'Expand menu',
    dk_copy_account: 'Copy account number',
    dk_copied: 'Account number copied',
    dk_days_short: 'd',
    dk_this_month: 'this month',
    dk_hide_balance: 'Hide balance',
    dk_show_balance: 'Show balance',
    dk_total: 'Total',
    dk_to_navigate: 'navigate',
    dk_to_open: 'open',
    dk_to_close: 'close',
    dk_menu: 'Menu',
    dk_history_chart: 'Balance trend',
    dk_open: 'Open',
    dk_cat_payment: 'Payments',
    dk_cat_savings: 'Savings',
    dk_cat_marketplace: 'Shop',
    dk_cat_marketplace_invoice: 'Shop invoices',
    dk_cat_donation: 'Donations',
    dk_cat_credit: 'Credits',
    dk_cat_topup: 'Top-ups',
    dk_cat_other: 'Other',
    dk_login_title: 'A learning bank for virtual finance',
    dk_login_p1: 'Cards, transfers and deposits — in TAX tokens',
    dk_login_p2: 'Anti-fraud and 3-D Secure, like a real bank',
    dk_login_p3: 'No real money: everything is for study and research',
  },
  it: {
    user_fallback: 'Utente',
    greeting_morning: 'Buongiorno',
    greeting_day: 'Buon pomeriggio',
    greeting_evening: 'Buonasera',
    greeting_night: 'Buonanotte',
    tabs_overview: 'Panoramica',
    tabs_operations: 'Operazioni',
    tabs_cards: 'Carte',
    tabs_market: 'Negozio',
    tabs_profile: 'Profilo',
    quick_topup: 'Ricarica',
    quick_by_card: 'Alla carta',
    quick_by_account: 'Per conto',
    quick_market: 'Negozio',
    balance_total: 'Saldo totale',
    cards_mine: 'Le mie carte',
    all: 'Tutte',
    quick_actions: 'Azioni rapide',
    recent_activity: 'Attività recente',
    history: 'Cronologia',
    no_transactions_yet: 'Nessuna transazione',
    topup_or_transfer: 'Ricarica il conto o effettua un trasferimento',
    profile_verified: 'Verificato',
    profile_name: 'Nome',
    profile_phone: 'Telefono',
    profile_email: 'Email',
    profile_account: 'Conto',
    profile_security: 'Sicurezza',
    profile_password: 'Password',
    profile_change_photo: 'Cambia foto',
    profile_remove_photo: 'Rimuovi',
    profile_change_password: 'Cambia password',
    profile_current_password: 'Password attuale',
    profile_new_password: 'Nuova password',
    profile_save: 'Salva',
    profile_logout: 'Esci',
    settings_language: 'Lingua',
    settings_language_sub: 'Interfaccia dell\'app',
    settings_notifications: 'Notifiche',
    settings_notif_tx: 'Transazioni',
    settings_notif_security: 'Sicurezza',
    settings_notif_promo: 'Offerte',
    settings_limits: 'Limiti di spesa',
    settings_limits_sub: 'Limite mensile per categoria',
    settings_limit_add: 'Aggiungi',
    settings_limit_spent: 'speso',
    settings_limit_of: 'di',
    settings_pin: 'Codice PIN',
    settings_pin_sub: 'Per confermare le operazioni',
    settings_pin_set: 'Imposta PIN',
    settings_pin_change: 'Cambia PIN',
    settings_pin_clear: 'Rimuovi PIN',
    settings_pin_active: 'PIN attivo',
    settings_app_info: 'Info',
    settings_version: 'Versione',
    settings_api_status: 'Stato API',
    settings_support: 'Supporto',
    dep_title: 'Depositi',
    dep_open: 'Apri deposito',
    dep_amount: 'Importo',
    dep_term: 'Durata',
    dep_rate: 'Tasso',
    dep_monthly: 'mesi',
    dep_interest: 'Interessi',
    dep_maturity: 'Scadenza',
    dep_days_left: 'giorni rimasti',
    dep_auto_renew: 'Rinnovo automatico',
    dep_close: 'Chiudi deposito',
    dep_close_early: 'Chiusura anticipata (senza interessi)',
    dep_status_active: 'Attivo',
    dep_status_matured: 'Scaduto',
    dep_status_closed: 'Chiuso',
    dep_status_early: 'Chiuso anticipatamente',
    dep_no_items: 'Nessun deposito attivo',
    dep_min_amount: 'Minimo — 500 TAX',
    dep_accrued: 'Maturato',
    dep_total_payout: 'Totale rimborso',
    lang_uk: 'Ucraino',
    lang_en: 'Inglese',
    lang_it: 'Italiano',
    lang_de: 'Tedesco',
    lang_ru: 'Russo',
    personal_cabinet: 'Private banking',
    face_id_unavailable: 'Non disponibile su questo dispositivo',
    push_notifications: 'Notifiche push',
    unavailable: 'Non disponibile',
    no_change: 'Nessuna variazione',
    new_cash_flow: 'Nuovo flusso di cassa',
    no_dynamics: 'Nessuna dinamica',
    receipt_opened: 'Ricevuta aperta',
    request_error: 'Errore di richiesta.',
    transfer_topup_title: 'Ricarica conto',
    transfer_by_card_title: 'Trasferimento alla carta',
    transfer_by_account_title: 'Trasferimento per conto',
    transfer_card_number: 'Numero carta',
    transfer_account_number: 'Numero conto',
    transfer_optional_desc: 'Descrizione (opzionale)',
    transfer_comment: 'Commento',
    amount_label: 'Importo (TAX)',
    enter_amount: 'Inserisci importo',
    enter_recipient: 'Inserisci destinatario',
    session_expired: 'Sessione scaduta. Accedi di nuovo.',
    operation_error: 'Errore operazione',
    topup_success: 'Conto ricaricato di',
    transfer_success: 'Trasferimento eseguito per',
    cards_not_issued: 'Nessuna carta emessa',
    cards_issue_hint: 'Vai alla sezione Carte per emettere la tua prima carta.',
    open_cards: 'Apri carte',
    spending_this_month: 'Spese di questo mese',
    insufficient_spend_data: 'Dati insufficienti per suddividere le spese.',
    spend_transfer: 'Trasferimenti',
    spend_food: 'Cibo',
    spend_transport: 'Trasporto',
    spend_utility: 'Utenze',
    spend_shopping: 'Shopping',
    spend_subscription: 'Abbonamenti',
    cards_title: 'Le mie carte',
    card_not_found: 'Carta non trovata.',
    pin_change_error: 'Errore cambio PIN',
    pin_saved: 'PIN carta aggiornato',
    card_blocked: 'Carta bloccata',
    card_unblocked: 'Carta sbloccata',
    card_closed: 'Carta chiusa',
    card_active_status: 'Attiva',
    card_frozen_status: 'Bloccata',
    card_design_error: 'Errore design carta',
    card_details: 'Dettagli',
    account_label: 'Conto',
    new_pin_4_digits: 'Nuovo PIN (4 cifre)',
    saving: 'Salvataggio…',
    save_pin: 'Salva PIN',
    operations_title: 'Operazioni',
    download_csv: 'Scarica CSV',
    search_transactions: 'Cerca transazioni...',
    nothing_found_for: 'Nessun risultato per',
    download_receipt: 'Scarica ricevuta',
    receipt_download_error: 'Errore scaricamento ricevuta',
    download_error: 'Errore di download',
    export_error: 'Errore esportazione',
    statement_error: 'Errore estratto conto',
    face_id_on: 'Face ID attivato',
    face_id_off: 'Face ID disattivato',
    password_changed: 'Password cambiata con successo',
    pick_image: 'Scegli un\'immagine',
    photo_too_large: 'Foto troppo grande (max 3MB)',
    photo_read_error: 'Impossibile leggere la foto',
    photo_updated: 'Foto profilo aggiornata',
    photo_upload_error: 'Impossibile caricare la foto',
    photo_removed: 'Foto rimossa',
    profile_photo_alt: 'Foto profilo',
    market_out_of_stock: 'Non disponibile',
    add_to_cart: 'Aggiungi al carrello',
    cart_title: 'Carrello',
    delivery_title: 'Consegna',
    cart_empty: 'Carrello vuoto',
    added_to_cart: 'aggiunto al carrello',
    checkout_success: 'Ordine effettuato!',
    checkout_error: 'Errore checkout',
    orders_tab: 'Ordini',
    invoices_tab: 'Fatture',
    market_title: 'Negozio',
    loading: 'Caricamento…',
    market_empty: 'Negozio vuoto',
    try_another_query: 'Prova un\'altra ricerca',
    no_results: 'Nessun risultato',
    products_not_added: 'I prodotti non sono ancora stati aggiunti.',
    orders_empty: 'Nessun ordine',
    invoices_empty: 'Nessuna fattura',
    invoices_after_orders: 'Le fatture appariranno dopo gli ordini.',
    invoice_label: 'Fattura',
    order_label: 'Ordine',
    login_tab: 'Accesso',
    register_tab: 'Registrazione',
    wait_processing: 'Elaborazione…',
    login_with_face_id: 'Accedi con Face ID',
    full_name_label: 'Nome completo',
    email_label: 'Email',
    phone_or_email: 'Telefono o Email',
    phone_or_email_placeholder: 'Telefono o email',
    password_label: 'Password',
    forgot_password: 'Password dimenticata?',
    confirm_password: 'Conferma password',
    repeat_password: 'Ripeti password',
    sign_in: 'Accedi',
    create_account: 'Crea account',
    issue_card: 'Emetti carta',
    creating: 'Creazione...',
    invalid_credentials: 'Dati non validi',
    registration_error: 'Errore registrazione',
    verification_error: 'Errore verifica',
    face_id_error: 'Errore Face ID',
    loading_data: 'Caricamento dati...',
    change_pin: 'Cambia PIN',
    choose_card_design: 'Scegli il design della carta',
    issue_new_card: 'Emissione nuova carta',
    applying: 'Applicazione…',
    apply_design: 'Applica design',
    issue_card_full: 'Emetti carta',
    face_id_transfer_sub: 'Accesso e conferma trasferimenti',
    in_stock: 'Disponibili',
    next_delivery: 'Avanti → Consegna',
    cart_items_count: 'articoli',
    total_label: 'Totale',
    recipient_label: 'Destinatario',
    delivery_phone: 'Telefono',
    delivery_address: 'Indirizzo di consegna',
    pay_total: 'Da pagare',
    place_order: 'Conferma ordine',
    checkout_processing: 'Ordine in corso…',
    catalog_tab: 'Catalogo',
    product_search: 'Cerca prodotti…',
    catalog_first_order_hint: 'Effettua il primo ordine dal catalogo.',
    receipt_short: 'Ricevuta',
    last_items: 'Ultimi',
    card_physical: 'Fisica',
    card_virtual: 'Virtuale',
    card_valid_until: 'fino al',
    card_design_label: 'Design',
    change_label: 'Cambia',
    account_activity_month: 'Attività mensile del conto',
    operations_short: 'op.',
    spent_label: 'spesi',
    account_balance_label: 'Saldo conto',
    design_action: 'Design',
    freeze_card: 'Blocca',
    unfreeze_card: 'Sblocca',
    close_card: 'Chiudi',
    error_boundary_title: 'Qualcosa è andato storto',
    error_boundary_refresh: 'Ricarica pagina',
    analytics_prev_month_suffix: 'rispetto al mese scorso',
    api_health_temporarily_unavailable: 'API temporaneamente non disponibile. Riprova tra qualche secondo.',
    api_health_status_unavailable: 'Stato API non disponibile.',
    api_health_no_connection: 'Nessuna connessione all\'API. Controlla la rete o riprova più tardi.',
    design_subtitle_gold: 'TaxTech',
    design_subtitle_forest: 'Verde profondo',
    design_subtitle_slate: 'Metallico chiaro',
    design_subtitle_dark: 'Minimal scuro',
    design_subtitle_florence: 'Cupola e città antica',
    design_subtitle_venice: 'Canali e piazza',
    design_subtitle_tuscany_hills: 'Campi toscani',
    design_subtitle_tuscany_villa: 'Paesaggio caldo',
    today_label: 'Oggi',
    yesterday_label: 'Ieri',
    no_new_notifications: 'Nessuna nuova notifica',
    demo_pin_unavailable: 'Modalità demo: cambio PIN non disponibile',
    demo_api_unavailable: 'Modalità demo: API non connessa',
    no_card_for_design_change: 'Nessuna carta per cambiare design',
    card_design_update_failed: 'Impossibile aggiornare il design',
    card_design_updated: 'Design della carta aggiornato',
    card_issue_failed: 'Impossibile emettere la carta',
    new_card_issued: 'Nuova carta emessa',
    card_short_label: 'Carta',
    confirm_pin: 'Conferma PIN',
    pin_mismatch: 'I PIN non coincidono',
    choose_style_then_issue: 'Scegli uno stile, poi emetti una carta virtuale',
    selected_label: 'Selezionato',
    cancel_label: 'Annulla',
    period_week_short: 'S',
    period_month_short: 'M',
    period_year_short: 'A',
    statement_pdf: 'Estratto PDF',
    copy_success: 'Copiato',
    copy_failed: 'Impossibile copiare',
    last_items_badge: 'ULTIMI',
    shipping_name_placeholder: 'Nome e cognome',
    shipping_address_placeholder: 'Kyiv, via Khreshchatyk 1, apt. 5',
    order_items_suffix: 'art.',
    due_prefix: 'entro',
    passwords_do_not_match: 'Le password non coincidono',
    forgot_password_contact_support: 'Contatta il supporto per recuperare la password',
    full_name_placeholder: 'Mario Rossi',
    data_load_failed: 'Impossibile caricare i dati.',
    active_cards_metric: 'Carte attive',
    cardholder_label: 'Cardholder',
    valid_label: 'Valid',
    transfer_placeholder_card: '4721 •••• •••• ••••',
    transfer_placeholder_account: 'AB-100011',
    filter_all: 'Tutti',
    filter_income: 'Entrate',
    filter_outcome: 'Uscite',
    notifications_center: 'Notifiche',
    balance_history_title: 'Storico Saldo',
    achievements_title: 'Traguardi',
    achievements_progress: 'completati',
    insights_title: 'Analisi',
    tx_note_label: 'Nota',
    tx_note_placeholder: 'Aggiungi una nota...',
    tx_note_saved: 'Nota salvata',
    top_recipients_title: 'Destinatari frequenti',
    mark_all_read: 'Segna tutto come letto',
    sent_label: 'trasferimenti',
    sort_newest: 'Nuovi',
    sort_oldest: 'Vecchi',
    sort_amount: 'Importo',
    dk_search: 'Cerca e comandi',
    dk_search_ph: 'Trova una pagina, un’azione o un’operazione…',
    dk_group_go: 'Vai a',
    dk_group_actions: 'Azioni',
    dk_group_tx: 'Operazioni',
    dk_no_results: 'Nessun risultato',
    dk_collapse: 'Comprimi il menu',
    dk_expand: 'Espandi il menu',
    dk_copy_account: 'Copia il numero del conto',
    dk_copied: 'Numero del conto copiato',
    dk_days_short: 'g',
    dk_this_month: 'questo mese',
    dk_hide_balance: 'Nascondi il saldo',
    dk_show_balance: 'Mostra il saldo',
    dk_total: 'Totale',
    dk_to_navigate: 'navigare',
    dk_to_open: 'aprire',
    dk_to_close: 'chiudere',
    dk_menu: 'Menu',
    dk_history_chart: 'Andamento del saldo',
    dk_open: 'Apri',
    dk_cat_payment: 'Pagamenti',
    dk_cat_savings: 'Risparmi',
    dk_cat_marketplace: 'Negozio',
    dk_cat_marketplace_invoice: 'Fatture del negozio',
    dk_cat_donation: 'Donazioni',
    dk_cat_credit: 'Crediti',
    dk_cat_topup: 'Ricariche',
    dk_cat_other: 'Altro',
    dk_login_title: 'Una banca didattica per la finanza virtuale',
    dk_login_p1: 'Carte, bonifici e depositi — in token TAX',
    dk_login_p2: 'Antifrode e 3-D Secure, come in una banca vera',
    dk_login_p3: 'Nessun denaro reale: tutto per studio e ricerca',
  },
  de: {
    user_fallback: 'Nutzer',
    greeting_morning: 'Guten Morgen',
    greeting_day: 'Guten Tag',
    greeting_evening: 'Guten Abend',
    greeting_night: 'Gute Nacht',
    tabs_overview: 'Übersicht',
    tabs_operations: 'Umsätze',
    tabs_cards: 'Karten',
    tabs_market: 'Shop',
    tabs_profile: 'Profil',
    quick_topup: 'Aufladen',
    quick_by_card: 'An Karte',
    quick_by_account: 'An Konto',
    quick_market: 'Shop',
    balance_total: 'Gesamtsaldo',
    cards_mine: 'Meine Karten',
    all: 'Alle',
    quick_actions: 'Schnellaktionen',
    recent_activity: 'Letzte Aktivität',
    history: 'Verlauf',
    no_transactions_yet: 'Noch keine Umsätze',
    topup_or_transfer: 'Laden Sie Ihr Konto auf oder überweisen Sie',
    profile_verified: 'Verifiziert',
    profile_name: 'Name',
    profile_phone: 'Telefon',
    profile_email: 'E-Mail',
    profile_account: 'Konto',
    profile_security: 'Sicherheit',
    profile_password: 'Passwort',
    profile_change_photo: 'Foto ändern',
    profile_remove_photo: 'Entfernen',
    profile_change_password: 'Passwort ändern',
    profile_current_password: 'Aktuelles Passwort',
    profile_new_password: 'Neues Passwort',
    profile_save: 'Speichern',
    profile_logout: 'Abmelden',
    settings_language: 'Sprache',
    settings_language_sub: 'App-Oberfläche',
    settings_notifications: 'Mitteilungen',
    settings_notif_tx: 'Umsätze',
    settings_notif_security: 'Sicherheit',
    settings_notif_promo: 'Aktionen und Angebote',
    settings_limits: 'Budgetlimits',
    settings_limits_sub: 'Monatliches Ausgabenlimit pro Kategorie',
    settings_limit_add: 'Limit hinzufügen',
    settings_limit_spent: 'ausgegeben',
    settings_limit_of: 'von',
    settings_pin: 'PIN-Code',
    settings_pin_sub: 'Zum Bestätigen von Vorgängen',
    settings_pin_set: 'PIN festlegen',
    settings_pin_change: 'PIN ändern',
    settings_pin_clear: 'PIN entfernen',
    settings_pin_active: 'PIN ist festgelegt',
    settings_app_info: 'Über die App',
    settings_version: 'Version',
    settings_api_status: 'API-Status',
    settings_support: 'Support',
    dep_title: 'Einlagen',
    dep_open: 'Einlage eröffnen',
    dep_amount: 'Einlagebetrag',
    dep_term: 'Laufzeit',
    dep_rate: 'Zinssatz',
    dep_monthly: 'Mon.',
    dep_interest: 'Zinsen',
    dep_maturity: 'Fälligkeit',
    dep_days_left: 'Tage übrig',
    dep_auto_renew: 'Automatisch verlängern',
    dep_close: 'Einlage schließen',
    dep_close_early: 'Vorzeitig schließen (ohne Zinsen)',
    dep_status_active: 'Aktiv',
    dep_status_matured: 'Fällig',
    dep_status_closed: 'Geschlossen',
    dep_status_early: 'Vorzeitig geschlossen',
    dep_no_items: 'Keine aktiven Einlagen',
    dep_min_amount: 'Mindestbetrag 500 TAX',
    dep_accrued: 'Aufgelaufen',
    dep_total_payout: 'Auszahlung',
    lang_uk: 'Ukrainisch',
    lang_en: 'Englisch',
    lang_it: 'Italienisch',
    lang_de: 'Deutsch',
    lang_ru: 'Russisch',
    personal_cabinet: 'Persönliches Banking',
    face_id_unavailable: 'Auf diesem Gerät nicht verfügbar',
    push_notifications: 'Push-Mitteilungen',
    unavailable: 'Nicht verfügbar',
    no_change: 'Keine Änderung',
    new_cash_flow: 'Neue Bewegung',
    no_dynamics: 'Keine Entwicklung',
    receipt_opened: 'Beleg geöffnet',
    request_error: 'Anfragefehler.',
    transfer_topup_title: 'Konto aufladen',
    transfer_by_card_title: 'Überweisung an Karte',
    transfer_by_account_title: 'Überweisung an Konto',
    transfer_card_number: 'Kartennummer',
    transfer_account_number: 'Kontonummer',
    transfer_optional_desc: 'Beschreibung (optional)',
    transfer_comment: 'Kommentar',
    amount_label: 'Betrag (TAX)',
    enter_amount: 'Betrag eingeben',
    enter_recipient: 'Empfänger eingeben',
    session_expired: 'Sitzung abgelaufen. Bitte erneut anmelden.',
    operation_error: 'Fehler beim Vorgang',
    topup_success: 'Konto aufgeladen um',
    transfer_success: 'Überweisung ausgeführt über',
    cards_not_issued: 'Noch keine Karten ausgegeben',
    cards_issue_hint: 'Gehen Sie zu Karten, um Ihre erste Karte auszugeben.',
    open_cards: 'Karten öffnen',
    spending_this_month: 'Ausgaben in diesem Monat',
    insufficient_spend_data: 'Zu wenig Daten für eine Aufschlüsselung.',
    spend_transfer: 'Überweisungen',
    spend_food: 'Essen',
    spend_transport: 'Verkehr',
    spend_utility: 'Nebenkosten',
    spend_shopping: 'Einkäufe',
    spend_subscription: 'Abos',
    cards_title: 'Meine Karten',
    card_not_found: 'Karte nicht gefunden.',
    pin_change_error: 'Fehler beim Ändern der PIN',
    pin_saved: 'Karten-PIN geändert',
    card_blocked: 'Karte gesperrt',
    card_unblocked: 'Karte entsperrt',
    card_closed: 'Karte geschlossen',
    card_active_status: 'Aktiv',
    card_frozen_status: 'Gesperrt',
    card_design_error: 'Fehler beim Kartendesign',
    card_details: 'Details',
    account_label: 'Konto',
    new_pin_4_digits: 'Neue PIN (4 Ziffern)',
    saving: 'Wird gespeichert…',
    save_pin: 'PIN speichern',
    operations_title: 'Umsätze',
    download_csv: 'CSV herunterladen',
    search_transactions: 'Umsätze suchen...',
    nothing_found_for: 'Nichts gefunden für',
    download_receipt: 'Beleg herunterladen',
    receipt_download_error: 'Fehler beim Herunterladen des Belegs',
    download_error: 'Fehler beim Herunterladen',
    export_error: 'Exportfehler',
    statement_error: 'Fehler beim Kontoauszug',
    face_id_on: 'Face ID aktiviert',
    face_id_off: 'Face ID deaktiviert',
    password_changed: 'Passwort erfolgreich geändert',
    pick_image: 'Bild auswählen',
    photo_too_large: 'Foto zu groß (max. 3 MB)',
    photo_read_error: 'Foto konnte nicht gelesen werden',
    photo_updated: 'Profilfoto aktualisiert',
    photo_upload_error: 'Foto konnte nicht hochgeladen werden',
    photo_removed: 'Foto entfernt',
    profile_photo_alt: 'Profilfoto',
    market_out_of_stock: 'Nicht vorrätig',
    add_to_cart: 'In den Warenkorb',
    cart_title: 'Warenkorb',
    delivery_title: 'Lieferung',
    cart_empty: 'Warenkorb ist leer',
    added_to_cart: 'zum Warenkorb hinzugefügt',
    checkout_success: 'Bestellung aufgegeben!',
    checkout_error: 'Fehler bei der Bestellung',
    orders_tab: 'Bestellungen',
    invoices_tab: 'Rechnungen',
    market_title: 'Shop',
    loading: 'Wird geladen…',
    market_empty: 'Der Shop ist leer',
    try_another_query: 'Versuchen Sie eine andere Suche',
    no_results: 'Nichts gefunden',
    products_not_added: 'Noch keine Produkte.',
    orders_empty: 'Noch keine Bestellungen',
    invoices_empty: 'Noch keine Rechnungen',
    invoices_after_orders: 'Rechnungen erscheinen nach Ihren Bestellungen.',
    invoice_label: 'Rechnung',
    order_label: 'Bestellung',
    login_tab: 'Anmelden',
    register_tab: 'Registrieren',
    wait_processing: 'Wird verarbeitet…',
    login_with_face_id: 'Mit Face ID anmelden',
    full_name_label: 'Vollständiger Name',
    email_label: 'E-Mail',
    phone_or_email: 'Telefon oder E-Mail',
    phone_or_email_placeholder: 'Telefon oder E-Mail',
    password_label: 'Passwort',
    forgot_password: 'Passwort vergessen?',
    confirm_password: 'Passwort bestätigen',
    repeat_password: 'Passwort wiederholen',
    sign_in: 'Anmelden',
    create_account: 'Konto erstellen',
    issue_card: 'Karte ausgeben',
    creating: 'Wird erstellt...',
    invalid_credentials: 'Ungültige Zugangsdaten',
    registration_error: 'Fehler bei der Registrierung',
    verification_error: 'Fehler bei der Verifizierung',
    face_id_error: 'Face-ID-Fehler',
    loading_data: 'Daten werden geladen...',
    change_pin: 'PIN ändern',
    choose_card_design: 'Kartendesign wählen',
    issue_new_card: 'Neue Karte ausgeben',
    applying: 'Wird angewendet…',
    apply_design: 'Design übernehmen',
    issue_card_full: 'Karte ausgeben',
    face_id_transfer_sub: 'Anmeldung und Bestätigung von Überweisungen',
    in_stock: 'Vorrätig',
    next_delivery: 'Weiter → Lieferung',
    cart_items_count: 'Artikel',
    total_label: 'Gesamt',
    recipient_label: 'Empfänger',
    delivery_phone: 'Telefon',
    delivery_address: 'Lieferadresse',
    pay_total: 'Zu zahlen',
    place_order: 'Bestellung aufgeben',
    checkout_processing: 'Bestellung läuft…',
    catalog_tab: 'Katalog',
    product_search: 'Produkte suchen…',
    catalog_first_order_hint: 'Geben Sie Ihre erste Bestellung im Katalog auf.',
    receipt_short: 'Beleg',
    last_items: 'Letzte',
    card_physical: 'Physisch',
    card_virtual: 'Virtuell',
    card_valid_until: 'bis',
    card_design_label: 'Design',
    change_label: 'Ändern',
    account_activity_month: 'Kontoaktivität im Monat',
    operations_short: 'Vorg.',
    spent_label: 'ausgegeben',
    account_balance_label: 'Kontostand',
    design_action: 'Design',
    freeze_card: 'Sperren',
    unfreeze_card: 'Entsperren',
    close_card: 'Schließen',
    error_boundary_title: 'Etwas ist schiefgelaufen',
    error_boundary_refresh: 'Seite neu laden',
    analytics_prev_month_suffix: 'ggü. Vormonat',
    api_health_temporarily_unavailable: 'Die API ist vorübergehend nicht erreichbar. Bitte in ein paar Sekunden erneut versuchen.',
    api_health_status_unavailable: 'API-Status nicht verfügbar.',
    api_health_no_connection: 'Keine Verbindung zur API. Prüfen Sie das Netz oder versuchen Sie es später.',
    design_subtitle_gold: 'TaxTech',
    design_subtitle_forest: 'Tiefes Grün',
    design_subtitle_slate: 'Helles Metallic',
    design_subtitle_dark: 'Dunkel und minimal',
    design_subtitle_florence: 'Kuppel und Altstadt',
    design_subtitle_venice: 'Kanäle und Platz',
    design_subtitle_tuscany_hills: 'Toskanische Felder',
    design_subtitle_tuscany_villa: 'Warme Landschaft',
    today_label: 'Heute',
    yesterday_label: 'Gestern',
    no_new_notifications: 'Keine neuen Mitteilungen',
    demo_pin_unavailable: 'Demomodus: PIN-Änderung nicht verfügbar',
    demo_api_unavailable: 'Demomodus: API nicht verbunden',
    no_card_for_design_change: 'Keine Karte für einen Designwechsel',
    card_design_update_failed: 'Design konnte nicht geändert werden',
    card_design_updated: 'Kartendesign geändert',
    card_issue_failed: 'Karte konnte nicht ausgegeben werden',
    new_card_issued: 'Neue Karte ausgegeben',
    card_short_label: 'Karte',
    confirm_pin: 'PIN bestätigen',
    pin_mismatch: 'Die PINs stimmen nicht überein',
    choose_style_then_issue: 'Stil wählen, dann eine virtuelle Karte ausgeben',
    selected_label: 'Ausgewählt',
    cancel_label: 'Abbrechen',
    period_week_short: 'W',
    period_month_short: 'M',
    period_year_short: 'J',
    statement_pdf: 'Kontoauszug PDF',
    copy_success: 'Kopiert',
    copy_failed: 'Kopieren fehlgeschlagen',
    last_items_badge: 'LETZTE',
    shipping_name_placeholder: 'Vor- und Nachname',
    shipping_address_placeholder: 'Kyjiw, Chreschtschatyk 1, Whg. 5',
    order_items_suffix: 'Pos.',
    due_prefix: 'bis',
    passwords_do_not_match: 'Die Passwörter stimmen nicht überein',
    forgot_password_contact_support: 'Wenden Sie sich an den Support, um Ihr Passwort wiederherzustellen',
    full_name_placeholder: 'Max Mustermann',
    data_load_failed: 'Daten konnten nicht geladen werden.',
    active_cards_metric: 'Aktive Karten',
    cardholder_label: 'Cardholder',
    valid_label: 'Valid',
    transfer_placeholder_card: '4721 •••• •••• ••••',
    transfer_placeholder_account: 'AB-100011',
    filter_all: 'Alle',
    filter_income: 'Eingänge',
    filter_outcome: 'Ausgaben',
    notifications_center: 'Mitteilungen',
    balance_history_title: 'Saldoverlauf',
    achievements_title: 'Erfolge',
    achievements_progress: 'erledigt',
    insights_title: 'Analysen',
    tx_note_label: 'Notiz',
    tx_note_placeholder: 'Notiz hinzufügen...',
    tx_note_saved: 'Notiz gespeichert',
    top_recipients_title: 'Häufige Empfänger',
    mark_all_read: 'Alle als gelesen markieren',
    sent_label: 'Überweisungen',
    sort_newest: 'Neueste',
    sort_oldest: 'Älteste',
    sort_amount: 'Betrag',
    dk_search: 'Suche und Befehle',
    dk_search_ph: 'Seite, Aktion oder Umsatz finden…',
    dk_group_go: 'Gehe zu',
    dk_group_actions: 'Aktionen',
    dk_group_tx: 'Umsätze',
    dk_no_results: 'Nichts gefunden',
    dk_collapse: 'Menü einklappen',
    dk_expand: 'Menü ausklappen',
    dk_copy_account: 'Kontonummer kopieren',
    dk_copied: 'Kontonummer kopiert',
    dk_days_short: 'T',
    dk_this_month: 'diesen Monat',
    dk_hide_balance: 'Saldo ausblenden',
    dk_show_balance: 'Saldo anzeigen',
    dk_total: 'Gesamt',
    dk_to_navigate: 'navigieren',
    dk_to_open: 'öffnen',
    dk_to_close: 'schließen',
    dk_menu: 'Menü',
    dk_history_chart: 'Saldoentwicklung',
    dk_open: 'Öffnen',
    dk_cat_payment: 'Zahlungen',
    dk_cat_savings: 'Ersparnisse',
    dk_cat_marketplace: 'Shop',
    dk_cat_marketplace_invoice: 'Shop-Rechnungen',
    dk_cat_donation: 'Spenden',
    dk_cat_credit: 'Kredite',
    dk_cat_topup: 'Aufladungen',
    dk_cat_other: 'Sonstiges',
    dk_login_title: 'Eine Lernbank für virtuelle Finanzen',
    dk_login_p1: 'Karten, Überweisungen und Einlagen — in TAX-Token',
    dk_login_p2: 'Betrugsschutz und 3-D Secure wie bei einer echten Bank',
    dk_login_p3: 'Kein echtes Geld: alles für Lernen und Forschung',
  },
  ru: {
    user_fallback: 'Пользователь',
    greeting_morning: 'Доброе утро',
    greeting_day: 'Добрый день',
    greeting_evening: 'Добрый вечер',
    greeting_night: 'Доброй ночи',
    tabs_overview: 'Обзор',
    tabs_operations: 'Операции',
    tabs_cards: 'Карты',
    tabs_market: 'Магазин',
    tabs_profile: 'Профиль',
    quick_topup: 'Пополнить',
    quick_by_card: 'На карту',
    quick_by_account: 'По счёту',
    quick_market: 'Магазин',
    balance_total: 'Общий баланс',
    cards_mine: 'Мои карты',
    all: 'Все',
    quick_actions: 'Быстрые действия',
    recent_activity: 'Последняя активность',
    history: 'История',
    no_transactions_yet: 'Операций пока нет',
    topup_or_transfer: 'Пополните счёт или сделайте перевод',
    profile_verified: 'Верифицирован',
    profile_name: 'Имя',
    profile_phone: 'Телефон',
    profile_email: 'Email',
    profile_account: 'Счёт',
    profile_security: 'Безопасность',
    profile_password: 'Пароль',
    profile_change_photo: 'Сменить фото',
    profile_remove_photo: 'Удалить',
    profile_change_password: 'Сменить пароль',
    profile_current_password: 'Текущий пароль',
    profile_new_password: 'Новый пароль',
    profile_save: 'Сохранить',
    profile_logout: 'Выйти из аккаунта',
    settings_language: 'Язык',
    settings_language_sub: 'Интерфейс приложения',
    settings_notifications: 'Уведомления',
    settings_notif_tx: 'Операции',
    settings_notif_security: 'Безопасность',
    settings_notif_promo: 'Акции и предложения',
    settings_limits: 'Бюджетные лимиты',
    settings_limits_sub: 'Месячный лимит расходов по категории',
    settings_limit_add: 'Добавить лимит',
    settings_limit_spent: 'потрачено',
    settings_limit_of: 'из',
    settings_pin: 'PIN-код',
    settings_pin_sub: 'Для подтверждения операций',
    settings_pin_set: 'Установить PIN',
    settings_pin_change: 'Сменить PIN',
    settings_pin_clear: 'Удалить PIN',
    settings_pin_active: 'PIN установлен',
    settings_app_info: 'О приложении',
    settings_version: 'Версия',
    settings_api_status: 'Статус API',
    settings_support: 'Поддержка',
    dep_title: 'Депозиты',
    dep_open: 'Открыть депозит',
    dep_amount: 'Сумма депозита',
    dep_term: 'Срок',
    dep_rate: 'Ставка',
    dep_monthly: 'мес.',
    dep_interest: 'Начисления',
    dep_maturity: 'Дата окончания',
    dep_days_left: 'дней осталось',
    dep_auto_renew: 'Автопролонгация',
    dep_close: 'Закрыть депозит',
    dep_close_early: 'Досрочное закрытие (без процентов)',
    dep_status_active: 'Активный',
    dep_status_matured: 'Завершён',
    dep_status_closed: 'Закрыт',
    dep_status_early: 'Закрыт досрочно',
    dep_no_items: 'У вас нет активных депозитов',
    dep_min_amount: 'Минимальная сумма — 500 TAX',
    dep_accrued: 'Начислено',
    dep_total_payout: 'К выплате',
    lang_uk: 'Украинский',
    lang_en: 'Английский',
    lang_it: 'Итальянский',
    lang_de: 'Немецкий',
    lang_ru: 'Русский',
    personal_cabinet: 'Личный кабинет',
    face_id_unavailable: 'Недоступно на этом устройстве',
    push_notifications: 'Push-уведомления',
    unavailable: 'Недоступно',
    no_change: 'Без изменений',
    new_cash_flow: 'Новое движение средств',
    no_dynamics: 'Без динамики',
    receipt_opened: 'Чек открыт',
    request_error: 'Ошибка запроса.',
    transfer_topup_title: 'Пополнить счёт',
    transfer_by_card_title: 'Перевод на карту',
    transfer_by_account_title: 'Перевод по счёту',
    transfer_card_number: 'Номер карты',
    transfer_account_number: 'Номер счёта',
    transfer_optional_desc: 'Описание (необязательно)',
    transfer_comment: 'Комментарий',
    amount_label: 'Сумма (TAX)',
    enter_amount: 'Укажите сумму',
    enter_recipient: 'Укажите получателя',
    session_expired: 'Сессия завершилась. Войдите снова.',
    operation_error: 'Ошибка операции',
    topup_success: 'Счёт пополнен на',
    transfer_success: 'Перевод выполнен на',
    cards_not_issued: 'Карты ещё не выпущены',
    cards_issue_hint: 'Перейдите в раздел «Карты», чтобы выпустить первую карту.',
    open_cards: 'Открыть карты',
    spending_this_month: 'Расходы в этом месяце',
    insufficient_spend_data: 'Недостаточно данных для разбивки расходов.',
    spend_transfer: 'Переводы',
    spend_food: 'Еда',
    spend_transport: 'Транспорт',
    spend_utility: 'Коммунальные',
    spend_shopping: 'Покупки',
    spend_subscription: 'Подписки',
    cards_title: 'Мои карты',
    card_not_found: 'Карта не найдена.',
    pin_change_error: 'Ошибка смены PIN',
    pin_saved: 'PIN карты изменён',
    card_blocked: 'Карта заморожена',
    card_unblocked: 'Карта разморожена',
    card_closed: 'Карта закрыта',
    card_active_status: 'Активна',
    card_frozen_status: 'Заморожена',
    card_design_error: 'Ошибка дизайна карты',
    card_details: 'Детали',
    account_label: 'Счёт',
    new_pin_4_digits: 'Новый PIN (4 цифры)',
    saving: 'Сохранение…',
    save_pin: 'Сохранить PIN',
    operations_title: 'Операции',
    download_csv: 'Скачать CSV',
    search_transactions: 'Поиск операций...',
    nothing_found_for: 'Ничего не найдено по запросу',
    download_receipt: 'Скачать чек',
    receipt_download_error: 'Ошибка загрузки чека',
    download_error: 'Ошибка загрузки',
    export_error: 'Ошибка экспорта',
    statement_error: 'Ошибка выписки',
    face_id_on: 'Face ID включён',
    face_id_off: 'Face ID выключен',
    password_changed: 'Пароль успешно изменён',
    pick_image: 'Выберите изображение',
    photo_too_large: 'Фото слишком большое (до 3 МБ)',
    photo_read_error: 'Не удалось прочитать фото',
    photo_updated: 'Фото профиля обновлено',
    photo_upload_error: 'Не удалось загрузить фото',
    photo_removed: 'Фото удалено',
    profile_photo_alt: 'Фото профиля',
    market_out_of_stock: 'Нет в наличии',
    add_to_cart: 'В корзину',
    cart_title: 'Корзина',
    delivery_title: 'Доставка',
    cart_empty: 'Корзина пуста',
    added_to_cart: 'добавлено в корзину',
    checkout_success: 'Заказ оформлен!',
    checkout_error: 'Ошибка оформления',
    orders_tab: 'Заказы',
    invoices_tab: 'Инвойсы',
    market_title: 'Магазин',
    loading: 'Загрузка…',
    market_empty: 'Магазин пуст',
    try_another_query: 'Попробуйте другой запрос',
    no_results: 'Ничего не найдено',
    products_not_added: 'Товары ещё не добавлены.',
    orders_empty: 'Заказов пока нет',
    invoices_empty: 'Инвойсов пока нет',
    invoices_after_orders: 'Инвойсы появятся после оформления заказов.',
    invoice_label: 'Инвойс',
    order_label: 'Заказ',
    login_tab: 'Вход',
    register_tab: 'Регистрация',
    wait_processing: 'Обработка…',
    login_with_face_id: 'Войти с Face ID',
    full_name_label: 'Полное имя',
    email_label: 'Email',
    phone_or_email: 'Телефон или Email',
    phone_or_email_placeholder: 'Телефон или email',
    password_label: 'Пароль',
    forgot_password: 'Забыли пароль?',
    confirm_password: 'Подтвердите пароль',
    repeat_password: 'Повторите пароль',
    sign_in: 'Войти',
    create_account: 'Создать аккаунт',
    issue_card: 'Выпустить',
    creating: 'Создание...',
    invalid_credentials: 'Неверные данные',
    registration_error: 'Ошибка регистрации',
    verification_error: 'Ошибка верификации',
    face_id_error: 'Ошибка Face ID',
    loading_data: 'Загрузка данных...',
    change_pin: 'Сменить PIN',
    choose_card_design: 'Выберите дизайн карты',
    issue_new_card: 'Выпуск новой карты',
    applying: 'Применение…',
    apply_design: 'Применить дизайн',
    issue_card_full: 'Выпустить карту',
    face_id_transfer_sub: 'Вход и подтверждение переводов',
    in_stock: 'В наличии',
    next_delivery: 'Далее → Доставка',
    cart_items_count: 'товаров',
    total_label: 'Итого',
    recipient_label: 'Получатель',
    delivery_phone: 'Телефон',
    delivery_address: 'Адрес доставки',
    pay_total: 'К оплате',
    place_order: 'Оформить заказ',
    checkout_processing: 'Оформление…',
    catalog_tab: 'Каталог',
    product_search: 'Поиск товаров…',
    catalog_first_order_hint: 'Оформите первый заказ в каталоге.',
    receipt_short: 'Чек',
    last_items: 'Последних',
    card_physical: 'Физическая',
    card_virtual: 'Виртуальная',
    card_valid_until: 'до',
    card_design_label: 'Дизайн',
    change_label: 'Изменить',
    account_activity_month: 'Активность счёта за месяц',
    operations_short: 'оп.',
    spent_label: 'расходов',
    account_balance_label: 'Баланс счёта',
    design_action: 'Дизайн',
    freeze_card: 'Заморозить',
    unfreeze_card: 'Разморозить',
    close_card: 'Закрыть',
    error_boundary_title: 'Что-то пошло не так',
    error_boundary_refresh: 'Обновить страницу',
    analytics_prev_month_suffix: 'к прошлому месяцу',
    api_health_temporarily_unavailable: 'API временно недоступно. Попробуйте через несколько секунд.',
    api_health_status_unavailable: 'Статус API недоступен.',
    api_health_no_connection: 'Нет соединения с API. Проверьте сеть или попробуйте позже.',
    design_subtitle_gold: 'TaxTech',
    design_subtitle_forest: 'Глубокий зелёный',
    design_subtitle_slate: 'Светлый металлик',
    design_subtitle_dark: 'Тёмный минимализм',
    design_subtitle_florence: 'Купол и старый город',
    design_subtitle_venice: 'Каналы и площадь',
    design_subtitle_tuscany_hills: 'Тосканские поля',
    design_subtitle_tuscany_villa: 'Тёплый пейзаж',
    today_label: 'Сегодня',
    yesterday_label: 'Вчера',
    no_new_notifications: 'Новых уведомлений нет',
    demo_pin_unavailable: 'Демо-режим: смена PIN недоступна',
    demo_api_unavailable: 'Демо-режим: API не подключено',
    no_card_for_design_change: 'Нет карты для смены дизайна',
    card_design_update_failed: 'Не удалось обновить дизайн',
    card_design_updated: 'Дизайн карты обновлён',
    card_issue_failed: 'Не удалось выпустить карту',
    new_card_issued: 'Новая карта выпущена',
    card_short_label: 'Карта',
    confirm_pin: 'Подтвердить PIN',
    pin_mismatch: 'PIN-коды не совпадают',
    choose_style_then_issue: 'Выберите стиль, затем выпустите виртуальную карту',
    selected_label: 'Выбрано',
    cancel_label: 'Отмена',
    period_week_short: 'Н',
    period_month_short: 'М',
    period_year_short: 'Г',
    statement_pdf: 'Выписка PDF',
    copy_success: 'Скопировано',
    copy_failed: 'Не удалось скопировать',
    last_items_badge: 'ПОСЛЕДНИЕ',
    shipping_name_placeholder: 'Фамилия Имя Отчество',
    shipping_address_placeholder: 'г. Киев, ул. Крещатик 1, кв. 5',
    order_items_suffix: 'поз.',
    due_prefix: 'до',
    passwords_do_not_match: 'Пароли не совпадают',
    forgot_password_contact_support: 'Обратитесь в поддержку для восстановления пароля',
    full_name_placeholder: 'Иван Петров',
    data_load_failed: 'Не удалось загрузить данные.',
    active_cards_metric: 'Активные карты',
    cardholder_label: 'Cardholder',
    valid_label: 'Valid',
    transfer_placeholder_card: '4721 •••• •••• ••••',
    transfer_placeholder_account: 'AB-100011',
    filter_all: 'Все',
    filter_income: 'Поступления',
    filter_outcome: 'Расходы',
    notifications_center: 'Уведомления',
    balance_history_title: 'Динамика баланса',
    achievements_title: 'Достижения',
    achievements_progress: 'выполнено',
    insights_title: 'Аналитика',
    tx_note_label: 'Заметка',
    tx_note_placeholder: 'Добавить заметку...',
    tx_note_saved: 'Заметка сохранена',
    top_recipients_title: 'Частые получатели',
    mark_all_read: 'Прочитать все',
    sent_label: 'переводов',
    sort_newest: 'Новые',
    sort_oldest: 'Старые',
    sort_amount: 'Сумма',
    dk_search: 'Поиск и команды',
    dk_search_ph: 'Найти страницу, действие или операцию…',
    dk_group_go: 'Перейти',
    dk_group_actions: 'Действия',
    dk_group_tx: 'Операции',
    dk_no_results: 'Ничего не найдено',
    dk_collapse: 'Свернуть меню',
    dk_expand: 'Развернуть меню',
    dk_copy_account: 'Скопировать номер счёта',
    dk_copied: 'Номер счёта скопирован',
    dk_days_short: 'д',
    dk_this_month: 'за месяц',
    dk_hide_balance: 'Скрыть баланс',
    dk_show_balance: 'Показать баланс',
    dk_total: 'Итого',
    dk_to_navigate: 'навигация',
    dk_to_open: 'открыть',
    dk_to_close: 'закрыть',
    dk_menu: 'Меню',
    dk_history_chart: 'Динамика баланса',
    dk_open: 'Открыть',
    dk_cat_payment: 'Оплаты',
    dk_cat_savings: 'Накопления',
    dk_cat_marketplace: 'Магазин',
    dk_cat_marketplace_invoice: 'Счета магазина',
    dk_cat_donation: 'Донаты',
    dk_cat_credit: 'Кредиты',
    dk_cat_topup: 'Пополнения',
    dk_cat_other: 'Другое',
    dk_login_title: 'Учебный банк для виртуальных финансов',
    dk_login_p1: 'Карты, переводы и депозиты — в токенах TAX',
    dk_login_p2: 'Антифрод и 3-D Secure, как в настоящем банке',
    dk_login_p3: 'Никаких реальных денег: всё для учёбы и исследований',
  },
} as const;

type TranslationKey = keyof typeof translations.uk;

function readSelectedCardIndex(): number {
  try {
    const raw = localStorage.getItem(CARD_INDEX_STORAGE_KEY);
    const n = Number(raw);
    return Number.isFinite(n) && n >= 0 ? Math.floor(n) : 0;
  } catch {
    return 0;
  }
}

function persistSelectedCardIndex(idx: number) {
  try {
    localStorage.setItem(CARD_INDEX_STORAGE_KEY, String(Math.max(0, Math.floor(idx))));
  } catch {
    // ignore storage errors (private mode / quota)
  }
}

function getToken(): string {
  return localStorage.getItem('army_bank_token') || '';
}

function clearToken() {
  localStorage.removeItem('army_bank_token');
  localStorage.removeItem('arm_cart');
}

let apiHealthCache: { ok: boolean; ts: number } | null = null;

async function ensureApiStatusHealthy(): Promise<void> {
  const tt = translations[getStoredLanguage()];
  const now = Date.now();
  if (apiHealthCache && (now - apiHealthCache.ts) < 15000) {
    if (!apiHealthCache.ok) throw new Error(tt.api_health_temporarily_unavailable);
    return;
  }

  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), 4500);
  try {
    const res = await fetch(apiUrl('/api-status'), {
      method: 'GET',
      cache: 'no-store',
      signal: controller.signal,
      headers: { Accept: 'text/html' },
    });
    const ok = res.ok;
    apiHealthCache = { ok, ts: now };
    if (!ok) throw new Error(tt.api_health_status_unavailable);
  } catch {
    apiHealthCache = { ok: false, ts: now };
    throw new Error(tt.api_health_no_connection);
  } finally {
    window.clearTimeout(timer);
  }
}

async function apiRequest<T>(url: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers = new Headers(options.headers || {});
  headers.set('Content-Type', 'application/json');
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(apiUrl(url), { ...options, headers });
  const refreshed = response.headers.get('X-Refresh-Token');
  if (refreshed) localStorage.setItem('army_bank_token', refreshed);

  let payload: Record<string, unknown> = {};
  try {
    const raw = await response.text();
    payload = raw ? JSON.parse(raw) as Record<string, unknown> : {};
  } catch {
    payload = {};
  }

  if (!response.ok || payload.ok === false) {
    const msg = String(payload.error || payload.message || translations[getStoredLanguage()].request_error);
    const err = new Error(msg) as Error & { status?: number };
    err.status = response.status;
    throw err;
  }
  return ((payload.data ?? payload) as T);
}

function getProfilePhoto(): string {
  try {
    return localStorage.getItem(PROFILE_PHOTO_STORAGE_KEY) || '';
  } catch {
    return '';
  }
}

function setProfilePhoto(value: string) {
  try {
    if (value) localStorage.setItem(PROFILE_PHOTO_STORAGE_KEY, value);
    else localStorage.removeItem(PROFILE_PHOTO_STORAGE_KEY);
  } catch {
    // ignore storage errors
  }
}

function getStoredLanguage(): AppLang {
  return initialLandingLang();
}

function setStoredLanguage(value: AppLang) {
  saveLandingLang(value);
}

function markAppContinuation() {
  try {
    localStorage.setItem(APP_CONTINUATION_STORAGE_KEY, String(Date.now()));
  } catch {
    // ignore storage errors
  }
}

function readStoredTab(): TabKey {
  try {
    const raw = localStorage.getItem(ACTIVE_TAB_STORAGE_KEY);
    if (raw === 'overview' || raw === 'operations' || raw === 'cards' || raw === 'market' || raw === 'profile') return raw;
  } catch {
    // ignore storage errors
  }
  return 'overview';
}

function readStoredMarketTab(): 'catalog' | 'orders' | 'invoices' {
  try {
    const raw = localStorage.getItem(MARKET_TAB_STORAGE_KEY);
    if (raw === 'catalog' || raw === 'orders' || raw === 'invoices') return raw;
  } catch {
    // ignore storage errors
  }
  return 'catalog';
}

function openPdfBlobInNewTab(blob: Blob, fallbackFileName: string, toast?: (msg: string) => void) {
  markAppContinuation();
  const blobUrl = URL.createObjectURL(blob);
  const popup = window.open(blobUrl, '_blank', 'noopener,noreferrer');
  if (popup) {
    window.setTimeout(() => URL.revokeObjectURL(blobUrl), 60_000);
    return;
  }

  // Fallback for popup blockers.
  const a = document.createElement('a');
  a.href = blobUrl;
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  a.download = fallbackFileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(blobUrl), 5_000);
  if (toast) toast(translations[getStoredLanguage()].receipt_opened);
}

// ─── Toast notification ───────────────────────────────────────
function Toast({ msg }: { msg: string }) {
  return (
    <div style={{
      position: 'fixed', bottom: mobileDockInset,
      left: '50%', transform: 'translateX(-50%)',
      zIndex: 9999, pointerEvents: 'none',
      padding: '12px 18px', borderRadius: 18,
      background: '#1c1c1e',
      backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
      border: '1px solid transparent',
      color: text.primary, ...T.sm, fontWeight: 500,
      boxShadow: '0 16px 40px rgba(0,0,0, 0.42)',
      maxWidth: 'min(420px, calc(100vw - 32px))', textAlign: 'center', whiteSpace: 'normal', lineHeight: 1.35,
    }}>{msg}</div>
  );
}

function useWindowWidth() {
  const [w, setW] = useState(() => window.innerWidth);
  useEffect(() => {
    const handler = () => setW(window.innerWidth);
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  }, []);
  return w;
}

function useSheetSwipeClose(onClose: () => void, threshold = 88) {
  const startXRef = useRef<number | null>(null);
  const startYRef = useRef<number | null>(null);
  const axisRef = useRef<'x' | 'y' | null>(null);
  const activeRef = useRef(false);
  const [offsetY, setOffsetY] = useState(0);
  const [dragging, setDragging] = useState(false);

  function reset() {
    startXRef.current = null;
    startYRef.current = null;
    axisRef.current = null;
    activeRef.current = false;
    setDragging(false);
    setOffsetY(0);
  }

  function onTouchStart(e: React.TouchEvent<HTMLDivElement>) {
    const t = e.touches[0];
    const el = e.currentTarget;
    const canDrag = (el.scrollTop || 0) <= 0;
    activeRef.current = canDrag;
    startXRef.current = t.clientX;
    startYRef.current = t.clientY;
    axisRef.current = null;
    setDragging(false);
  }

  function onTouchMove(e: React.TouchEvent<HTMLDivElement>) {
    if (!activeRef.current || startXRef.current == null || startYRef.current == null) return;
    const t = e.touches[0];
    const dx = t.clientX - startXRef.current;
    const dy = t.clientY - startYRef.current;
    if (!axisRef.current && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
      axisRef.current = Math.abs(dy) >= Math.abs(dx) ? 'y' : 'x';
    }
    if (axisRef.current !== 'y' || dy <= 0) return;
    e.preventDefault();
    setDragging(true);
    setOffsetY(Math.max(0, Math.min(220, dy)));
  }

  function onTouchEnd() {
    if (offsetY >= threshold) {
      onClose();
    }
    reset();
  }

  return {
    offsetY,
    progress: Math.max(0, Math.min(1, offsetY / 180)),
    dragging,
    sheetProps: {
      onTouchStart,
      onTouchMove,
      onTouchEnd,
      onTouchCancel: onTouchEnd,
    },
    sheetStyle: {
      transform: `translate3d(0, ${offsetY}px, 0)`,
      transition: dragging ? 'none' : 'transform 220ms cubic-bezier(0.22, 0.61, 0.36, 1)',
      willChange: 'transform',
    } as React.CSSProperties,
  };
}

// ─── Shared helpers ───────────────────────────────────────────
function Chevron({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M6 4l4 4-4 4" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TrendUpIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 16l5-5 3 3 6-7" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M14 7h5v5" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TrendDownIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 8l5 5 3-3 6 7" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M14 17h5v-5" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function WalletIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 8.5A2.5 2.5 0 016.5 6H18a2 2 0 012 2v8a2 2 0 01-2 2H6.5A2.5 2.5 0 014 15.5v-7z" stroke={color} strokeWidth="1.8" />
      <path d="M4 9h14.5A1.5 1.5 0 0120 10.5v3A1.5 1.5 0 0118.5 15H4" stroke={color} strokeWidth="1.8" />
      <circle cx="16.5" cy="12" r="1" fill={color} />
    </svg>
  );
}

function BankIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 9l8-4 8 4" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M6 10v7M10 10v7M14 10v7M18 10v7" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
      <path d="M3 19h18" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function ReceiptIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M7 3h10v18l-2-1.6L13 21l-2-1.6L9 21l-2-1.6L5 21V5a2 2 0 012-2z" stroke={color} strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M9 8h6M9 12h6M9 16h4" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function TrophyIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M8 4h8v3a4 4 0 01-8 0V4z" stroke={color} strokeWidth="1.8" />
      <path d="M8 6H5a2 2 0 000 4h2M16 6h3a2 2 0 010 4h-2" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
      <path d="M12 11v4M9 20h6M10 15h4v5h-4z" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function CheckBadgeIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="8" stroke={color} strokeWidth="1.8" />
      <path d="M8.5 12l2.3 2.3 4.7-4.8" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function ChartIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 19V9M12 19V5M19 19v-7" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
      <path d="M4 19h16" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function AlertIcon({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 4l8 14H4l8-14z" stroke={color} strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M12 9v4M12 16h.01" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function TipIcon({ size = 14, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M9 18h6M10 21h4M8.5 14.5C7.6 13.7 7 12.5 7 11a5 5 0 1110 0c0 1.5-.6 2.7-1.5 3.5-.7.6-1 1.2-1.2 1.8h-2.6c-.2-.6-.5-1.2-1.2-1.8z" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// ─── Premium card ─────────────────────────────────────────────
type CardVariant =
  | 'gold'
  | 'emerald'
  | 'platinum'
  | 'obsidian'
  | 'florence'
  | 'tuscany_hills'
  | 'venice'
  | 'tuscany_villa'
  | 'roma_aureus'
  | 'roma_purpura'
  | 'roma_marmor'
  | 'roma_colosseum'
  | 'roma_spqr'
  | 'roma_pantheon'
  | 'roma_aqueduct'
  | 'roma_forum'
  | 'roma_colosseum_night';

interface CardData {
  variant: CardVariant;
  design?: string;
  number: string;
  name: string;
  expiry: string;
  type?: string;
  status?: string;
  limit?: string;
  used?: string;
}

const DESIGN_TO_VARIANT: Record<string, CardVariant> = {
  gold: 'gold',
  navy: 'obsidian',
  forest: 'emerald',
  rose: 'platinum',
  slate: 'platinum',
  camo: 'emerald',
  dark: 'obsidian',
  florence: 'florence',
  tuscany_hills: 'tuscany_hills',
  venice: 'venice',
  tuscany_villa: 'tuscany_villa',
  roma_aureus: 'roma_aureus',
  roma_purpura: 'roma_purpura',
  roma_marmor: 'roma_marmor',
  roma_colosseum: 'roma_colosseum',
  roma_spqr: 'roma_spqr',
  roma_pantheon: 'roma_pantheon',
  roma_aqueduct: 'roma_aqueduct',
  roma_forum: 'roma_forum',
  roma_colosseum_night: 'roma_colosseum_night',
};

function cardVariantFromDesign(design?: string | null): CardVariant {
  return DESIGN_TO_VARIANT[String(design || '').toLowerCase()] ?? 'gold';
}

function toUiCard(card: ApiCard, holderName: string): CardData {
  const tt = translations[getStoredLanguage()];
  return {
    design: (card.design || 'gold').toLowerCase(),
    variant: cardVariantFromDesign(card.design),
    number: cardTail(card.masked_number),
    name: (holderName || 'ARMY BANK').toUpperCase().slice(0, 26),
    expiry: card.expiry_display || '--/--',
    type: card.card_type === 'physical' ? tt.card_physical : tt.card_virtual,
    status: card.status || 'active',
  };
}


const photoVariant = (image: string, light = false) => ({
  bg: light ? '#ece8df' : '#1a120c', image,
  text: light ? '#1d1810' : '#ffffff', muted: light ? 'rgba(29,24,16,0.62)' : 'rgba(255,255,255,0.72)',
  shimmer: 'transparent',
  overlay: light
    ? 'linear-gradient(180deg, rgba(255,255,255,0.15) 0%, rgba(255,255,255,0) 40%, rgba(255,255,255,0.25) 100%)'
    : 'linear-gradient(180deg, rgba(0,0,0,0.42) 0%, rgba(0,0,0,0.05) 38%, rgba(0,0,0,0.12) 58%, rgba(0,0,0,0.72) 100%)',
  numberPlate: light ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.22)',
  bottomPlate: light ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.22)',
  badgePlate: light ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.22)',
});

const CARD_VARIANTS: Record<CardVariant, {
  bg: string;
  text: string;
  muted: string;
  shimmer: string;
  overlay: string;
  image?: string;
  numberPlate: string;
  bottomPlate: string;
  badgePlate: string;
}> = {
  gold: {
    bg: '#ffffff',
    text: '#000000', muted: 'rgba(0,0,0, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(0,0,0, 0.06)',
    bottomPlate: 'rgba(0,0,0, 0.06)',
    badgePlate: 'rgba(0,0,0, 0.06)',
  },
  emerald: {
    bg: '#d9d9d9',
    text: '#000000', muted: 'rgba(0,0,0, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(0,0,0, 0.06)',
    bottomPlate: 'rgba(0,0,0, 0.06)',
    badgePlate: 'rgba(0,0,0, 0.06)',
  },
  platinum: {
    bg: '#2b2b2b',
    text: '#ffffff', muted: 'rgba(255,255,255, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(255,255,255, 0.1)',
    bottomPlate: 'rgba(255,255,255, 0.1)',
    badgePlate: 'rgba(255,255,255, 0.1)',
  },
  obsidian: {
    bg: 'linear-gradient(135deg, #2a2a2c 0%, #111112 55%, #050505 100%)',
    text: '#ffffff', muted: 'rgba(255,255,255, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(255,255,255, 0.1)',
    bottomPlate: 'rgba(255,255,255, 0.1)',
    badgePlate: 'rgba(255,255,255, 0.1)',
  },
  florence: {
    bg: '#8f8f8f',
    text: '#000000', muted: 'rgba(0,0,0, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(0,0,0, 0.06)',
    bottomPlate: 'rgba(0,0,0, 0.06)',
    badgePlate: 'rgba(0,0,0, 0.06)',
  },
  tuscany_hills: {
    bg: '#161616',
    text: '#ffffff', muted: 'rgba(255,255,255, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(255,255,255, 0.1)',
    bottomPlate: 'rgba(255,255,255, 0.1)',
    badgePlate: 'rgba(255,255,255, 0.1)',
  },
  venice: {
    bg: '#5c5c5c',
    text: '#ffffff', muted: 'rgba(255,255,255, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(255,255,255, 0.1)',
    bottomPlate: 'rgba(255,255,255, 0.1)',
    badgePlate: 'rgba(255,255,255, 0.1)',
  },
  roma_aureus: photoVariant('/cards/roma-forum.webp'),
  roma_purpura: photoVariant('/cards/roma-pantheon.webp'),
  roma_marmor: photoVariant('/cards/roma-marble.webp', true),
  roma_colosseum: photoVariant('/cards/roma-colosseum.webp'),
  roma_spqr: photoVariant('/cards/roma-colosseum-night.webp'),
  roma_pantheon: photoVariant('/cards/roma-pantheon.webp'),
  roma_aqueduct: photoVariant('/cards/roma-aqueduct.webp'),
  roma_forum: photoVariant('/cards/roma-forum.webp'),
  roma_colosseum_night: photoVariant('/cards/roma-colosseum-night.webp'),
  tuscany_villa: {
    bg: '#bdbdbd',
    text: '#000000', muted: 'rgba(0,0,0, 0.55)',
    shimmer: 'transparent',
    overlay: 'transparent',
    numberPlate: 'rgba(0,0,0, 0.06)',
    bottomPlate: 'rgba(0,0,0, 0.06)',
    badgePlate: 'rgba(0,0,0, 0.06)',
  },
};

type CardDesignOption = {
  design: string;
  variant: CardVariant;
  title: string;
  subtitleKey?: TranslationKey;
  subtitle?: string;
};

// Achievement titles come from the server in Ukrainian; the app shows them in the chosen language by id.
const ACH_TITLES: Record<string, [string, string]> = {
  first_tx: ['Перша операція', 'First transaction'],
  tx_10: ['10 операцій', '10 transactions'],
  tx_50: ['50 операцій', '50 transactions'],
  first_donate: ['Перший донат', 'First donation'],
  donate_1k: ['Донат 1 000 TAX', 'Donated 1,000 TAX'],
  donate_10k: ['Меценат', 'Patron'],
  first_goal: ['Перша ціль', 'First goal'],
  goals_3: ['Три цілі', 'Three goals'],
  saver_1k: ['Накопичувач', 'Saver'],
  saver_10k: ['Великий заощаджувач', 'Big saver'],
  family: ['Близькі поруч', 'Close ones nearby'],
  transfer_5: ['Активний', 'Active sender'],
};
const achTitle = (a: { id: string; title: string }) => (ACH_TITLES[a.id] ? tr(...ACH_TITLES[a.id]) : a.title);

// English names of the card designs (the list below keeps the Ukrainian ones); shown through tr().
const DESIGN_TITLE_EN: Record<string, string> = {
  'Колізей': 'Colosseum', 'Колізей уночі': 'Colosseum at night', 'Пантеон': 'Pantheon', 'Форум': 'Forum', 'Акведук': 'Aqueduct',
  'Мармур': 'Marble', 'Папір': 'Paper', 'Попіл': 'Ash', 'Графіт': 'Graphite', 'Чорний': 'Black', 'Сталь': 'Steel', 'Туман': 'Mist',
  'Вугілля': 'Charcoal', 'Срібло': 'Silver',
};

const CARD_DESIGN_OPTIONS: CardDesignOption[] = [
  { design: 'roma_colosseum', variant: 'roma_colosseum', title: 'Колізей', subtitle: 'Фото: Wilfredor · CC0' },
  { design: 'roma_colosseum_night', variant: 'roma_colosseum_night', title: 'Колізей уночі', subtitle: 'Фото: John Samuel · CC BY-SA 4.0' },
  { design: 'roma_pantheon', variant: 'roma_pantheon', title: 'Пантеон', subtitle: 'Фото: Nhartmannphotos · CC BY-SA 4.0' },
  { design: 'roma_forum', variant: 'roma_forum', title: 'Форум', subtitle: 'Храм Сатурна · фото: Nicholas Hartmann · CC BY-SA 4.0' },
  { design: 'roma_aqueduct', variant: 'roma_aqueduct', title: 'Акведук', subtitle: 'Аква Клавдія · фото: Mario2912 · CC BY-SA 4.0' },
  { design: 'roma_marmor', variant: 'roma_marmor', title: 'Мармур', subtitle: 'Каррара · фото: Solarence · CC BY-SA 4.0' },
  { design: 'gold', variant: 'gold', title: 'Папір', subtitleKey: 'design_subtitle_gold' },
  { design: 'forest', variant: 'emerald', title: 'Попіл', subtitleKey: 'design_subtitle_forest' },
  { design: 'slate', variant: 'platinum', title: 'Графіт', subtitleKey: 'design_subtitle_slate' },
  { design: 'dark', variant: 'obsidian', title: 'Чорний', subtitleKey: 'design_subtitle_dark' },
  { design: 'florence', variant: 'florence', title: 'Сталь', subtitleKey: 'design_subtitle_florence' },
  { design: 'venice', variant: 'venice', title: 'Туман', subtitleKey: 'design_subtitle_venice' },
  { design: 'tuscany_hills', variant: 'tuscany_hills', title: 'Вугілля', subtitleKey: 'design_subtitle_tuscany_hills' },
  { design: 'tuscany_villa', variant: 'tuscany_villa', title: 'Срібло', subtitleKey: 'design_subtitle_tuscany_villa' },
];

// ─── Data helpers ─────────────────────────────────────────────
function fmtInt(n: number) {
  return Math.floor(Math.abs(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '\u00a0');
}
function fmtDec(n: number) { return ',' + (Math.abs(n) % 1).toFixed(2).slice(2); }
function fmtDateLabel(iso: string, lang: AppLang = getStoredLanguage()): string {
  const tt = translations[lang];
  const locale = localeForLang(lang);
  if (!iso) return '—';
  const d = new Date(iso.slice(0, 10) + 'T00:00:00');
  if (isNaN(d.getTime())) return iso.slice(0, 10) || '—';
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const yest = new Date(today); yest.setDate(today.getDate() - 1);
  if (d >= today) return tt.today_label;
  if (d >= yest) return tt.yesterday_label;
  return d.toLocaleDateString(locale, { day: 'numeric', month: 'long' });
}
function fmtTime(iso: string, lang: AppLang = getStoredLanguage()): string {
  const locale = localeForLang(lang);
  if (!iso) return '—';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso.slice(11, 16) || '—';
  return d.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit' });
}
function txToCat(tx: TxItem): TxCat {
  if (tx.direction === 'in') return 'income';
  const m: Record<string, TxCat> = { food: 'food', transport: 'transport', utility: 'utility', shopping: 'shopping', subscription: 'subscription', transfer: 'transfer' };
  return (m[tx.tx_type] ?? 'transfer') as TxCat;
}
function apiCardToData(c: CardInfo, holderFallback = 'ARMY BANK'): CardData & { id: number; type: string; limit: string; used: string; statusRaw: string; cardTypeRaw: string; balance: number; isPrimary: boolean } {
  const tt = translations[getStoredLanguage()];
  const normalizedDesign = String(c.design || 'gold').toLowerCase();
  return {
    id: c.id,
    design: normalizedDesign,
    variant: DESIGN_TO_VARIANT[normalizedDesign] ?? 'gold',
    number: String(c.masked_number || '').slice(-4) || '0000',
    name: (holderFallback !== 'ARMY BANK' ? holderFallback : (c.holder_name || holderFallback)).toUpperCase().slice(0, 26),
    expiry: c.expiry_display || '--/--',
    type: c.card_type === 'virtual' ? tt.card_virtual : tt.card_physical,
    status: c.status === 'active' ? tt.card_active_status : c.status === 'blocked' ? tt.card_frozen_status : tt.card_closed,
    statusRaw: c.status,
    cardTypeRaw: c.card_type,
    limit: '—',
    used: '—',
    balance: c.display_balance ?? 0,
    isPrimary: c.is_primary ?? false,
  };
}

// Рубашка картки: стрічка, CVV і номер у скляних чипах, дійсна до та власник. Розкладка потоком, без відсотків
function CardBack({ bg, image, expiry, name, last4, revealed, toast }: {
  bg: string; image?: string; expiry: string; name: string; last4: string;
  revealed: { cvv: string; card_number: string } | null | undefined; toast: (m: string) => void;
}) {
  const mono = '"SF Mono", ui-monospace, Menlo, monospace';
  const copy = (value: string | undefined, msg: string) => (e: React.MouseEvent) => {
    e.stopPropagation();
    if (value) navigator.clipboard.writeText(value).then(() => toast(msg)).catch(() => {});
  };
  const chip: React.CSSProperties = {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, height: 32, padding: '0 11px',
    background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.14)', borderRadius: 10,
    color: '#fff', fontFamily: mono, fontWeight: 700, cursor: revealed ? 'pointer' : 'default',
  };
  const cap: React.CSSProperties = { fontSize: 8.5, color: 'rgba(255,255,255,0.5)', letterSpacing: 1, textTransform: 'uppercase' };
  const copyIcon = <svg width="11" height="11" viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2" stroke="rgba(255,255,255,0.65)" strokeWidth="2" /><path d="M5 15V5a2 2 0 012-2h10" stroke="rgba(255,255,255,0.65)" strokeWidth="2" /></svg>;
  const number = revealed ? revealed.card_number.replace(/\s/g, '').replace(/(.{4})/g, '$1 ').trim() : `•••• •••• •••• ${last4}`;
  return (
    <div style={{
      position: 'absolute', inset: 0, backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden',
      transform: 'rotateY(180deg)', borderRadius: 22, overflow: 'hidden', background: bg,
      boxShadow: '0 20px 40px -12px rgba(0,0,0,0.55)', display: 'flex', flexDirection: 'column',
    }}>
      {image && <div style={{ position: 'absolute', inset: 0, backgroundImage: `url(${image})`, backgroundSize: 'cover', backgroundPosition: 'center', filter: 'brightness(0.3)', transform: 'scale(1.04)' }} />}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.6)' }} />
      <div style={{ position: 'relative', height: '15%', minHeight: 22, marginTop: '7%', background: 'linear-gradient(180deg, #202022, #0c0c0d)', boxShadow: '0 1px 0 rgba(255,255,255,0.06)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', padding: '0 14px' }}><span style={{ ...cap, fontSize: 9 }}>{tr('↩ закрити', '↩ close')}</span></div>
      <div style={{ position: 'relative', flex: 1, minHeight: 0, padding: '9px 16px 11px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
          <span style={cap}>CVV2</span>
          <button onClick={copy(revealed?.cvv, tr('CVV скопійовано ✓', 'CVV copied ✓'))} style={{ ...chip, width: 84, flexShrink: 0, border: '1px solid rgba(255,255,255,0.14)' }}>
            <span style={{ fontSize: 14, letterSpacing: 3 }}>{revealed?.cvv || '•••'}</span>{revealed && copyIcon}
          </button>
        </div>
        <div>
          <div style={{ ...cap, marginBottom: 4 }}>{tr('Номер картки', 'Card number')}</div>
          <button onClick={copy(revealed?.card_number.replace(/\s/g, ''), tr('Номер скопійовано ✓', 'Number copied ✓'))} style={{ ...chip, width: '100%' }}>
            <span style={{ fontSize: 13, letterSpacing: 1.6, whiteSpace: 'nowrap' }}>{number}</span>{revealed && copyIcon}
          </button>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16 }}>
          <div><div style={cap}>{tr('Дійсна до', 'Valid until')}</div><div style={{ fontFamily: mono, fontSize: 12, fontWeight: 700, color: '#fff', marginTop: 2 }}>{expiry}</div></div>
          <div style={{ flex: 1, minWidth: 0 }}><div style={cap}>{tr('Власник', 'Holder')}</div><div style={{ fontSize: 11, fontWeight: 700, color: '#fff', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{name}</div></div>
        </div>
      </div>
    </div>
  );
}

const CARD_GRAIN = `url("data:image/svg+xml;utf8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180"><filter id="n"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 .5  0 0 0 0 .5  0 0 0 0 .5  0 0 0 1.1 -.2"/></filter><rect width="180" height="180" filter="url(#n)"/></svg>')}")`;

function PremiumCard({ variant, number, name, expiry, type, style = {}, balance, isPrimary }: CardData & { style?: React.CSSProperties; balance?: number; isPrimary?: boolean }) {
  const v = CARD_VARIANTS[variant] ?? CARD_VARIANTS.gold;
  const tt = translations[getStoredLanguage()];
  const patId = `g-${variant}`;
  const hasPhoto = Boolean(v.image);
  const lightText = v.text.toLowerCase() === '#ffffff';
  const titleShadow = hasPhoto ? '0 1px 3px rgba(0,0,0, 0.62)' : '0 1px 1px rgba(0,0,0, 0.2)';
  return (
    <div style={{
      position: 'relative', aspectRatio: '1.586 / 1', borderRadius: 22, containerType: 'inline-size',
      background: v.bg,
      boxShadow: '0 20px 40px -12px rgba(0,0,0, 0.55), 0 6px 16px -8px rgba(0,0,0, 0.4), inset 0 0 0 1px rgba(255,255,255, 0.12)',
      color: v.text, overflow: 'hidden',
      fontFamily: '"SF Pro Display", -apple-system, system-ui',
      ...style,
    }}>
      <div style={{ position: 'absolute', inset: 0, background: v.bg }} />
      {v.image && (
        <div style={{
          position: 'absolute',
          inset: 0,
          backgroundImage: `url(${v.image})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          transform: 'scale(1.03)',
          filter: 'saturate(1.02) contrast(1.01)',
        }} />
      )}
      <div style={{ position: 'absolute', inset: 0, background: v.overlay }} />
      <div aria-hidden style={{ position: 'absolute', inset: 0, backgroundImage: CARD_GRAIN, backgroundSize: '180px 180px', opacity: hasPhoto ? 0.16 : 0.22, mixBlendMode: 'overlay', pointerEvents: 'none' }} />
      <div aria-hidden style={{ position: 'absolute', inset: 0, background: 'linear-gradient(118deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0.06) 26%, rgba(255,255,255,0) 44%, rgba(255,255,255,0) 66%, rgba(255,255,255,0.08) 100%)', mixBlendMode: lightText ? 'soft-light' : 'overlay', pointerEvents: 'none' }} />
      <div aria-hidden style={{ position: 'absolute', inset: 0, borderRadius: 'inherit', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.4), inset 1px 0 0 rgba(255,255,255,0.14), inset 0 -1px 0 rgba(0,0,0,0.45), inset -1px 0 0 rgba(0,0,0,0.25)', pointerEvents: 'none', zIndex: 3 }} />
      <svg aria-hidden viewBox="0 0 44 34" style={{ position: 'absolute', left: '8%', top: '30%', width: '13%', filter: 'drop-shadow(0 1px 1.5px rgba(0,0,0,0.45))' }}>
        <defs>
          <linearGradient id={`${patId}-chip`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#f7e7b4" /><stop offset=".35" stopColor="#d3ac55" /><stop offset=".62" stopColor="#f0d58e" /><stop offset="1" stopColor="#a47f33" />
          </linearGradient>
        </defs>
        <rect x=".5" y=".5" width="43" height="33" rx="6" fill={`url(#${patId}-chip)`} stroke="rgba(70,45,5,0.55)" />
        <g fill="none" stroke="rgba(70,45,5,0.55)" strokeWidth=".9">
          <path d="M.5 12h12.5q4 0 4 5t-4 5H.5M43.5 12H31q-4 0-4 5t4 5h12.5M17 .5v8.5M27 .5v8.5M17 33.5V25M27 33.5V25M17 9h10v16H17z" />
        </g>
      </svg>
      <div style={{ position: 'absolute', inset: 0, background: v.shimmer, pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', inset: 0, padding: 'clamp(14px, 6.4cqw, 26px)', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span aria-hidden style={{ width: 'clamp(20px, 7cqw, 30px)', height: 'clamp(20px, 7cqw, 30px)', color: v.text, display: 'inline-grid' }} dangerouslySetInnerHTML={{ __html: markSvg.replace('<svg ', '<svg style="width:100%;height:100%" ') }} />
            <span style={{ fontSize: 'max(14px, 4.4cqw)', fontWeight: 500, letterSpacing: 0.5, textShadow: titleShadow }}>
              Tax<span style={{ fontWeight: 300 }}>Tech</span>
            </span>
          </div>
          <svg aria-hidden viewBox="0 0 24 24" style={{ width: 'clamp(16px, 5.4cqw, 24px)', height: 'clamp(16px, 5.4cqw, 24px)', fill: 'none', stroke: v.text, strokeWidth: 1.7, strokeLinecap: 'round', opacity: 0.8, filter: lightText ? 'drop-shadow(0 1px 2px rgba(0,0,0,0.4))' : undefined }}><path d="M8.5 7.5a6 6 0 0 1 0 9M12 5a9.5 9.5 0 0 1 0 14M15.5 2.5a13 13 0 0 1 0 19" /></svg>
        </div>
        <div style={{
          fontFamily: '"SF Mono", monospace', fontSize: 'clamp(15px, 5.6cqw, 26px)', fontWeight: 600, letterSpacing: 1.5,
          color: v.text, textShadow: lightText ? '0 -1px 0 rgba(0,0,0,0.55), 0 1px 0 rgba(255,255,255,0.28), 0 2px 6px rgba(0,0,0,0.35)' : '0 1px 0 rgba(255,255,255,0.55), 0 -1px 0 rgba(0,0,0,0.22)',
          display: 'flex', gap: 'clamp(8px, 3.6cqw, 18px)', alignItems: 'center', marginBottom: -8,
          padding: 0,
          background: 'transparent',
        }}>
          <span style={{ color: v.muted }}>••••</span>
          <span style={{ color: v.muted }}>••••</span>
          <span style={{ color: v.muted }}>••••</span>
          <span>{number}</span>
        </div>
        <div style={{
          display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
          padding: 0,
          background: 'transparent',
        }}>
          <div>
            <div style={{ fontSize: 'max(12px, 3.6cqw)', fontWeight: 600, letterSpacing: 0.4, textShadow: titleShadow }}>{name}</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: 'max(12px, 3.6cqw)', fontWeight: 600, fontFamily: '"SF Mono", monospace', textShadow: titleShadow }}>{expiry}</div>
            </div>
            <div style={{ position: 'relative', width: 34, height: 22 }}>
              <div style={{ position: 'absolute', left: 0, top: 0, width: 22, height: 22, borderRadius: '50%', background: '#343434' }} />
              <div style={{ position: 'absolute', right: 0, top: 0, width: 22, height: 22, borderRadius: '50%', background: '#a7a7a7', mixBlendMode: 'multiply' }} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Screen top padding helper ───────────────────────────────
function useTopPad() {
  const layout = useLayout();
  return layout === 'desktop' ? '28px' : 'max(20px, calc(env(safe-area-inset-top, 0px) + 12px))';
}

// ─── Desktop content wrapper: max-width + padding ────────────
function ContentWrap({ children, maxW = 720 }: { children: React.ReactNode; maxW?: number }) {
  const layout = useLayout();
  if (layout !== 'desktop') return <>{children}</>;
  return (
    <div style={{ maxWidth: maxW, margin: '0 auto', padding: '0 40px', width: '100%', boxSizing: 'border-box' }}>
      {children}
    </div>
  );
}

// Desktop screen header — replaces the mobile avatar+greeting bar
function DesktopHeader({ title, subtitle, children }: { title: string; subtitle?: string; children?: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
      <div>
        {subtitle && <div style={{ ...T.caption, color: text.muted, marginBottom: 4 }}>{subtitle}</div>}
        <div style={{ ...T.h1, color: text.primary }}>{title}</div>
      </div>
      {children && <div style={{ display: 'flex', gap: 10 }}>{children}</div>}
    </div>
  );
}

function timeGreeting(lang: AppLang): string {
  const h = new Date().getHours();
  if (h >= 6 && h < 12) return translations[lang].greeting_morning;
  if (h >= 12 && h < 18) return translations[lang].greeting_day;
  if (h >= 18 && h < 23) return translations[lang].greeting_evening;
  return translations[lang].greeting_night;
}

// ─── Balance History Chart ────────────────────────────────────
function BalanceHistoryChart() {
  const { t, lang } = usePreferences();
  const [points, setPoints] = useState<BalancePoint[]>([]);
  const [loading, setLoading] = useState(true);
  const uid = useId().replace(/:/g, '');
  const gradId = `balGrad_${uid}`;

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) { setLoading(false); return; }
    const ctrl = new AbortController();
    fetch(apiUrl('/api/analytics/balance-history?days=14'), { headers: { Authorization: `Bearer ${token}` }, signal: ctrl.signal })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok && Array.isArray(j.data)) setPoints(j.data); })
      .catch(() => {})
      .finally(() => setLoading(false));
    return () => ctrl.abort();
  }, []);

  if (loading || points.length < 2) return null;

  const min = Math.min(...points.map(p => p.balance));
  const max = Math.max(...points.map(p => p.balance));
  const range = max - min || 1;
  const W = 320, H = 120, PAD = 10;
  const toY = (v: number) => H - PAD - ((v - min) / range) * (H - PAD * 2);
  const toX = (i: number) => (i / (points.length - 1)) * W;
  const pts = points.map((p, i): [number, number] => [toX(i), toY(p.balance)]);
  const clampY = (y: number) => Math.max(PAD / 2, Math.min(H - PAD / 2, y));
  let pathD = `M ${pts[0][0].toFixed(1)} ${pts[0][1].toFixed(1)}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
    const c1: [number, number] = [p1[0] + (p2[0] - p0[0]) / 6, clampY(p1[1] + (p2[1] - p0[1]) / 6)];
    const c2: [number, number] = [p2[0] - (p3[0] - p1[0]) / 6, clampY(p2[1] - (p3[1] - p1[1]) / 6)];
    pathD += ` C ${c1[0].toFixed(1)} ${c1[1].toFixed(1)} ${c2[0].toFixed(1)} ${c2[1].toFixed(1)} ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`;
  }
  const areaD = `${pathD} L ${W} ${H} L 0 ${H} Z`;
  const last = pts[pts.length - 1];
  const locale = localeForLang(lang);
  const startDay = new Date(points[0].day).toLocaleDateString(locale, { day: 'numeric', month: 'short' });
  const endDay = new Date(points[points.length - 1].day).toLocaleDateString(locale, { day: 'numeric', month: 'short' });
  const lastBalance = points[points.length - 1].balance;
  const firstBalance = points[0].balance;
  const diff = lastBalance - firstBalance;
  const isUp = diff >= 0;

  return (
    <div style={{ padding: '0 22px 20px' }}>
      <div style={{ padding: '18px 18px 14px', ...glassCard() }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 6 }}>
          <div>
            <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 6 }}>{t('balance_history_title')}</div>
            <div style={{ fontSize: 26, fontWeight: 600, letterSpacing: -0.7, color: text.primary, ...T.num }}>
              {fmtInt(lastBalance)}<span style={{ fontSize: 16, fontWeight: 500, color: text.dim }}>{fmtDec(lastBalance)}</span>
            </div>
          </div>
          <div style={{ textAlign: 'right', fontSize: 13, fontWeight: 600, color: isUp ? '#5fd68a' : '#ff8d80', ...T.num }}>
            {isUp ? '↑ +' : '↓ '}{fmtInt(diff)}{fmtDec(diff)}
            <div style={{ fontSize: 11, fontWeight: 500, color: text.dim, marginTop: 3 }}>{tr('за 14 днів', 'over 14 days')}</div>
          </div>
        </div>
        <div style={{ position: 'relative' }}>
          <svg width="100%" viewBox={`0 0 ${W} ${H}`} style={{ display: 'block', overflow: 'visible' }}>
            <defs>
              <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#FFD400" stopOpacity="0.34" />
                <stop offset="70%" stopColor="#FFD400" stopOpacity="0.04" />
                <stop offset="100%" stopColor="#FFD400" stopOpacity="0" />
              </linearGradient>
            </defs>
            {[0.25, 0.5, 0.75].map(f => <line key={f} x1="0" x2={W} y1={H * f} y2={H * f} stroke="rgba(255,255,255,0.06)" strokeWidth="1" strokeDasharray="2 5" />)}
            <path d={areaD} fill={`url(#${gradId})`} />
            <path d={pathD} fill="none" stroke="#FFD400" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" style={{ filter: 'drop-shadow(0 4px 10px rgba(255,212,0,0.45))' }} />
            <circle cx={last[0]} cy={last[1]} r="9" fill="#FFD400" opacity="0.18" />
            <circle cx={last[0]} cy={last[1]} r="4" fill="#FFD400" stroke="#19191b" strokeWidth="2" />
          </svg>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <span style={{ fontSize: 11, color: text.dim }}>{startDay}</span>
          <span style={{ fontSize: 11, color: text.dim }}>{endDay}</span>
        </div>
      </div>
    </div>
  );
}

// ─── Spending Insights Strip ──────────────────────────────────
function InsightsStrip() {
  const { t } = usePreferences();
  const [insights, setInsights] = useState<SpendingInsight[]>([]);

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) return;
    const ctrl = new AbortController();
    fetch('/api/analytics/insights', { headers: { Authorization: `Bearer ${token}` }, signal: ctrl.signal })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok && j.data?.insights) setInsights(j.data.insights); })
      .catch(() => {});
    return () => ctrl.abort();
  }, []);

  if (!insights.length) return null;

  return (
    <div style={{ padding: '0 22px 20px' }}>
      <div style={{ fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}>{t('insights_title')}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {insights.map((ins, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 14px', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: 14 }}>
            <span aria-hidden style={{ width: 6, height: 6, borderRadius: '50%', background: i === 0 ? gold : 'rgba(255,255,255,0.35)', flexShrink: 0, marginTop: 7 }} />
            <span style={{ fontSize: 12, color: text.secondary, lineHeight: 1.5 }}>{ins.text}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Top Recipients Mini ──────────────────────────────────────
function TopRecipientsMini({ onTransfer }: { onTransfer: (account: string) => void }) {
  const { t } = usePreferences();
  const dk = useLayout() === 'desktop';
  const [recipients, setRecipients] = useState<TopRecipient[]>([]);

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) return;
    const ctrl = new AbortController();
    fetch('/api/analytics/top-recipients', { headers: { Authorization: `Bearer ${token}` }, signal: ctrl.signal })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok && Array.isArray(j.data)) setRecipients(j.data); })
      .catch(() => {});
    return () => ctrl.abort();
  }, []);

  if (!recipients.length) return null;

  return (
    <div style={{ padding: dk ? 0 : '0 22px 20px' }}>
      <div style={dk ? { ...dkTitle, marginBottom: 16 } : { fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 10 }}>{t('top_recipients_title')}</div>
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', scrollbarWidth: 'none', paddingBottom: 2 }}>
        {recipients.map((r, i) => (
          <button key={i} onClick={() => onTransfer(r.related_account)} style={{
            flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5,
            padding: '10px 12px', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent',
            borderRadius: 16, cursor: 'pointer', minWidth: 80,
          }}>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(255,255,255, 0.08)', border: '1px solid transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 700, color: text.primary, fontFamily: 'monospace' }}>
              {r.related_account.slice(-2)}
            </div>
            <span style={{ fontSize: 10, color: text.muted, fontFamily: 'monospace', letterSpacing: 0.5 }}>••{r.related_account.slice(-4)}</span>
            <span style={{ fontSize: 10, color: text.dim }}>{r.tx_count} {t('sent_label')}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ─── Overview screen ──────────────────────────────────────────
function QuickAction({ icon, label, onClick }: { icon: React.ReactNode; label: string; onClick?: () => void }) {
  const layout = useLayout();
  const isMobile = layout === 'mobile';
  const size = isMobile ? 58 : 62;
  return (
    <button onClick={onClick} className="kp-tx-row" style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-start',
      gap: 10, padding: isMobile ? '6px 2px 4px' : '10px 6px 8px', background: 'transparent', border: 'none',
      color: text.secondary, fontFamily: 'inherit', cursor: 'pointer', textAlign: 'center', minWidth: 0,
    }}>
      <div style={{
        width: size, height: size, borderRadius: 20, display: 'grid', placeItems: 'center',
        background: 'linear-gradient(160deg, #2b2b2e 0%, #1d1d20 100%)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.07), 0 10px 20px -12px rgba(0,0,0,0.8)',
      }}>
        <div style={{ transform: 'scale(1.3)', display: 'grid', placeItems: 'center' }}>{recolorIcon(icon, '#FFD400')}</div>
      </div>
      <span style={{
        fontSize: isMobile ? 12 : 10.5, fontWeight: 600, lineHeight: 1.2, letterSpacing: isMobile ? 0 : 0.4,
        textTransform: isMobile ? 'none' : 'uppercase', color: text.secondary,
      }}>{label}</span>
    </button>
  );
}

function ActivityRow({ iconEl, title, subtitle, amount, positive, onClick }: {
  iconBg?: string; iconEl: React.ReactNode; title: string; subtitle: string; amount: string; positive?: boolean; onClick?: () => void;
}) {
  const tint = positive ? '#4fd18b' : '#FFD400';
  return (
    <div onClick={onClick} className="kp-tx-row" style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '13px 16px', cursor: onClick ? 'pointer' : 'default' }}>
      <Medallion tint={tint} size={46}>{recolorIcon(iconEl, tint)}</Medallion>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...T.body, fontWeight: 500, color: text.primary, lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', overflowWrap: 'anywhere' }}>{title}</div>
        <div style={{ ...T.sm, color: text.muted, marginTop: 3 }}>{subtitle}</div>
      </div>
      <div style={{ flexShrink: 0, textAlign: 'right', fontSize: 16, fontWeight: 600, letterSpacing: -0.2, color: positive ? '#5fd68a' : text.primary, ...T.num, whiteSpace: 'nowrap' }}>
        {positive ? '+' : '\u2212'}{amount.replace(/[\s\u00a0]*TAX$/, '')}
        <div style={{ fontSize: 10.5, fontWeight: 500, color: text.dim, letterSpacing: 0.6, marginTop: 2 }}>TAX</div>
      </div>
    </div>
  );
}

function txActivityVisual(tx: ApiTransaction) {
  if (tx.direction === 'in') {
    return {
      iconBg: 'rgba(169,169,169, 0.1)',
      iconEl: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 2v20M6 16l6 6 6-6" stroke="#a9a9a9" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>,
      positive: true,
    };
  }
  if (tx.tx_type === 'transfer') {
    return {
      iconBg: 'rgba(215,215,215, 0.08)',
      iconEl: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M4 12h16M4 12l5-5M4 12l5 5" stroke="#d8d8d8" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>,
      positive: false,
    };
  }
  if (tx.tx_type === 'topup') {
    return {
      iconBg: 'rgba(169,169,169, 0.1)',
      iconEl: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 2v20M6 16l6 6 6-6" stroke="#a9a9a9" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>,
      positive: true,
    };
  }
  return {
    iconBg: 'rgba(172,172,172, 0.1)',
    iconEl: <svg width="16" height="16" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="none" stroke={gold} strokeWidth="1.8" /><path d="M8 12h8M12 8v8" stroke={gold} strokeWidth="1.8" strokeLinecap="round" /></svg>,
    positive: false,
  };
}

function BalanceBlock({ visible, onToggle, balance, accountNumber }: { visible: boolean; onToggle: () => void; balance: number; accountNumber: string }) {
  const { t } = usePreferences();
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
        <span style={{ ...T.caption, color: text.muted }}>{t('balance_total')}</span>
        <button onClick={onToggle} style={{ width: 24, height: 24, borderRadius: '50%', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', cursor: 'pointer', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {visible
            ? <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z" stroke={text.muted} strokeWidth="1.6" /><circle cx="12" cy="12" r="3" stroke={text.muted} strokeWidth="1.6" /></svg>
            : <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M3 3l18 18M10.6 10.6a2 2 0 002.8 2.8M9.4 5.1A10.9 10.9 0 0112 5c6 0 10 7 10 7a18 18 0 01-3.2 3.9M6.6 6.6A18 18 0 002 12s4 7 10 7a11 11 0 003.4-.5" stroke={text.muted} strokeWidth="1.6" strokeLinecap="round" /></svg>
          }
        </button>
      </div>
      <div style={{ position: 'relative' }}>
        <div style={{ ...T.num, fontSize: 46, fontWeight: 300, letterSpacing: -1.8, color: text.primary, lineHeight: 1, display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span style={{ fontSize: 26, fontWeight: 600, color: gold, letterSpacing: -0.5 }}>TAX</span>
          <span style={{ fontWeight: 500, background: 'linear-gradient(180deg, #ffffff 30%, #a9a9b2 100%)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent', filter: 'drop-shadow(0 6px 22px rgba(255,212,0,0.18))' }}>{visible ? fmtInt(balance) : '• • • • • • •'}</span>
          <span style={{ fontSize: 24, fontWeight: 300, color: 'rgba(235,235,235, 0.38)', letterSpacing: -0.5 }}>{visible ? fmtDec(balance) : ''}</span>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 12, flexWrap: 'wrap' }}>
        {accountNumber && accountNumber !== '—' && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12.5, color: 'rgba(215,215,215, 0.6)', fontWeight: 500, letterSpacing: 0.3, ...T.num }}>
            {accountNumber}
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none"><rect x="9" y="9" width="11" height="11" rx="2" stroke="currentColor" strokeWidth="2" /><path d="M5 15V5a2 2 0 012-2h10" stroke="currentColor" strokeWidth="2" /></svg>
          </div>
        )}
      </div>
    </div>
  );
}

function ActivityFeed({ title = true, transactions }: { title?: boolean; transactions: TxItem[] }) {
  const { goTo } = useApp();
  const { t, lang } = usePreferences();
  const rows = transactions.slice(0, 5).map(tx => {
    const cat = txToCat(tx);
    const s = CAT_STYLES[cat];
    return { iconBg: s.bg, iconEl: s.icon, title: tx.description, subtitle: fmtTime(tx.created_at, lang), amount: `${fmtInt(tx.amount)}${fmtDec(tx.amount)}\u00a0TAX`, positive: tx.direction === 'in' };
  });
  return (
    <div>
      {title && (
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 12 }}>
          <span style={{ ...T.h3, color: text.secondary }}>{t('recent_activity')}</span>
          <div style={{ flex: 1 }} />
          <button onClick={() => goTo('operations')} style={{ ...T.sm, color: gold, background: 'none', border: 'none', display: 'flex', alignItems: 'center', gap: 3, fontFamily: 'inherit', fontWeight: 600, cursor: 'pointer', letterSpacing: -0.1 }}>
            {t('history')} <Chevron size={12} color={gold} />
          </button>
        </div>
      )}
      <div style={{ background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 20, overflow: 'hidden', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)', boxShadow: '0 2px 12px rgba(0,0,0, 0.08)' }}>
        {rows.length === 0 ? (
          <div style={{ padding: '28px 16px', textAlign: 'center' }}>
            <div style={{ fontSize: 13, color: text.muted, marginBottom: 4 }}>{t('no_transactions_yet')}</div>
            <div style={{ fontSize: 11, color: text.dim }}>{t('topup_or_transfer')}</div>
          </div>
        ) : rows.map((r, i) => (
          <Fragment key={i}>
            <ActivityRow {...r} onClick={() => goTo('operations')} />
            {i < rows.length - 1 && <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 16px' }} />}
          </Fragment>
        ))}
      </div>
    </div>
  );
}

// ─── Transfer modal ───────────────────────────────────────────
// ── EMV 3-D Secure Challenge Modal ───────────────────────────────────────────
interface TdsChallenge {
  challenge_id: string;
  demo_otp: string;
  masked_phone: string;
  expires_in: number;
}
function ThreeDSModal({
  challenge,
  amount,
  recipient,
  onVerified,
  onCancel,
}: {
  challenge: TdsChallenge;
  amount: number;
  recipient: string;
  onVerified: (sessionToken: string) => void;
  onCancel: () => void;
}) {
  const { t } = usePreferences();
  const [otp, setOtp] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [timeLeft, setTimeLeft] = useState(challenge.expires_in);
  const inputRef = React.useRef<HTMLInputElement>(null);

  React.useEffect(() => {
    inputRef.current?.focus();
  }, []);

  React.useEffect(() => {
    if (timeLeft <= 0) return;
    const id = setTimeout(() => setTimeLeft(t => t - 1), 1000);
    return () => clearTimeout(id);
  }, [timeLeft]);

  async function verify() {
    if (otp.length !== 6) { setError(tr('Введіть 6-значний код', 'Enter the 6-digit code')); return; }
    setLoading(true); setError('');
    const token = localStorage.getItem('army_bank_token');
    try {
      const r = await fetch('/api/3ds/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ challenge_id: challenge.challenge_id, otp_code: otp }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка верифікації', 'Verification error'));
      onVerified(j.data.session_token);
    } catch (e) {
      setError(e instanceof Error ? e.message : tr('Помилка', 'Error'));
    } finally {
      setLoading(false);
    }
  }

  const expired = timeLeft <= 0;
  const mm = String(Math.floor(timeLeft / 60)).padStart(2, '0');
  const ss = String(timeLeft % 60).padStart(2, '0');

  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 2000,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'rgba(0,0,0, 0.72)', backdropFilter: 'blur(12px)',
    }}>
      <div style={{
        width: '92%', maxWidth: 400,
        background: '#232323',
        border: '1px solid transparent',
        borderRadius: 24, overflow: 'hidden',
        boxShadow: '0 32px 80px rgba(0,0,0, 0.7)',
      }}>
        {/* Header — Visa Secure style */}
        <div style={{
          background: '#383838',
          padding: '14px 20px',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          {/* Visa Secure logo mark */}
          <div style={{
            width: 36, height: 36, borderRadius: 8,
            background: '#4f4f4f',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <svg width="20" height="14" viewBox="0 0 28 18" fill="none">
              <path d="M11.5 0.5L9 17.5H13.5L16 0.5H11.5Z" fill="white"/>
              <path d="M24 0.5C23 0.5 21.5 1 20.5 3L13.5 17.5H18L18.9 15H24.5L25 17.5H29L24 0.5ZM20 11.5L22 6L23.2 11.5H20Z" fill="white"/>
              <path d="M7.5 0.5L3 12.5L2.5 10C1.5 7 -0.5 3.5 -2.5 1.5L1.5 17.5H6L12 0.5H7.5Z" fill="white"/>
              <path d="M-0.5 0.5H-7L-7.2 1C-2 2.5 2 6 3 10L1.5 2C1 0.5 0 0.5 -0.5 0.5Z" fill="#a7a7a7"/>
            </svg>
          </div>
          <div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255, 0.6)', letterSpacing: 1 }}>VISA SECURE</div>
            <div style={{ fontSize: 13, color: '#ffffff', fontWeight: 600 }}>{tr('Підтвердження платежу', 'Payment confirmation')}</div>
          </div>
          <div style={{ flex: 1 }} />
          <div style={{
            width: 32, height: 32, borderRadius: '50%',
            background: 'rgba(255,255,255, 0.1)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="11" width="18" height="11" rx="2" stroke="rgba(255,255,255, 0.8)" strokeWidth="2"/>
              <path d="M7 11V7a5 5 0 0110 0v4" stroke="rgba(255,255,255, 0.8)" strokeWidth="2" strokeLinecap="round"/>
            </svg>
          </div>
        </div>

        {/* Content */}
        <div style={{ padding: '24px 20px 28px' }}>
          {/* Payment summary */}
          <div style={{
            background: 'rgba(255,255,255, 0.1)', borderRadius: 14,
            border: '1px solid transparent',
            padding: '14px 16px', marginBottom: 20,
          }}>
            <div style={{ fontSize: 11, color: 'rgba(215,215,215, 0.5)', letterSpacing: 1, marginBottom: 4 }}>{tr('СУМА ПЕРЕКАЗУ', 'TRANSFER AMOUNT')}</div>
            <div style={{ fontSize: 26, fontWeight: 700, color: '#ebebeb', letterSpacing: -0.5 }}>
              {amount.toLocaleString('uk-UA', { minimumFractionDigits: 2 })}{'\u00a0TAX'}
            </div>
            {recipient && (
              <div style={{ fontSize: 12, color: 'rgba(215,215,215, 0.5)', marginTop: 4 }}>
                → {recipient}
              </div>
            )}
          </div>

          <div style={{ fontSize: 13, color: 'rgba(215,215,215, 0.7)', marginBottom: 6, lineHeight: 1.4 }}>
            {tr('Для підтвердження введіть одноразовий код, надісланий на номер', 'To confirm, enter the one-time code sent to')}{' '}
            <span style={{ color: '#ebebeb', fontWeight: 600 }}>{challenge.masked_phone}</span>
          </div>

          {/* Demo OTP hint */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent',
            borderRadius: 10, padding: '8px 12px', marginBottom: 16,
          }}>
            <span style={{ fontSize: 14 }}>🧪</span>
            <div>
              <div style={{ fontSize: 10, color: 'rgba(171,171,171, 0.7)', letterSpacing: 0.8 }}>{tr('ДЕМО-РЕЖИМ', 'DEMO MODE')}</div>
              <div style={{ fontSize: 13, color: '#ababab', fontWeight: 600, fontFamily: '"SF Mono", monospace', letterSpacing: 3 }}>
                {challenge.demo_otp}
              </div>
            </div>
          </div>

          {/* OTP input */}
          <div style={{ marginBottom: 12 }}>
            <input
              ref={inputRef}
              type="text"
              inputMode="numeric"
              pattern="[0-9]*"
              maxLength={6}
              value={otp}
              onChange={e => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
              onKeyDown={e => e.key === 'Enter' && !expired && verify()}
              disabled={loading || expired}
              style={{
                width: '100%', padding: '16px', textAlign: 'center',
                fontSize: 28, fontWeight: 700, letterSpacing: 10,
                fontFamily: '"SF Mono", monospace',
                background: 'rgba(255,255,255, 0.1)',
                border: `1px solid ${error ? 'rgba(110,110,110, 0.5)' : 'rgba(172,172,172, 0.2)'}`,
                borderRadius: 14, color: '#ebebeb', outline: 'none',
                boxSizing: 'border-box',
              }}
              placeholder="••••••"
            />
          </div>

          {/* Timer */}
          <div style={{ textAlign: 'center', marginBottom: 16, fontSize: 12, color: expired ? '#989898' : 'rgba(215,215,215, 0.45)' }}>
            {expired ? tr('⚠ Код прострочено', '⚠ Code expired') : `${tr('Код дійсний', 'Code valid for')}: ${mm}:${ss}`}
          </div>

          {error && (
            <div style={{ padding: '10px 14px', background: 'rgba(255,255,255, 0.1)', borderRadius: 10, color: '#989898', fontSize: 13, marginBottom: 12 }}>
              {error}
            </div>
          )}

          <div style={{ display: 'flex', gap: 10 }}>
            <button
              onClick={onCancel}
              style={{
                flex: 1, padding: '13px', borderRadius: 12,
                background: 'rgba(255,255,255, 0.1)',
                border: '1px solid transparent',
                color: 'rgba(215,215,215, 0.7)', fontSize: 14, cursor: 'pointer', fontFamily: 'inherit',
              }}
            >
              {tr('Скасувати', 'Cancel')}
            </button>
            <button
              onClick={verify}
              disabled={loading || expired || otp.length !== 6}
              style={{
                flex: 2, padding: '13px', borderRadius: 12,
                background: loading || expired || otp.length !== 6
                  ? 'rgba(51,51,51, 0.4)'
                  : '#4f4f4f',
                border: 'none',
                color: loading || expired || otp.length !== 6 ? 'rgba(215,215,215, 0.4)' : '#ffffff',
                fontSize: 14, fontWeight: 600, cursor: loading || expired ? 'default' : 'pointer',
                fontFamily: 'inherit',
              }}
            >
              {loading ? '…' : tr('Підтвердити', 'Confirm')}
            </button>
          </div>

          {/* Powered by */}
          <div style={{ textAlign: 'center', marginTop: 16, fontSize: 10, color: 'rgba(172,172,172, 0.3)', letterSpacing: 0.5 }}>
            {tr('3-D Secure · навчальний банк TaxTech', '3-D Secure · TaxTech learning bank')}
          </div>
        </div>
      </div>
    </div>
  );
}

function TransferModal({ mode, onClose }: { mode: TransferMode; onClose: () => void }) {
  const { toast, refreshDashboard } = useApp();
  const { t } = usePreferences();
  const sheetSwipe = useSheetSwipeClose(onClose);
  const [amount, setAmount] = useState('');
  const [recipient, setRecipient] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [tdsChallenge, setTdsChallenge] = useState<TdsChallenge | null>(null);

  const cfg = {
    topup:      { title: t('transfer_topup_title'), recipientLabel: '', placeholder: t('transfer_optional_desc') },
    by_card:    { title: t('transfer_by_card_title'),  recipientLabel: t('transfer_card_number'),   placeholder: t('transfer_comment') },
    by_account: { title: t('transfer_by_account_title'), recipientLabel: t('transfer_account_number'),  placeholder: t('transfer_comment') },
  }[mode];

  function parseAmount(value: string): number {
    const normalized = String(value || '')
      .replace(/\s+/g, '')
      .replace(',', '.')
      .replace(/[^\d.]/g, '');
    return parseFloat(normalized);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    const amtNum = parseAmount(amount);
    if (!amtNum || amtNum <= 0) { setError(t('enter_amount')); return; }
    if (mode !== 'topup' && !recipient.trim()) { setError(t('enter_recipient')); return; }

    // For non-topup: require 3DS challenge first
    if (mode !== 'topup') {
      setLoading(true);
      const token = localStorage.getItem('army_bank_token');
      if (!token) { setLoading(false); setError(t('session_expired')); return; }
      try {
        await ensureApiStatusHealthy();
        const r = await fetch(apiUrl('/api/3ds/challenge'), {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ amount: amtNum, recipient: recipient.trim() }),
        });
        const j = await r.json();
        if (!j.ok) throw new Error(j.error || tr('Помилка 3DS', '3DS error'));
        setTdsChallenge(j.data);
      } catch (err: unknown) {
        setError(err instanceof Error ? err.message : t('operation_error'));
      } finally {
        setLoading(false);
      }
      return; // Wait for 3DS modal
    }

    // Topup — no 3DS needed
    await _executeTransfer(null, amtNum);
  }

  async function _executeTransfer(tdsSession: string | null, amtOverride?: number) {
    const amtNum = amtOverride ?? parseAmount(amount);
    setLoading(true);
    const token = localStorage.getItem('army_bank_token');
    if (!token) { setLoading(false); setError(t('session_expired')); return; }
    const idempotencyKey = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    try {
      await ensureApiStatusHealthy();
      const url = mode === 'topup' ? '/api/transactions/topup'
        : mode === 'by_card' ? '/api/transactions/transfer-by-card'
        : '/api/transactions/transfer';
      const normalizedCard = recipient.replace(/\D/g, '').slice(0, 16);
      const body: Record<string, unknown> = mode === 'topup'
        ? { amount: amtNum, description: description || t('transfer_topup_title'), idempotency_key: idempotencyKey }
        : mode === 'by_card'
        ? { card_number: normalizedCard, amount: amtNum, description: description || t('transfer_by_card_title'), idempotency_key: idempotencyKey }
        : { recipient_account_number: recipient.trim(), amount: amtNum, description: description || t('transfer_by_account_title'), idempotency_key: idempotencyKey };
      if (tdsSession) body['tds_session'] = tdsSession;
      const r = await fetch(apiUrl(url), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify(body),
      });
      const raw = await r.text();
      let j: Record<string, unknown> = {};
      try { j = raw ? JSON.parse(raw) : {}; } catch { j = {}; }
      if (!r.ok || j.ok === false) {
        const backendMsg = String((j && (j.error || j.message)) || '').trim();
        throw new Error(backendMsg || `${t('operation_error')} (${r.status})`);
      }
      toast(mode === 'topup' ? `${t('topup_success')} ${amtNum.toFixed(2)}\u00a0TAX` : `${t('transfer_success')} ${amtNum.toFixed(2)}\u00a0TAX`);
      refreshDashboard();
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t('operation_error'));
      setTdsChallenge(null);
    } finally {
      setLoading(false);
    }
  }

  const inp: React.CSSProperties = {
    width: '100%', padding: '12px 14px', boxSizing: 'border-box',
    background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`,
    borderRadius: 12, color: '#ebebeb', fontSize: 15, outline: 'none', fontFamily: 'inherit',
  };

  const amtNum = parseAmount(amount);

  return (
    <>
    {tdsChallenge && (
      <ThreeDSModal
        challenge={tdsChallenge}
        amount={amtNum}
        recipient={recipient}
        onVerified={async (sessionToken) => {
          setTdsChallenge(null);
          await _executeTransfer(sessionToken, amtNum);
        }}
        onCancel={() => setTdsChallenge(null)}
      />
    )}
    <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 1000, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', background: 'rgba(0,0,0, 0.55)', backdropFilter: 'blur(6px)' }} onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="tt-sheet"
        {...sheetSwipe.sheetProps}
        style={{ width: '100%', maxWidth: 480, background: '#232323', border: '1px solid transparent', borderRadius: '24px 24px 0 0', padding: '28px 24px calc(40px + env(safe-area-inset-bottom, 0px))', boxShadow: '0 -20px 60px rgba(0,0,0, 0.5)', ...sheetSwipe.sheetStyle }}
      >
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '-8px auto 16px' }} />
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8 }}>
          <div style={{ ...T.h2, color: text.primary, flex: 1, textAlign: 'center', paddingLeft: 28 }}>{cfg.title}</div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'rgba(215,215,215, 0.5)', padding: 4 }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M5 5l14 14M19 5L5 19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
          </button>
        </div>
        <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <label className="tt-amount">
            <span className="sr-only">{t('amount_label')}</span>
            <input
              type="text"
              inputMode="decimal"
              autoFocus
              value={amount}
              onChange={e => setAmount(e.target.value.replace(/[^\d.,\s]/g, ''))}
              placeholder="0"
              size={Math.max(1, (amount || '0').length)}
            />
            <em>TAX</em>
          </label>
          <div className="tt-quick">
            {[100, 500, 1000, 5000].map(v => (
              <button key={v} type="button" className={parseAmount(amount) === v ? 'on' : ''} onClick={() => setAmount(String(v))}>{v.toLocaleString('uk-UA')}</button>
            ))}
          </div>
          {mode !== 'topup' && (
            <div className="tt-field">
              <label htmlFor="tt-recipient">{cfg.recipientLabel}</label>
              <input id="tt-recipient" value={recipient} onChange={e => setRecipient(e.target.value)} placeholder={mode === 'by_card' ? t('transfer_placeholder_card') : t('transfer_placeholder_account')} inputMode={mode === 'by_card' ? 'numeric' : 'text'} autoComplete="off" />
            </div>
          )}
          <div className="tt-field">
            <label htmlFor="tt-desc">{mode === 'topup' ? t('transfer_optional_desc') : t('transfer_comment')}</label>
            <input id="tt-desc" value={description} onChange={e => setDescription(e.target.value)} placeholder={cfg.placeholder} />
          </div>
          {error && <div role="alert" className="tt-error">{error}</div>}
          <button type="submit" className="tt-primary" disabled={loading || !(amtNum > 0)}>
            {loading ? '…' : amtNum > 0 ? `${cfg.title} · ${amtNum.toLocaleString('uk-UA', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} TAX` : cfg.title}
          </button>
          {mode !== 'topup' && <p className="tt-hint">{tr('Переказ підтверджується одноразовим кодом 3-D Secure.', 'The transfer is confirmed with a one-time 3-D Secure code.')}</p>}
        </form>
      </div>
    </div>
    </>
  );
}

// ── Currency rates widget (NBU open API) ─────────────────────────────────────
interface NbuRate { code: string; rate: number; }
// ─── FX Exchange Modal ────────────────────────────────────────────────────────
interface FxRate { code: string; rate: number; }
const CURRENCY_FLAGS: Record<string, string> = { USD: '🇺🇸', EUR: '🇪🇺', GBP: '🇬🇧', PLN: '🇵🇱' };
function FxExchangeModal({ rates, onClose }: { rates: FxRate[]; onClose: () => void }) {
  const { toast } = useApp();
  const [dir, setDir] = useState<'buy' | 'sell'>('buy');
  const [currency, setCurrency] = useState(rates[0]?.code ?? 'USD');
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const SPREAD = 0.015;
  const rate = rates.find(r => r.code === currency)?.rate ?? 0;
  const buyRate = rate * (1 + SPREAD);
  const sellRate = rate * (1 - SPREAD);
  const amtNum = parseFloat(amount.replace(',', '.')) || 0;
  const fxAmt = dir === 'buy' ? amtNum / buyRate : amtNum * sellRate;
  const commission = dir === 'buy' ? amtNum * SPREAD : amtNum * rate * SPREAD;

  async function handleExchange() {
    if (!amtNum || amtNum <= 0) { toast(tr('Введіть суму', 'Enter an amount')); return; }
    setLoading(true);
    await new Promise(r => setTimeout(r, 900));
    toast(`✅ ${dir === 'buy' ? `${tr('Куплено', 'Bought')} ${fxAmt.toFixed(4)} ${currency} · ${amtNum.toFixed(2)}\u00a0TAX` : `${tr('Продано', 'Sold')} ${amtNum.toFixed(4)} ${currency} → ${fxAmt.toFixed(2)}\u00a0TAX`}`);
    setLoading(false); onClose();
  }

  return (
    <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 2000, display: 'flex', alignItems: 'flex-end' }}>
      <div onClick={onClose} style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0, 0.6)', backdropFilter: 'blur(6px)' }} />
      <div className="tt-sheet" style={{ position: 'relative', width: '100%', maxWidth: 500, margin: '0 auto', background: '#1f1f1f', borderRadius: '28px 28px 0 0', padding: '24px 24px max(env(safe-area-inset-bottom,20px),24px)', boxShadow: '0 -20px 60px rgba(0,0,0, 0.5)' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: 'rgba(255,255,255, 0.1)', margin: '0 auto 20px' }} />
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 20 }}>
          <div style={{ fontSize: 20, fontWeight: 700, color: text.primary }}>{tr('Обмін валюти', 'Currency exchange')}</div>
          <div style={{ flex: 1 }} />
          <button onClick={onClose} style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(255,255,255, 0.1)', border: 'none', cursor: 'pointer', color: text.muted, fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✕</button>
        </div>
        <div style={{ display: 'flex', background: 'rgba(36,36,36, 0.6)', borderRadius: 14, padding: 4, marginBottom: 20 }}>
          {([['buy', tr('Купити', 'Buy')] as const, ['sell', tr('Продати', 'Sell')] as const]).map(([d, label]) => (
            <button key={d} onClick={() => setDir(d)} style={{ flex: 1, padding: '10px', borderRadius: 10, border: 'none', cursor: 'pointer', fontFamily: 'inherit', background: dir === d ? `${goldDark}` : 'transparent', color: dir === d ? '#242424' : text.muted, fontWeight: dir === d ? 700 : 500, fontSize: 13 }}>{label}</button>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
          {rates.map(r => (
            <button key={r.code} onClick={() => setCurrency(r.code)} style={{ flex: 1, padding: '10px 6px', borderRadius: 12, border: `1.5px solid ${currency === r.code ? gold : 'rgba(172,172,172, 0.15)'}`, background: currency === r.code ? 'rgba(171,171,171, 0.1)' : 'rgba(255,255,255, 0.1)', cursor: 'pointer', fontFamily: 'inherit', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
              <span style={{ fontSize: 18 }}>{CURRENCY_FLAGS[r.code] ?? '🌐'}</span>
              <span style={{ fontSize: 11, fontWeight: 700, color: currency === r.code ? gold : text.secondary }}>{r.code}</span>
              <span style={{ fontSize: 10, color: text.muted }}>{(dir === 'buy' ? r.rate * (1 + SPREAD) : r.rate * (1 - SPREAD)).toFixed(2)}</span>
            </button>
          ))}
        </div>
        <div style={{ marginBottom: 16 }}>
          <label style={{ fontSize: 12, color: text.muted, display: 'block', marginBottom: 6 }}>{dir === 'buy' ? tr('Сума в токенах TAX', 'Amount in TAX tokens') : `${tr('Сума в', 'Amount in')} ${currency}`}</label>
          <input type="text" inputMode="decimal" value={amount} onChange={e => setAmount(e.target.value)} placeholder="0.00" style={{ width: '100%', padding: '14px 16px', borderRadius: 14, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, color: text.primary, fontSize: 22, fontWeight: 600, outline: 'none', textAlign: 'right' }} />
        </div>
        {amtNum > 0 && (
          <div style={{ background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: 14, padding: '14px 16px', marginBottom: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: text.muted }}>{tr('Ви отримаєте', 'You get')}</span>
              <span style={{ fontSize: 16, fontWeight: 700, color: '#a9a9a9' }}>{dir === 'buy' ? `${fxAmt.toFixed(4)} ${currency}` : `${fxAmt.toFixed(2)}\u00a0TAX`}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: text.muted }}>{tr('Курс', 'Rate')}</span>
              <span style={{ fontSize: 13, color: text.secondary }}>{dir === 'buy' ? `1 ${currency} = ${buyRate.toFixed(4)}\u00a0TAX` : `1 ${currency} = ${sellRate.toFixed(4)}\u00a0TAX`}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontSize: 12, color: text.muted }}>{tr('Комісія банку (1.5%)', 'Bank fee (1.5%)')}</span>
              <span style={{ fontSize: 12, color: text.muted }}>{commission.toFixed(2)}{'\u00a0TAX'}</span>
            </div>
          </div>
        )}
        <button onClick={handleExchange} disabled={loading || !amtNum} style={{ width: '100%', padding: '16px', borderRadius: 16, border: 'none', cursor: loading || !amtNum ? 'default' : 'pointer', background: loading || !amtNum ? 'rgba(51,51,51, 0.4)' : `${goldDark}`, color: loading || !amtNum ? text.dim : '#242424', fontSize: 16, fontWeight: 700, fontFamily: 'inherit' }}>
          {loading ? tr('⏳ Виконується…', '⏳ In progress…') : `${dir === 'buy' ? tr('Купити', 'Buy') : tr('Продати', 'Sell')} ${currency}`}
        </button>
      </div>
    </div>
  );
}

// ─── Monthly Financial Summary ────────────────────────────────────────────────
function MonthlyFinanceSummary({ transactions }: { transactions: TxItem[] }) {
  const { lang } = usePreferences();
  const dk = useLayout() === 'desktop';
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const prevMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const prevMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0);
  const thisMonthTx = transactions.filter(tx => new Date(tx.created_at) >= monthStart);
  const prevMonthTx = transactions.filter(tx => { const d = new Date(tx.created_at); return d >= prevMonthStart && d <= prevMonthEnd; });
  const income = thisMonthTx.filter(tx => tx.direction === 'in').reduce((s, tx) => s + tx.amount, 0);
  const expenses = thisMonthTx.filter(tx => tx.direction === 'out').reduce((s, tx) => s + tx.amount, 0);
  const prevExpenses = prevMonthTx.filter(tx => tx.direction === 'out').reduce((s, tx) => s + tx.amount, 0);
  const net = income - expenses;
  const savingsRate = income > 0 ? Math.round((net / income) * 100) : 0;
  const expensesDelta = prevExpenses > 0 ? ((expenses - prevExpenses) / prevExpenses * 100) : 0;
  const monthName = now.toLocaleDateString(localeForLang(lang), { month: 'long' });
  const items = [
    { label: tr('Дохід', 'Income'), value: `${fmtInt(income)}\u00a0TAX`, color: '#a9a9a9', icon: <TrendUpIcon color="#a9a9a9" /> },
    { label: tr('Витрати', 'Expenses'), value: `${fmtInt(expenses)}\u00a0TAX`, color: income > 0 && expenses > income ? '#888888' : text.secondary, icon: <TrendDownIcon color={income > 0 && expenses > income ? '#888888' : text.secondary} />, sub: prevExpenses > 0 ? `${expensesDelta >= 0 ? '+' : ''}${expensesDelta.toFixed(0)}% ${tr('до минулого місяця', 'vs last month')}` : undefined },
    { label: tr('Баланс', 'Balance'), value: `${net >= 0 ? '+' : '−'}${fmtInt(Math.abs(net))}\u00a0TAX`, color: net >= 0 ? '#a9a9a9' : '#888888', icon: <WalletIcon color={net >= 0 ? '#a9a9a9' : '#888888'} /> },
    { label: tr('Заощадження', 'Savings'), value: `${savingsRate}%`, color: savingsRate >= 20 ? '#a9a9a9' : savingsRate >= 10 ? gold : text.secondary, icon: <BankIcon color={savingsRate >= 20 ? '#a9a9a9' : savingsRate >= 10 ? gold : text.secondary} /> },
  ];
  if (!income && !expenses) return null;
  return (
    <div style={{ padding: dk ? 0 : '20px 22px 0' }}>
      <div style={dk ? { ...dkTitle, marginBottom: 16, textTransform: 'capitalize' } : { ...sectionLabel, paddingLeft: 0, paddingRight: 0, marginBottom: 12 }}>{tr('Фінансовий звіт', 'Financial report')} · {monthName}</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {items.map(({ label, value, color, icon, sub }) => (
          <div key={label} style={{ ...glassCard(), padding: '14px 16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 16, height: 16 }}>{icon}</span>
              <span style={{ fontSize: 11, color: text.muted }}>{label}</span>
            </div>
            <div style={{ fontSize: 18, fontWeight: 700, color, fontFeatureSettings: '"tnum"' }}>{value}</div>
            {sub && <div style={{ fontSize: 10, color: text.dim, marginTop: 3 }}>{sub}</div>}
          </div>
        ))}
      </div>
    </div>
  );
}

function CurrencyRatesBar({ onRatesLoaded, onExchange }: { onRatesLoaded?: (r: FxRate[]) => void; onExchange?: () => void } = {}) {
  const [rates, setRates] = useState<NbuRate[]>([]);
  const dk = useLayout() === 'desktop';
  const FALLBACK: FxRate[] = [{ code: 'USD', rate: 41.20 }, { code: 'EUR', rate: 44.85 }, { code: 'GBP', rate: 52.10 }, { code: 'PLN', rate: 10.35 }];
  useEffect(() => {
    fetch('https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?json')
      .then(r => r.json())
      .then((data: { cc: string; rate: number }[]) => {
        const wanted = ['USD', 'EUR', 'GBP', 'PLN'];
        const filtered = data.filter(r => wanted.includes(r.cc)).map(r => ({ code: r.cc, rate: r.rate }));
        setRates(filtered); onRatesLoaded?.(filtered);
      })
      .catch(() => { setRates(FALLBACK); onRatesLoaded?.(FALLBACK); });
  }, []);
  if (!rates.length) return null;
  return (
    <div style={{ padding: dk ? 0 : '20px 22px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 10 }}>
        <div style={dk ? { ...dkTitle, flex: 1 } : { ...sectionLabel, paddingLeft: 0, paddingRight: 0, flex: 1 }}>{tr('Курси НБУ', 'NBU rates')}</div>
        {onExchange && <button onClick={onExchange} className={dk ? 'kp-btn' : undefined} style={dk ? { height: 36, padding: '0 14px', fontSize: 13 } : { fontSize: 12, color: gold, background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontWeight: 600 }}>{dk ? tr('Обміняти', 'Exchange') : tr('💱 Обміняти', '💱 Exchange')}</button>}
      </div>
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2, scrollbarWidth: 'none' }}>
        {rates.map(r => (
          <div key={r.code} onClick={onExchange} style={{ ...glassCard(), padding: '10px 14px', flexShrink: 0, minWidth: 72, display: 'flex', flexDirection: 'column', gap: 4, cursor: onExchange ? 'pointer' : 'default' }}>
            <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8, fontWeight: 600 }}>{r.code}</div>
            <div style={{ fontSize: 15, color: text.primary, fontWeight: 700, fontFeatureSettings: '"tnum"' }}>
              {r.rate.toFixed(2)}<span style={{ fontSize: 10, color: text.muted, fontWeight: 400 }}> TAX</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Savings goals mini widget ─────────────────────────────────────────────────
interface SavingsGoal { id: number; title: string; target_amount: number; current_amount: number; deadline?: string; }
function SavingsGoalsMini() {
  const [goals, setGoals] = useState<SavingsGoal[]>([]);
  const dk = useLayout() === 'desktop';
  const { toast } = useApp();
  const token = localStorage.getItem('army_bank_token');
  const [contributeId, setContributeId] = useState<number | null>(null);
  const [contributeAmt, setContributeAmt] = useState('');
  const [creating, setCreating] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newTarget, setNewTarget] = useState('');
  const [showCreate, setShowCreate] = useState(false);

  const load = () => {
    if (!token) return;
    fetch('/api/savings-goals', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.json())
      .then(j => { if (j.ok) setGoals(j.data || []); })
      .catch(() => {});
  };
  useEffect(load, []);

  const contribute = async (goalId: number) => {
    const amount = parseFloat(contributeAmt.replace(',', '.'));
    if (!amount || amount <= 0) return;
    try {
      const idempotencyKey = `goal-contribute-${goalId}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const r = await fetch(`/api/savings-goals/${goalId}/contribute`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ amount, idempotency_key: idempotencyKey }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка', 'Error'));
      toast(tr('Внесок зараховано ✓', 'Contribution added ✓'));
      setContributeId(null); setContributeAmt(''); load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
  };

  const createGoal = async () => {
    const target = parseFloat(newTarget.replace(',', '.'));
    if (!newTitle.trim() || !target) return;
    setCreating(true);
    try {
      const idempotencyKey = `goal-create-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const r = await fetch('/api/savings-goals', {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ title: newTitle.trim(), target_amount: target, idempotency_key: idempotencyKey }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка', 'Error'));
      toast(tr('Ціль створено ✓', 'Goal created ✓'));
      setShowCreate(false); setNewTitle(''); setNewTarget(''); load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
    finally { setCreating(false); }
  };

  const deleteGoal = async (goalId: number) => {
    try {
      await fetch(`/api/savings-goals/${goalId}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
      load();
    } catch { /* ignore */ }
  };

  return (
    <div style={{ padding: dk ? 0 : '20px 22px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <div style={dk ? dkTitle : { ...sectionLabel, paddingLeft: 0, paddingRight: 0 }}>{tr('Цілі заощаджень', 'Savings goals')}</div>
        <button onClick={() => setShowCreate(v => !v)} style={{
          padding: '5px 12px', fontSize: 11, fontWeight: 600, color: gold,
          background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`,
          borderRadius: 20, cursor: 'pointer', fontFamily: 'inherit',
        }}>{tr('+ Нова', '+ New')}</button>
      </div>

      {showCreate && (
        <div style={{ ...glassCard(), padding: '14px 16px', marginBottom: 10 }}>
          <input value={newTitle} onChange={e => setNewTitle(e.target.value)} placeholder={tr('Назва цілі', 'Goal name')}
            style={{ width: '100%', padding: '9px 12px', marginBottom: 8, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: '#d8d8d8', fontSize: 13, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box' }} />
          <input value={newTarget} onChange={e => setNewTarget(e.target.value)} placeholder={tr('Сума, TAX', 'Amount, TAX')} type="text" inputMode="decimal"
            style={{ width: '100%', padding: '9px 12px', marginBottom: 10, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: '#d8d8d8', fontSize: 13, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box' }} />
          <button onClick={createGoal} disabled={creating} style={{
            width: '100%', padding: '10px', fontSize: 13, fontWeight: 600,
            background: `${gold}`, color: '#161616',
            border: 'none', borderRadius: 10, cursor: 'pointer', fontFamily: 'inherit',
          }}>{creating ? '…' : tr('Створити', 'Create')}</button>
        </div>
      )}

      {goals.length === 0 && !showCreate && (
        <div style={{ fontSize: 13, color: text.muted, textAlign: 'center', padding: '18px 0' }}>
          {tr('Немає активних цілей', 'No active goals')}
        </div>
      )}

      {goals.map(goal => {
        const pct = goal.target_amount > 0 ? Math.min(100, Math.round((goal.current_amount / goal.target_amount) * 100)) : 0;
        const isContributing = contributeId === goal.id;
        return (
          <div key={goal.id} style={{ ...glassCard(), padding: '14px 16px', marginBottom: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
              <span style={{ color: text.secondary, fontWeight: 600, fontSize: 14 }}>{goal.title}</span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ color: gold, fontSize: 12, fontWeight: 600 }}>{pct}%</span>
                <button onClick={() => deleteGoal(goal.id)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'rgba(110,110,110, 0.6)', fontSize: 16, padding: '0 0 0 4px', lineHeight: 1 }}>×</button>
              </div>
            </div>
            <div style={{ height: 5, background: 'rgba(255,255,255, 0.1)', borderRadius: 4, marginBottom: 6 }}>
              <div style={{ width: `${pct}%`, height: '100%', background: `${goldDark}`, borderRadius: 4, transition: 'width 0.6s ease' }} />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: isContributing ? 10 : 0 }}>
              <span style={{ color: text.muted, fontSize: 11 }}>{fmtInt(goal.current_amount)}{'\u00a0TAX'}</span>
              <span style={{ color: text.muted, fontSize: 11 }}>{tr('з', 'of')} {fmtInt(goal.target_amount)}{'\u00a0TAX'}</span>
            </div>
            {!isContributing ? (
              <button onClick={() => { setContributeId(goal.id); setContributeAmt(''); }} style={{
                marginTop: 8, width: '100%', padding: '7px', fontSize: 12, fontWeight: 600,
                background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`,
                borderRadius: 8, cursor: 'pointer', color: gold, fontFamily: 'inherit',
              }}>{tr('Поповнити', 'Top up')}</button>
            ) : (
              <div style={{ display: 'flex', gap: 8 }}>
                <input value={contributeAmt} onChange={e => setContributeAmt(e.target.value)} placeholder={tr('Сума', 'Amount')} type="text" inputMode="decimal"
                  style={{ flex: 1, padding: '8px 10px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 8, color: '#d8d8d8', fontSize: 13, outline: 'none', fontFamily: 'inherit' }} />
                <button onClick={() => contribute(goal.id)} style={{
                  padding: '8px 14px', fontSize: 12, fontWeight: 600,
                  background: `${gold}`, color: '#161616',
                  border: 'none', borderRadius: 8, cursor: 'pointer', fontFamily: 'inherit',
                }}>✓</button>
                <button onClick={() => setContributeId(null)} style={{
                  padding: '8px 10px', fontSize: 12,
                  background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`,
                  borderRadius: 8, cursor: 'pointer', color: text.muted, fontFamily: 'inherit',
                }}>✕</button>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Recurring payments section ────────────────────────────────────────────────
interface RecurringTx { id: number; title: string; amount: number; tx_type: string; recipient_account?: string; frequency: string; next_run_date?: string; is_active: boolean; }
// [Ukrainian, English]; shown through tr() so they follow the language.
const FREQ_LABELS: Record<string, [string, string]> = { daily: ['Щодня', 'Daily'], weekly: ['Щотижня', 'Weekly'], biweekly: ['Раз на 2 тижні', 'Every 2 weeks'], monthly: ['Щомісяця', 'Monthly'], quarterly: ['Щокварталу', 'Quarterly'] };
function RecurringSection() {
  const token = localStorage.getItem('army_bank_token');
  const { toast } = useApp();
  const [list, setList] = useState<RecurringTx[]>([]);
  const [showCreate, setShowCreate] = useState(false);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ title: '', amount: '', recipient_account: '', frequency: 'monthly' });

  const load = () => {
    if (!token) return;
    fetch('/api/recurring-transactions', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.json())
      .then(j => { if (j.ok) setList(j.data || []); })
      .catch(() => {});
  };
  useEffect(load, []);

  const toggle = async (id: number, current: boolean) => {
    try {
      const r = await fetch(`/api/recurring-transactions/${id}/toggle`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ is_active: !current }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
  };

  const remove = async (id: number) => {
    try {
      await fetch(`/api/recurring-transactions/${id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
      load();
    } catch { /* ignore */ }
  };

  const create = async () => {
    const amount = parseFloat(form.amount.replace(',', '.'));
    if (!form.title.trim() || !amount) return;
    setCreating(true);
    try {
      const idempotencyKey = `recurring-create-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const r = await fetch('/api/recurring-transactions', {
        method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ title: form.title.trim(), amount, tx_type: 'transfer', recipient_account: form.recipient_account.trim() || undefined, frequency: form.frequency, idempotency_key: idempotencyKey }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка', 'Error'));
      toast(tr('Регулярний платіж створено ✓', 'Recurring payment created ✓'));
      setShowCreate(false); setForm({ title: '', amount: '', recipient_account: '', frequency: 'monthly' }); load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
    finally { setCreating(false); }
  };

  const inputStyle: React.CSSProperties = { width: '100%', padding: '9px 12px', marginBottom: 8, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: '#d8d8d8', fontSize: 13, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box' };

  return (
    <div style={{ padding: '24px 22px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <div style={{ ...sectionLabel, paddingLeft: 0, paddingRight: 0 }}>{tr('Регулярні платежі', 'Recurring payments')}</div>
        <button onClick={() => setShowCreate(v => !v)} style={{
          padding: '5px 12px', fontSize: 11, fontWeight: 600, color: gold,
          background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`,
          borderRadius: 20, cursor: 'pointer', fontFamily: 'inherit',
        }}>{tr('+ Новий', '+ New')}</button>
      </div>

      {showCreate && (
        <div style={{ ...glassCard(), padding: '16px', marginBottom: 12 }}>
          <input value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder={tr('Назва платежу', 'Payment name')} style={inputStyle} />
          <input value={form.amount} onChange={e => setForm(f => ({ ...f, amount: e.target.value }))} placeholder={tr('Сума, TAX', 'Amount, TAX')} type="text" inputMode="decimal" style={inputStyle} />
          <input value={form.recipient_account} onChange={e => setForm(f => ({ ...f, recipient_account: e.target.value }))} placeholder={tr('Рахунок отримувача (необов\'язково)', 'Recipient\'s account (optional)')} style={inputStyle} />
          <select value={form.frequency} onChange={e => setForm(f => ({ ...f, frequency: e.target.value }))} style={{ ...inputStyle, marginBottom: 12 }}>
            {Object.entries(FREQ_LABELS).map(([k, v]) => <option key={k} value={k}>{tr(v[0], v[1])}</option>)}
          </select>
          <button onClick={create} disabled={creating} style={{ width: '100%', padding: '10px', fontSize: 13, fontWeight: 600, background: `${gold}`, color: '#161616', border: 'none', borderRadius: 10, cursor: 'pointer', fontFamily: 'inherit' }}>
            {creating ? '…' : tr('Створити', 'Create')}
          </button>
        </div>
      )}

      {list.length === 0 && !showCreate && (
        <div style={{ ...glassCard(), padding: '20px 16px', textAlign: 'center' }}>
          <div style={{ fontSize: 13, color: text.muted }}>{tr('Немає регулярних платежів', 'No recurring payments')}</div>
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {list.map(rec => (
          <div key={rec.id} style={{ ...glassCard(), padding: '14px 16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: rec.is_active ? 'rgba(180,180,180, 0.15)' : 'rgba(172,172,172, 0.08)', border: `1px solid ${rec.is_active ? 'rgba(180,180,180, 0.3)' : 'rgba(172,172,172, 0.15)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, flexShrink: 0 }}>🔄</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: text.secondary, marginBottom: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{rec.title}</div>
                <div style={{ fontSize: 11, color: text.muted }}>
                  {FREQ_LABELS[rec.frequency] ? tr(...FREQ_LABELS[rec.frequency]) : rec.frequency}
                  {rec.next_run_date && ` · ${tr('наступний', 'next')} ${rec.next_run_date}`}
                </div>
              </div>
              <div style={{ textAlign: 'right', flexShrink: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: text.secondary, fontFeatureSettings: '"tnum"' }}>{fmtInt(rec.amount)}{'\u00a0TAX'}</div>
                <div style={{ fontSize: 10, color: rec.is_active ? '#a9a9a9' : 'rgba(126,126,126, 0.7)', marginTop: 2 }}>{rec.is_active ? tr('Активний', 'Active') : tr('Призупинено', 'Paused')}</div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
              <button onClick={() => toggle(rec.id, rec.is_active)} style={{ flex: 1, padding: '7px', fontSize: 12, fontWeight: 600, background: rec.is_active ? 'rgba(172,172,172, 0.08)' : 'rgba(180,180,180, 0.12)', border: `1px solid ${rec.is_active ? 'rgba(172,172,172, 0.18)' : 'rgba(180,180,180, 0.3)'}`, borderRadius: 8, cursor: 'pointer', color: rec.is_active ? text.muted : '#a9a9a9', fontFamily: 'inherit' }}>
                {rec.is_active ? tr('Призупинити', 'Pause') : tr('Активувати', 'Activate')}
              </button>
              <button onClick={() => remove(rec.id)} style={{ padding: '7px 12px', fontSize: 12, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 8, cursor: 'pointer', color: 'rgba(110,110,110, 0.8)', fontFamily: 'inherit' }}>{tr('Видалити', 'Delete')}</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function getQuickActions(t: (key: TranslationKey) => string): { label: string; icon: React.ReactNode; action: TabKey | TransferMode }[] {
  return [
    { label: t('quick_topup'), action: 'topup', icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 19V5M5 12l7-7 7 7" stroke="#292929" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg> },
    { label: t('quick_by_card'), action: 'by_card', icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M12 5l7 7-7 7" stroke="#292929" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg> },
    { label: t('quick_by_account'), action: 'by_account', icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M3 9h18M3 15h18M6 5v14M18 5v14" stroke="#292929" strokeWidth="2" strokeLinecap="round" /></svg> },
    { label: t('quick_market'), action: 'market', icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13l-1.5 6h12" stroke="#292929" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /><circle cx="9" cy="21" r="1" fill="#292929" /><circle cx="19" cy="21" r="1" fill="#292929" /></svg> },
  ];
}

// ─── Financial Health Score ────────────────────────────────────────────────
function computeHealth(transactions: TxItem[], account: AccountInfo) {
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthTx = transactions.filter(tx => new Date(tx.created_at) >= monthStart);
  const income = monthTx.filter(tx => tx.direction === 'in').reduce((s, tx) => s + tx.amount, 0);
  const expenses = monthTx.filter(tx => tx.direction === 'out').reduce((s, tx) => s + tx.amount, 0);
  const balance = account.balance;
  const savingsRate = income > 0 ? Math.max(0, Math.min(100, ((income - expenses) / income) * 100)) : 50;
  const balanceScore = Math.min(100, (balance / 50000) * 100);
  const activityScore = Math.min(100, monthTx.length * 5);
  const score = Math.round(savingsRate * 0.5 + balanceScore * 0.3 + activityScore * 0.2);
  const label = score >= 80 ? tr('Відмінно', 'Excellent') : score >= 60 ? tr('Добре', 'Good') : score >= 40 ? tr('Задовільно', 'Fair') : tr('Потребує уваги', 'Needs attention');
  const tips = [
    income > 0 && expenses / income > 0.8 && tr('Витрати перевищують 80% доходу — розгляньте бюджет', 'Spending is over 80% of income — consider a budget'),
    balance < 1000 && tr('Підтримуйте резервний фонд від 5 000 TAX', 'Keep a reserve of at least 5,000 TAX'),
    monthTx.length < 3 && tr('Мало активності — використовуйте картку для кешбеку', 'Little activity — use your card to earn cashback'),
  ].filter(Boolean) as string[];
  return { score, label, tips, parts: [
    { label: tr('Заощадження', 'Savings'), val: Math.round(savingsRate) },
    { label: tr('Баланс', 'Balance'), val: Math.round(balanceScore) },
    { label: tr('Активність', 'Activity'), val: Math.round(activityScore) },
  ] };
}

function DesktopHealth({ transactions, account }: { transactions: TxItem[]; account: AccountInfo | null }) {
  const [on, setOn] = useState(false);
  useEffect(() => { const id = requestAnimationFrame(() => setOn(true)); return () => cancelAnimationFrame(id); }, []);
  if (!account) return null;
  const { score, label, tips, parts } = computeHealth(transactions, account);
  const R = 54, C = 2 * Math.PI * R;
  return (
    <div style={{ height: '100%' }}>
      <div style={{ ...T.h3, fontSize: 18, color: text.primary, marginBottom: 20 }}>{tr('Фінансовий рейтинг', 'Financial score')}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        <div style={{ position: 'relative', width: 128, height: 128, flexShrink: 0 }}>
          <svg viewBox="0 0 128 128" width="128" height="128" role="img" aria-label={`${score} / 100`} style={{ transform: 'rotate(-90deg)' }}>
            <circle cx="64" cy="64" r={R} fill="none" stroke="rgba(255,255,255, 0.1)" strokeWidth="10" />
            <circle cx="64" cy="64" r={R} fill="none" stroke="#f4f4f5" strokeWidth="10" strokeLinecap="round"
              strokeDasharray={`${on ? (score / 100) * C : 0} ${C}`} style={{ transition: 'stroke-dasharray 1.1s var(--kp-ease)' }} />
          </svg>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ fontSize: 38, fontWeight: 300, color: text.primary, letterSpacing: -1.5, lineHeight: 1, ...T.num }}>{score}</span>
            <span style={{ fontSize: 12, color: text.dim, marginTop: 3 }}>{tr('з 100', 'of 100')}</span>
          </div>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 16, fontWeight: 600, color: text.primary, marginBottom: 12 }}>{label}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
            {parts.map(p => (
              <div key={p.label}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12.5, color: text.muted, marginBottom: 4 }}>
                  <span>{p.label}</span><span style={{ ...T.num, color: text.secondary, fontWeight: 600 }}>{p.val}</span>
                </div>
                <div style={{ height: 4, borderRadius: 4, background: 'rgba(255,255,255,0.07)', overflow: 'hidden' }}>
                  <div style={{ width: on ? `${p.val}%` : 0, height: '100%', borderRadius: 4, background: 'rgba(244,244,245,0.82)', transition: 'width 1s var(--kp-ease)' }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
      {tips.length > 0 && (
        <ul style={{ margin: '20px 0 0', padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {tips.map(tip => (
            <li key={tip} style={{ fontSize: 13.5, lineHeight: 1.45, color: text.muted, padding: '10px 14px', borderRadius: 12, background: 'var(--kp-fill)' }}>{tip}</li>
          ))}
        </ul>
      )}
    </div>
  );
}

function FinancialHealthScore({ transactions, account }: { transactions: TxItem[]; account: AccountInfo | null }) {
  const dk = useLayout() === 'desktop';
  if (!account) return null;
  const { score, label: levelLabel, tips, parts } = computeHealth(transactions, account);
  const savingsRate = parts[0].val, balanceScore = parts[1].val, activityScore = parts[2].val;

  const level = score >= 80 ? { label: levelLabel, color: '#4fd18b', icon: <TrophyIcon color="#4fd18b" /> }
    : score >= 60 ? { label: levelLabel, color: '#b6d94c', icon: <CheckBadgeIcon color="#b6d94c" /> }
    : score >= 40 ? { label: levelLabel, color: '#FFD400', icon: <ChartIcon color="#FFD400" /> }
    : { label: levelLabel, color: '#ff7a6b', icon: <AlertIcon color="#ff7a6b" /> };

  return (
    <div style={{ margin: dk ? 0 : '14px 22px 20px', ...ENGRAVED_FRAME, borderRadius: dk ? 24 : 20, padding: dk ? 24 : '18px 20px', overflow: 'hidden', position: 'relative', height: dk ? '100%' : undefined, boxSizing: 'border-box' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 18, marginBottom: 18 }}>
        <div style={{ position: 'relative', width: 92, height: 92, flexShrink: 0, filter: `drop-shadow(0 6px 16px ${level.color}40)` }}>
          <svg width="92" height="92" viewBox="0 0 92 92" aria-hidden="true">
            <circle cx="46" cy="46" r="38" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="7" />
            <circle cx="46" cy="46" r="38" fill="none" stroke={level.color} strokeWidth="7" strokeLinecap="round"
              strokeDasharray={`${(2 * Math.PI * 38 * score) / 100} ${2 * Math.PI * 38}`} transform="rotate(-90 46 46)"
              style={{ transition: 'stroke-dasharray 1s ease' }} />
          </svg>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ fontSize: 30, fontWeight: 700, lineHeight: 1, color: text.primary, letterSpacing: -0.8, ...T.num }}>{score}</div>
            <div style={{ fontSize: 10, color: text.muted, marginTop: 3 }}>{tr('зі 100', 'of 100')}</div>
          </div>
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 11, color: text.muted, letterSpacing: 1, marginBottom: 6 }}>{tr('ФІНАНСОВИЙ РЕЙТИНГ', 'FINANCIAL SCORE')}</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '5px 11px', borderRadius: 999, background: `${level.color}22`, color: level.color, fontSize: 13, fontWeight: 600 }}>
            <span style={{ display: 'inline-flex', width: 15, height: 15 }}>{level.icon}</span>
            <span>{level.label}</span>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginBottom: tips.length ? 16 : 0 }}>
        {[
          { label: tr('Заощадження', 'Savings'), val: Math.round(savingsRate) },
          { label: tr('Баланс', 'Balance'), val: Math.round(balanceScore) },
          { label: tr('Активність', 'Activity'), val: Math.round(activityScore) },
        ].map(({ label, val }) => (
          <div key={label}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12.5, color: text.muted, marginBottom: 5 }}>
              <span>{label}</span><span style={{ color: text.secondary, fontWeight: 600, ...T.num }}>{val}</span>
            </div>
            <div style={{ height: 5, borderRadius: 5, background: 'rgba(255,255,255,0.07)', overflow: 'hidden' }}>
              <div style={{ width: `${val}%`, height: '100%', borderRadius: 5, background: `linear-gradient(90deg, ${level.color}99, ${level.color})`, transition: 'width 1s ease' }} />
            </div>
          </div>
        ))}
      </div>
      {/* Tips */}
      {tips.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {tips.map((tip, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 8, fontSize: 11, color: text.muted, background: 'rgba(255,255,255, 0.1)', borderRadius: 8, padding: '7px 10px' }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 14, height: 14, color: gold, flexShrink: 0, marginTop: 1 }}>
                <TipIcon color={gold} />
              </span>
              <span>{tip}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Budget Planner (localStorage) ────────────────────────────────────────
const BUDGET_KEY = 'army_bank_budget_v1';
const BUDGET_CATEGORIES = [
  { key: 'food', label: ['Їжа', 'Food'], icon: '🛒' },
  { key: 'transport', label: ['Транспорт', 'Transport'], icon: '🚗' },
  { key: 'entertainment', label: ['Розваги', 'Entertainment'], icon: '🎭' },
  { key: 'health', label: ['Здоров\'я', 'Health'], icon: '💊' },
  { key: 'shopping', label: ['Шопінг', 'Shopping'], icon: '🛍️' },
  { key: 'utilities', label: ['Комунальні', 'Utilities'], icon: '🏠' },
  { key: 'other', label: ['Інше', 'Other'], icon: '📦' },
];

function txToCategory(tx: TxItem): string {
  const desc = (tx.description || '').toLowerCase();
  if (desc.includes('їж') || desc.includes('продукт') || desc.includes('food') || desc.includes('supermarket') || desc.includes('кафе') || desc.includes('ресторан')) return 'food';
  if (desc.includes('таксі') || desc.includes('uber') || desc.includes('bolt') || desc.includes('metro') || desc.includes('автобус')) return 'transport';
  if (desc.includes('кіно') || desc.includes('netflix') || desc.includes('гра') || desc.includes('gaming')) return 'entertainment';
  if (desc.includes('аптек') || desc.includes('лікар') || desc.includes('клінік') || desc.includes('health')) return 'health';
  if (desc.includes('шопінг') || desc.includes('магаз') || desc.includes('amazon') || desc.includes('rozetka')) return 'shopping';
  if (desc.includes('комунал') || desc.includes('електрик') || desc.includes('газ') || desc.includes('вода')) return 'utilities';
  return 'other';
}

const BUDGET_ICON_PATHS: Record<string, string> = {"food": "M6 6h15l-1.5 8.5H7.5L6 6Zm0 0L5 3H2M9 20a1 1 0 1 0 0-2 1 1 0 0 0 0 2Zm9 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z", "transport": "M5 17h14M6 17v2M18 17v2M5 17l1.5-6.5A2 2 0 0 1 8.4 9h7.2a2 2 0 0 1 1.9 1.5L19 17M7.5 14h.01M16.5 14h.01", "entertainment": "M5 4h14v16l-7-4-7 4V4Z", "health": "M12 21s-7-4.5-9.3-9A5 5 0 0 1 12 6a5 5 0 0 1 9.3 6C19 16.5 12 21 12 21Z", "shopping": "M6 8h12l1 13H5L6 8Zm3 0V6a3 3 0 0 1 6 0v2", "utilities": "M3 11l9-7 9 7M5 10v10h14V10", "other": "M4 7l8-4 8 4-8 4-8-4Zm0 0v10l8 4 8-4V7M12 11v10"};

function BudgetPlanner({ transactions }: { transactions: TxItem[] }) {
  const [budgets, setBudgets] = useState<Record<string, number>>(() => {
    try { return JSON.parse(localStorage.getItem(BUDGET_KEY) || '{}'); } catch { return {}; }
  });
  const [editing, setEditing] = useState<string | null>(null);
  const [editVal, setEditVal] = useState('');

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const outTx = transactions.filter(tx => tx.direction === 'out' && new Date(tx.created_at) >= monthStart);

  const spent: Record<string, number> = {};
  for (const tx of outTx) {
    const cat = txToCategory(tx);
    spent[cat] = (spent[cat] || 0) + tx.amount;
  }

  function saveBudget(key: string, val: number) {
    const next = { ...budgets, [key]: val };
    setBudgets(next);
    try { localStorage.setItem(BUDGET_KEY, JSON.stringify(next)); } catch {}
    setEditing(null);
  }

  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const dayOfMonth = now.getDate();
  const monthProgress = dayOfMonth / daysInMonth;

  return (
    <div style={{ margin: '0 22px 20px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: text.secondary }}>{tr('Бюджет на місяць', 'Monthly budget')}</div>
        <div style={{ fontSize: 11, color: text.muted }}>{dayOfMonth}/{daysInMonth} {tr('дн.', 'days')}</div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {BUDGET_CATEGORIES.map(cat => {
          const limit = budgets[cat.key] || 0;
          const spentAmt = spent[cat.key] || 0;
          const pct = limit > 0 ? Math.min(100, (spentAmt / limit) * 100) : 0;
          const pace = limit > 0 ? (spentAmt / limit) / monthProgress : 0; // >1 = over pace
          const barColor = pct >= 100 ? '#757575' : pct >= 80 ? '#afafaf' : '#a9a9a9';
          const isEditing = editing === cat.key;

          return (
            <div key={cat.key} style={{ background: bg.card, border: `1px solid ${bg.border}`, borderRadius: 16, padding: '12px 14px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: limit > 0 ? 10 : 0 }}>
                <span aria-hidden style={{ width: 34, height: 34, borderRadius: 10, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#d8d8d8" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d={BUDGET_ICON_PATHS[cat.key] ?? BUDGET_ICON_PATHS.other} /></svg>
                </span>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: 13, fontWeight: 600, color: text.primary }}>{tr(cat.label[0], cat.label[1])}</span>
                    {limit > 0 && (
                      <span style={{ fontSize: 12, color: pct >= 100 ? '#757575' : text.secondary, fontWeight: 600 }}>
                        {spentAmt.toLocaleString('uk-UA', { maximumFractionDigits: 0 })}{'\u00a0TAX'} / {limit.toLocaleString('uk-UA', { maximumFractionDigits: 0 })}{'\u00a0TAX'}
                      </span>
                    )}
                    {limit === 0 && <span style={{ fontSize: 11, color: text.dim }}>{spentAmt.toLocaleString('uk-UA', { maximumFractionDigits: 0 })}{'\u00a0TAX'} {tr('цього місяця', 'this month')}</span>}
                  </div>
                </div>
                <button onClick={() => { setEditing(isEditing ? null : cat.key); setEditVal(limit > 0 ? String(limit) : ''); }}
                  style={{ background: 'none', border: 'none', color: gold, fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', padding: '2px 6px' }}>
                  {isEditing ? '✕' : limit > 0 ? tr('Змінити', 'Change') : tr('+ Ліміт', '+ Limit')}
                </button>
              </div>
              {isEditing && (
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <input type="text" inputMode="decimal" value={editVal} onChange={e => setEditVal(e.target.value)}
                    placeholder={tr('Ліміт TAX', 'Limit, TAX')}
                    style={{ flex: 1, padding: '8px 12px', borderRadius: 10, background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, color: text.primary, fontSize: 14, outline: 'none' }} />
                  <button onClick={() => { const v = parseFloat(editVal.replace(',', '.')); if (v > 0) saveBudget(cat.key, v); }}
                    style={{ padding: '8px 14px', borderRadius: 10, border: 'none', background: '#a9a9a9', color: '#ffffff', fontSize: 13, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
                    {tr('ОК', 'OK')}
                  </button>
                </div>
              )}
              {limit > 0 && (
                <>
                  <div style={{ background: 'rgba(255,255,255, 0.1)', borderRadius: 4, height: 5, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: `${pct}%`, borderRadius: 4, background: `${barColor}`, transition: 'width 0.6s' }} />
                  </div>
                  {pace > 1.2 && <div style={{ fontSize: 10, color: '#afafaf', marginTop: 4 }}>{tr('Темп витрат вищий за плановий', 'Spending faster than planned')}</div>}
                  {pct >= 100 && <div style={{ fontSize: 10, color: '#757575', marginTop: 4 }}>{tr('Ліміт вичерпано', 'Limit reached')}</div>}
                </>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ─── Referral Widget ───────────────────────────────────────────────────────
function ReferralWidget({ user }: { user: UserInfo | null }) {
  const [copied, setCopied] = useState(false);
  if (!user) return null;

  // Generate a stable referral code from the user's phone
  const code = 'TT' + (user.phone || '').replace(/\D/g, '').slice(-6);
  const link = `https://bank.munister.com.ua/?ref=${code}`;

  function copyLink() {
    navigator.clipboard.writeText(link).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }).catch(() => {
      // fallback for older iOS
      const el = document.createElement('textarea');
      el.value = link;
      document.body.appendChild(el);
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  function shareLink() {
    if (navigator.share) {
      navigator.share({ title: 'TaxTech', text: tr('Навчальний банк TaxTech: картки, депозити й перекази на віртуальних гривнях', 'TaxTech learning bank: cards, deposits and transfers in a virtual currency'), url: link });
    } else {
      copyLink();
    }
  }

  return (
    <div style={{ margin: '0 18px 20px', background: `rgba(255,255,255, 0.1)`, border: `1px solid transparent`, borderRadius: 22, padding: '18px 20px', boxShadow: '0 18px 34px rgba(0,0,0, 0.14)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
        <div style={{ width: 42, height: 42, borderRadius: 13, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <path d="M12 3l2.5 5 5.5.8-4 3.9.9 5.6-4.9-2.6-4.9 2.6.9-5.6-4-3.9 5.5-.8L12 3z" stroke={gold} strokeWidth="1.6" strokeLinejoin="round" />
          </svg>
        </div>
        <div>
          <div style={{ fontSize: 15, fontWeight: 700, color: text.secondary }}>{tr('Запросити друга', 'Invite a friend')}</div>
          <div style={{ fontSize: 12, color: text.muted }}>{tr('Поділіться TaxTech з одногрупниками', 'Share TaxTech with your classmates')}</div>
        </div>
      </div>
      <div style={{ background: 'rgba(0,0,0, 0.2)', borderRadius: 12, padding: '10px 14px', marginBottom: 12, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8, marginBottom: 2 }}>{tr('ВАШ КОД', 'YOUR CODE')}</div>
          <div style={{ fontSize: 18, fontWeight: 700, color: gold, letterSpacing: 2 }}>{code}</div>
        </div>
        <button onClick={copyLink} style={{ padding: '7px 14px', borderRadius: 10, border: `1px solid transparent`, background: copied ? 'rgba(169,169,169, 0.15)' : 'rgba(171,171,171, 0.1)', color: copied ? '#a9a9a9' : gold, fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all 0.2s' }}>
          {copied ? tr('✓ Скопійовано', '✓ Copied') : tr('Копіювати', 'Copy')}
        </button>
      </div>
      <button onClick={shareLink} style={{ width: '100%', padding: '12px', borderRadius: 14, border: 'none', background: 'rgba(171,171,171, 0.25)', color: gold, fontSize: 14, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M18 8a3 3 0 100-6 3 3 0 000 6zM6 15a3 3 0 100-6 3 3 0 000 6zM18 22a3 3 0 100-6 3 3 0 000 6zM8.59 13.51l6.83 3.98M15.41 6.51l-6.82 3.98" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/></svg>
        {tr('Поділитися посиланням', 'Share the link')}
      </button>
    </div>
  );
}

function OverviewScreen() {
  const layout = useLayout();
  const topPad = useTopPad();
  const { goTo, toast, user, account, transactions, cards: apiCards, openTransfer } = useApp();
  const { profilePhoto, lang, t } = usePreferences();
  function handleQuickAction(action: TabKey | TransferMode) {
    if (action === 'topup' || action === 'by_card' || action === 'by_account') openTransfer(action);
    else goTo(action as TabKey);
  }
  const { analytics } = useBankData();
  const displayName = user?.full_name ?? t('user_fallback');
  const firstName = displayName.split(/\s+/)[0];
  const avatarInitials = initials(displayName);
  const quickActions = getQuickActions(t);
  const [balanceVisible, setBalanceVisible] = useState(true);
  const [showFx, setShowFx] = useState(false);
  const [fxRates, setFxRates] = useState<FxRate[]>([]);
  const [cardIdx, setCardIdx] = useState(() => readSelectedCardIndex());
  const [ovFlipped, setOvFlipped] = useState(false);
  const [ovRevealed, setOvRevealed] = useState<{ card_number: string; cvv: string } | null>(null);
  const [ovRevealing, setOvRevealing] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [apiNotifications, setApiNotifications] = useState<ApiNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const byType = (analytics?.by_type || []).filter(r => r.direction === 'out');
  const totalOut = byType.reduce((s, r) => s + Number(r.total), 0);
  const monthIn = Number(analytics?.current_month?.total_in || 0);
  const monthOut = Number(analytics?.current_month?.total_out || 0);
  const flowNet = monthIn - monthOut;
  const flowNetSign = flowNet >= 0 ? '+' : '−';
  const SPEND_LABELS: Record<string, string> = { transfer: t('spend_transfer'), food: t('spend_food'), transport: t('spend_transport'), utility: t('spend_utility'), shopping: t('spend_shopping'), subscription: t('spend_subscription') };
  const SPEND_COLORS: Record<string, string> = { transfer: '#d8d8d8', food: '#b1b1b1', transport: '#a6a6a6', utility: gold, shopping: '#919191', subscription: '#b6b6b6' };
  const spendRows = totalOut > 0 ? byType.map(r => ({
    label: SPEND_LABELS[r.tx_type] || r.tx_type,
    pct: Math.round(Number(r.total) / totalOut * 100),
    color: SPEND_COLORS[r.tx_type] || gold,
  })) : [];

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) return;
    fetch('/api/notifications/unread-count', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok) setUnreadCount(j.data?.count ?? 0); })
      .catch(() => {});
  }, []);

  async function openNotificationsPanel() {
    const token = localStorage.getItem('army_bank_token');
    setShowNotifications(true);
    try {
      const [notifRes] = await Promise.all([
        fetch('/api/notifications', { headers: { Authorization: `Bearer ${token ?? ''}` } }),
        token ? fetch('/api/notifications/read-all', { method: 'POST', headers: { Authorization: `Bearer ${token}` } }) : Promise.resolve(null),
      ]);
      if (notifRes.ok) {
        const j = await notifRes.json();
        if (j?.ok && Array.isArray(j.data)) setApiNotifications(j.data);
      }
      setUnreadCount(0);
    } catch { /* ignore */ }
  }


  const userNameUp = (user?.full_name || 'ARMY BANK').toUpperCase();
  const cards = apiCards.length > 0
    ? apiCards.filter(c => c.status !== 'closed').map(c => apiCardToData(c, userNameUp))
    : [
      { variant: 'gold', number: '0001', name: userNameUp, expiry: '03/29', balance: Number(account?.balance || 0), isPrimary: true },
      { variant: 'emerald', number: '1183', name: userNameUp, expiry: '02/29', balance: Number(account?.balance || 0), isPrimary: false },
      { variant: 'platinum', number: '7147', name: userNameUp, expiry: '08/28', balance: Number(account?.balance || 0), isPrimary: false },
      { variant: 'obsidian', number: '4402', name: userNameUp, expiry: '11/30', balance: Number(account?.balance || 0), isPrimary: false },
    ];
  const safeCardIdx = Math.min(cardIdx, Math.max(0, cards.length - 1));
  const swipeStartXRef = useRef<number | null>(null);
  const swipeStartYRef = useRef<number | null>(null);
  const swipeAxisRef = useRef<'x' | 'y' | null>(null);
  const cardViewportRef = useRef<HTMLDivElement | null>(null);
  const [cardViewportWidth, setCardViewportWidth] = useState(0);
  const [dragOffsetX, setDragOffsetX] = useState(0);
  const [isCardDragging, setIsCardDragging] = useState(false);

  useEffect(() => {
    if (cardIdx !== safeCardIdx) setCardIdx(safeCardIdx);
  }, [cardIdx, safeCardIdx]);

  useEffect(() => {
    persistSelectedCardIndex(safeCardIdx);
    setOvFlipped(false);
    setOvRevealed(null);
  }, [safeCardIdx]);

  useEffect(() => {
    function syncCardViewport() {
      const nextWidth = cardViewportRef.current?.clientWidth || 0;
      if (nextWidth > 0) setCardViewportWidth(nextWidth);
    }
    syncCardViewport();
    window.addEventListener('resize', syncCardViewport);
    window.visualViewport?.addEventListener('resize', syncCardViewport);
    return () => {
      window.removeEventListener('resize', syncCardViewport);
      window.visualViewport?.removeEventListener('resize', syncCardViewport);
    };
  }, []);

  function resetCardSwipe() {
    swipeStartXRef.current = null;
    swipeStartYRef.current = null;
    swipeAxisRef.current = null;
    setIsCardDragging(false);
    setDragOffsetX(0);
  }

  function handleCardTouchStart(e: React.TouchEvent<HTMLDivElement>) {
    if (cards.length < 2) return;
    const t = e.touches[0];
    swipeStartXRef.current = t.clientX;
    swipeStartYRef.current = t.clientY;
    swipeAxisRef.current = null;
    setIsCardDragging(true);
    setDragOffsetX(0);
  }

  function handleCardTouchMove(e: React.TouchEvent<HTMLDivElement>) {
    if (cards.length < 2) return;
    if (swipeStartXRef.current == null || swipeStartYRef.current == null) return;
    const t = e.touches[0];
    const dx = t.clientX - swipeStartXRef.current;
    const dy = t.clientY - swipeStartYRef.current;
    if (!swipeAxisRef.current) {
      if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
        swipeAxisRef.current = Math.abs(dx) >= Math.abs(dy) ? 'x' : 'y';
      }
    }
    if (swipeAxisRef.current !== 'x') return;
    e.preventDefault();
    const bounded = Math.max(-150, Math.min(150, dx));
    setDragOffsetX(bounded);
  }

  function handleCardTouchEnd() {
    if (cards.length < 2) {
      resetCardSwipe();
      return;
    }
    const threshold = 52;
    const swipe = dragOffsetX;
    if (Math.abs(swipe) >= threshold) {
      const dir = swipe < 0 ? 1 : -1;
      setCardIdx(prev => Math.max(0, Math.min(cards.length - 1, prev + dir)));
    }
    resetCardSwipe();
  }

  async function ovRevealCard() {
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); setOvFlipped(true); return; }
    const c = apiCards[safeCardIdx];
    const token = localStorage.getItem('army_bank_token');
    setOvRevealing(true);
    try {
      const r = await fetch(`/api/cards/${c.id}/reveal`, { headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка', 'Error'));
      setOvRevealed(j.data);
      setOvFlipped(true);
    } catch (e) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
    finally { setOvRevealing(false); }
  }

  function ovFlipCard() {
    if (!ovFlipped) { ovRevealCard(); } else { setOvFlipped(false); }
  }

  const cardSection = (
    <div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 14 }}>
        <span style={{ ...T.h3, color: text.secondary }}>{t('cards_mine')}</span>
        <span style={{ ...T.sm, color: text.dim }}>• {cards.length}</span>
        <div style={{ flex: 1 }} />
        <button onClick={() => goTo('cards')} style={{
          fontSize: 12,
          color: goldLight,
          background: 'rgba(255,255,255, 0.1)',
          border: '1px solid transparent',
          borderRadius: 999,
          padding: '7px 11px',
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          fontFamily: 'inherit',
          fontWeight: 600,
          cursor: 'pointer',
          boxShadow: 'none',
        }}>
          {t('all')} <Chevron size={12} color={gold} />
        </button>
      </div>
      {!cards.length ? (
        <div style={{ maxWidth: 380, padding: '16px 18px', borderRadius: 16, border: `1px solid ${bg.border}`, background: bg.card }}>
          <div style={{ fontSize: 14, color: text.secondary, marginBottom: 6 }}>{t('cards_not_issued')}</div>
          <div style={{ fontSize: 12, color: text.muted, marginBottom: 12 }}>{t('cards_issue_hint')}</div>
          <button
            onClick={() => goTo('cards')}
            style={{ padding: '8px 12px', borderRadius: 10, border: `1px solid ${bg.border}`, background: 'rgba(255,255,255, 0.1)', color: text.secondary, cursor: 'pointer' }}
          >
            {t('open_cards')}
          </button>
        </div>
      ) : (
        <>
          <div
            ref={cardViewportRef}
            data-no-tab-swipe="true"
            style={{
              maxWidth: layout === 'desktop' ? 460 : 380,
              overflow: 'hidden',
              borderRadius: 22,
              touchAction: 'pan-y',
            }}
            onTouchStart={handleCardTouchStart}
            onTouchMove={handleCardTouchMove}
            onTouchEnd={handleCardTouchEnd}
            onTouchCancel={handleCardTouchEnd}
          >
            <div
              style={{
                display: 'flex',
                width: '100%',
                transform: `translate3d(${dragOffsetX - safeCardIdx * (cardViewportWidth || 0)}px, 0, 0)`,
                transition: isCardDragging ? 'none' : 'transform 320ms cubic-bezier(0.22, 0.61, 0.36, 1)',
                willChange: 'transform',
              }}
            >
              {cards.map((c, i) => {
                const v = CARD_VARIANTS[c.variant as CardVariant] ?? CARD_VARIANTS.gold;
                const isSelected = i === safeCardIdx;
                return (
                  <div key={`${c.number}-${i}`} style={{ flex: '0 0 100%' }}>
                    {isSelected ? (
                      <div style={{ perspective: 1000, width: '100%', aspectRatio: '1.586 / 1', cursor: 'pointer' }}
                        onClick={ovFlipCard}>
                        <div style={{
                          width: '100%', height: '100%', position: 'relative',
                          transformStyle: 'preserve-3d',
                          transform: ovFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                          transition: 'transform 0.55s cubic-bezier(0.4, 0, 0.2, 1)',
                        }}>
                          {/* Front */}
                          <div style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}>
                            <PremiumCard {...c} style={{ width: '100%' }} />
                            {!ovFlipped && <div style={{ position: 'absolute', bottom: 10, right: 12, fontSize: 9, color: 'rgba(255,255,255, 0.5)', pointerEvents: 'none' }}>{ovRevealing ? '…' : tr('👁 перевернути', '👁 flip')}</div>}
                          </div>
                          {/* Back */}
                            <CardBack bg={v.bg} image={v.image} expiry={c.expiry} name={c.name} last4={c.number} revealed={ovRevealed} toast={toast} />
                        </div>
                      </div>
                    ) : (
                      <PremiumCard {...c} style={{ width: '100%' }} />
                    )}
                  </div>
                );
              })}
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginTop: 16 }}>
            {cards.map((_, i) => (
              <button key={i} onClick={() => setCardIdx(i)} style={{ width: i === safeCardIdx ? 24 : 7, height: 7, borderRadius: 999, background: i === safeCardIdx ? `${gold}` : 'rgba(176,176,176, 0.22)', border: 'none', padding: 0, cursor: 'pointer', transition: 'all 0.25s', boxShadow: i === safeCardIdx ? '0 0 0 2px rgba(176,176,176, 0.14), 0 0 8px rgba(176,176,176, 0.24)' : 'none' }} />
            ))}
          </div>
        </>
      )}
    </div>
  );

  const quickActionsSection = (
    <div>
      <div style={{ ...T.h3, color: text.secondary, marginBottom: 14 }}>{t('quick_actions')}</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
        {quickActions.map(a => <Fragment key={a.label}><QuickAction icon={a.icon} label={a.label} onClick={() => handleQuickAction(a.action)} /></Fragment>)}
      </div>
    </div>
  );

  const greeting = timeGreeting(lang);

  if (layout === 'desktop') {
    const donutRows = byType
      .map(r => ({ label: txTypeLabel(r.tx_type, t), value: Number(r.total) }))
      .filter(r => r.value > 0)
      .sort((x, y) => y.value - x.value)
      .filter((r, _i, all) => r.value / all.reduce((a, b) => a + b.value, 0) >= 0.005);
    return (
      <div style={{ padding: '32px 40px 72px', maxWidth: 1600, margin: '0 auto' }}>
        <div className="grid grid-cols-12 gap-6">
          <DesktopHero
            span="col-span-12 xl:col-span-7 2xl:col-span-8"
            firstName={firstName} greeting={greeting}
            balance={account?.balance ?? 0} accountNumber={account?.account_number ?? '—'}
            flowNet={flowNet} visible={balanceVisible} onToggle={() => setBalanceVisible(v => !v)}
          />
          <section className="kp-card kp-rise col-span-12 xl:col-span-5 2xl:col-span-4" style={{ padding: 28, display: 'flex', flexDirection: 'column', gap: 24, ['--i' as string]: 1 }}>
            {cardSection}
            <div style={{ flex: 1 }} />
            <div className="kp-card-flat" style={{ padding: '18px 20px' }}>
              <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 14 }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: text.secondary }}>{t('dk_this_month')}</span>
                <span style={{ fontSize: 12.5, color: text.dim }}>{t('filter_income')} / {t('filter_outcome')}</span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                {[
                  { label: t('filter_income'), value: monthIn, sign: '+', color: '#5fd68a' },
                  { label: t('filter_outcome'), value: monthOut, sign: '−', color: text.primary },
                ].map(x => (
                  <div key={x.label}>
                    <div style={{ fontSize: 12.5, color: text.muted, marginBottom: 4 }}>{x.label}</div>
                    <div style={{ fontSize: 22, fontWeight: 600, color: x.color, letterSpacing: -0.5, ...T.num }}>
                      {x.sign}{fmtInt(x.value)}<span style={{ fontSize: 14, color: 'var(--kp-dim)', fontWeight: 500 }}>{fmtDec(x.value)}</span>
                    </div>
                  </div>
                ))}
              </div>
              <div aria-hidden style={{ display: 'flex', height: 6, borderRadius: 999, overflow: 'hidden', marginTop: 16, background: 'var(--kp-fill)', gap: 3 }}>
                <div style={{ flex: Math.max(monthIn, 0.0001), background: '#5fd68a', borderRadius: 999, transition: 'flex 0.8s var(--kp-ease)' }} />
                <div style={{ flex: Math.max(monthOut, 0.0001), background: gold, borderRadius: 999, transition: 'flex 0.8s var(--kp-ease)' }} />
              </div>
            </div>
            <TopRecipientsMini onTransfer={() => { openTransfer('by_account'); }} />
          </section>

          <DesktopActivity span="col-span-12 xl:col-span-7 2xl:col-span-8" transactions={transactions} />
          <SpendDonut span="col-span-12 xl:col-span-5 2xl:col-span-4" rows={donutRows} />

          <div className="kp-card kp-rise kp-slot col-span-12 md:col-span-6 xl:col-span-4" style={{ padding: 24, ['--i' as string]: 4 }}>
            <MonthlyFinanceSummary transactions={transactions} />
          </div>
          <div className="kp-card kp-rise kp-slot col-span-12 md:col-span-6 xl:col-span-4" style={{ padding: 24, ['--i' as string]: 5 }}>
            <DesktopHealth transactions={transactions} account={account} />
          </div>
          <div className="kp-card kp-rise kp-slot col-span-12 xl:col-span-4" style={{ padding: 24, ['--i' as string]: 6 }}>
            <SavingsGoalsMini />
          </div>
          <div className="kp-card kp-rise kp-slot col-span-12" style={{ padding: 24, ['--i' as string]: 7 }}>
            <CurrencyRatesBar onRatesLoaded={setFxRates} onExchange={() => setShowFx(true)} />
          </div>
        </div>
        {showFx && fxRates.length > 0 && <FxExchangeModal rates={fxRates} onClose={() => setShowFx(false)} />}
      </div>
    );
  }

  // ── Mobile layout ──
  return (
    <>
    <div style={{ paddingBottom: 20 }}>
      <div style={{ padding: `${topPad} 18px 0` }}>
        <div style={{
          ...glassCard({
            padding: '18px 18px 16px',
            borderRadius: 28,
            background: '#1c1c1e',
            boxShadow: '0 20px 42px rgba(0,0,0, 0.24)',
          }),
          position: 'relative',
          overflow: 'hidden',
        }}>
          <HeroRosette />
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 48, height: 48, borderRadius: '50%', background: `${goldLight}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#242424', fontSize: 14, fontWeight: 700, boxShadow: '0 0 0 2px rgba(176,176,176, 0.14), 0 6px 18px rgba(0,0,0, 0.28)', overflow: 'hidden', flexShrink: 0 }}>
              {profilePhoto ? <img src={profilePhoto} alt={t('profile_photo_alt')} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : avatarInitials}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 11, color: 'rgba(215,215,215, 0.68)', letterSpacing: 0.5, marginBottom: 3 }}>{greeting}</div>
              <div style={{ fontSize: 20, fontWeight: 700, color: text.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', lineHeight: 1.08, letterSpacing: -0.2 }}>{firstName}</div>
            </div>
            {[
              <svg key="shop" width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M6 8h12l1 13H5L6 8Zm3 0V6a3 3 0 0 1 6 0v2" stroke="#d8d8d8" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>,
              <svg key="bell" width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9M10 21a2 2 0 004 0" stroke="#d8d8d8" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>,
            ].map((icon, i) => (
              <button key={i} aria-label={i === 0 ? tr('Магазин', 'Shop') : tr('Сповіщення', 'Notifications')} onClick={() => i === 0 ? goTo('market') : openNotificationsPanel()} style={{ width: 40, height: 40, borderRadius: 14, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', boxShadow: '0 2px 6px rgba(0,0,0, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0, position: 'relative', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)' }}>

                {icon}
                {i === 1 && unreadCount > 0 && <span style={{ position: 'absolute', top: 6, right: 6, width: 8, height: 8, borderRadius: '50%', background: '#888888', border: '1.5px solid rgba(18,18,18, 0.9)' }} />}
              </button>
            ))}
          </div>
          <div style={{ height: 18 }} />
          <BalanceBlock visible={balanceVisible} onToggle={() => setBalanceVisible(v => !v)} balance={account?.balance ?? 0} accountNumber={account?.account_number ?? '—'} />
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 16, marginTop: 20, paddingTop: 16, borderTop: '1px solid rgba(255,255,255,0.07)' }}>
            <div>
              <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 5 }}>{tr('Цього місяця', 'This month')}</div>
              <div style={{ fontSize: 20, fontWeight: 600, letterSpacing: -0.4, color: flowNet >= 0 ? '#5fd68a' : '#ff8d80', ...T.num }}>
                {flowNetSign}{fmtInt(Math.abs(flowNet))}<span style={{ fontSize: 14, fontWeight: 500, opacity: 0.7 }}>{fmtDec(Math.abs(flowNet))}</span>
                <span style={{ fontSize: 12, fontWeight: 500, color: text.dim, marginLeft: 5 }}>TAX</span>
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 5 }}>{tr('Картки', 'Cards')}</div>
              <div style={{ fontSize: 20, fontWeight: 600, letterSpacing: -0.4, color: text.primary, ...T.num }}>{cards.length}</div>
            </div>
          </div>
        </div>
      </div>

      <div style={{ padding: '18px 18px 0' }}>
        <div style={{ ...glassCard({ padding: '18px 16px 16px', borderRadius: 24, background: '#1c1c1e' }) }}>
          {cardSection}
        </div>
      </div>

      <div style={{ padding: '18px 18px 0' }}>
        <div style={{ ...glassCard({ padding: '18px 16px 16px', borderRadius: 24, background: '#1c1c1e' }) }}>
          {quickActionsSection}
        </div>
      </div>

      <div style={{ height: 20 }} />
      <BalanceHistoryChart />
      <TopRecipientsMini onTransfer={acc => { openTransfer('by_account'); }} />

      <div style={{ padding: '0 22px 0' }}>
        <div style={{ padding: 0 }}>
          <ActivityFeed transactions={transactions} />
        </div>
      </div>

      <CurrencyRatesBar onRatesLoaded={setFxRates} onExchange={() => setShowFx(true)} />

      <MonthlyFinanceSummary transactions={transactions} />
      <FinancialHealthScore transactions={transactions} account={account} />

      <SavingsGoalsMini />

      <div style={{ height: 24 }} />
      {showFx && fxRates.length > 0 && <FxExchangeModal rates={fxRates} onClose={() => setShowFx(false)} />}
    </div>
    {showNotifications && (
      <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 300, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => setShowNotifications(false)}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0, 0.55)', backdropFilter: 'blur(4px)' }} />
        <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{
          position: 'relative', width: '100%', maxWidth: 520,
          background: '#1c1c1e',
          backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
          borderRadius: '24px 24px 0 0',
          padding: '28px 24px calc(32px + env(safe-area-inset-bottom,0px))',
          border: '1px solid transparent', borderBottom: 'none',
        }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 20px' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ fontSize: 18, fontWeight: 700, color: text.primary }}>{t('notifications_center')}</div>
              {apiNotifications.filter(n => !n.is_read).length > 0 && (
                <span style={{ fontSize: 10, fontWeight: 700, color: '#ffffff', background: '#888888', borderRadius: 100, padding: '1px 6px', letterSpacing: 0.3 }}>
                  {apiNotifications.filter(n => !n.is_read).length}
                </span>
              )}
            </div>
            <button onClick={() => setShowNotifications(false)} style={{ width: 30, height: 30, borderRadius: 8, background: 'rgba(255,255,255, 0.1)', border: 'none', cursor: 'pointer', color: text.muted, fontSize: 16, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✕</button>
          </div>
          {apiNotifications.length === 0 ? (
            <div style={{ padding: '28px 0', textAlign: 'center', color: text.muted, fontSize: 14 }}>
              {t('no_new_notifications')}
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 0, background: bg.card, border: `1px solid ${bg.border}`, borderRadius: 18, overflow: 'hidden', maxHeight: '60vh', overflowY: 'auto' }}>
              {apiNotifications.map((notif, i) => (
                <Fragment key={notif.id}>
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 16px', opacity: notif.is_read ? 0.65 : 1 }}>
                    <div style={{ width: 36, height: 36, borderRadius: 10, background: notif.is_read ? 'rgba(172,172,172, 0.08)' : 'rgba(169,169,169, 0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 17 }}>
                      {notif.icon || '🔔'}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                        <div style={{ fontSize: 13, fontWeight: notif.is_read ? 400 : 600, color: text.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{notif.title}</div>
                        {!notif.is_read && <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#a9a9a9', flexShrink: 0, display: 'inline-block' }} />}
                      </div>
                      {notif.body ? <div style={{ fontSize: 11, color: text.muted, lineHeight: 1.4 }}>{notif.body}</div> : null}
                      <div style={{ fontSize: 10, color: text.dim, marginTop: 3 }}>{fmtTime(notif.created_at, lang)}</div>
                    </div>
                  </div>
                  {i < apiNotifications.length - 1 && <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 16px 0 64px' }} />}
                </Fragment>
              ))}
            </div>
          )}
        </div>
      </div>
    )}
    </>
  );
}

// ─── Cards screen ─────────────────────────────────────────────
function CardsScreen() {
  const layout = useLayout();
  const topPad = useTopPad();
  const { toast, cards: apiCards, refreshDashboard, transactions: allTx, account, user } = useApp();
  const { t } = usePreferences();
  const { refresh } = useBankData();
  const userNameUp = (user?.full_name || 'ARMY BANK').toUpperCase();
  const statusText = (status?: string) => status === 'active' ? t('card_active_status') : status === 'blocked' ? t('card_frozen_status') : t('card_closed');
  const FALLBACK_CARDS: (CardData & { id: number; type: string; limit: string; used: string; statusRaw: string; cardTypeRaw: string; balance: number; isPrimary: boolean })[] = [
    { id: 0, design: 'gold', variant: 'gold', number: '0001', name: userNameUp, expiry: '03/29', type: t('card_virtual'), limit: '150 000', used: '48 230', status: statusText('active'), statusRaw: 'active', cardTypeRaw: 'virtual', balance: Number(account?.balance || 0), isPrimary: true },
    { id: 0, design: 'florence', variant: 'florence', number: '1183', name: userNameUp, expiry: '02/29', type: t('card_physical'), limit: '80 000', used: '12 400', status: statusText('active'), statusRaw: 'active', cardTypeRaw: 'physical', balance: Number(account?.balance || 0), isPrimary: false },
    { id: 0, design: 'venice', variant: 'venice', number: '7147', name: userNameUp, expiry: '08/28', type: t('card_physical'), limit: '500 000', used: '215 800', status: statusText('active'), statusRaw: 'active', cardTypeRaw: 'physical', balance: Number(account?.balance || 0), isPrimary: false },
    { id: 0, design: 'tuscany_villa', variant: 'tuscany_villa', number: '4402', name: userNameUp, expiry: '11/30', type: t('card_virtual'), limit: '50 000', used: '0', status: statusText('blocked'), statusRaw: 'blocked', cardTypeRaw: 'virtual', balance: Number(account?.balance || 0), isPrimary: false },
  ];
  const [designOverrides, setDesignOverrides] = useState<Record<number, string>>({});
  const cards = apiCards.length > 0
    ? apiCards.filter(c => c.status !== 'closed').map(c => {
      const mapped = apiCardToData(c, userNameUp);
      mapped.type = c.card_type === 'physical' ? t('card_physical') : t('card_virtual');
      mapped.status = statusText(c.status);
      const forcedDesign = designOverrides[c.id];
      if (forcedDesign) {
        mapped.design = forcedDesign;
        mapped.variant = DESIGN_TO_VARIANT[forcedDesign] ?? mapped.variant;
      }
      return mapped;
    })
    : FALLBACK_CARDS;
  const [selected, setSelected] = useState(() => readSelectedCardIndex());
  const [pinModal, setPinModal] = useState(false);
  const [pinValue, setPinValue] = useState('');
  const [pinConfirm, setPinConfirm] = useState('');
  const [pinLoading, setPinLoading] = useState(false);
  const [designModal, setDesignModal] = useState(false);
  const [designMode, setDesignMode] = useState<'current' | 'issue'>('current');
  const [designLoading, setDesignLoading] = useState(false);
  const [selectedDesign, setSelectedDesign] = useState<string>('gold');
  const safeIdx = Math.min(selected, Math.max(0, cards.length - 1));
  const card = cards[safeIdx];

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthTransactions = allTx.filter(tx => new Date(tx.created_at) >= monthStart);
  const monthOut = monthTransactions.filter(tx => tx.direction === 'out').reduce((s, tx) => s + tx.amount, 0);
  const busyCardId: number | null = designLoading && designMode === 'current' ? (apiCards[safeIdx]?.id ?? null) : null;
  const statusLabel = card?.status || t('unavailable');
  const currentDesignOption = CARD_DESIGN_OPTIONS.find(opt => opt.design === String(card?.design || '').toLowerCase());
  const activeDesignOption = CARD_DESIGN_OPTIONS.find(opt => opt.design === selectedDesign) ?? CARD_DESIGN_OPTIONS[0];
  const [topupModal, setTopupModal] = useState(false);
  const [topupAmount, setTopupAmount] = useState('');
  const [topupLoading, setTopupLoading] = useState(false);
  const activeCardsCount = cards.filter(c => c.statusRaw === 'active').length;

  // Card flip / reveal
  const [flipped, setFlipped] = useState(false);
  const [revealed, setRevealed] = useState<{ card_number: string; cvv: string } | null>(null);
  const [revealing, setRevealing] = useState(false);

  // Reset flip when card changes
  useEffect(() => { setFlipped(false); setRevealed(null); }, [safeIdx]);

  async function revealCard() {
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); setFlipped(true); return; }
    const c = apiCards[safeIdx];
    const token = localStorage.getItem('army_bank_token');
    setRevealing(true);
    try {
      const r = await fetch(`/api/cards/${c.id}/reveal`, { headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || tr('Помилка', 'Error'));
      setRevealed(j.data);
      setFlipped(true);
    } catch (e: unknown) { toast(e instanceof Error ? e.message : tr('Помилка', 'Error')); }
    finally { setRevealing(false); }
  }

  function flipCard() {
    if (!flipped) { revealCard(); } else { setFlipped(false); }
  }

  useEffect(() => {
    if (card?.design) setSelectedDesign(card.design);
    else if (!card) setSelectedDesign('florence');
  }, [card?.id, card?.design]);

  useEffect(() => {
    if (selected !== safeIdx) setSelected(safeIdx);
  }, [selected, safeIdx]);

  useEffect(() => {
    persistSelectedCardIndex(safeIdx);
  }, [safeIdx]);

  async function changePin() {
    if (pinValue.length !== 4 || !/^\d{4}$/.test(pinValue)) { toast(t('new_pin_4_digits')); return; }
    if (pinValue !== pinConfirm) { toast(t('pin_mismatch')); return; }
    if (apiCards.length === 0) { toast(t('demo_pin_unavailable')); return; }
    const c = apiCards[safeIdx];
    const token = localStorage.getItem('army_bank_token');
    setPinLoading(true);
    try {
      const r = await fetch(`/api/cards/${c.id}/pin`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ pin: pinValue }),
      });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('pin_change_error'));
      toast(`✓ ${t('pin_saved')} •• ${card.number}`);
      setPinModal(false); setPinValue(''); setPinConfirm('');
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('pin_change_error')); }
    finally { setPinLoading(false); }
  }

  async function toggleBlock() {
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); return; }
    const c = apiCards[safeIdx];
    const token = localStorage.getItem('army_bank_token');
    try {
      const r = await fetch(`/api/cards/${c.id}/block`, { method: 'PATCH', headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('operation_error'));
      toast(c.status === 'active' ? `${t('card_blocked')} •• ${card.number}` : `${t('card_unblocked')} •• ${card.number}`);
      refreshDashboard();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
  }

  async function closeCard() {
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); return; }
    const c = apiCards[safeIdx];
    const token = localStorage.getItem('army_bank_token');
    try {
      const r = await fetch(`/api/cards/${c.id}/close`, { method: 'PATCH', headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('operation_error'));
      toast(`${t('card_closed')} •• ${card.number}`);
      refreshDashboard();
      setSelected(0);
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
  }

  async function setPrimaryCard() {
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); return; }
    const c = apiCards[safeIdx];
    if (c.is_primary) { toast(tr('Ця картка вже є головною', 'This card is already the main one')); return; }
    const token = localStorage.getItem('army_bank_token');
    try {
      const r = await fetch(`/api/cards/${c.id}/set_primary`, { method: 'PATCH', headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('operation_error'));
      toast(tr('Головну картку змінено ✓', 'Main card changed ✓'));
      refreshDashboard();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
  }

  async function topupCard() {
    const amount = parseFloat(topupAmount.replace(',', '.'));
    if (!amount || amount <= 0) { toast(tr('Введіть суму', 'Enter an amount')); return; }
    if (apiCards.length === 0) { toast(t('demo_api_unavailable')); return; }
    const c = apiCards[safeIdx];
    const token = localStorage.getItem('army_bank_token');
    setTopupLoading(true);
    try {
      const idempotencyKey = `topup-${c.id}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const r = await fetch(`/api/cards/${c.id}/topup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ amount, idempotency_key: idempotencyKey }),
      });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('operation_error'));
      toast(`${tr('Картку поповнено', 'Card topped up')} •• ${card.number} · ${amount.toLocaleString(localeForLang(trLang()), { minimumFractionDigits: 2 })}\u00a0TAX ✓`);
      setTopupModal(false);
      setTopupAmount('');
      refreshDashboard();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setTopupLoading(false); }
  }

  function openDesignModal(mode: 'current' | 'issue') {
    setDesignMode(mode);
    if (mode === 'current' && card?.design) setSelectedDesign(card.design);
    else if (mode === 'issue') setSelectedDesign('florence');
    setDesignModal(true);
  }

  async function applyCardDesign() {
    if (!selectedDesign) return;
    const token = localStorage.getItem('army_bank_token');
    if (!token) {
      toast(t('session_expired'));
      return;
    }
    setDesignLoading(true);
    try {
      if (designMode === 'current') {
        if (apiCards.length === 0) {
          toast(t('no_card_for_design_change'));
          return;
        }
        const c = apiCards[safeIdx];
        if (!c) throw new Error(t('card_not_found'));
        const r = await fetch(`/api/cards/${c.id}/design`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify({ design: selectedDesign }),
        });
        const j = await r.json();
        if (!r.ok || !j.ok) throw new Error(j.message || t('card_design_update_failed'));
        setDesignOverrides(prev => ({ ...prev, [c.id]: selectedDesign }));
        toast(`${t('card_design_updated')} •• ${card.number}`);
      } else {
        const idempotencyKey = `card-issue-${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const r = await fetch('/api/cards', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey },
          body: JSON.stringify({ card_type: 'virtual', design: selectedDesign, idempotency_key: idempotencyKey }),
        });
        const j = await r.json();
        if (!r.ok || !j.ok) throw new Error(j.message || t('card_issue_failed'));
        toast(t('new_card_issued'));
      }
      await refresh().catch(() => {});
      await refreshDashboard();
      setDesignModal(false);
      if (designMode === 'issue') setSelected(0);
    } catch (e: unknown) {
      toast(e instanceof Error ? e.message : t('card_design_error'));
    } finally {
      setDesignLoading(false);
    }
  }

  const isFrozen = apiCards.length > 0 ? apiCards[safeIdx]?.status === 'blocked' : card?.statusRaw === 'blocked';

    const cardsHeader = (
    <>
      <div style={{ padding: `${topPad} 18px 14px` }}>
        <div style={{
          ...glassCard({
            padding: '18px 18px 16px',
            borderRadius: 26,
            background: '#1c1c1e',
            boxShadow: '0 20px 42px rgba(0,0,0, 0.22)',
          }),
          position: 'relative',
          overflow: 'hidden',
        }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 11, color: text.muted, letterSpacing: 0.6, marginBottom: 4 }}>{t('cards_title')}</div>
              <div style={{ ...T.h1, color: text.primary, marginBottom: 8 }}>{t('cards_title')}</div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <div style={{ padding: '7px 12px', borderRadius: 999, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', fontSize: 11, color: 'rgba(215,215,215, 0.78)', fontWeight: 600 }}>
                  {cards.length} {cards.length === 1 ? tr('картка', 'card') : tr('картки', 'cards')}
                </div>
                <div style={{ padding: '7px 12px', borderRadius: 999, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', fontSize: 11, color: '#c5c5c5', fontWeight: 600 }}>
                  {activeCardsCount} {tr('активних', 'active')}
                </div>
              </div>
            </div>
            <button onClick={() => openDesignModal('issue')} style={{
              padding: '11px 16px', background: `${goldLight}`,
              color: '#292929', border: 'none', borderRadius: 16, fontSize: 13, fontWeight: 700,
              fontFamily: 'inherit', display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer',
              boxShadow: `0 10px 22px -10px rgba(172,172,172, 0.45)`,
              opacity: designLoading && designMode === 'issue' ? 0.65 : 1,
              flexShrink: 0,
            }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="#292929" strokeWidth="2.4" strokeLinecap="round" /></svg>
              {designLoading && designMode === 'issue' ? t('creating') : t('issue_card')}
            </button>
          </div>
        </div>
      </div>

    </>
    );
    const cardsStrip = (
    <>
      {/* Horizontal card scroll */}
      <div style={layout === 'desktop' ? {
        display: 'grid', gridTemplateColumns: '1fr', gap: 20, padding: '0 18px 10px',
      } : {
        display: 'flex', gap: 12, padding: '0 18px 10px',
        overflowX: 'auto', scrollSnapType: 'x mandatory', scrollbarWidth: 'none',
      }}>
        {cards.map((c, i) => {
          const isSelected = i === safeIdx;
          const v = CARD_VARIANTS[c.variant] ?? CARD_VARIANTS.gold;
          return (
            <div key={i} style={{ flexShrink: 0, width: layout === 'desktop' ? '100%' : 260, scrollSnapAlign: 'center' }}>
              {isSelected ? (
                // ── Flippable selected card ──
                <div style={{ perspective: 1000, width: '100%', aspectRatio: '1.586 / 1', cursor: 'pointer' }}
                  onClick={flipCard}>
                  <div style={{
                    width: '100%', height: '100%', position: 'relative',
                    transformStyle: 'preserve-3d',
                    transform: flipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                    transition: 'transform 0.55s cubic-bezier(0.4, 0, 0.2, 1)',
                  }}>
                    {/* Front */}
                    <div style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backfaceVisibility: 'hidden', WebkitBackfaceVisibility: 'hidden' }}>
                      <PremiumCard {...c} style={{ width: '100%' }} balance={c.balance} isPrimary={c.isPrimary} />
                      {!flipped && <div style={{ position: 'absolute', bottom: 12, right: 14, fontSize: 9, color: 'rgba(255,255,255, 0.54)', pointerEvents: 'none', letterSpacing: 0.5, textTransform: 'uppercase' }}>{revealing ? '…' : tr('Реквізити', 'Details')}</div>}
                    </div>
                    {/* Back */}
                      <CardBack bg={v.bg} image={v.image} expiry={c.expiry} name={c.name} last4={c.number} revealed={revealed} toast={toast} />
                  </div>
                </div>
              ) : (
                <button onClick={() => { setSelected(i); setFlipped(false); }} style={{
                  width: '100%', padding: 0, background: 'transparent', border: 'none', cursor: 'pointer',
                  textAlign: 'left', opacity: 0.55, transition: 'opacity 0.3s',
                  filter: 'saturate(0.7)',
                }}>
                  <PremiumCard {...c} style={{ width: '100%' }} />
                </button>
              )}
            </div>
          );
        })}
        {!cards.length && (
          <div style={{ padding: '20px', borderRadius: 18, border: `1px solid ${bg.border}`, background: bg.card, color: text.muted, minWidth: 280 }}>
            {t('cards_not_issued')}
          </div>
        )}
      </div>

    </>
    );
    const cardsDetails = (
    <>
      {/* Card details */}
      <div style={{ padding: '20px 22px 0' }}>
        <div style={{ background: bg.card, border: `1px solid ${bg.border}`, borderRadius: 22, padding: 20 }}>
          {!card ? (
            <div style={{ color: text.muted }}>{t('card_not_found')}</div>
          ) : (
          <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18 }}>
            <div style={{ fontFamily: '"SF Mono", monospace', fontSize: 16, fontWeight: 600, color: text.primary, letterSpacing: 1 }}>
              {revealed ? revealed.card_number.replace(/\s/g, '').replace(/(.{4})/g, '$1 ').trim() : `•••• •••• •••• ${card.number}`}
            </div>
            <div style={{
              padding: '3px 8px', borderRadius: 100, background: card.statusRaw === 'active' ? 'rgba(169,169,169, 0.15)' : 'rgba(215,215,215, 0.1)',
              color: card.statusRaw === 'active' ? '#a9a9a9' : 'rgba(215,215,215, 0.7)',
              fontSize: 10.5, fontWeight: 600, letterSpacing: 0.3,
            }}>{statusLabel}</div>
            <div style={{ flex: 1 }} />
            <div style={{ fontSize: 11, color: text.muted }}>{card.cardTypeRaw === 'physical' ? t('card_physical') : t('card_virtual')} • {t('card_valid_until')} {card.expiry}</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, gap: 10 }}>
            <div style={{ fontSize: 12, color: text.muted }}>
              {t('card_design_label')}: <span style={{ color: text.secondary, fontWeight: 600 }}>{currentDesignOption ? tr(currentDesignOption.title, DESIGN_TITLE_EN[currentDesignOption.title] ?? currentDesignOption.title) : 'Classic Gold'}</span>
            </div>
            <button
              onClick={() => openDesignModal('current')}
              style={{
                padding: '7px 12px', borderRadius: 10, border: '1px solid transparent',
                background: 'rgba(255,255,255, 0.1)', color: text.secondary, fontSize: 12, fontWeight: 600, cursor: 'pointer',
              }}
            >{t('change_label')}</button>
          </div>

          {/* Card balance block */}
          <div style={{ marginBottom: 18, padding: '14px 16px', background: 'linear-gradient(160deg, rgba(255,212,0,0.10), rgba(255,255,255,0.03) 60%)', borderRadius: 16, border: '1px solid rgba(255,255,255,0.06)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
              <div>
                <div style={{ fontSize: 10, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 4 }}>
                  {card?.isPrimary ? tr('Баланс рахунку (головна картка)', 'Account balance (main card)') : tr('Баланс картки', 'Card balance')}
                </div>
                <div style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.4, color: text.primary, fontFeatureSettings: '"tnum"' }}>
                  {formatUah(card?.balance ?? 0)}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {!card?.isPrimary && card?.statusRaw === 'active' && (
                  <button onClick={() => setTopupModal(true)} style={{
                    ...docPill, height: 34, padding: '0 14px', fontSize: 12.5,
                  }}>{tr('Поповнити', 'Top up')}</button>
                )}
                {!card?.isPrimary && card?.statusRaw !== 'closed' && (
                  <button onClick={setPrimaryCard} style={{
                    ...docPill, height: 34, padding: '0 14px', fontSize: 12.5, color: text.secondary, border: '1px solid rgba(255,255,255,0.16)', background: 'rgba(255,255,255,0.05)',
                  }}>{tr('Зробити головною', 'Make main')}</button>
                )}
              </div>
            </div>
            {card?.isPrimary && (
              <div style={{ fontSize: 11, color: text.dim, marginTop: 6 }}>
                {tr("Всі перекази на/з рахунку прив'язані до цієї картки", 'All transfers to and from the account go through this card')}
              </div>
            )}
          </div>

          {/* Account activity */}
          <div style={{ marginBottom: 18 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8, alignItems: 'baseline' }}>
              <span style={{ ...T.caption, color: text.muted }}>{t('account_activity_month')}</span>
              <span style={{ fontSize: 12, color: 'rgba(215,215,215, 0.6)', fontFeatureSettings: '"tnum"' }}>{monthTransactions.length} {t('operations_short')}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 10 }}>
              <span style={{ fontSize: 22, fontWeight: 600, color: text.primary, fontFeatureSettings: '"tnum"' }}>{formatUah(monthOut)}</span>
              <span style={{ fontSize: 13, color: text.dim, fontFeatureSettings: '"tnum"' }}>{t('spent_label')}</span>
            </div>
          </div>

          {/* Actions */}
          <div style={{ display: 'grid', gridTemplateColumns: layout === 'mobile' ? 'repeat(2, minmax(0, 1fr))' : 'repeat(4, 1fr)', gap: 10, marginBottom: 16 }}>
            {[
              { label: t('card_details'), msg: `${t('cards_title')} •• ${card.number} · ${t('card_valid_until')} ${card.expiry}`, icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="13" rx="2" stroke={gold} strokeWidth="1.6" /><path d="M3 10h18" stroke={gold} strokeWidth="1.6" /></svg> },
              { label: 'PIN', action: () => setPinModal(true), icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="4" y="11" width="16" height="10" rx="2" stroke={gold} strokeWidth="1.6" /><path d="M8 11V8a4 4 0 018 0v3" stroke={gold} strokeWidth="1.6" /></svg> },
              { label: t('design_action'), action: () => openDesignModal('current'), icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M4 6h16M4 12h16M4 18h16" stroke={gold} strokeWidth="1.8" strokeLinecap="round" /><circle cx="8" cy="6" r="2" fill={gold} /><circle cx="16" cy="12" r="2" fill={gold} /><circle cx="11" cy="18" r="2" fill={gold} /></svg> },
              { label: t('account_label'), msg: `${t('account_label')}: ${account?.account_number || '—'}`, icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M4 12a8 8 0 1116 0" stroke={gold} strokeWidth="1.6" strokeLinecap="round" /><path d="M12 12l4-4" stroke={gold} strokeWidth="1.6" strokeLinecap="round" /><circle cx="12" cy="12" r="1.5" fill={gold} /></svg> },
            ].map((a, i) => (
              <button key={i} onClick={() => 'action' in a ? a.action() : toast(a.msg as string)} style={{
                display: 'flex', flexDirection: 'column', alignItems: layout === 'mobile' ? 'flex-start' : 'center', gap: 10,
                minHeight: layout === 'mobile' ? 94 : undefined,
                padding: layout === 'mobile' ? '14px 12px' : '10px 4px',
                background: 'linear-gradient(180deg, rgba(255,255,255,0.07), rgba(255,255,255,0.03))',
                border: '1px solid rgba(255,255,255,0.05)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.08)', borderRadius: 16,
                color: '#e8e8ea', fontSize: layout === 'mobile' ? 12.5 : 11, fontFamily: 'inherit', fontWeight: 600, cursor: 'pointer',
                textAlign: layout === 'mobile' ? 'left' : 'center',
              }}>
                <Medallion tint={gold} size={38}>{a.icon}</Medallion>{a.label}
              </button>
            ))}
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <button onClick={toggleBlock} style={{
              flex: 1, padding: '12px', background: isFrozen ? 'rgba(169,169,169, 0.08)' : 'rgba(177,177,177, 0.08)',
              border: `1px solid ${isFrozen ? 'rgba(169,169,169, 0.2)' : 'rgba(177,177,177, 0.2)'}`, borderRadius: 12,
              color: isFrozen ? '#a9a9a9' : '#b1b1b1', fontSize: 13, fontWeight: 500, fontFamily: 'inherit', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              opacity: busyCardId === card.id || card.statusRaw === 'closed' ? 0.6 : 1,
            }}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none"><rect x="4" y="11" width="16" height="10" rx="2" stroke="currentColor" strokeWidth="1.8" /><path d="M8 11V8a4 4 0 018 0v3" stroke="currentColor" strokeWidth="1.8" /></svg>
              {isFrozen ? t('unfreeze_card') : t('freeze_card')}
            </button>
            <button onClick={closeCard} style={{
              flex: 1, padding: '12px', background: 'rgba(255,255,255, 0.1)',
              border: '1px solid transparent', borderRadius: 12,
              color: '#7e7e7e', fontSize: 13, fontWeight: 500, fontFamily: 'inherit', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              opacity: busyCardId === card.id || card.statusRaw === 'closed' ? 0.6 : 1,
            }}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none"><path d="M5 5l14 14M19 5L5 19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
              {t('close_card')}
            </button>
          </div>
          </>
          )}
        </div>
      </div>
    </>
    );

  return (
    <>
    <ContentWrap maxW={layout === 'desktop' ? 1560 : 760}>
    <div style={{ paddingBottom: layout === 'desktop' ? 80 : 24 }}>
      {layout === 'desktop' ? (
        <>
          <div style={{ margin: '0 -18px' }}>{cardsHeader}</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'minmax(340px, 440px) minmax(0, 1fr)', gap: 24, alignItems: 'start', margin: '0 -18px' }}>
            <div className="kp-rise" style={{ minWidth: 0 }}>{cardsStrip}</div>
            <div className="kp-rise" style={{ minWidth: 0, position: 'sticky', top: 100, ['--i' as string]: 1 }}>{cardsDetails}</div>
          </div>
        </>
      ) : (
        <>
          {cardsHeader}
          {cardsStrip}
          {cardsDetails}
        </>
      )}
    </div>
    </ContentWrap>

    {/* PIN Change Modal */}
    {pinModal && (
      <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 300, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => setPinModal(false)}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0, 0.6)', backdropFilter: 'blur(4px)' }} />
        <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{
          position: 'relative', width: '100%', maxWidth: 480,
          background: '#1c1c1e',
          backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
          borderRadius: '24px 24px 0 0', padding: '28px 24px calc(32px + env(safe-area-inset-bottom,0px))',
          border: '1px solid transparent', borderBottom: 'none',
        }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 20px' }} />
          <div style={{ fontSize: 18, fontWeight: 700, color: text.primary, marginBottom: 4 }}>{t('change_pin')}</div>
          <div style={{ fontSize: 12, color: text.muted, marginBottom: 20 }}>{t('card_short_label')} •• {card.number}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <label style={{ fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 5, display: 'block' }}>{t('new_pin_4_digits')}</label>
              <input
                type="password" inputMode="numeric" maxLength={4}
                value={pinValue} onChange={e => setPinValue(e.target.value.replace(/\D/g, '').slice(0, 4))}
                placeholder="••••"
                style={{ width: '100%', padding: '12px 14px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 12, color: text.primary, fontSize: 20, outline: 'none', fontFamily: fontFamily, letterSpacing: 8, boxSizing: 'border-box' }}
              />
            </div>
            <div>
              <label style={{ fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 5, display: 'block' }}>{t('confirm_pin')}</label>
              <input
                type="password" inputMode="numeric" maxLength={4}
                value={pinConfirm} onChange={e => setPinConfirm(e.target.value.replace(/\D/g, '').slice(0, 4))}
                placeholder="••••"
                style={{ width: '100%', padding: '12px 14px', background: 'rgba(255,255,255, 0.1)', border: `1px solid ${pinConfirm && pinValue !== pinConfirm ? 'rgba(110,110,110, 0.5)' : 'rgba(172,172,172, 0.18)'}`, borderRadius: 12, color: text.primary, fontSize: 20, outline: 'none', fontFamily: fontFamily, letterSpacing: 8, boxSizing: 'border-box' }}
              />
              {pinConfirm && pinValue !== pinConfirm && <div style={{ fontSize: 11, color: '#888888', marginTop: 4 }}>{t('pin_mismatch')}</div>}
            </div>
            {/* 4-dot indicator */}
            <div style={{ display: 'flex', justifyContent: 'center', gap: 14, margin: '4px 0' }}>
              {[0,1,2,3].map(i => (
                <div key={i} style={{ width: 14, height: 14, borderRadius: '50%', background: i < pinValue.length ? gold : 'rgba(172,172,172, 0.2)', transition: 'background 0.15s', boxShadow: i < pinValue.length ? `0 0 8px ${gold}88` : 'none' }} />
              ))}
            </div>
            <button
              onClick={changePin} disabled={pinLoading || pinValue.length !== 4 || pinValue !== pinConfirm}
              style={{
                width: '100%', padding: '14px', borderRadius: 16, border: 'none', fontSize: 15, fontWeight: 700,
                background: (pinLoading || pinValue.length !== 4 || pinValue !== pinConfirm) ? 'rgba(95,95,95, 0.3)' : `${goldDark}`,
                color: text.primary, cursor: (pinLoading || pinValue.length !== 4 || pinValue !== pinConfirm) ? 'default' : 'pointer', fontFamily: fontFamily,
              }}>{pinLoading ? t('saving') : t('save_pin')}</button>
          </div>
        </div>
      </div>
    )}
    {designModal && (
      <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 320, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => !designLoading && setDesignModal(false)}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0, 0.62)', backdropFilter: 'blur(4px)' }} />
        <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{
          position: 'relative', width: '100%', maxWidth: 620,
          background: '#1c1c1e',
          backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
          borderRadius: '24px 24px 0 0', padding: '24px 20px calc(22px + env(safe-area-inset-bottom,0px))',
          border: '1px solid transparent', borderBottom: 'none',
          maxHeight: '82vh', overflowY: 'auto',
        }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 18px' }} />
          <div style={{ fontSize: 18, fontWeight: 700, color: text.primary, marginBottom: 4 }}>
            {designMode === 'current' ? t('choose_card_design') : t('issue_new_card')}
          </div>
          <div style={{ fontSize: 12, color: text.muted, marginBottom: 16 }}>
            {designMode === 'current'
              ? `${t('card_short_label')} •• ${card?.number || '0000'}`
              : t('choose_style_then_issue')}
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 12 }}>
            {CARD_DESIGN_OPTIONS.map((opt) => (
              <button
                key={opt.design}
                onClick={() => setSelectedDesign(opt.design)}
                style={{
                  padding: 10,
                  borderRadius: 14,
                  border: selectedDesign === opt.design ? '1px solid rgba(215,215,215, 0.42)' : '1px solid rgba(172,172,172, 0.18)',
                  background: selectedDesign === opt.design ? 'rgba(255,255,255, 0.08)' : 'rgba(255,255,255, 0.1)',
                  color: text.secondary,
                  textAlign: 'left',
                  cursor: 'pointer',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 8,
                }}
              >
                <PremiumCard
                  variant={opt.variant}
                  number={card?.number || '0001'}
                  name={card?.name || userNameUp}
                  expiry={card?.expiry || '03/29'}
                  type={card?.type || t('card_virtual')}
                  style={{ width: '100%' }}
                />
                <div>
                  <div style={{ fontSize: 12.5, fontWeight: 700, color: text.primary }}>{tr(opt.title, DESIGN_TITLE_EN[opt.title] ?? opt.title)}</div>
                  <div style={{ fontSize: 11, color: text.muted }}>{opt.subtitleKey ? t(opt.subtitleKey) : tr(opt.subtitle ?? '', (opt.subtitle ?? '').replace(/^Фото:/, 'Photo:').replace(' · фото:', ' · photo:').replace('Храм Сатурна', 'Temple of Saturn').replace('Аква Клавдія', 'Aqua Claudia').replace('Каррара', 'Carrara'))}</div>
                </div>
              </button>
            ))}
          </div>

          <div style={{ marginTop: 14, fontSize: 12, color: text.muted }}>
            {t('selected_label')}: <span style={{ color: text.secondary, fontWeight: 700 }}>{tr(activeDesignOption.title, DESIGN_TITLE_EN[activeDesignOption.title] ?? activeDesignOption.title)}</span>
          </div>

          <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
            <button
              onClick={() => setDesignModal(false)}
              disabled={designLoading}
              style={{
                flex: 1, padding: '13px 12px', borderRadius: 14, border: '1px solid transparent',
                background: 'rgba(255,255,255, 0.1)', color: text.secondary, fontSize: 14, fontWeight: 600, cursor: designLoading ? 'default' : 'pointer',
              }}
            >{t('cancel_label')}</button>
            <button
              onClick={applyCardDesign}
              disabled={designLoading}
              style={{
                flex: 1.2, padding: '13px 12px', borderRadius: 14, border: 'none',
                background: `${goldDark}`,
                color: '#292929', fontSize: 14, fontWeight: 800, cursor: designLoading ? 'default' : 'pointer',
                opacity: designLoading ? 0.7 : 1,
              }}
            >{designLoading ? t('applying') : (designMode === 'current' ? t('apply_design') : t('issue_card_full'))}</button>
          </div>
        </div>
      </div>
    )}
    {/* Top-up card modal */}
    {topupModal && (
      <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 300, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => setTopupModal(false)}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0, 0.6)', backdropFilter: 'blur(4px)' }} />
        <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{
          position: 'relative', width: '100%', maxWidth: 480,
          background: '#1c1c1e',
          backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
          borderRadius: '24px 24px 0 0', padding: '28px 24px calc(32px + env(safe-area-inset-bottom,0px))',
          border: '1px solid transparent', borderBottom: 'none',
        }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 20px' }} />
          <div style={{ fontSize: 18, fontWeight: 700, color: text.primary, marginBottom: 4 }}>{tr('Поповнити картку', 'Top up card')}</div>
          <div style={{ fontSize: 12, color: text.muted, marginBottom: 20 }}>
            {card?.name} •• {card?.number} · {tr('Поточний баланс', 'Current balance')}: {formatUah(card?.balance ?? 0)}
          </div>
          <div style={{ fontSize: 11, color: text.muted, marginBottom: 4, textTransform: 'uppercase', letterSpacing: 0.8 }}>{tr('Сума поповнення', 'Top-up amount')}</div>
          <input
            type="text" inputMode="decimal"
            value={topupAmount} onChange={e => setTopupAmount(e.target.value)}
            placeholder="0.00"
            style={{ width: '100%', padding: '13px 14px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 12, color: text.primary, fontSize: 20, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box', marginBottom: 6 }}
          />
          <div style={{ fontSize: 11, color: text.dim, marginBottom: 20 }}>
            {tr('Баланс рахунку', 'Account balance')}: {formatUah(Number(account?.balance || 0))}
          </div>
          <button
            onClick={topupCard} disabled={topupLoading || !topupAmount}
            style={{
              width: '100%', padding: '14px', borderRadius: 16, border: 'none', fontSize: 15, fontWeight: 700,
              background: (!topupAmount || topupLoading) ? 'rgba(95,95,95, 0.3)' : `${goldDark}`,
              color: text.primary, cursor: (!topupAmount || topupLoading) ? 'default' : 'pointer', fontFamily: 'inherit',
            }}>{topupLoading ? tr('Обробка...', 'Processing...') : tr('Поповнити', 'Top up')}</button>
        </div>
      </div>
    )}
    </>
  );
}

// ─── Operations screen ────────────────────────────────────────
type TxCat = 'income' | 'food' | 'transport' | 'utility' | 'shopping' | 'transfer' | 'subscription';

// ── Гравійований медальйон: розетка гільйошу, подвійне кільце, мікрошкала ──
function rosettePaths(curves: number, lobes: number, depth: number, second: number, r: number, steps = 96): string[] {
  const out: string[] = [];
  for (let k = 0; k < curves; k++) {
    const phase = (k / curves) * Math.PI * 2;
    let d = '';
    for (let i = 0; i <= steps; i++) {
      const t = (i / steps) * Math.PI * 2;
      const rr = r * (1 - depth - second + depth * Math.cos(lobes * t + phase) + second * Math.cos((lobes * 2) * t - phase));
      d += (i ? 'L' : 'M') + (50 + rr * Math.cos(t)).toFixed(1) + ' ' + (50 + rr * Math.sin(t)).toFixed(1);
    }
    out.push(d);
  }
  return out;
}
const MEDALLION_ROSETTE = rosettePaths(10, 6, 0.2, 0.06, 45).join('');
const MEDALLION_TICKS = Array.from({ length: 60 }, (_, i) => {
  const a = (i / 60) * Math.PI * 2, long = i % 5 === 0, r0 = 48.6, r1 = long ? 44.6 : 46;
  return `M${(50 + r0 * Math.cos(a)).toFixed(1)} ${(50 + r0 * Math.sin(a)).toFixed(1)}L${(50 + r1 * Math.cos(a)).toFixed(1)} ${(50 + r1 * Math.sin(a)).toFixed(1)}`;
}).join('');
// Велика гільошна розетка для шапок: тло, що не заважає читанню
const HERO_ROSETTE = rosettePaths(26, 8, 0.2, 0.06, 46, 110).join('');
function HeroRosette({ size = 280, style }: { size?: number; style?: React.CSSProperties }) {
  return (
    <>
      <div aria-hidden="true" style={{ position: 'absolute', right: -size * 0.3, top: -size * 0.35, width: size * 0.95, height: size * 0.95, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,212,0,0.30), rgba(255,170,0,0.08) 55%, transparent 72%)', filter: 'blur(18px)', pointerEvents: 'none', ...style }} />
      <div aria-hidden="true" style={{ position: 'absolute', left: -size * 0.35, bottom: -size * 0.45, width: size * 0.9, height: size * 0.9, borderRadius: '50%', background: 'radial-gradient(circle, rgba(90,120,255,0.22), transparent 68%)', filter: 'blur(22px)', pointerEvents: 'none' }} />
      <svg width={size} height={size} viewBox="0 0 100 100" aria-hidden="true" style={{ position: 'absolute', right: -size * 0.28, top: -size * 0.3, opacity: 0.16, pointerEvents: 'none', ...style }}>
        <path d={HERO_ROSETTE} fill="none" stroke={gold} strokeWidth="0.18" />
        <circle cx="50" cy="50" r="47" fill="none" stroke={gold} strokeWidth="0.25" />
        <circle cx="50" cy="50" r="14" fill="none" stroke={gold} strokeWidth="0.25" />
      </svg>
    </>
  );
}
let medallionSeq = 0;
function Medallion({ tint, size = 42, children }: { tint: string; size?: number; children?: React.ReactNode }) {
  const [id] = useState(() => `md${++medallionSeq}`);
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} viewBox="0 0 100 100" aria-hidden="true" style={{ position: 'absolute', inset: 0 }}>
        <defs>
          <radialGradient id={`${id}f`} cx="30%" cy="25%" r="85%">
            <stop offset="0" stopColor={tint} stopOpacity="0.42" />
            <stop offset="1" stopColor={tint} stopOpacity="0.1" />
          </radialGradient>
          <linearGradient id={`${id}r`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor={tint} />
            <stop offset="0.3" stopColor="#fff" stopOpacity="0.9" />
            <stop offset="0.55" stopColor={tint} stopOpacity="0.35" />
            <stop offset="0.8" stopColor="#fff" stopOpacity="0.7" />
            <stop offset="1" stopColor={tint} />
          </linearGradient>
        </defs>
        <circle cx="50" cy="50" r="49" fill={`url(#${id}f)`} />
        <path d={MEDALLION_ROSETTE} fill="none" stroke={tint} strokeOpacity="0.32" strokeWidth="0.5" />
        <path d={MEDALLION_TICKS} fill="none" stroke={tint} strokeOpacity="0.45" strokeWidth="0.6" />
        <circle cx="50" cy="50" r="26" fill={tint} fillOpacity="0.2" />
        <circle cx="50" cy="50" r="26" fill="none" stroke="#fff" strokeOpacity="0.35" strokeWidth="0.8" />
        <circle cx="50" cy="50" r="49" fill="none" stroke={`url(#${id}r)`} strokeWidth="1.8" />
        <circle cx="50" cy="50" r="45.5" fill="none" stroke={tint} strokeOpacity="0.35" strokeWidth="0.6" />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', filter: 'drop-shadow(0 1px 1px rgba(0,0,0,0.4))' }}>{children}</div>
    </div>
  );
}
const MEDALLION_TINT: Record<string, string> = {
  income: '#4fd18b', food: '#e0a043', transport: '#6f9bff', utility: '#c9b24a', shopping: '#FFD400', transfer: '#7aa6ff', subscription: '#b48cff',
};
function recolorIcon(icon: React.ReactNode, color: string): React.ReactNode {
  return React.isValidElement(icon) ? React.cloneElement(icon as React.ReactElement<Record<string, unknown>>, { children: React.Children.map((icon as React.ReactElement<{ children?: React.ReactNode }>).props.children, (c) => React.isValidElement(c) ? React.cloneElement(c as React.ReactElement<Record<string, unknown>>, { stroke: color }) : c) }) : icon;
}

const CAT_STYLES: Record<TxCat, { bg: string; color: string; icon: React.ReactNode }> = {
  income:       { bg: 'rgba(169,169,169, 0.12)', color: '#a9a9a9', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 2v20M6 16l6 6 6-6" stroke="#a9a9a9" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  food:         { bg: 'rgba(177,177,177, 0.12)', color: '#b1b1b1', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M6 2v8a3 3 0 006 0V2M9 2v6M18 2c-2 0-3 2-3 5s1 5 3 5v8" stroke="#b1b1b1" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  transport:    { bg: 'rgba(166,166,166, 0.12)', color: '#a6a6a6', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 17h14l-2-8H7l-2 8zM7 17v2M17 17v2M9 9V6a3 3 0 016 0v3" stroke="#a6a6a6" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  utility:      { bg: 'rgba(172,172,172, 0.12)', color: gold, icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 2L4 7v6c0 5 4 8 8 9 4-1 8-4 8-9V7l-8-5zM12 8v4l3 2" stroke={gold} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  shopping:     { bg: 'rgba(145,145,145, 0.12)', color: '#919191', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M4 7h16l-1.5 11a2 2 0 01-2 1.8h-9a2 2 0 01-2-1.8L4 7zM9 7V5a3 3 0 016 0v2" stroke="#919191" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  transfer:     { bg: 'rgba(215,215,215, 0.1)', color: '#d8d8d8', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M7 17l-4-4 4-4M3 13h13M17 7l4 4-4 4M21 11H8" stroke="#d8d8d8" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
  subscription: { bg: 'rgba(182,182,182, 0.12)', color: '#b6b6b6', icon: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M3 12a9 9 0 0115-6.7L21 8M21 3v5h-5M21 12a9 9 0 01-15 6.7L3 16M3 21v-5h5" stroke="#b6b6b6" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
};

// ── Deposits Section ─────────────────────────────────────────────────────────
interface Deposit {
  id: number; amount: number; interest_rate: number; term_months: number;
  maturity_date: string; interest_earned: number; interest_accrued: number;
  auto_renew: boolean; status: string; days_left: number; progress: number;
  description: string; created_at: string;
}
const DEPOSIT_RATES: Record<number, number> = { 1: 8, 3: 10, 6: 12, 12: 14 };
const DEPOSIT_TERMS = [1, 3, 6, 12];

function DepositsSection() {
  const { toast } = useApp();
  const { t, lang } = usePreferences();
  const [deposits, setDeposits] = useState<Deposit[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [amount, setAmount] = useState('');
  const [termMonths, setTermMonths] = useState(6);
  const [autoRenew, setAutoRenew] = useState(false);
  const [creating, setCreating] = useState(false);
  const [closing, setClosing] = useState<number | null>(null);
  const locale = localeForLang(lang);

  async function load() {
    setLoading(true);
    try {
      const data = await apiRequest<Deposit[]>('/api/deposits');
      setDeposits(Array.isArray(data) ? data : []);
    } catch { /* ignore */ }
    finally { setLoading(false); }
  }

  useEffect(() => { load(); }, []);

  async function createDeposit(e: React.FormEvent) {
    e.preventDefault();
    const amt = parseFloat(String(amount).replace(/[\s ]/g, '').replace(',', '.'));
    if (!amt || amt < 500) { toast(t('dep_min_amount')); return; }
    setCreating(true);
    try {
      const idempotencyKey = `dep-create-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      await apiRequest('/api/deposits', {
        method: 'POST',
        headers: { 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ amount: amt, term_months: termMonths, auto_renew: autoRenew, idempotency_key: idempotencyKey }),
      });
      toast(`✓ ${tr('Депозит відкрито', 'Deposit opened')}: ${amt.toLocaleString(localeForLang(trLang()))}\u00a0TAX`);
      setShowCreate(false); setAmount('');
      setAutoRenew(false);
      load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setCreating(false); }
  }

  async function closeDeposit(dep: Deposit, early: boolean) {
    setClosing(dep.id);
    try {
      const idempotencyKey = `dep-close-${dep.id}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const data = await apiRequest<{ payout: number }>(`/api/deposits/${dep.id}/close`, {
        method: 'POST',
        headers: { 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ early, idempotency_key: idempotencyKey }),
      });
      const payout = data?.payout ?? 0;
      toast(`✓ ${tr('Депозит закрито. Виплачено', 'Deposit closed. Paid out')} ${Number(payout).toLocaleString(localeForLang(trLang()))}\u00a0TAX`);
      load();
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setClosing(null); }
  }

  const depStatusLabel = (s: string) => ({
    active: t('dep_status_active'), matured: t('dep_status_matured'),
    closed: t('dep_status_closed'), withdrawn_early: t('dep_status_early'),
  }[s] ?? s);

  const depStatusColor = (s: string) => ({
    active: '#a9a9a9', matured: gold, closed: 'rgba(215,215,215, 0.4)',
    withdrawn_early: '#989898',
  }[s] ?? 'rgba(215,215,215, 0.4)');

  const projectedInterest = () => {
    const amt = parseFloat(String(amount).replace(',', '.')) || 0;
    const rate = DEPOSIT_RATES[termMonths] || 0;
    const days = termMonths * 30;
    return (amt * rate / 100 * days / 365).toFixed(2);
  };

  const panelStyle: React.CSSProperties = {
    background: '#1c1c1e',
    border: '1px solid transparent',
    borderRadius: 26,
    overflow: 'hidden',
    boxShadow: '0 18px 44px rgba(0,0,0, 0.16)',
  };
  const metricGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'minmax(0, 1fr)',
    gap: 1,
    background: 'rgba(255,255,255, 0.06)',
    borderRadius: 18,
    overflow: 'hidden',
    marginBottom: 14,
  };
  const metricCellStyle: React.CSSProperties = {
    background: '#232325',
    padding: '13px 16px',
    display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12,
  };
  const actionBtnBase: React.CSSProperties = {
    flex: 1,
    padding: '14px 12px',
    borderRadius: 16,
    fontFamily: 'inherit',
    fontSize: 13,
    cursor: 'pointer',
    transition: 'transform 0.18s ease, opacity 0.18s ease',
  };
  const sectionIconStyle: React.CSSProperties = {
    width: 42,
    height: 42,
    borderRadius: 14,
    background: 'rgba(157,157,157, 0.24)',
    border: '1px solid transparent',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: goldLight,
    flexShrink: 0,
    boxShadow: 'none',
  };

  return (
    <div style={{ margin: '0 0 24px' }}>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 14 }}>
        <div style={sectionIconStyle}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <path d="M4 10h16M6 10V8a6 6 0 0112 0v2M6 10v8a2 2 0 002 2h8a2 2 0 002-2v-8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M12 13v3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
        </div>
        <div>
          <div style={{ ...T.h3, color: text.secondary }}>{t('dep_title')}</div>
          <div style={{ fontSize: 12, color: text.muted }}>{deposits.filter(dep => dep.status === 'active').length > 0 ? `${deposits.filter(dep => dep.status === 'active').length} ${t('dep_status_active').toLowerCase()}` : t('dep_no_items')}</div>
        </div>
        <div style={{ flex: 1 }} />
        <button
          onClick={() => setShowCreate(v => !v)}
          style={{
            padding: '10px 16px',
            borderRadius: 14,
            background: showCreate ? 'rgba(255,255,255, 0.1)' : 'rgba(126,126,126, 0.95)',
            border: showCreate ? `1px solid ${bg.border}` : '1px solid rgba(171,171,171, 0.22)',
            color: showCreate ? text.secondary : '#f5f5f5',
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            fontFamily: 'inherit',
            fontWeight: 700,
            fontSize: 12.5,
            cursor: 'pointer',
            boxShadow: showCreate ? 'none' : '0 12px 28px rgba(56,56,56, 0.22)',
          }}
        >
          {showCreate ? tr('✕ Скасувати', '✕ Cancel') : `+ ${t('dep_open')}`}
        </button>
      </div>

      {/* Create form */}
      {showCreate && (
        <div style={{ ...panelStyle, padding: '20px 20px 18px', marginBottom: 14 }}>
          <form onSubmit={createDeposit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <div style={{ fontSize: 11, color: text.muted, letterSpacing: 0.8, marginBottom: 8 }}>{t('dep_amount').toUpperCase()}</div>
              <input
                type="text" inputMode="decimal"
                value={amount} onChange={e => setAmount(e.target.value)}
                placeholder="0,00"
                style={{ width: '100%', padding: '14px 16px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 14, color: text.primary, fontSize: 22, fontWeight: 500, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box', boxShadow: 'none' }}
              />
              <div style={{ fontSize: 11, color: text.muted, marginTop: 4 }}>{t('dep_min_amount')}</div>
            </div>

            <div>
              <div style={{ fontSize: 11, color: text.muted, letterSpacing: 0.8, marginBottom: 8 }}>{t('dep_term').toUpperCase()}</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
                {DEPOSIT_TERMS.map(m => (
                  <button
                    key={m} type="button"
                    onClick={() => setTermMonths(m)}
                    style={{
                      padding: '10px 4px', borderRadius: 12, fontFamily: 'inherit', cursor: 'pointer',
                      border: termMonths === m ? `1px solid ${gold}55` : `1px solid transparent`,
                      background: termMonths === m ? `rgba(171,171,171, 0.12)` : 'rgba(255,255,255, 0.1)',
                      color: termMonths === m ? gold : text.secondary,
                      fontSize: 12, fontWeight: termMonths === m ? 700 : 500,
                    }}
                  >
                    {m} {t('dep_monthly')}<br />
                    <span style={{ fontSize: 10, opacity: 0.7 }}>{DEPOSIT_RATES[m]}% {tr('р.', 'p.a.')}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Projected return */}
            <div style={{ background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 16, padding: '14px 16px', display: 'flex', justifyContent: 'space-between', gap: 12 }}>
              <div>
                <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8 }}>{t('dep_accrued')}</div>
                <div style={{ fontSize: 16, fontWeight: 700, color: gold }}>+{projectedInterest()}{'\u00a0TAX'}</div>
              </div>
              <div>
                <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8, textAlign: 'right' }}>{t('dep_rate')}</div>
                <div style={{ fontSize: 16, fontWeight: 700, color: text.secondary, textAlign: 'right' }}>{DEPOSIT_RATES[termMonths]}% {tr('р.а.', 'p.a.')}</div>
              </div>
            </div>

            {/* Auto-renew toggle */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <div style={{ fontSize: 13, color: text.secondary, fontWeight: 500 }}>{t('dep_auto_renew')}</div>
              </div>
              <button
                type="button"
                onClick={() => setAutoRenew(v => !v)}
                style={{
                  width: 44, height: 26, borderRadius: 13, border: 'none', cursor: 'pointer',
                  background: autoRenew ? gold : 'rgba(172,172,172, 0.2)',
                  position: 'relative', transition: 'background 0.2s',
                }}
              >
                <div style={{
                  position: 'absolute', top: 3, left: autoRenew ? 21 : 3,
                  width: 20, height: 20, borderRadius: '50%', background: '#ffffff',
                  transition: 'left 0.2s',
                }} />
              </button>
            </div>

            <button type="submit" disabled={creating} style={{
              padding: '14px', borderRadius: 14, border: 'none',
              background: creating ? 'rgba(51,51,51, 0.4)' : `${goldDark}`,
              color: creating ? text.dim : '#242424', fontSize: 14, fontWeight: 700,
              cursor: creating ? 'default' : 'pointer', fontFamily: 'inherit',
            }}>
              {creating ? '…' : t('dep_open')}
            </button>
          </form>
        </div>
      )}

      {/* Deposits list */}
      {loading ? (
        <div style={{ padding: '20px', color: text.muted, fontSize: 13, textAlign: 'center' }}>…</div>
      ) : deposits.length === 0 ? (
        <div style={{ padding: '20px 0', color: text.muted, fontSize: 13 }}>{t('dep_no_items')}</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {deposits.map(dep => {
            const isActive = dep.status === 'active';
            const statusColor = depStatusColor(dep.status);
            const matDate = dep.maturity_date ? new Date(dep.maturity_date).toLocaleDateString(locale) : '—';
            const total = Number(dep.amount) + Number(dep.interest_earned || 0);
            const progressPct = Math.round(Math.max(0, Math.min(1, Number(dep.progress || 0))) * 100);
            return (
              <div key={dep.id} style={panelStyle}>
                <div style={{ padding: '18px 18px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                    <div style={{ ...sectionIconStyle, width: 56, height: 56, borderRadius: 18 }}>
                      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                        <path d="M4 10h16M6 10V8a6 6 0 0112 0v2M6 10v8a2 2 0 002 2h8a2 2 0 002-2v-8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                        <path d="M12 13v3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                      </svg>
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 15, fontWeight: 700, color: text.primary }}>{dep.description || `${t('dep_title')} ${dep.term_months}${t('dep_monthly')}`}</div>
                      <div style={{ fontSize: 12, color: text.muted, marginTop: 2 }}>{dep.interest_rate}% {tr('р.а.', 'p.a.')} · {matDate}</div>
                    </div>
                    <div style={{ padding: '7px 12px', borderRadius: 999, background: `${statusColor}16`, border: `1px solid ${statusColor}30`, fontSize: 11, fontWeight: 700, color: statusColor, flexShrink: 0, letterSpacing: 0.2 }}>
                      {depStatusLabel(dep.status)}
                    </div>
                  </div>

                  <div style={metricGridStyle}>
                    <div style={metricCellStyle}>
                      <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8 }}>{tr('ТІЛО', 'PRINCIPAL')}</div>
                      <div style={{ fontSize: 18, fontWeight: 700, color: text.primary, marginTop: 4 }}>{formatUah(Number(dep.amount), lang)}</div>
                    </div>
                    <div style={{ ...metricCellStyle, textAlign: 'right' }}>
                      <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8 }}>{t('dep_accrued')}</div>
                      <div style={{ fontSize: 18, fontWeight: 700, color: isActive ? gold : text.secondary, marginTop: 4 }}>+{formatUah(Number(dep.interest_accrued), lang)}</div>
                    </div>
                    <div style={{ ...metricCellStyle, textAlign: 'right' }}>
                      <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8 }}>{t('dep_total_payout')}</div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: text.secondary, marginTop: 4 }}>{formatUah(total, lang)}</div>
                    </div>
                  </div>

                  {isActive && (
                    <>
                      <div style={{ height: 6, background: 'rgba(255,255,255, 0.1)', borderRadius: 999, overflow: 'hidden', marginBottom: 8 }}>
                        <div style={{ height: '100%', width: `${progressPct}%`, background: `${goldDark}`, borderRadius: 999, boxShadow: '0 0 18px rgba(171,171,171, 0.18)' }} />
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: text.muted, marginBottom: 14 }}>
                        <span>{progressPct}%</span>
                        <span>{dep.days_left} {t('dep_days_left')}</span>
                      </div>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <button
                          onClick={() => closeDeposit(dep, false)}
                          disabled={closing === dep.id || dep.days_left > 0}
                          style={{
                            ...actionBtnBase,
                            background: dep.days_left > 0 ? 'rgba(172,172,172, 0.06)' : 'rgba(169,169,169, 0.12)',
                            border: `1px solid ${dep.days_left > 0 ? 'rgba(172,172,172, 0.1)' : 'rgba(169,169,169, 0.3)'}`,
                            color: dep.days_left > 0 ? text.muted : '#a9a9a9', fontWeight: 700,
                            cursor: dep.days_left > 0 || closing === dep.id ? 'default' : 'pointer',
                            opacity: closing === dep.id ? 0.5 : 1,
                          }}
                        >{closing === dep.id ? '…' : t('dep_close')}</button>
                        <button
                          onClick={() => closeDeposit(dep, true)}
                          disabled={closing === dep.id}
                          style={{
                            ...actionBtnBase,
                            background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent',
                            color: '#989898', fontSize: 12, fontWeight: 600,
                            cursor: closing === dep.id ? 'default' : 'pointer',
                            opacity: closing === dep.id ? 0.5 : 1,
                          }}
                        >{t('dep_close_early')}</button>
                      </div>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Credits Section ──────────────────────────────────────────────────────────
interface Credit { id: number; user_id: number; account_id: number; principal: number; interest_rate: number; term_months: number; monthly_payment: number; total_paid: number; balance_remaining: number; next_payment_date: string; status: string; description: string; created_at: string; days_to_payment: number | null; progress: number; scheduled_total?: number; }
const CREDIT_RATES: Record<number, number> = { 3: 18, 6: 20, 12: 22, 24: 24, 36: 26 };
const CREDIT_TERMS = [3, 6, 12, 24, 36];

function CreditsSection() {
  const { toast } = useApp();
  const { lang } = usePreferences();
  const [credits, setCredits] = useState<Credit[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [amount, setAmount] = useState('');
  const [term, setTerm] = useState(12);
  const [desc, setDesc] = useState('');
  const [creating, setCreating] = useState(false);
  const [repaying, setRepaying] = useState<number | null>(null);
  const tt = React.useMemo(() => ({
    uk: {
      title: 'Кредити',
      subtitle: 'Споживче кредитування',
      activeSuffix: 'активних',
      toggleOpen: 'Взяти кредит',
      amountLabel: 'Сума кредиту',
      amountPlaceholder: '1 000 – 500 000 TAX',
      termLabel: 'Строк',
      monthlyPayment: 'ЩОМІСЯЧНИЙ ПЛАТІЖ',
      totalCost: 'ЗАГАЛЬНА ВАРТІСТЬ',
      purposePlaceholder: "Призначення (необов'язково)",
      submit: 'Взяти кредит',
      noCredits: 'У вас немає активних кредитів',
      statusActive: 'Активний',
      statusClosed: 'Погашено',
      progressPaid: 'погашено',
      remaining: 'Залишок',
      paymentPerMonth: 'Платіж/міс.',
      nextPayment: 'Наступний',
      overdue: 'Прострочено на {days} днів',
      payInstallment: 'Сплатити платіж',
      repayFull: 'Погасити',
      minAmount: 'Мінімальна сума — 1 000 TAX',
      maxAmount: 'Максимальна сума — 500 TAX 000',
      serverNoResponse: 'Сервер не відповів — зачекайте хвилину і спробуйте ще раз',
      createSuccess: 'Кредит оформлено',
      repaySuccess: 'Кредит погашено',
      paymentSuccess: 'Платіж зараховано',
      serverError: 'Помилка сервера',
      networkError: 'Помилка мережі',
      genericError: 'Помилка',
      creditLine: 'Кредит {months} міс. · {rate}% річних',
    },
    en: {
      title: 'Loans',
      subtitle: 'Consumer lending',
      activeSuffix: 'active',
      toggleOpen: 'Get a loan',
      amountLabel: 'Loan amount',
      amountPlaceholder: '1,000 – 500,000 TAX',
      termLabel: 'Term',
      monthlyPayment: 'MONTHLY PAYMENT',
      totalCost: 'TOTAL COST',
      purposePlaceholder: 'Purpose (optional)',
      submit: 'Get a loan',
      noCredits: 'You have no active loans',
      statusActive: 'Active',
      statusClosed: 'Closed',
      progressPaid: 'repaid',
      remaining: 'Remaining',
      paymentPerMonth: 'Monthly',
      nextPayment: 'Next',
      overdue: 'Overdue by {days} days',
      payInstallment: 'Pay installment',
      repayFull: 'Repay fully',
      minAmount: 'Minimum amount is 1,000 TAX',
      maxAmount: 'Maximum amount is 500,000 TAX',
      serverNoResponse: 'Server did not respond. Please try again shortly',
      createSuccess: 'Loan issued',
      repaySuccess: 'Loan repaid',
      paymentSuccess: 'Payment received',
      serverError: 'Server error',
      networkError: 'Network error',
      genericError: 'Error',
      creditLine: 'Loan {months} mo · {rate}% APR',
    },
    it: {
      title: 'Prestiti',
      subtitle: 'Credito al consumo',
      activeSuffix: 'attivi',
      toggleOpen: 'Richiedi prestito',
      amountLabel: 'Importo del prestito',
      amountPlaceholder: '1.000 – 500.000 TAX',
      termLabel: 'Durata',
      monthlyPayment: 'RATA MENSILE',
      totalCost: 'COSTO TOTALE',
      purposePlaceholder: 'Finalità (facoltativa)',
      submit: 'Richiedi prestito',
      noCredits: 'Non hai prestiti attivi',
      statusActive: 'Attivo',
      statusClosed: 'Estinto',
      progressPaid: 'rimborsato',
      remaining: 'Residuo',
      paymentPerMonth: 'Rata/mese',
      nextPayment: 'Prossima',
      overdue: 'Scaduto da {days} giorni',
      payInstallment: 'Paga rata',
      repayFull: 'Estingui',
      minAmount: 'L’importo minimo è 1.000 TAX',
      maxAmount: 'L’importo massimo è 500.000 TAX',
      serverNoResponse: 'Il server non risponde. Riprova tra poco',
      createSuccess: 'Prestito erogato',
      repaySuccess: 'Prestito estinto',
      paymentSuccess: 'Pagamento registrato',
      serverError: 'Errore del server',
      networkError: 'Errore di rete',
      genericError: 'Errore',
      creditLine: 'Prestito {months} mesi · {rate}% annuo',
    },
    de: {
      title: 'Kredite',
      subtitle: 'Konsumentenkredit',
      activeSuffix: 'aktiv',
      toggleOpen: 'Kredit beantragen',
      amountLabel: 'Kreditbetrag',
      amountPlaceholder: '1.000 – 500.000 TAX',
      termLabel: 'Laufzeit',
      monthlyPayment: 'MONATSRATE',
      totalCost: 'GESAMTKOSTEN',
      purposePlaceholder: 'Zweck (optional)',
      submit: 'Kredit beantragen',
      noCredits: 'Sie haben keine aktiven Kredite',
      statusActive: 'Aktiv',
      statusClosed: 'Getilgt',
      progressPaid: 'getilgt',
      remaining: 'Restschuld',
      paymentPerMonth: 'Monatlich',
      nextPayment: 'Nächste',
      overdue: '{days} Tage überfällig',
      payInstallment: 'Rate zahlen',
      repayFull: 'Vollständig tilgen',
      minAmount: 'Mindestbetrag 1.000 TAX',
      maxAmount: 'Höchstbetrag 500.000 TAX',
      serverNoResponse: 'Der Server antwortet nicht. Bitte gleich erneut versuchen',
      createSuccess: 'Kredit ausgezahlt',
      repaySuccess: 'Kredit getilgt',
      paymentSuccess: 'Zahlung eingegangen',
      serverError: 'Serverfehler',
      networkError: 'Netzwerkfehler',
      genericError: 'Fehler',
      creditLine: 'Kredit {months} Mon. · {rate}% p. a.',
    },
    ru: {
      title: 'Кредиты',
      subtitle: 'Потребительское кредитование',
      activeSuffix: 'активных',
      toggleOpen: 'Оформить кредит',
      amountLabel: 'Сумма кредита',
      amountPlaceholder: '1 000 – 500 000 TAX',
      termLabel: 'Срок',
      monthlyPayment: 'ЕЖЕМЕСЯЧНЫЙ ПЛАТЁЖ',
      totalCost: 'ПОЛНАЯ СТОИМОСТЬ',
      purposePlaceholder: 'Цель (необязательно)',
      submit: 'Оформить кредит',
      noCredits: 'У вас нет активных кредитов',
      statusActive: 'Активный',
      statusClosed: 'Погашен',
      progressPaid: 'погашено',
      remaining: 'Остаток',
      paymentPerMonth: 'Платёж/мес',
      nextPayment: 'Следующий',
      overdue: 'Просрочка {days} дн.',
      payInstallment: 'Внести платёж',
      repayFull: 'Погасить полностью',
      minAmount: 'Минимальная сумма — 1 000 TAX',
      maxAmount: 'Максимальная сумма — 500 000 TAX',
      serverNoResponse: 'Сервер не ответил. Попробуйте чуть позже',
      createSuccess: 'Кредит выдан',
      repaySuccess: 'Кредит погашен',
      paymentSuccess: 'Платёж принят',
      serverError: 'Ошибка сервера',
      networkError: 'Ошибка сети',
      genericError: 'Ошибка',
      creditLine: 'Кредит {months} мес · {rate}% годовых',
    },
  }[lang]), [lang]);

  const activeCredits = credits.filter(c => c.status === 'active').length;
  const panelStyle: React.CSSProperties = {
    background: '#1c1c1e',
    border: '1px solid transparent',
    borderRadius: 26,
    overflow: 'hidden',
    boxShadow: '0 18px 44px rgba(0,0,0, 0.16)',
  };
  const sectionIconStyle: React.CSSProperties = {
    width: 42,
    height: 42,
    borderRadius: 14,
    background: 'rgba(102,102,102, 0.28)',
    border: '1px solid transparent',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: '#dbdbdb',
    flexShrink: 0,
    boxShadow: 'none',
  };
  const metricGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'minmax(0, 1fr)',
    gap: 1,
    background: 'rgba(255,255,255, 0.06)',
    borderRadius: 18,
    overflow: 'hidden',
  };
  const metricCellStyle: React.CSSProperties = {
    background: '#232325',
    padding: '13px 16px',
    display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12,
  };

  async function load() {
    try {
      const data = await apiRequest<Credit[]>('/api/credits');
      setCredits(Array.isArray(data) ? data : []);
    } catch {
      setCredits([]);
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => { load(); }, []);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    const amtNum = parseFloat(amount.replace(/[\s ]/g, '').replace(',', '.'));
    if (!amtNum || amtNum < 1000) { toast(tt.minAmount); return; }
    if (amtNum > 500000) { toast(tt.maxAmount); return; }
    setCreating(true);
    try {
      const idempotencyKey = `credit-create-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      await apiRequest('/api/credits', {
        method: 'POST',
        headers: { 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ amount: amtNum, term_months: term, description: desc, idempotency_key: idempotencyKey }),
      });
      setShowCreate(false);
      setAmount('');
      setDesc('');
      toast(tt.createSuccess);
      load();
    } catch (err) {
      toast(err instanceof Error ? err.message : tt.networkError);
    } finally {
      setCreating(false);
    }
  }

  async function handleRepay(creditId: number, full = false) {
    setRepaying(creditId);
    try {
      const credit = credits.find(c => c.id === creditId);
      const idempotencyKey = `credit-repay-${creditId}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const body = full ? { amount: credit?.balance_remaining, idempotency_key: idempotencyKey } : { idempotency_key: idempotencyKey };
      const updated = await apiRequest<Credit>(`/api/credits/${creditId}/repay`, {
        method: 'POST',
        headers: { 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify(body),
      });
      toast(updated.status === 'closed' ? tt.repaySuccess : tt.paymentSuccess);
      load();
    } catch {
      toast(tt.genericError);
    } finally {
      setRepaying(null);
    }
  }

  const amtNum = parseFloat(amount.replace(',', '.')) || 0;
  const r = (CREDIT_RATES[term] ?? 22) / 100 / 12;
  const monthlyPayment = amtNum > 0 && r > 0 ? amtNum * r * (1 + r) ** term / ((1 + r) ** term - 1) : 0;
  const totalCost = monthlyPayment * term;
  const fmtDate = (iso: string | null | undefined) => {
    if (!iso) return '—';
    try { return new Date(iso).toLocaleDateString(localeForLang(lang)); }
    catch { return '—'; }
  };

  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 14 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={sectionIconStyle}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="6" width="18" height="12" rx="3" stroke="currentColor" strokeWidth="1.8" />
              <path d="M3 10h18" stroke="currentColor" strokeWidth="1.8" />
              <path d="M7 15h4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            </svg>
          </div>
          <div>
            <div style={{ fontSize: 16, fontWeight: 700, color: text.primary }}>{tt.title}</div>
            <div style={{ fontSize: 12, color: text.muted }}>{activeCredits > 0 ? `${activeCredits} ${tt.activeSuffix}` : tt.subtitle}</div>
          </div>
        </div>
        <button onClick={() => setShowCreate(v => !v)} style={{ padding: '10px 16px', borderRadius: 14, border: showCreate ? `1px solid ${bg.border}` : '1px solid rgba(128,128,128, 0.18)', cursor: 'pointer', background: showCreate ? 'rgba(255,255,255, 0.1)' : 'rgba(98,98,98, 0.96)', color: '#f8f8f8', fontSize: 12.5, fontWeight: 700, fontFamily: 'inherit', boxShadow: showCreate ? 'none' : '0 12px 28px rgba(47,47,47, 0.22)' }}>{showCreate ? '✕' : tt.toggleOpen}</button>
      </div>

      {showCreate && (
        <div style={{ ...panelStyle, padding: 20, marginBottom: 16 }}>
          <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <label style={{ fontSize: 12, color: text.muted, display: 'block', marginBottom: 6 }}>{tt.amountLabel}</label>
              <input type="text" inputMode="decimal" value={amount} onChange={e => setAmount(e.target.value)} placeholder={tt.amountPlaceholder} style={{ width: '100%', padding: '14px 16px', borderRadius: 14, background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, color: text.primary, fontSize: 16, outline: 'none', boxShadow: 'none' }} />
            </div>
            <div>
              <label style={{ fontSize: 12, color: text.muted, display: 'block', marginBottom: 8 }}>{tt.termLabel}</label>
              <div style={{ display: 'flex', gap: 8 }}>
                {CREDIT_TERMS.map(mo => (
                  <button key={mo} type="button" onClick={() => setTerm(mo)} style={{ flex: 1, padding: '10px 0', borderRadius: 12, border: `1.5px solid ${term === mo ? '#787878' : bg.border}`, background: term === mo ? 'rgba(120,120,120, 0.14)' : 'rgba(255,255,255, 0.1)', color: term === mo ? '#cacaca' : text.muted, fontSize: 12, fontWeight: term === mo ? 700 : 500, cursor: 'pointer', fontFamily: 'inherit' }}>
                    {mo}{tr('м', 'm')}<div style={{ fontSize: 10, marginTop: 2 }}>{CREDIT_RATES[mo]}%</div>
                  </button>
                ))}
              </div>
            </div>
            {amtNum > 0 && (
              <div style={{ background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: 16, padding: 14, display: 'flex', gap: 16 }}>
                <div style={{ flex: 1, textAlign: 'center' }}>
                  <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8, marginBottom: 4 }}>{tt.monthlyPayment}</div>
                  <div style={{ fontSize: 18, fontWeight: 700, color: '#cacaca' }}>{formatUah(monthlyPayment, lang)}</div>
                </div>
                <div style={{ flex: 1, textAlign: 'center' }}>
                  <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.8, marginBottom: 4 }}>{tt.totalCost}</div>
                  <div style={{ fontSize: 18, fontWeight: 700, color: text.secondary }}>{formatUah(totalCost, lang)}</div>
                </div>
              </div>
            )}
            <input value={desc} onChange={e => setDesc(e.target.value)} placeholder={tt.purposePlaceholder} style={{ width: '100%', padding: '14px 16px', borderRadius: 14, background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, color: text.primary, fontSize: 14, outline: 'none', boxShadow: 'none' }} />
            <button type="submit" disabled={creating} style={{ padding: '14px', borderRadius: 16, border: 'none', background: creating ? 'rgba(51,51,51, 0.4)' : 'rgba(98,98,98, 0.96)', color: creating ? text.dim : '#f8f8f8', fontSize: 14, fontWeight: 700, cursor: creating ? 'default' : 'pointer', fontFamily: 'inherit', boxShadow: creating ? 'none' : '0 14px 30px rgba(47,47,47, 0.2)' }}>{creating ? '…' : tt.submit}</button>
          </form>
        </div>
      )}

      {loading ? <div style={{ padding: '20px', color: text.muted, fontSize: 13, textAlign: 'center' }}>…</div>
       : credits.length === 0 ? <div style={{ padding: '20px 0', color: text.muted, fontSize: 13 }}>{tt.noCredits}</div>
       : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {credits.map(cr => {
            const isActive = cr.status === 'active';
            const statusColor = isActive ? '#939393' : '#888888';
            const nextDate = fmtDate(cr.next_payment_date);
            const overdue = isActive && (cr.days_to_payment ?? 0) < 0;
            const creditLine = tt.creditLine
              .replace('{months}', String(cr.term_months))
              .replace('{rate}', String(cr.interest_rate));
            return (
              <div key={cr.id} style={panelStyle}>
                <div style={{ padding: '18px 18px 14px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
                    <div>
                      <div style={{ fontSize: 15, fontWeight: 700, color: text.primary }}>{creditLine}</div>
                      {cr.description ? <div style={{ fontSize: 12, color: text.muted, marginTop: 3 }}>{cr.description}</div> : null}
                    </div>
                    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.3, padding: '7px 12px', borderRadius: 999, background: `${statusColor}18`, color: statusColor, border: `1px solid ${statusColor}30` }}>{isActive ? tt.statusActive : tt.statusClosed}</div>
                  </div>
                  <div style={{ background: 'rgba(255,255,255, 0.1)', borderRadius: 999, height: 6, overflow: 'hidden' }}>
                    <div style={{ height: '100%', borderRadius: 999, background: isActive ? 'rgba(86,86,86, 0.95)' : '#666666', width: `${cr.progress}%`, transition: 'width 0.6s', boxShadow: isActive ? '0 0 16px rgba(151,151,151, 0.16)' : 'none' }} />
                  </div>
                  <div style={{ fontSize: 11, color: text.muted, marginTop: 6 }}>{cr.progress.toFixed(0)}% {tt.progressPaid}</div>
                </div>
                <div style={metricGridStyle}>
                  {[{ label: tt.remaining, value: formatUah(Number(cr.balance_remaining), lang) }, { label: tt.paymentPerMonth, value: formatUah(Number(cr.monthly_payment), lang) }, { label: tt.nextPayment, value: isActive ? nextDate : '—' }].map(({ label, value }) => (
                    <div key={label} style={metricCellStyle}>
                      <div style={{ fontSize: 10, color: text.muted, letterSpacing: 0.6 }}>{label}</div>
                      <div style={{ fontSize: 14, fontWeight: 700, color: text.primary, marginTop: 4 }}>{value}</div>
                    </div>
                  ))}
                </div>
                {overdue && <div style={{ padding: '10px 16px', background: 'rgba(255,255,255, 0.1)', borderTop: `1px solid rgba(93,93,93, 0.22)` }}><div style={{ fontSize: 12, color: '#adadad', fontWeight: 600 }}>⚠️ {tt.overdue.replace('{days}', String(Math.abs(cr.days_to_payment ?? 0)))}</div></div>}
                {isActive && (
                  <div style={{ padding: '14px 16px 16px', display: 'flex', gap: 8 }}>
                    <button disabled={repaying === cr.id} onClick={() => handleRepay(cr.id)} style={{ flex: 1, padding: '14px', borderRadius: 16, border: 'none', cursor: 'pointer', background: repaying === cr.id ? 'rgba(51,51,51, 0.4)' : 'rgba(98,98,98, 0.96)', color: '#f8f8f8', fontSize: 13, fontWeight: 700, fontFamily: 'inherit', boxShadow: repaying === cr.id ? 'none' : '0 14px 30px rgba(47,47,47, 0.18)' }}>{repaying === cr.id ? '…' : tt.payInstallment}</button>
                    <button disabled={repaying === cr.id} onClick={() => handleRepay(cr.id, true)} style={{ padding: '14px 16px', borderRadius: 16, border: `1px solid transparent`, background: 'rgba(255,255,255, 0.02)', color: '#cacaca', fontSize: 13, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit' }}>{tt.repayFull}</button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ─── Документи: QR-печатка й сховище ──────────────────────────
interface DocRecord {
  id: number; kind: 'receipt' | 'statement'; ref: string; code: string; title: string;
  amount?: number | null; direction?: string | null; created_at: string; verify_url: string;
  meta?: { period?: string; count?: number };
}

function DocSeal({ doc, lang }: { doc: DocRecord; lang: AppLang }) {
  const uk = lang === 'uk';
  const [copied, setCopied] = useState(false);
  const copy = () => { navigator.clipboard?.writeText(doc.code).then(() => { setCopied(true); setTimeout(() => setCopied(false), 1600); }).catch(() => {}); };
  return (
    <div style={{ border: '1px solid rgba(255,212,0,0.30)', borderRadius: 22, padding: '16px 16px 14px', marginBottom: 22, textAlign: 'center',
      background: 'linear-gradient(180deg, rgba(255,212,0,0.07), rgba(255,212,0,0.015))', boxShadow: 'inset 0 0 0 3px rgba(255,212,0,0.03)' }}>
      <div style={{ fontSize: 9.5, fontWeight: 700, letterSpacing: 2.2, color: gold, marginBottom: 12 }}>{tr('ПЕРЕВІРКА · QR', 'VERIFY · QR')}</div>
      <div style={{ position: 'relative', width: 164, height: 164, margin: '0 auto', background: '#fff', borderRadius: 16, boxShadow: '0 8px 22px rgba(0,0,0,0.35)' }}>
        <img src={apiUrl(`/api/qr/${doc.code}.svg`)} alt="QR" width={136} height={136} style={{ position: 'absolute', inset: 14, imageRendering: 'pixelated' }} />
        {[[0, 0], [1, 0], [0, 1], [1, 1]].map(([x, y]) => (
          <span key={`${x}${y}`} style={{ position: 'absolute', width: 15, height: 15, [x ? 'right' : 'left']: 5, [y ? 'bottom' : 'top']: 5,
            borderTop: y ? 'none' : `3px solid ${gold}`, borderBottom: y ? `3px solid ${gold}` : 'none',
            borderLeft: x ? 'none' : `3px solid ${gold}`, borderRight: x ? `3px solid ${gold}` : 'none',
            borderRadius: `${!x && !y ? 5 : 0}px ${x && !y ? 5 : 0}px ${x && y ? 5 : 0}px ${!x && y ? 5 : 0}px` }} />
        ))}
      </div>
      <div style={{ marginTop: 12, fontSize: 11, letterSpacing: 1, color: text.muted }}>{tr('Код документа', 'Document code')}</div>
      <div style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 17, fontWeight: 700, letterSpacing: 1.2, color: text.primary, margin: '3px 0 8px' }}>{doc.code}</div>
      <div style={{ fontSize: 12, color: text.muted, lineHeight: 1.45, marginBottom: 12 }}>
        {tr('Скануйте QR або введіть код на сторінці перевірки: вона звіряє документ із реєстром і не показує особистих даних.', 'Scan the QR or enter the code on the verification page: it checks the document against the ledger and shows no personal data.')}
      </div>
      <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
        <a href={doc.verify_url} target="_blank" rel="noopener noreferrer" style={{ ...docPill, textDecoration: 'none', color: '#161616', background: gold, border: 'none' }}>
          {tr('Перевірити онлайн', 'Verify online')}
        </a>
        <button onClick={copy} style={docPill}>{copied ? tr('Скопійовано', 'Copied') : tr('Код', 'Code')}</button>
      </div>
    </div>
  );
}

function DocumentsSheet({ onClose, lang }: { onClose: () => void; lang: AppLang }) {
  const uk = lang === 'uk';
  const [docs, setDocs] = useState<DocRecord[] | null>(null);
  const [open, setOpen] = useState<DocRecord | null>(null);
  const [kind, setKind] = useState<'all' | 'receipt' | 'statement'>('all');
  useEffect(() => { apiRequest<DocRecord[]>('/api/documents').then(setDocs).catch(() => setDocs([])); }, []);
  const rows = (docs || []).filter(d => kind === 'all' || d.kind === kind);
  return createPortal(
    <div className="tt-overlay" style={{ position: 'fixed', inset: 0, zIndex: 310, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={onClose}>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(4px)' }} />
      <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{ position: 'relative', width: '100%', maxWidth: 520, background: '#1c1c1e',
        borderRadius: '24px 24px 0 0', padding: '14px 20px calc(24px + env(safe-area-inset-bottom,0px))', maxHeight: '92vh', overflowY: 'auto' }}>
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172,0.25)', margin: '0 auto 18px' }} />
        {open ? (
          <>
            <button onClick={() => setOpen(null)} style={{ ...docPill, height: 32, marginBottom: 14 }}>← {tr('Документи', 'Documents')}</button>
            <div style={{ ...T.h3, color: text.primary, marginBottom: 4 }}>{open.title}</div>
            <div style={{ fontSize: 12, color: text.muted, marginBottom: 16 }}>{new Date(open.created_at.replace(' ', 'T') + 'Z').toLocaleString(localeForLang(lang))}</div>
            <DocSeal doc={open} lang={lang} />
          </>
        ) : (
          <>
            <div style={{ ...T.h3, color: text.primary, marginBottom: 4 }}>{tr('Мої документи', 'My documents')}</div>
            <div style={{ fontSize: 12, color: text.muted, marginBottom: 14 }}>{tr('Квитанції й виписки з кодом і QR для перевірки', 'Receipts and statements with a code and QR to verify')}</div>
            <div style={{ display: 'flex', gap: 6, marginBottom: 12 }}>
              {(['all', 'receipt', 'statement'] as const).map(k => (
                <button key={k} onClick={() => setKind(k)} style={{ ...docPill, height: 32, opacity: kind === k ? 1 : 0.55 }}>
                  {k === 'all' ? tr('Усі', 'All') : k === 'receipt' ? tr('Квитанції', 'Receipts') : tr('Виписки', 'Statements')}
                </button>
              ))}
            </div>
            {docs === null && <div style={{ color: text.muted, fontSize: 13, padding: 16 }}>…</div>}
            {docs !== null && rows.length === 0 && <div style={{ color: text.muted, fontSize: 13, padding: '20px 4px' }}>{tr('Документів поки немає', 'No documents yet')}</div>}
            {rows.map((d, i) => (
              <button key={d.id} onClick={() => setOpen(d)} style={{ display: 'flex', width: '100%', alignItems: 'center', gap: 12, padding: '12px 2px', background: 'none', border: 'none',
                borderTop: i ? '1px solid rgba(255,255,255,0.06)' : 'none', color: 'inherit', fontFamily: 'inherit', textAlign: 'left', cursor: 'pointer' }}>
                <span style={{ width: 40, height: 40, borderRadius: 20, flexShrink: 0, display: 'grid', placeItems: 'center', color: d.kind === 'receipt' ? '#34c759' : gold,
                  border: `1px solid ${d.kind === 'receipt' ? 'rgba(52,199,89,0.45)' : 'rgba(255,212,0,0.45)'}`, background: 'rgba(255,255,255,0.04)' }}>
                  {d.kind === 'receipt' ? '✓' : '≡'}
                </span>
                <span style={{ flex: 1, minWidth: 0 }}>
                  <span style={{ display: 'block', fontSize: 14, color: text.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{d.title}</span>
                  <span style={{ display: 'block', fontSize: 11.5, color: text.muted, fontFamily: 'ui-monospace, Menlo, monospace', marginTop: 2 }}>{d.code}</span>
                </span>
                {d.amount != null && <span style={{ fontSize: 14, color: d.direction === 'in' ? '#34c759' : text.primary, ...T.num }}>{d.direction === 'in' ? '+' : '−'}{d.amount.toLocaleString('uk-UA', { minimumFractionDigits: 2 })}</span>}
              </button>
            ))}
          </>
        )}
      </div>
    </div>,
    document.body
  );
}

function OperationsScreen() {
  const opsWide = useWindowWidth() >= 1180;
  const layout = useLayout();
  const { t, lang } = usePreferences();
  const topPad = useTopPad();
  const { toast, transactions, account } = useApp();
  const [period, setPeriod] = useState(0);
  const [searchQuery, setSearchQuery] = useState('');
  const [txFilter, setTxFilter] = useState<'all' | 'in' | 'out'>('all');
  const [sortOrder, setSortOrder] = useState<'desc' | 'asc' | 'amount'>('desc');
  const [dlReceipt, setDlReceipt] = useState<number | null>(null);
  const [dlExport, setDlExport] = useState(false);
  const [selectedTxId, setSelectedTxId] = useState<number | null>(null);
  const [sealDoc, setSealDoc] = useState<DocRecord | null>(null);
  const [docsOpen, setDocsOpen] = useState(false);
  useEffect(() => {
    setSealDoc(null);
    if (selectedTxId == null) return;
    let live = true;
    apiRequest<DocRecord>(`/api/documents/receipt/${selectedTxId}`).then(d => { if (live) setSealDoc(d); }).catch(() => {});
    return () => { live = false; };
  }, [selectedTxId]);
  const [txNote, setTxNote] = useState('');
  const [savingNote, setSavingNote] = useState(false);
  const token = localStorage.getItem('army_bank_token');

  const selectedTxData = useMemo(
    () => selectedTxId ? transactions.find(tx => tx.id === selectedTxId) ?? null : null,
    [selectedTxId, transactions],
  );

  async function saveNote() {
    if (!selectedTxId || !token) return;
    setSavingNote(true);
    try {
      const r = await fetch(`/api/transactions/${selectedTxId}/note`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ note: txNote }),
      });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || t('operation_error'));
      toast(t('tx_note_saved'));
      setSelectedTxId(null);
    } catch (e: unknown) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setSavingNote(false); }
  }

  const locale = localeForLang(lang);
  const periodLabels = [t('period_week_short'), t('period_month_short'), t('period_year_short')];
  const periodDays = [7, 30, 365][period];
  const periodMs = periodDays * 24 * 60 * 60 * 1000;
  const now = Date.now();
  const startTs = now - periodMs;
  const bucketMs = periodMs / 7;
  const values = Array.from({ length: 7 }, (_, i) => {
    const bucketStart = startTs + i * bucketMs;
    const bucketEnd = bucketStart + bucketMs;
    return transactions.filter(tx => tx.direction === 'out' && new Date(tx.created_at).getTime() >= bucketStart && new Date(tx.created_at).getTime() < bucketEnd).reduce((s, tx) => s + tx.amount, 0);
  });
  const max = Math.max(...values, 1);
  const labels = Array.from({ length: 7 }, (_, i) => {
    const stamp = new Date(startTs + (i + 1) * bucketMs);
    return period === 2
      ? stamp.toLocaleDateString(locale, { month: 'short' })
      : stamp.toLocaleDateString(locale, { day: '2-digit', month: '2-digit' });
  });

  async function downloadReceipt(txId: number) {
    setDlReceipt(txId);
    try {
      const r = await fetch(`/api/transactions/${txId}/receipt`, { headers: { Authorization: `Bearer ${token}` } });
      if (!r.ok) { toast(t('receipt_download_error')); return; }
      const blob = await r.blob();
      openPdfBlobInNewTab(blob, `receipt-${txId}.pdf`, toast);
    } catch { toast(t('download_error')); } finally { setDlReceipt(null); }
  }

  async function downloadExport() {
    setDlExport(true);
    try {
      const r = await fetch('/api/transactions/export', { headers: { Authorization: `Bearer ${token}` } });
      if (!r.ok) { toast(t('export_error')); return; }
      const blob = await r.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a'); a.href = url; a.download = 'army_bank_transactions.csv'; a.click();
      URL.revokeObjectURL(url);
    } catch { toast(t('download_error')); } finally { setDlExport(false); }
  }

  async function downloadStatement() {
    try {
      const r = await fetch('/api/transactions/statement', { headers: { Authorization: `Bearer ${token}` } });
      if (!r.ok) { toast(t('statement_error')); return; }
      const blob = await r.blob();
      openPdfBlobInNewTab(blob, 'statement.pdf', toast);
    } catch { toast(t('download_error')); }
  }

  // Build tx groups from real API data (or fallback to static)
  const STATIC_GROUPS: { group: string; items: { txId?: number; title: string; subtitle: string; amount: string; value?: number; positive?: boolean; cat: TxCat }[] }[] = [
    { group: t('today_label'), items: [
      { title: 'Income • FOP', subtitle: '14:32', amount: '+84 200,00', positive: true, cat: 'income' },
      { title: 'Silpo', subtitle: `12:18 • ${t('card_short_label')} •• 0001`, amount: '-1 247,50', cat: 'food' },
      { title: 'Uklon', subtitle: '09:42 • Apple Pay', amount: '-148,00', cat: 'transport' },
    ]},
    { group: t('yesterday_label'), items: [
      { title: 'Utilities', subtitle: 'Kyivenergo', amount: '-3 180,00', cat: 'utility' },
      { title: 'Rozetka', subtitle: 'Online shopping', amount: '-6 420,00', cat: 'shopping' },
    ]},
  ];

  const filtered = useMemo(() => (
    (searchQuery.trim()
      ? transactions.filter(tx => tx.description.toLowerCase().includes(searchQuery.toLowerCase()))
      : transactions
    ).filter(tx => txFilter === 'all' || tx.direction === txFilter)
  ), [searchQuery, transactions, txFilter]);

  const apiGroups = useMemo(() => {
    const map: Record<string, ApiTransaction[]> = {};
    for (const tx of filtered) { const k = tx.created_at.slice(0, 10); if (!map[k]) map[k] = []; map[k].push(tx); }
    const dateSort = sortOrder === 'asc'
      ? ([a]: [string, unknown], [b]: [string, unknown]) => a.localeCompare(b)
      : ([a]: [string, unknown], [b]: [string, unknown]) => b.localeCompare(a);
    return Object.entries(map).sort(dateSort).map(([dateKey, items]) => {
      const sortedItems = sortOrder === 'amount'
        ? [...items].sort((a, b) => b.amount - a.amount)
        : sortOrder === 'asc'
        ? [...items].sort((a, b) => a.created_at.localeCompare(b.created_at))
        : [...items].sort((a, b) => b.created_at.localeCompare(a.created_at));
      return {
        group: fmtDateLabel(dateKey, lang),
        items: sortedItems.map(tx => ({
          txId: tx.id,
          title: tx.description,
          subtitle: fmtTime(tx.created_at, lang) + (tx.related_account ? ` • ${tx.related_account}` : ''),
          amount: (tx.direction === 'in' ? '+' : '−') + fmtInt(tx.amount) + fmtDec(tx.amount),
          value: tx.amount,
          positive: tx.direction === 'in',
          cat: txToCat(tx as TxItem),
        })),
      };
    });
  }, [filtered, sortOrder, lang]);

  const txGroups = apiGroups.length > 0 ? apiGroups : (searchQuery ? [] : STATIC_GROUPS);

  // Spending total from real data
  const totalSpent = transactions.filter(t => t.direction === 'out').reduce((s, t) => s + t.amount, 0);
  const spentLabel = account && transactions.length > 0 ? `${fmtInt(totalSpent)}${fmtDec(totalSpent)}\u00a0TAX` : '42\u00a0380\u00a0TAX';

    const opsHeader = (
    <>
      <div style={{ padding: `${topPad} 18px 14px` }}>
        <div style={{
          ...glassCard({
            padding: '18px 18px 16px',
            borderRadius: 26,
            background: '#1c1c1e',
            boxShadow: '0 20px 42px rgba(0,0,0, 0.2)',
          }),
          position: 'relative',
          overflow: 'hidden',
        }}>
        <div style={{ ...T.h1, color: text.primary, marginBottom: 14 }}>{t('operations_title')}</div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 14, flexWrap: 'wrap' }}>
          <button onClick={downloadStatement} style={docPill}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8l-6-6z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round"/>
              <path d="M14 2v6h6M9 14h6M9 18h4" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            {t('statement_pdf')}
          </button>
          <button onClick={downloadExport} disabled={dlExport} style={{ ...docPill, opacity: dlExport ? 0.6 : 1 }}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <rect x="3" y="4" width="18" height="16" rx="3" stroke="currentColor" strokeWidth="1.7"/>
              <path d="M3 10h18M9 10v10" stroke="currentColor" strokeWidth="1.7"/>
            </svg>
            {dlExport ? '…' : 'CSV'}
          </button>
          <button onClick={() => setDocsOpen(true)} style={docPill}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
              <path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2v2h-2zM14 18h2v2h-2zM18 18h2v2h-2z" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"/>
            </svg>
            {tr('Документи', 'Docs')}
          </button>
        </div>
        <div style={{ position: 'relative' }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', opacity: 0.5 }}><circle cx="11" cy="11" r="7" stroke="#d8d8d8" strokeWidth="1.8" /><path d="M20 20l-3-3" stroke="#d8d8d8" strokeWidth="1.8" strokeLinecap="round" /></svg>
          <input
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            placeholder={t('search_transactions')}
            style={{ width: '100%', padding: '10px 14px 10px 36px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 12, color: '#d8d8d8', fontSize: 13, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box' }}
          />
        </div>
        <div style={{ display: 'flex', gap: 4, padding: '3px', background: 'rgba(36,36,36, 0.5)', borderRadius: 100, marginTop: 10 }}>
          {(['all', 'in', 'out'] as const).map(f => (
            <button key={f} onClick={() => setTxFilter(f)} style={{
              flex: 1, padding: '5px 8px', fontSize: 11, fontWeight: 500,
              background: f === txFilter ? `${gold}` : 'transparent',
              color: f === txFilter ? '#161616' : 'rgba(215,215,215, 0.6)',
              border: 'none', borderRadius: 100, cursor: 'pointer', fontFamily: 'inherit',
              transition: 'background 0.2s, color 0.2s',
            }}>
              {f === 'all' ? t('filter_all') : f === 'in' ? t('filter_income') : t('filter_outcome')}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
          <span style={{ fontSize: 10, color: text.dim, textTransform: 'uppercase', letterSpacing: 0.7, flexShrink: 0 }}>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" style={{ verticalAlign: 'middle', marginRight: 3 }}><path d="M4 6h16M4 12h10M4 18h6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" /></svg>
          </span>
          <div style={{ display: 'flex', gap: 3, padding: '2px', background: 'rgba(36,36,36, 0.5)', borderRadius: 100 }}>
            {(['desc', 'asc', 'amount'] as const).map(s => (
              <button key={s} onClick={() => setSortOrder(s)} style={{
                padding: '4px 10px', fontSize: 10, fontWeight: 500,
                background: s === sortOrder ? `rgba(172,172,172, 0.25)` : 'transparent',
                color: s === sortOrder ? gold : 'rgba(215,215,215, 0.5)',
                border: s === sortOrder ? `1px solid rgba(172,172,172, 0.2)` : '1px solid transparent',
                borderRadius: 100, cursor: 'pointer', fontFamily: 'inherit',
                transition: 'background 0.15s, color 0.15s',
              }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                  {s === 'desc' && (
                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none"><path d="M12 4v16M6 14l6 6 6-6" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
                  )}
                  {s === 'asc' && (
                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none"><path d="M12 20V4M6 10l6-6 6 6" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
                  )}
                  {s === 'amount' && (
                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none"><path d="M12 3v18M7 7h7a3 3 0 010 6H8a3 3 0 000 6h9" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
                  )}
                  {s === 'desc' ? t('sort_newest') : s === 'asc' ? t('sort_oldest') : t('sort_amount')}
                </span>
              </button>
            ))}
          </div>
        </div>
        </div>
      </div>

    </>
    );
    const opsChart = (
    <>
      <div style={{ padding: '0 18px 18px' }}>
        <div style={{ padding: 20, ...glassCard({ borderRadius: 24, background: '#1c1c1e' }) }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 14 }}>
            <div>
              <div style={{ ...sectionLabel, padding: 0, marginBottom: 4 }}>{t('spending_this_month')}</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                <span style={{ ...T.h1, ...T.num, color: text.primary }}>{spentLabel}</span>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 4, padding: 3, background: 'rgba(36,36,36, 0.5)', borderRadius: 100 }}>
              {periodLabels.map((p, i) => (
                <button key={p} onClick={() => setPeriod(i)} style={{
                  padding: '4px 11px', fontSize: 11, fontWeight: 500,
                  background: i === period ? `${gold}` : 'transparent',
                  color: i === period ? '#161616' : 'rgba(215,215,215, 0.6)',
                  border: 'none', borderRadius: 100, cursor: 'pointer', fontFamily: 'inherit',
                }}>{p}</button>
              ))}
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 90, marginBottom: 8 }}>
            {values.map((v, i) => (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, height: '100%', justifyContent: 'flex-end' }}>
                <div style={{
                  width: '100%', height: `${(v / max) * 100}%`,
                  background: i === 6
                    ? `${goldLight}`
                    : 'rgba(172,172,172, 0.35)',
                  borderRadius: 6,
                  boxShadow: i === 6 ? '0 0 20px rgba(172,172,172, 0.4)' : 'none',
                }} />
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {labels.map((d, i) => (
              <div key={i} style={{ flex: 1, textAlign: 'center', fontSize: 10, color: i === 6 ? gold : 'rgba(215,215,215, 0.4)', fontWeight: i === 6 ? 600 : 400 }}>{d}</div>
            ))}
          </div>
        </div>
      </div>

    </>
    );
    const opsCategory = (
    <>
      {/* Category breakdown (only in "all" or "outcome" mode with real data) */}
      {(() => {
        const outTx = filtered.filter(tx => tx.direction === 'out');
        if (outTx.length === 0) return null;
        const catTotals: Record<string, number> = {};
        for (const tx of outTx) {
          const cat = txToCat(tx);
          catTotals[cat] = (catTotals[cat] || 0) + tx.amount;
        }
        const total = outTx.reduce((s, tx) => s + tx.amount, 0);
        const rows = Object.entries(catTotals)
          .sort(([, a], [, b]) => b - a)
          .map(([cat, amt]) => ({
            cat: cat as TxCat,
            pct: Math.round(amt / total * 100),
            amt,
          }));
        if (!rows.length) return null;
        const SPEND_LABELS: Record<string, string> = { transfer: t('spend_transfer'), food: t('spend_food'), transport: t('spend_transport'), utility: t('spend_utility'), shopping: t('spend_shopping'), subscription: t('spend_subscription'), income: t('filter_income') };
        return (
          <div style={{ padding: '0 18px 18px' }}>
            <div style={{ padding: 20, ...glassCard({ borderRadius: 24, background: '#1c1c1e' }) }}>
              <div style={{ fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 14 }}>{t('filter_outcome')}</div>
              {rows.map(({ cat, pct, amt }) => {
                const s = CAT_STYLES[cat];
                return (
                  <div key={cat} style={{ marginBottom: 10 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 5 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <div style={{ width: 20, height: 20, borderRadius: 6, background: s.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{s.icon}</div>
                        <span style={{ fontSize: 12, color: text.secondary }}>{SPEND_LABELS[cat] || cat}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                        <span style={{ fontSize: 12, color: text.secondary, fontFeatureSettings: '"tnum"' }}>{fmtInt(amt)}{fmtDec(amt)} TAX</span>
                        <span style={{ fontSize: 10, color: text.muted }}>{pct}%</span>
                      </div>
                    </div>
                    <div style={{ height: 4, background: 'rgba(255,255,255, 0.1)', borderRadius: 4 }}>
                      <div style={{ width: `${pct}%`, height: '100%', background: s.color, borderRadius: 4, opacity: 0.75, transition: 'width 0.4s ease' }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })()}

    </>
    );
    const opsPlanning = (
    <>
      {txFilter === 'all' && <InsightsStrip />}
      {txFilter === 'all' && <BudgetPlanner transactions={transactions} />}

      {/* Credits & Deposits — right after spending chart */}
      <div style={{ padding: '0 18px 4px' }}>
        <CreditsSection />
        <DepositsSection />
      </div>

    </>
    );
    const opsTxList = (
    <>
      {/* Transactions */}
      {txGroups.length === 0 && (
        <div style={{ padding: '40px 18px', textAlign: 'center', color: text.muted, fontSize: 14 }}>
          {searchQuery ? `${t('nothing_found_for')} «${searchQuery}»` : t('no_transactions_yet')}
        </div>
      )}
      {txGroups.map((g, gi) => {
        const net = g.items.reduce((sum, it) => sum + (it.positive ? 1 : -1) * (it.value ?? 0), 0);
        return (
        <div key={gi} style={{ padding: '4px 18px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 6px 8px' }}>
            <span style={{ ...T.caption, color: text.muted }}>{g.group}</span>
            {net !== 0 && <span style={{ fontSize: 12, color: text.dim, ...T.num }}>{net > 0 ? '+' : '−'}{fmtInt(net)}{fmtDec(net)}</span>}
          </div>
          <div style={{ background: '#1c1c1e', borderRadius: 22, overflow: 'hidden' }}>
            {g.items.map((item, i) => {
              const s = CAT_STYLES[item.cat];
              const open = () => { if (item.txId) { setSelectedTxId(item.txId); const tx = transactions.find(tx => tx.id === item.txId); setTxNote(tx?.note ?? ''); } };
              return (
                <Fragment key={i}>
                  <div
                    role={item.txId ? 'button' : undefined}
                    onClick={open}
                    className="kp-tx-row"
                    style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', cursor: item.txId ? 'pointer' : 'default' }}>
                    <Medallion tint={MEDALLION_TINT[item.cat] || '#FFD400'} size={46}>{recolorIcon(s.icon, MEDALLION_TINT[item.cat] || '#FFD400')}</Medallion>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ ...T.body, fontWeight: 500, color: text.primary, lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', overflowWrap: 'anywhere' }}>{item.title}</div>
                      <div style={{ ...T.sm, color: text.muted, marginTop: 3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.subtitle}</div>
                    </div>
                    <div style={{ flexShrink: 0, textAlign: 'right', fontSize: 16, fontWeight: 600, letterSpacing: -0.2, color: item.positive ? '#5fd68a' : text.primary, ...T.num }}>
                      {item.amount}
                      <div style={{ fontSize: 10.5, fontWeight: 500, color: text.dim, letterSpacing: 0.6, marginTop: 2 }}>TAX</div>
                    </div>
                  </div>
                  {i < g.items.length - 1 && <div style={{ height: 1, background: 'rgba(255,255,255, 0.06)', margin: '0 16px 0 72px' }} />}
                </Fragment>
              );
            })}
          </div>
        </div>
        );
      })}

    </>
    );
    const opsRecurring = <RecurringSection />;

  return (
    <>
    <ContentWrap maxW={layout === 'desktop' ? 1560 : 720}>
    <div style={{ paddingBottom: layout === 'desktop' ? 80 : 24 }}>
      {layout === 'desktop' ? (
        <div style={{ display: 'grid', gridTemplateColumns: opsWide ? 'minmax(0, 1fr) minmax(400px, 460px)' : 'minmax(0, 1fr)', gap: 24, alignItems: 'start' }}>
          <div className="kp-rise" style={{ minWidth: 0, margin: '0 -18px' }}>
            {opsHeader}
            {opsTxList}
          </div>
          <div className="kp-rise" style={{ minWidth: 0, margin: '0 -18px', ['--i' as string]: 1 }}>
            {opsChart}
            {opsCategory}
            {opsPlanning}
            {opsRecurring}
          </div>
        </div>
      ) : (
        <>
          {opsHeader}
          {opsChart}
          {opsCategory}
          {opsPlanning}
          {opsTxList}
          {opsRecurring}
        </>
      )}
      <div style={{ height: 20 }} />
    </div>
    </ContentWrap>

    {/* Transaction detail sheet */}
    {selectedTxId && selectedTxData && createPortal(
      <div className="tt-overlay" style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 300, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => setSelectedTxId(null)}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0, 0.55)', backdropFilter: 'blur(4px)' }} />
        <div className="tt-sheet" onClick={e => e.stopPropagation()} style={{
          position: 'relative', width: '100%', maxWidth: 520,
          background: '#1c1c1e',
          backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
          borderRadius: '24px 24px 0 0', padding: '14px 20px calc(28px + env(safe-area-inset-bottom,0px))',
          border: '1px solid transparent', borderBottom: 'none', maxHeight: '92vh', overflowY: 'auto',
        }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 22px' }} />
          {(() => {
            const tx = selectedTxData;
            const cat = txToCat(tx);
            const s = CAT_STYLES[cat];
            const incoming = tx.direction === 'in';
            const D = ({ uk: { date: 'Дата', kind: 'Категорія', who: 'Рахунок', no: 'Номер операції', done: 'Виконано' },
              en: { date: 'Date', kind: 'Category', who: 'Account', no: 'Operation no.', done: 'Completed' },
              it: { date: 'Data', kind: 'Categoria', who: 'Conto', no: 'N. operazione', done: 'Eseguita' },
              de: { date: 'Datum', kind: 'Kategorie', who: 'Konto', no: 'Vorgangsnr.', done: 'Ausgeführt' },
              ru: { date: 'Дата', kind: 'Категория', who: 'Счёт', no: 'Номер операции', done: 'Выполнено' } } as Record<string, Record<string, string>>)[lang] || {};
            const kind = ({ transfer: t('spend_transfer'), food: t('spend_food'), transport: t('spend_transport'), utility: t('spend_utility'), shopping: t('spend_shopping'), subscription: t('spend_subscription'), income: t('filter_income') } as Record<string, string>)[cat] || cat;
            const when = new Date(tx.created_at);
            const dateStr = isNaN(when.getTime()) ? tx.created_at.slice(0, 10) : when.toLocaleDateString(localeForLang(lang), { day: 'numeric', month: 'long', year: 'numeric' }) + ', ' + fmtTime(tx.created_at, lang);
            const rows: [string, string][] = [[D.date, dateStr], [D.kind, kind]];
            if (tx.related_account) rows.push([D.who, String(tx.related_account)]);
            rows.push([D.no, '№ ' + String(tx.id).padStart(8, '0')]);
            return (
              <>
                <div style={{ textAlign: 'center', marginBottom: 20 }}>
                  <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 14 }}><Medallion tint={MEDALLION_TINT[cat] || '#FFD400'} size={72}>{recolorIcon(s.icon, MEDALLION_TINT[cat] || '#FFD400')}</Medallion></div>
                  <div style={{ fontSize: 15, color: text.muted, lineHeight: 1.35, overflowWrap: 'anywhere', padding: '0 8px' }}>{tx.description}</div>
                  <div style={{ fontSize: 34, fontWeight: 700, letterSpacing: -1, marginTop: 8, color: incoming ? '#5fd68a' : text.primary, ...T.num }}>
                    {incoming ? '+' : '−'}{fmtInt(tx.amount)}<span style={{ fontSize: 20, color: text.muted }}>{fmtDec(tx.amount)}</span>
                    <span style={{ fontSize: 15, fontWeight: 600, color: text.muted, marginLeft: 6, letterSpacing: 0.4 }}>TAX</span>
                  </div>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 10, padding: '4px 11px', borderRadius: 100, background: 'rgba(95,214,138, 0.12)', color: '#5fd68a', fontSize: 12, fontWeight: 600 }}>
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
                    {D.done}
                  </div>
                </div>
                <div style={{ background: 'rgba(255,255,255, 0.05)', borderRadius: 18, padding: '4px 16px', marginBottom: 18 }}>
                  {rows.map(([k, v], i) => (
                    <div key={k} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 16, padding: '12px 0', borderTop: i ? '1px solid rgba(255,255,255, 0.06)' : 'none' }}>
                      <span style={{ fontSize: 13, color: text.muted, flexShrink: 0 }}>{k}</span>
                      <span style={{ fontSize: 14, color: text.secondary, textAlign: 'right', overflowWrap: 'anywhere', ...T.num }}>{v}</span>
                    </div>
                  ))}
                </div>
                <button onClick={() => downloadReceipt(tx.id)} disabled={dlReceipt === tx.id} style={{ ...docPill, width: '100%', justifyContent: 'center', height: 48, marginBottom: 22, fontSize: 14, color: '#161616', border: '1px solid rgba(255,255,255,0.35)', background: 'linear-gradient(180deg, #FFE566 0%, #FFD400 48%, #E6B800 100%)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), inset 0 0 0 3px rgba(0,0,0,0.05), 0 8px 22px rgba(255,212,0,0.22)', opacity: dlReceipt === tx.id ? 0.6 : 1 }}>
                  <ReceiptIcon size={16} color="#161616" />
                  {dlReceipt === tx.id ? '…' : t('download_receipt')}
                </button>
                {sealDoc && <DocSeal doc={sealDoc} lang={lang} />}
              </>
            );
          })()}
          <label style={{ fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, display: 'block', marginBottom: 8 }}>{t('tx_note_label')}</label>
          <textarea
            value={txNote}
            onChange={e => setTxNote(e.target.value)}
            placeholder={t('tx_note_placeholder')}
            rows={3}
            style={{ width: '100%', padding: '12px 14px', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: 14, color: text.primary, fontSize: 14, outline: 'none', fontFamily: 'inherit', resize: 'none', boxSizing: 'border-box' }}
          />
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <button onClick={() => setSelectedTxId(null)} style={{ flex: 1, padding: '12px', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: 14, color: text.muted, fontSize: 14, fontWeight: 500, fontFamily: 'inherit', cursor: 'pointer' }}>
              {t('cancel_label')}
            </button>
            <button onClick={saveNote} disabled={savingNote} style={{ flex: 2, padding: '12px', background: `${gold}`, border: 'none', borderRadius: 14, color: '#161616', fontSize: 14, fontWeight: 700, fontFamily: 'inherit', cursor: 'pointer', opacity: savingNote ? 0.7 : 1 }}>
              {savingNote ? '…' : t('profile_save')}
            </button>
          </div>
        </div>
      </div>,
      document.body
    )}
    {docsOpen && <DocumentsSheet onClose={() => setDocsOpen(false)} lang={lang} />}
    </>
  );
}

// ─── Profile screen ───────────────────────────────────────────
function ProfileRow({ label, value, mono, copyable, last }: { label: string; value: string; mono?: boolean; copyable?: boolean; last?: boolean }) {
  const { toast } = useApp();
  const copy = () => {
    const tt = translations[getStoredLanguage()];
    navigator.clipboard.writeText(value).then(() => toast(`${tt.copy_success}: ${value}`)).catch(() => toast(tt.copy_failed));
  };
  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 18px', gap: 12 }}>
        <span style={{ ...T.caption, color: text.muted }}>{label}</span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
          <span style={{
            fontSize: 14, color: text.secondary, fontWeight: 500,
            fontFamily: mono ? '"SF Mono", monospace' : 'inherit',
            fontFeatureSettings: '"tnum"', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          }}>{value}</span>
          {copyable && (
            <button onClick={copy} style={{
              width: 26, height: 26, borderRadius: 7, background: `rgba(255,255,255, 0.1)`,
              border: `1px solid transparent`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0, flexShrink: 0,
            }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none"><rect x="9" y="9" width="11" height="11" rx="2" stroke={gold} strokeWidth="2" /><path d="M5 15V5a2 2 0 012-2h10" stroke={gold} strokeWidth="2" /></svg>
            </button>
          )}
        </div>
      </div>
      {!last && <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />}
    </>
  );
}

function ProfileToggle({ label, sub, on, onChange, icon }: { label: string; sub?: string; on: boolean; onChange: (v: boolean) => void; icon: React.ReactNode }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 18px' }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10, background: 'rgba(255,255,255, 0.1)',
        border: `1px solid transparent`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, color: text.secondary, fontWeight: 500, marginBottom: 2 }}>{label}</div>
        {sub && <div style={{ fontSize: 11.5, color: text.muted }}>{sub}</div>}
      </div>
      <button onClick={() => onChange(!on)} style={{
        width: 44, height: 26, borderRadius: 100,
        background: on ? `${goldDark}` : 'rgba(172,172,172, 0.15)',
        border: 'none', padding: 0, cursor: 'pointer', position: 'relative', transition: 'background 0.2s',
        boxShadow: on ? 'inset 0 1px 0 rgba(225,225,225, 0.4)' : 'none',
      }}>
        <div style={{
          position: 'absolute', top: 3, left: on ? 21 : 3,
          width: 20, height: 20, borderRadius: '50%', background: '#ffffff',
          transition: 'left 0.2s',
          boxShadow: '0 1px 4px rgba(0,0,0, 0.25)',
        }} />
      </button>
    </div>
  );
}

function ProfileScreen() {
  const layout = useLayout();
  const topPad = useTopPad();
  const { logout, user, account, toast } = useApp();
  const { profilePhoto, setProfilePhotoValue, lang, setLang, t } = usePreferences();
  const [faceid, setFaceid] = useState(false);
  const [faceIdReady, setFaceIdReady] = useState(false);
  const [faceIdBusy, setFaceIdBusy] = useState(false);
  const [push, setPush] = useState(true);
  const [notifTx, setNotifTx] = useState(true);
  const [notifSec, setNotifSec] = useState(true);
  const [notifPromo, setNotifPromo] = useState(false);
  // Budget limits
  const [limits, setLimits] = useState<{ tx_type: string; monthly_limit: number; spent: number }[]>([]);
  const [newLimitType, setNewLimitType] = useState('transfer');
  const [newLimitAmt, setNewLimitAmt] = useState('');
  const [limitsLoading, setLimitsLoading] = useState(false);
  // PIN
  const [pinStatus, setPinStatus] = useState(false);
  const [showPinForm, setShowPinForm] = useState(false);
  const [pinInput, setPinInput] = useState('');
  const [pinLoading, setPinLoading] = useState(false);
  const photoInputRef = useRef<HTMLInputElement | null>(null);

  // Check passkey status on mount
  useEffect(() => {
    const checkFaceId = async () => {
      if (!window.PublicKeyCredential) return;
      const available = await window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().catch(() => false);
      if (!available) return;
      setFaceIdReady(true);
      const token = localStorage.getItem('army_bank_token');
      const res = await fetch('/api/auth/passkey/status', { headers: { Authorization: `Bearer ${token}` } }).catch(() => null);
      if (res?.ok) {
        const json = await res.json();
        setFaceid(json.data?.has_passkey ?? false);
      }
    };
    checkFaceId();
  }, []);

  async function handleFaceIdToggle(on: boolean) {
    if (faceIdBusy) return;
    setFaceIdBusy(true);
    const token = localStorage.getItem('army_bank_token');
    try {
      if (on) {
        // Register passkey
        const optRes = await fetch('/api/auth/passkey/register-options', {
          method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: '{}',
        });
        const optJson = await optRes.json();
        if (!optRes.ok || !optJson.ok) throw new Error(optJson.error || t('operation_error'));
        const attResp = await startRegistration({ optionsJSON: optJson.data });
        const verRes = await fetch('/api/auth/passkey/register', {
          method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: JSON.stringify(attResp),
        });
        const verJson = await verRes.json();
        if (!verRes.ok || !verJson.ok) throw new Error(verJson.error || t('registration_error'));
        setFaceid(true);
        toast(t('face_id_on'));
      } else {
        // Remove passkey
        const res = await fetch('/api/auth/passkey/remove', { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
        const json = await res.json();
        if (!res.ok || !json.ok) throw new Error(json.error || t('operation_error'));
        setFaceid(false);
        toast(t('face_id_off'));
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : t('operation_error');
      if (!msg.toLowerCase().includes('cancel') && !msg.toLowerCase().includes('abort') && !msg.toLowerCase().includes('not allowed')) {
        toast(msg);
      }
    } finally {
      setFaceIdBusy(false);
    }
  }
  // Load budget limits + PIN status
  useEffect(() => {
    const tk = localStorage.getItem('army_bank_token');
    // Limits
    fetch('/api/budget-limits', { headers: { Authorization: `Bearer ${tk}` } })
      .then(r => r.json()).then(j => { if (j.ok) setLimits(j.data); }).catch(() => {});
    // PIN
    fetch('/api/auth/pin/status', { headers: { Authorization: `Bearer ${tk}` } })
      .then(r => r.json()).then(j => { if (j.ok) setPinStatus(j.data?.has_pin ?? false); }).catch(() => {});
  }, []);

  async function addLimit(e: React.FormEvent) {
    e.preventDefault();
    const amt = parseFloat(newLimitAmt.replace(',', '.'));
    if (!amt) return;
    setLimitsLoading(true);
    try {
      const tk = localStorage.getItem('army_bank_token');
      const idempotencyKey = `budget-limit-${newLimitType}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const r = await fetch('/api/budget-limits', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tk}`, 'Idempotency-Key': idempotencyKey },
        body: JSON.stringify({ tx_type: newLimitType, monthly_limit: amt, idempotency_key: idempotencyKey }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error);
      const r2 = await fetch('/api/budget-limits', { headers: { Authorization: `Bearer ${tk}` } });
      const j2 = await r2.json();
      if (j2.ok) setLimits(j2.data);
      setNewLimitAmt('');
      toast(tr('✓ Ліміт встановлено', '✓ Limit set'));
    } catch (e) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setLimitsLoading(false); }
  }

  async function deleteLimit(tx_type: string) {
    const tk = localStorage.getItem('army_bank_token');
    await fetch(`/api/budget-limits/${tx_type}`, { method: 'DELETE', headers: { Authorization: `Bearer ${tk}` } });
    setLimits(prev => prev.filter(l => l.tx_type !== tx_type));
    toast(tr('✓ Ліміт видалено', '✓ Limit removed'));
  }

  async function setPin(e: React.FormEvent) {
    e.preventDefault();
    if (pinInput.length < 4) { toast(tr('Мінімум 4 цифри', 'At least 4 digits')); return; }
    setPinLoading(true);
    try {
      const tk = localStorage.getItem('army_bank_token');
      const r = await fetch('/api/auth/pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tk}` },
        body: JSON.stringify({ pin: pinInput }),
      });
      const j = await r.json();
      if (!j.ok) throw new Error(j.error || t('operation_error'));
      setPinStatus(true); setShowPinForm(false); setPinInput('');
      toast(tr('✓ PIN встановлено', '✓ PIN set'));
    } catch (e) { toast(e instanceof Error ? e.message : t('operation_error')); }
    finally { setPinLoading(false); }
  }

  async function clearPin() {
    const tk = localStorage.getItem('army_bank_token');
    const r = await fetch('/api/auth/pin', { method: 'DELETE', headers: { Authorization: `Bearer ${tk}` } });
    const j = await r.json();
    if (j.ok) { setPinStatus(false); toast(tr('✓ PIN видалено', '✓ PIN removed')); }
  }

  const [changingPwd, setChangingPwd] = useState(false);
  const [oldPwd, setOldPwd] = useState('');
  const [newPwd, setNewPwd] = useState('');
  const [pwdLoading, setPwdLoading] = useState(false);
  const [achievements, setAchievements] = useState<{ achievements: Achievement[]; done: number; total: number } | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) return;
    fetch('/api/achievements', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok && j.data) setAchievements(j.data); })
      .catch(() => {});
  }, []);

  const displayName = user?.full_name ?? t('user_fallback');
  const userInitials = initials(displayName);
  const phone = user?.phone
    ? ('+' + user.phone.replace(/^\+/, '')).replace(/^\+(\d{3})(\d{2})(\d{3})(\d{2})(\d{2})$/, '+$1 $2 $3 $4 $5')
    : '—';

  async function changePassword(e: React.FormEvent) {
    e.preventDefault();
    setPwdLoading(true);
    try {
      const token = localStorage.getItem('army_bank_token');
      const res = await fetch('/api/auth/password', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ old_password: oldPwd, new_password: newPwd }),
      });
      const json = await res.json();
      if (!res.ok || !json.ok) throw new Error(json.message || t('operation_error'));
      toast(t('password_changed'));
      setChangingPwd(false); setOldPwd(''); setNewPwd('');
    } catch (err: unknown) {
      toast(err instanceof Error ? err.message : t('operation_error'));
    } finally {
      setPwdLoading(false);
    }
  }

  function onPickProfilePhoto(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      toast(t('pick_image'));
      return;
    }
    if (file.size > 3 * 1024 * 1024) {
      toast(t('photo_too_large'));
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const value = typeof reader.result === 'string' ? reader.result : '';
      if (!value) {
        toast(t('photo_read_error'));
        return;
      }
      setProfilePhoto(value);
      setProfilePhotoValue(value);
      toast(t('photo_updated'));
    };
    reader.onerror = () => toast(t('photo_upload_error'));
    reader.readAsDataURL(file);
    e.target.value = '';
  }

  function removeProfilePhoto() {
    setProfilePhoto('');
    setProfilePhotoValue('');
    toast(t('photo_removed'));
  }

  const languageOptions: { value: AppLang; label: string }[] = [
    { value: 'uk', label: t('lang_uk') },
    { value: 'en', label: t('lang_en') },
    { value: 'it', label: t('lang_it') },
    { value: 'de', label: t('lang_de') },
    { value: 'ru', label: t('lang_ru') },
  ];

  const section = (children: React.ReactNode) => (
    <div style={{ breakInside: 'avoid', background: '#1c1c1e', border: `1px solid ${bg.border}`, borderRadius: 22, overflow: 'hidden', margin: '0 18px 14px', boxShadow: '0 16px 34px rgba(0,0,0, 0.14)' }}>
      {children}
    </div>
  );
  const sectionTitleWrapStyle: React.CSSProperties = { padding: '4px 18px 8px', breakAfter: 'avoid', breakInside: 'avoid' };

  return (
    <ContentWrap maxW={layout === 'desktop' ? 1240 : 680}>
    <div style={{ paddingBottom: layout === 'desktop' ? 80 : 24 }}>
      <div style={{ padding: `${topPad} 18px 18px` }}>
        <div style={{
          ...glassCard({
            padding: '22px 18px 18px',
            borderRadius: 28,
            background: '#1c1c1e',
            boxShadow: '0 22px 44px rgba(0,0,0, 0.22)',
          }),
          position: 'relative',
          overflow: 'hidden',
        }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <input
          ref={photoInputRef}
          type="file"
          accept="image/*"
          onChange={onPickProfilePhoto}
          style={{ display: 'none' }}
        />
        <div style={{
          width: 80, height: 80, borderRadius: '50%',
          background: `${gold}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 28, fontWeight: 700, color: '#242424', letterSpacing: 0.5,
          boxShadow: `0 0 0 3px rgba(0,0,0, 0.6), 0 0 0 5px ${gold}55`,
          marginBottom: 14,
          overflow: 'hidden',
        }}>
          {profilePhoto ? (
            <img src={profilePhoto} alt={t('profile_photo_alt')} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            userInitials
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
          <button
            onClick={() => photoInputRef.current?.click()}
            style={{
              padding: '6px 12px', borderRadius: 10, border: '1px solid transparent',
              background: 'rgba(255,255,255, 0.1)', color: text.secondary, fontSize: 12, fontWeight: 600, cursor: 'pointer',
            }}
          >
            {t('profile_change_photo')}
          </button>
          {profilePhoto && (
            <button
              onClick={removeProfilePhoto}
              style={{
                padding: '6px 12px', borderRadius: 10, border: '1px solid transparent',
                background: 'rgba(255,255,255, 0.1)', color: '#c3c3c3', fontSize: 12, fontWeight: 600, cursor: 'pointer',
              }}
            >
              {t('profile_remove_photo')}
            </button>
          )}
        </div>
        <div style={{ ...T.h2, color: text.primary, marginBottom: 4 }}>{displayName}</div>
        <div style={{ fontSize: 12, color: text.muted, marginBottom: 12 }}>{account?.account_number ?? '—'}</div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: '#5fd68a', fontSize: 12.5, fontWeight: 600 }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 2l2.4 2 3.1-.3 1 3 2.7 1.6-.9 3 .9 3-2.7 1.6-1 3-3.1-.3L12 22l-2.4-2-3.1.3-1-3L2.8 15.7l.9-3-.9-3 2.7-1.6 1-3 3.1.3L12 2z" fill="currentColor" opacity="0.22" /><path d="M8.5 12.2l2.4 2.4 4.6-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
          {t('profile_verified')}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 1px minmax(0, 1fr)', width: '100%', marginTop: 22, paddingTop: 18, borderTop: '1px solid rgba(255,255,255,0.07)', alignItems: 'center' }}>
          <div style={{ textAlign: 'center', padding: '0 8px' }}>
            <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 6 }}>{t('profile_phone')}</div>
            <div style={{ fontSize: 14.5, color: text.primary, fontWeight: 600, letterSpacing: -0.2, whiteSpace: 'nowrap', ...T.num }}>{phone}</div>
          </div>
          <div style={{ alignSelf: 'stretch', background: 'rgba(255,255,255,0.07)' }} />
          <div style={{ textAlign: 'center', padding: '0 8px' }}>
            <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 6 }}>{t('balance_total')}</div>
            <div style={{ fontSize: 14.5, color: text.primary, fontWeight: 600, letterSpacing: -0.2, whiteSpace: 'nowrap', ...T.num }}>{formatUah(Number(account?.balance || 0), lang)}</div>
          </div>
        </div>
        </div>
        </div>
      </div>

      <div style={layout === 'desktop' ? { columnCount: 2, columnGap: 0, margin: '0 -0px' } : undefined}>
      {/* Account info */}
      {section(<>
        <ProfileRow label={t('profile_name')} value={displayName} />
        <ProfileRow label={t('profile_phone')} value={phone} mono />
        <ProfileRow label={t('profile_email')} value={user?.email ?? '—'} copyable />
        <ProfileRow label={t('profile_account')} value={account?.account_number ?? '—'} mono copyable last />
      </>)}

      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('settings_language')}</div>
      </div>
      {section(
        <div style={{ padding: '14px 18px' }}>
          <div style={{ fontSize: 14, color: text.secondary, fontWeight: 500, marginBottom: 4 }}>{t('settings_language')}</div>
          <div style={{ fontSize: 11.5, color: text.muted, marginBottom: 12 }}>{t('settings_language_sub')}</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 10 }}>
            {languageOptions.map(option => {
              const active = option.value === lang;
              return (
                <button
                  key={option.value}
                  onClick={() => setLang(option.value)}
                  style={{
                    padding: '11px 12px',
                    borderRadius: 12,
                    border: active ? `1px solid rgba(172,172,172, 0.34)` : '1px solid transparent',
                    background: active ? 'rgba(172,172,172, 0.16)' : 'rgba(255,255,255, 0.1)',
                    color: active ? text.primary : text.secondary,
                    fontSize: 13,
                    fontWeight: active ? 700 : 500,
                    cursor: 'pointer',
                    fontFamily: 'inherit',
                  }}
                >
                  {option.label}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Security */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('profile_security')}</div>
      </div>
      {section(<>
        {faceIdReady ? (
          <ProfileToggle
            label="Face ID"
            sub={faceIdBusy ? t('wait_processing') : t('face_id_transfer_sub')}
            on={faceid}
            onChange={handleFaceIdToggle}
            icon={
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={gold} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M2 9V5a2 2 0 012-2h3M2 15v4a2 2 0 002 2h3M22 9V5a2 2 0 00-2-2h-3M22 15v4a2 2 0 01-2 2h-3"/>
                <circle cx="9" cy="10" r="0.6" fill={gold} stroke="none"/>
                <circle cx="15" cy="10" r="0.6" fill={gold} stroke="none"/>
                <path d="M9 15c0 0 1 1.5 3 1.5s3-1.5 3-1.5"/>
                <path d="M12 7v2"/>
              </svg>
            }
          />
        ) : (
          <ProfileToggle label="Face ID" sub={t('face_id_unavailable')} on={false} onChange={() => {}}
            icon={<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="rgba(172,172,172, 0.35)" strokeWidth="1.5" strokeLinecap="round"><path d="M2 9V5a2 2 0 012-2h3M2 15v4a2 2 0 002 2h3M22 9V5a2 2 0 00-2-2h-3M22 15v4a2 2 0 01-2 2h-3"/></svg>}
          />
        )}
        <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
        <ProfileToggle label={t('push_notifications')} on={push} onChange={setPush}
          icon={<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9M10 21a2 2 0 004 0" stroke={gold} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>}
        />
      </>)}

      {/* Change password */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('profile_password')}</div>
      </div>
      {section(<>
        <div
          onClick={() => setChangingPwd(v => !v)}
          style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 18px', cursor: 'pointer' }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="4" y="11" width="16" height="10" rx="2" stroke={gold} strokeWidth="1.6" /><path d="M8 11V8a4 4 0 018 0v3" stroke={gold} strokeWidth="1.6" /></svg>
            </div>
            <span style={{ fontSize: 14, color: text.secondary, fontWeight: 500 }}>{t('profile_change_password')}</span>
          </div>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="none" style={{ transform: changingPwd ? 'rotate(90deg)' : 'none', transition: 'transform 0.2s' }}>
            <path d="M6 4l4 4-4 4" stroke={text.muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        {changingPwd && (
          <>
            <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
            <form onSubmit={changePassword} style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column', gap: 10 }}>
              <input
                type="password" placeholder={t('profile_current_password')} value={oldPwd} onChange={e => setOldPwd(e.target.value)} required
                style={{ padding: '11px 14px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: text.primary, fontSize: 14, outline: 'none', fontFamily: 'inherit' }}
              />
              <input
                type="password" placeholder={t('profile_new_password')} value={newPwd} onChange={e => setNewPwd(e.target.value)} required
                style={{ padding: '11px 14px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: text.primary, fontSize: 14, outline: 'none', fontFamily: 'inherit' }}
              />
              <button type="submit" disabled={pwdLoading} style={{
                padding: '11px', background: pwdLoading ? 'rgba(95,95,95, 0.3)' : `${goldDark}`,
                border: 'none', borderRadius: 10, color: text.primary, fontSize: 13, fontWeight: 600, fontFamily: 'inherit', cursor: pwdLoading ? 'default' : 'pointer',
              }}>{pwdLoading ? '…' : t('profile_save')}</button>
            </form>
          </>
        )}
      </>)}

      {/* Notifications */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('settings_notifications')}</div>
      </div>
      {section(<>
        <ProfileToggle label={t('settings_notif_tx')} on={notifTx} onChange={setNotifTx}
          icon={<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6V11c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z" fill={gold} fillOpacity={0.7}/></svg>}
        />
        <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
        <ProfileToggle label={t('settings_notif_security')} on={notifSec} onChange={setNotifSec}
          icon={<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="4" y="11" width="16" height="10" rx="2" stroke={gold} strokeWidth="1.6"/><path d="M8 11V8a4 4 0 018 0v3" stroke={gold} strokeWidth="1.6"/></svg>}
        />
        <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
        <ProfileToggle label={t('settings_notif_promo')} on={notifPromo} onChange={setNotifPromo}
          icon={<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M20 12V6H4v6M4 6l8 7 8-7" stroke="rgba(172,172,172, 0.5)" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>}
        />
      </>)}

      {/* Budget Limits */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('settings_limits')}</div>
      </div>
      {section(
        <div style={{ padding: '14px 18px' }}>
          <div style={{ fontSize: 12, color: text.muted, marginBottom: 12 }}>{t('settings_limits_sub')}</div>
          {limits.map(lim => {
            const pct = lim.monthly_limit > 0 ? Math.min(100, Math.round(lim.spent / lim.monthly_limit * 100)) : 0;
            const over = pct >= 100;
            return (
              <div key={lim.tx_type} style={{ marginBottom: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 5 }}>
                  <div style={{ fontSize: 13, color: text.secondary, fontWeight: 500, textTransform: 'capitalize' }}>{lim.tx_type}</div>
                  <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                    <span style={{ fontSize: 11, color: over ? '#989898' : text.muted }}>
                      {Number(lim.spent).toLocaleString('uk-UA')}{'\u00a0TAX'} {t('settings_limit_of')} {Number(lim.monthly_limit).toLocaleString('uk-UA')}{'\u00a0TAX'}
                    </span>
                    <button onClick={() => deleteLimit(lim.tx_type)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#989898', fontSize: 12, padding: 0 }}>✕</button>
                  </div>
                </div>
                <div style={{ height: 4, background: 'rgba(255,255,255, 0.1)', borderRadius: 2, overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${pct}%`, background: over ? '#989898' : `${goldDark}`, borderRadius: 2 }} />
                </div>
              </div>
            );
          })}
          <form onSubmit={addLimit} style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <select value={newLimitType} onChange={e => setNewLimitType(e.target.value)}
              style={{ flex: 1, padding: '9px 10px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: text.secondary, fontSize: 13, outline: 'none', fontFamily: 'inherit' }}>
              {['transfer','food','transport','utility','shopping','subscription'].map(v => <option key={v} value={v}>{v}</option>)}
            </select>
            <input value={newLimitAmt} onChange={e => setNewLimitAmt(e.target.value)}
              placeholder="5000" type="text" inputMode="decimal"
              style={{ width: 80, padding: '9px 10px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: text.secondary, fontSize: 13, outline: 'none', fontFamily: 'inherit' }}
            />
            <button type="submit" disabled={limitsLoading}
              style={{ padding: '9px 12px', borderRadius: 10, border: 'none', background: `${goldDark}`, color: '#242424', fontSize: 12, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit' }}>
              {t('settings_limit_add')}
            </button>
          </form>
        </div>
      )}

      {/* PIN */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('settings_pin')}</div>
      </div>
      {section(<>
        <div style={{ padding: '14px 18px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: pinStatus ? 12 : 0 }}>
            <div>
              <div style={{ fontSize: 14, color: text.secondary, fontWeight: 500 }}>{t('settings_pin')}</div>
              <div style={{ fontSize: 11.5, color: text.muted }}>{pinStatus ? t('settings_pin_active') : t('settings_pin_sub')}</div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              {pinStatus && (
                <button onClick={clearPin} style={{ padding: '6px 10px', borderRadius: 8, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', color: '#989898', fontSize: 11, cursor: 'pointer', fontFamily: 'inherit' }}>{t('settings_pin_clear')}</button>
              )}
              <button onClick={() => setShowPinForm(v => !v)} style={{ padding: '6px 12px', borderRadius: 8, background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, color: gold, fontSize: 11, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
                {pinStatus ? t('settings_pin_change') : t('settings_pin_set')}
              </button>
            </div>
          </div>
          {showPinForm && (
            <form onSubmit={setPin} style={{ display: 'flex', gap: 8, marginTop: 10 }}>
              <input
                type="password" inputMode="numeric" pattern="[0-9]*" maxLength={8}
                value={pinInput} onChange={e => setPinInput(e.target.value.replace(/\D/g, '').slice(0, 8))}
                placeholder="••••"
                style={{ flex: 1, padding: '10px 12px', background: 'rgba(255,255,255, 0.1)', border: `1px solid transparent`, borderRadius: 10, color: text.primary, fontSize: 20, letterSpacing: 8, outline: 'none', fontFamily: 'inherit' }}
              />
              <button type="submit" disabled={pinLoading || pinInput.length < 4} style={{ padding: '10px 16px', borderRadius: 10, border: 'none', background: pinInput.length >= 4 ? `${goldDark}` : 'rgba(95,95,95, 0.3)', color: '#242424', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', fontSize: 13 }}>
                {pinLoading ? '…' : t('profile_save')}
              </button>
            </form>
          )}
        </div>
      </>)}

      {/* App info */}
      <div style={sectionTitleWrapStyle}>
        <div style={{ ...sectionLabel }}>{t('settings_app_info')}</div>
      </div>
      {section(<>
        <ProfileRow label={t('settings_version')} value="2026.04 · build 06" />
        <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
        <div style={{ padding: '13px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}
          onClick={() => window.open('/api-status', '_blank')} className="clickable">
          <span style={{ fontSize: 14, color: text.secondary, fontWeight: 500 }}>{t('settings_api_status')}</span>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M6 4l4 4-4 4" stroke={text.muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </div>
        <div style={{ height: 1, background: 'rgba(255,255,255, 0.1)', margin: '0 18px' }} />
        <ProfileRow label={t('settings_support')} value="bank.munister.com.ua" copyable last />
      </>)}

      {/* Achievements */}
      {achievements && (
        <div style={{ margin: '0 18px 14px', breakInside: 'avoid' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ ...T.h3, color: text.secondary }}>{t('achievements_title')}</span>
            <span style={{ fontSize: 12, color: text.muted }}>{achievements.done}/{achievements.total} {t('achievements_progress')}</span>
          </div>
          <div style={{ height: 3, background: 'rgba(255,255,255, 0.1)', borderRadius: 3, marginBottom: 14, overflow: 'hidden' }}>
            <div style={{ height: '100%', width: `${(achievements.done / achievements.total) * 100}%`, background: `${gold}`, borderRadius: 3, transition: 'width 0.6s ease' }} />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: layout === 'mobile' ? 'repeat(2, minmax(0, 1fr))' : 'repeat(4, 1fr)', gap: 10 }}>
            {achievements.achievements.map(a => (
              <div key={a.id} style={{
                display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 10, padding: '12px',
                background: a.done ? 'rgba(169,169,169, 0.12)' : 'rgba(255,255,255, 0.1)',
                border: `1px solid ${a.done ? 'rgba(169,169,169, 0.18)' : 'rgba(172,172,172, 0.08)'}`,
                borderRadius: 16, opacity: a.done ? 1 : 0.72, transition: 'opacity 0.3s',
              }}>
                <div style={{ width: 34, height: 34, borderRadius: 12, background: a.done ? 'rgba(169,169,169, 0.14)' : 'rgba(172,172,172, 0.08)', border: `1px solid ${a.done ? 'rgba(169,169,169, 0.22)' : 'rgba(172,172,172, 0.12)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: a.done ? '#c5c5c5' : gold, fontSize: 11, fontWeight: 800, letterSpacing: 0.6 }}>
                  {achTitle(a).split(/\s+/).slice(0, 2).map(part => part[0]).join('').slice(0, 2).toUpperCase()}
                </div>
                <div style={{ fontSize: 11.5, color: a.done ? text.secondary : text.muted, lineHeight: 1.35, fontWeight: a.done ? 600 : 500 }}>
                  {achTitle(a)}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Referral */}
      <div style={{ breakInside: 'avoid' }}><ReferralWidget user={user} /></div>

      {/* Sign out */}
      <div style={{ padding: '8px 18px', breakInside: 'avoid' }}>
        <button onClick={logout} style={{
          width: '100%', padding: '14px', borderRadius: 16,
          background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent',
          color: '#7e7e7e', fontSize: 14, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 16l4-4-4-4M21 12H9M13 4a9 9 0 100 16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>
          {t('profile_logout')}
        </button>
      </div>
      </div>
    </div>
    </ContentWrap>
  );
}

// ─── Bottom tab bar ───────────────────────────────────────────

// ─── Marketplace screen ───────────────────────────────────────
interface Product { id: number; title: string; description?: string; price: number; currency?: string; image_emoji?: string; image_url?: string; badge?: string; stock?: number; slug?: string; }
interface MarketOrder { id: number; total_amount: number; currency: string; status: string; invoice_number?: string; invoice_status?: string; created_at?: string; items_count?: number; }
interface MarketInvoice { invoice_number: string; amount: number; currency: string; status: string; due_at?: string; paid_at?: string; created_at?: string; order_id?: number; }
interface CartItem { product: Product; qty: number; size?: string; }
const cartKey = (i: CartItem) => `${i.product.id}|${i.size || ''}`;
const isShopProduct = (p: Product) => String(p.slug || '').startsWith('munister-');

const shipErrStyle: React.CSSProperties = { borderColor: '#d0594a' };
function ShipError({ text: msg }: { text: string }) {
  return <div role="alert" style={{ marginTop: 5, fontSize: 12, color: '#e07a6c' }}>{msg}</div>;
}

/** Delivery form rules; the backend wants a name and an address of 8+ characters. */
function validateShipping(name: string, phone: string, addr: string, uk: boolean): { name?: string; phone?: string; address?: string } {
  const e: { name?: string; phone?: string; address?: string } = {};
  const n = name.trim();
  if (!n) e.name = tr('Вкажіть імʼя та прізвище одержувача', 'Enter the recipient\u2019s full name');
  else if (n.length < 2 || !/^[\p{L}][\p{L}\s'’.\-]*$/u.test(n)) e.name = tr('Лише літери, щонайменше 2', 'Letters only, at least 2');
  const digits = phone.replace(/\D/g, '');
  const p = (phone.trim().startsWith('+') ? '+' : '') + digits;
  if (!phone.trim()) e.phone = tr('Вкажіть номер телефону', 'Enter a phone number');
  else if (!/^\+?\d{9,15}$/.test(p) || (p.startsWith('0') && p.length !== 10)) e.phone = tr('Невірний номер, приклад: +380 50 123 45 67', 'Invalid number, e.g. +380 50 123 45 67');
  if (!addr.trim()) e.address = tr('Вкажіть адресу або відділення Нової пошти', 'Enter an address or a Nova Poshta branch');
  else if (addr.trim().length < 8) e.address = tr('Додайте місто, вулицю й номер (мінімум 8 символів)', 'Add the city, street and number (8+ characters)');
  return e;
}

const BADGE_COLORS: Record<string, { bg: string; color: string }> = {
  'HOT':      { bg: 'rgba(94,94,94, 0.15)', color: '#888888' },
  'NEW':      { bg: 'rgba(150,150,150, 0.15)', color: '#a9a9a9' },
  'TOP':      { bg: 'rgba(168,168,168, 0.15)', color: gold },
  'SALE':     { bg: 'rgba(135,135,135, 0.15)', color: '#9e9e9e' },
  'PRO':      { bg: 'rgba(111,111,111, 0.15)', color: '#999999' },
  'GAMING':   { bg: 'rgba(101,101,101, 0.15)', color: '#8b8b8b' },
  'DEAL': { bg: 'rgba(172,172,172, 0.15)', color: gold },
  'M3':       { bg: 'rgba(113,113,113, 0.15)', color: '#9a9a9a' },
  'M4':       { bg: 'rgba(113,113,113, 0.15)', color: '#9a9a9a' },
};

function productBrand(p: Product): string {
  return String(p.description || '').split(' · ')[0].trim();
}
function productName(p: Product): string {
  const name = String(p.title || '').replace(/\s*\([^)]*\)\s*$/, '').trim();
  const brand = productBrand(p);
  if (brand && name.toLowerCase().endsWith(brand.toLowerCase())) {
    const rest = name.slice(0, name.length - brand.length).trim();
    if (rest) return rest;
  }
  return name;
}

const SHOP_CATEGORIES: { k: string; uk: string; en: string }[] = [
  { k: '', uk: 'Усе', en: 'All' },
  { k: 'women', uk: 'Жінкам', en: 'Women' },
  { k: 'men', uk: 'Чоловікам', en: 'Men' },
  { k: 'shoes', uk: 'Взуття', en: 'Shoes' },
  { k: 'bags', uk: 'Сумки', en: 'Bags' },
  { k: 'accessories', uk: 'Аксесуари', en: 'Accessories' },
];

const SHOP_FONT = "'Jost', 'Inter', ui-sans-serif, system-ui, sans-serif";
const SHOP_CREAM = '#f7f5f0';
const SHOP_INK = '#171714';
const SHOP_TAN = '#dcb48a';
const shopCaps = (size = 11, track = 0.16): React.CSSProperties => ({ fontFamily: SHOP_FONT, fontSize: size, fontWeight: 500, letterSpacing: `${track}em`, textTransform: 'uppercase' });

type ShopIconName = 'truck' | 'shield' | 'swap' | 'bag' | 'bag-plus' | 'arrow' | 'search' | 'taxpay';
function ShopIcon({ n, size = 20, color = 'currentColor' }: { n: ShopIconName; size?: number; color?: string }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 1.5, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true };
  switch (n) {
    case 'truck': return <svg {...common}><path d="M2.5 6.5h11v9h-11z" /><path d="M13.5 9.5h4l3 3v3h-7z" /><circle cx="7" cy="17" r="1.8" fill="#161616" /><circle cx="17" cy="17" r="1.8" fill="#161616" /></svg>;
    case 'shield': return <svg {...common}><path d="M12 3l7.5 2.8v5.6c0 4.4-3 7.8-7.5 9.6-4.5-1.8-7.5-5.2-7.5-9.6V5.8L12 3z" /><path d="M8.6 12.2l2.6 2.6 4.4-5" /></svg>;
    case 'swap': return <svg {...common}><path d="M20 11a8 8 0 0 0-14-4.5L4 9" /><path d="M4 4v5h5" /><path d="M4 13a8 8 0 0 0 14 4.5L20 15" /><path d="M20 20v-5h-5" /></svg>;
    case 'bag': return <svg {...common}><path d="M6 8h12l1 13H5L6 8z" /><path d="M9 8V6.5a3 3 0 0 1 6 0V8" /></svg>;
    case 'bag-plus': return <svg {...common}><path d="M6 8h12l1 13H5L6 8z" /><path d="M9 8V6.5a3 3 0 0 1 6 0V8" /><path d="M12 12.5v5M9.5 15h5" /></svg>;
    case 'arrow': return <svg {...common}><path d="M4 12h16" /><path d="M14 6l6 6-6 6" /></svg>;
    case 'search': return <svg {...common}><circle cx="11" cy="11" r="6.5" /><path d="M20 20l-4.2-4.2" /></svg>;
    case 'taxpay': return <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden><rect x="2" y="2" width="20" height="20" rx="6" fill={gold} /><path d="M7.5 8h9M12 8v9" stroke="#161616" strokeWidth="2.6" strokeLinecap="round" /></svg>;
  }
}

function BadgePill({ badge }: { badge: string }) {
  return (
    <span style={{ ...shopCaps(9.5, 0.1), fontWeight: 600, display: 'inline-block', padding: '4px 7px', borderRadius: 5, background: SHOP_CREAM, color: SHOP_INK, lineHeight: 1 }}>{badge}</span>
  );
}

function ShopHeading({ title, sub, action, onAction }: { title: string; sub?: string; action?: string; onAction?: () => void }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 12 }}>
      <div style={{ minWidth: 0 }}>
        <div style={{ ...shopCaps(20, 0.08), fontWeight: 500, color: text.primary, lineHeight: 1.15 }}>{title}</div>
        {sub && <div style={{ fontSize: 13, color: text.muted, marginTop: 5 }}>{sub}</div>}
      </div>
      {action && (
        <button onClick={onAction} style={{ ...shopCaps(11, 0.14), fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 6, color: text.primary, background: 'none', border: 'none', padding: 0, cursor: 'pointer', flexShrink: 0 }}>
          {action}<ShopIcon n="arrow" size={14} />
        </button>
      )}
    </div>
  );
}

function ShopHero({ lang, onShop }: { lang: AppLang; onShop: () => void }) {
  const uk = lang === 'uk';
  return (
    <div style={{ position: 'relative', borderRadius: 24, overflow: 'hidden', minHeight: 400, background: '#1c1c1e', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <img src="/shop/hero-autumn.webp" alt="" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', objectPosition: '36% 30%' }} />
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(8,8,7,0.08) 0%, rgba(8,8,7,0.12) 38%, rgba(8,8,7,0.82) 100%)' }} />
      <div style={{ position: 'relative', padding: '0 22px 22px' }}>
        <div style={{ fontFamily: SHOP_FONT, fontWeight: 500, fontSize: 38, lineHeight: 1.04, letterSpacing: '0.02em', textTransform: 'uppercase', color: SHOP_CREAM }}>
          {tr('Осінь', 'Autumn')}<br /><span style={{ color: SHOP_TAN }}>{tr('вже тут', 'has arrived')}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 20, flexWrap: 'wrap' }}>
          <button onClick={onShop} style={{ ...shopCaps(12, 0.18), fontWeight: 600, height: 48, padding: '0 26px', borderRadius: 14, border: 'none', background: SHOP_CREAM, color: SHOP_INK, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 10 }}>
            {tr('До каталогу', 'Shop now')}<ShopIcon n="arrow" size={15} />
          </button>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, fontSize: 13, color: 'rgba(247,245,240,0.82)' }}>
            <ShopIcon n="taxpay" size={18} />
            {tr('Оплата TaxPay в один дотик', 'Pay in one tap with TaxPay')}
          </div>
        </div>
      </div>
    </div>
  );
}

function ShopTrustRow({ lang }: { lang: AppLang }) {
  const uk = lang === 'uk';
  const items: { icon: ShopIconName; label: string }[] = [
    { icon: 'shield', label: tr('Дослідницька вітрина', 'Research storefront') },
    { icon: 'bag', label: tr('Ціни в TAX', 'Prices in TAX') },
    { icon: 'swap', label: tr('Нічого не відправляється', 'Nothing is shipped') },
    { icon: 'taxpay', label: tr('Оплата TaxPay', 'Pay with TaxPay') },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '18px 12px', padding: '20px 4px', borderTop: '1px solid rgba(255,255,255,0.07)', borderBottom: '1px solid rgba(255,255,255,0.07)' }}>
      {items.map(i => (
        <div key={i.label} style={{ display: 'flex', alignItems: 'center', gap: 11, color: text.secondary, minWidth: 0 }}>
          <span style={{ display: 'inline-flex', flexShrink: 0, color: text.secondary }}><ShopIcon n={i.icon} size={22} /></span>
          <span style={{ ...shopCaps(11, 0.13), whiteSpace: 'nowrap' }}>{i.label}</span>
        </div>
      ))}
    </div>
  );
}

function ShopCategoryTiles({ lang, onPick }: { lang: AppLang; onPick: (k: string) => void }) {
  const uk = lang === 'uk';
  const tiles = [
    { k: 'women', img: '/shop/cat-women.webp', label: tr('Жінкам', 'Women'), sub: tr('Сукні · верхній одяг · взуття', 'Dresses · outerwear · shoes') },
    { k: 'men', img: '/shop/cat-men.webp', label: tr('Чоловікам', 'Men'), sub: tr('Сорочки · поло · костюми', 'Shirts · polos · suits') },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
      {tiles.map(c => (
        <button key={c.k} onClick={() => onPick(c.k)} className="tt-shop-tile" style={{ position: 'relative', aspectRatio: '3 / 4', borderRadius: 20, overflow: 'hidden', border: 'none', padding: 0, cursor: 'pointer', background: '#1c1c1e', textAlign: 'left', fontFamily: 'inherit' }}>
          <img src={c.img} alt="" loading="lazy" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(8,8,7,0) 45%, rgba(8,8,7,0.8) 100%)' }} />
          <div style={{ position: 'absolute', left: 14, right: 14, bottom: 14, color: SHOP_CREAM }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6 }}>
              <span style={{ ...shopCaps(15, 0.08), fontWeight: 500 }}>{c.label}</span>
              <ShopIcon n="arrow" size={16} />
            </div>
            <div style={{ fontSize: 11.5, marginTop: 5, color: 'rgba(247,245,240,0.72)', lineHeight: 1.3 }}>{c.sub}</div>
          </div>
        </button>
      ))}
    </div>
  );
}

function ShopProductCard({ p, onOpen, onAdd, compact }: { p: Product; onOpen: () => void; onAdd: () => void; compact: boolean }) {
  const { t, lang } = usePreferences();
  const out = p.stock !== undefined && p.stock <= 0;
  const tag = p.badge || (p.stock === 1 ? tr('Остання одиниця', 'Last piece') : '');
  const brand = productBrand(p);
  return (
    <div className="tt-product-card" onClick={onOpen} style={{ cursor: 'pointer', minWidth: 0 }}>
      <div style={{ position: 'relative', aspectRatio: '3 / 4', borderRadius: 16, overflow: 'hidden', background: '#ecebe8' }}>
        <ProductVisual product={p} />
        {tag && <div style={{ position: 'absolute', top: 10, left: 10 }}><BadgePill badge={tag} /></div>}
        <button aria-label={t('add_to_cart')} onClick={e => { e.stopPropagation(); onAdd(); }} disabled={out} style={{
          position: 'absolute', right: 10, bottom: 10, width: 36, height: 36, borderRadius: 12, border: 'none',
          background: 'rgba(247,245,240,0.94)', color: SHOP_INK, display: 'grid', placeItems: 'center',
          cursor: out ? 'default' : 'pointer', opacity: out ? 0.45 : 1, boxShadow: '0 8px 18px -8px rgba(0,0,0,0.55)',
        }}><ShopIcon n="bag-plus" size={19} /></button>
      </div>
      <div style={{ padding: '11px 2px 0' }}>
        {brand && <div style={{ ...shopCaps(compact ? 10.5 : 11, 0.14), fontWeight: 600, color: text.primary, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{brand}</div>}
        <div style={{ fontSize: compact ? 13 : 14, color: text.muted, margin: '4px 0 7px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{productName(p)}</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 5, ...T.num }}>
          <span style={{ fontSize: compact ? 15 : 16, fontWeight: 600, color: gold, letterSpacing: -0.1 }}>{fmtInt(p.price)}</span>
          <span style={{ fontSize: 10.5, fontWeight: 500, color: text.dim, letterSpacing: 0.6 }}>TAX</span>
        </div>
      </div>
    </div>
  );
}

function ProductVisual({ product, size = 'card' }: { product: Product; size?: 'card' | 'detail' | 'cart' }) {
  const emoji = product.image_emoji || '🛍️';
  const [imageFailed, setImageFailed] = useState(false);
  const imageUrl = String(product.image_url || '').trim();
  const preferFallback = false;

  useEffect(() => {
    setImageFailed(false);
  }, [imageUrl, product.id]);

  if (imageUrl && !imageFailed && !preferFallback) {
    return (
      <img
        src={imageUrl}
        alt={product.title}
        loading="lazy"
        onError={() => setImageFailed(true)}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          objectPosition: 'center top',
          display: 'block',
          background: '#ecebe8',
          padding: 0,
          boxSizing: 'border-box',
          transform: size === 'detail' ? 'scale(1.01)' : 'scale(1)',
        }}
      />
    );
  }
  return (
    <span style={{
      width: '100%',
      height: '100%',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: size === 'detail' ? 62 : size === 'cart' ? 24 : 42,
      lineHeight: 1,
      filter: 'grayscale(1)',
      background: size === 'cart'
        ? 'rgba(216,216,216, 0.06)'
        : 'rgba(216,216,216, 0.18)',
    }}>
      {emoji}
    </span>
  );
}

function ProductDetailDrawer({ product, onClose, onAddToCart }: { product: Product; onClose: () => void; onAddToCart: (p: Product, size: string, qty: number) => void }) {
  const { t, lang } = usePreferences();
  const layout = useLayout();
  const sheetSwipe = useSheetSwipeClose(onClose);
  const desktop = layout === 'desktop';
  const out = product.stock !== undefined && product.stock <= 0;
  const brand = productBrand(product);
  const name = productName(product);
  const code = (String(product.title || '').match(/\(([^)]*)\)\s*$/) || [])[1] || '';
  const shopId = String(product.slug || '').startsWith('munister-') ? String(product.slug).slice(9) : '';

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const uk = lang === 'uk';
  // Sizes come live from the shop: a product with none is one-size, nothing to pick.
  const shopItem = isShopProduct(product);
  const [sizes, setSizes] = useState<{ size: string; available: number }[] | null>(shopItem ? null : []);
  const [sizesErr, setSizesErr] = useState(false);
  const [sizesTry, setSizesTry] = useState(0);
  const [size, setSize] = useState('');
  const [qty, setQty] = useState(1);
  useEffect(() => {
    if (!shopItem) return;
    let off = false;
    setSizes(null); setSizesErr(false);
    fetch(apiUrl(`/api/marketplace/catalog/${product.id}/sizes`))
      .then(r => r.json())
      .then(j => { if (!off) { if (j.ok) setSizes(j.data?.sizes || []); else setSizesErr(true); } })
      .catch(() => { if (!off) setSizesErr(true); });
    return () => { off = true; };
  }, [product.id, shopItem, sizesTry]);
  const needsSize = Boolean(sizes && sizes.length > 0);
  const sizeLeft = size ? (sizes?.find(x => x.size === size)?.available ?? 0) : (product.stock ?? 10);
  const maxQty = Math.max(1, Math.min(10, sizeLeft || 1, product.stock ?? 10));
  const qtyNow = Math.min(qty, maxQty);
  const loadingSizes = shopItem && sizes === null && !sizesErr;
  const canAdd = !out && !loadingSizes && !sizesErr && (!needsSize || Boolean(size));
  const perks: { icon: ShopIconName; label: string }[] = [
    { icon: 'taxpay', label: tr('Оплата в TAX через TaxPay, без реальних грошей', 'Paid in TAX with TaxPay, no real money') },
    { icon: 'bag', label: tr('Тестове замовлення: нічого не відправляється', 'A test order: nothing is shipped') },
    { icon: 'shield', label: tr('Дослідницька вітрина TaxTech', 'A TaxTech research storefront') },
  ];
  const stepSt: React.CSSProperties = { width: 44, height: '100%', border: 'none', background: 'transparent', color: text.primary, fontSize: 20, cursor: 'pointer', fontFamily };
  const info = (
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
      {(product.badge || (product.stock !== undefined && product.stock > 0 && product.stock <= 5)) && (
        <div style={{ display: 'flex', gap: 6, marginBottom: 14, flexWrap: 'wrap' }}>
          {product.badge && <BadgePill badge={product.badge} />}
          {product.stock !== undefined && product.stock > 0 && product.stock <= 5 && <BadgePill badge={`${t('last_items_badge')} ${product.stock}`} />}
        </div>
      )}
      {brand && <div style={{ ...shopCaps(12, 0.2), fontWeight: 600, color: text.muted, marginBottom: 8 }}>{brand}</div>}
      <div style={{ fontFamily: SHOP_FONT, fontSize: 26, fontWeight: 500, lineHeight: 1.15, letterSpacing: '0.01em', color: text.primary, marginBottom: 6 }}>{name}</div>
      {code && <div style={{ fontSize: 12, color: text.dim, fontVariantNumeric: 'tabular-nums' }}>{code}</div>}
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, margin: '18px 0 6px', ...T.num }}>
        <span style={{ fontSize: 32, fontWeight: 600, color: gold, letterSpacing: -0.5 }}>{fmtInt(product.price)}{Number.isInteger(product.price) ? '' : fmtDec(product.price)}</span>
        <span style={{ fontSize: 13, fontWeight: 500, color: text.dim, letterSpacing: 0.8 }}>TAX</span>
      </div>
      {product.stock !== undefined && (
        <div style={{ fontSize: 12.5, color: out ? '#888888' : text.muted, marginBottom: shopItem ? 16 : 22 }}>
          {out ? t('market_out_of_stock') : `${t('in_stock')}: ${product.stock}`}
        </div>
      )}
      {!out && shopItem && (
        <div style={{ marginBottom: 18 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ ...shopCaps(11, 0.16), color: text.muted }}>{tr('Розмір', 'Size')}</span>
            {size && <span style={{ fontSize: 12, color: text.primary }}>{size}</span>}
          </div>
          {loadingSizes && <div style={{ fontSize: 13, color: text.muted }}>{tr('Завантажуємо розміри…', 'Loading sizes…')}</div>}
          {sizesErr && (
            <div style={{ fontSize: 13, color: text.muted }}>
              {tr('Не вдалося завантажити розміри. ', 'Could not load sizes. ')}
              <button onClick={() => setSizesTry(n => n + 1)} style={{ background: 'none', border: 'none', color: gold, cursor: 'pointer', fontFamily, fontSize: 13, padding: 0 }}>{tr('Спробувати ще', 'Try again')}</button>
            </div>
          )}
          {needsSize && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {sizes!.map(x => {
                const gone = x.available <= 0;
                const on = size === x.size;
                return (
                  <button key={x.size} disabled={gone} aria-pressed={on} onClick={() => { setSize(x.size); setQty(1); }}
                    title={gone ? tr('Немає в наявності', 'Out of stock') : `${x.available} ${tr('шт.', 'pcs')}`}
                    style={{
                      position: 'relative', minWidth: 48, height: 44, padding: '0 14px', borderRadius: 12, fontFamily, fontSize: 14, fontWeight: 500,
                      border: `1px solid ${on ? SHOP_CREAM : 'rgba(255,255,255,0.18)'}`,
                      background: on ? SHOP_CREAM : 'transparent', color: on ? SHOP_INK : gone ? 'rgba(255,255,255,0.28)' : text.primary,
                      textDecoration: gone ? 'line-through' : 'none', cursor: gone ? 'not-allowed' : 'pointer',
                    }}>
                    {x.size}
                    {!gone && !on && x.available <= 2 && <span aria-hidden style={{ position: 'absolute', top: 5, right: 5, width: 6, height: 6, borderRadius: '50%', background: '#e8a33d' }} />}
                  </button>
                );
              })}
            </div>
          )}
          {size && sizeLeft > 0 && sizeLeft <= 2 && (
            <div style={{ marginTop: 10, fontSize: 12.5, color: '#e8a33d' }}>
              {sizeLeft === 1 ? (tr('Остання одиниця в розмірі {size}', 'Last piece in {size}').replace('{size}', size)) : (tr('Лишилось {n} шт. у розмірі {size}', 'Only {n} left in {size}').replace('{n}', String(sizeLeft)).replace('{size}', size))}
            </div>
          )}
        </div>
      )}
      <div style={{ display: 'flex', gap: 10, marginTop: desktop ? 'auto' : 0 }}>
        {!out && (
          <div role="group" aria-label={tr('Кількість', 'Quantity')} style={{ display: 'flex', alignItems: 'stretch', height: 54, flexShrink: 0, borderRadius: 14, border: '1px solid rgba(255,255,255,0.18)' }}>
            <button aria-label="−" disabled={qtyNow <= 1} onClick={() => setQty(Math.max(1, qtyNow - 1))} style={{ ...stepSt, opacity: qtyNow <= 1 ? 0.35 : 1 }}>−</button>
            <span style={{ minWidth: 28, display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 600, color: text.primary, ...T.num }}>{qtyNow}</span>
            <button aria-label="+" disabled={qtyNow >= maxQty} onClick={() => setQty(Math.min(maxQty, qtyNow + 1))} style={{ ...stepSt, opacity: qtyNow >= maxQty ? 0.35 : 1 }}>+</button>
          </div>
        )}
        <button
          onClick={() => { onAddToCart(product, size, qtyNow); onClose(); }}
          disabled={!canAdd}
          style={{
            ...shopCaps(13, 0.18), fontWeight: 600, flex: 1, minWidth: 0, height: 54, borderRadius: 14, border: 'none',
            background: canAdd ? SHOP_CREAM : 'rgba(95,95,95, 0.25)',
            color: canAdd ? SHOP_INK : text.muted, cursor: canAdd ? 'pointer' : 'default',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10, whiteSpace: 'nowrap',
          }}
        >
          {out ? t('market_out_of_stock')
            : loadingSizes ? '…'
            : needsSize && !size ? tr('Оберіть розмір', 'Select a size')
            : <><ShopIcon n="bag-plus" size={19} />{t('add_to_cart')}{qtyNow > 1 ? ` · ${qtyNow}` : ''}</>}
        </button>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 24, paddingTop: 20, borderTop: '1px solid rgba(255,255,255,0.08)' }}>
        {perks.map(k => (
          <div key={k.label} style={{ display: 'flex', alignItems: 'center', gap: 12, fontSize: 13.5, color: text.secondary }}>
            <span style={{ display: 'inline-flex', flexShrink: 0 }}><ShopIcon n={k.icon} size={20} /></span>{k.label}
          </div>
        ))}
      </div>
      {shopId && (
        <a href={`https://shop.munister.com.ua/product/${shopId}`} target="_blank" rel="noreferrer"
          style={{ ...shopCaps(11, 0.16), marginTop: 22, textAlign: 'center', color: text.muted, textDecoration: 'none' }}>
          Saint Agnes <span style={{ color: gold }}>↗</span>
        </a>
      )}
    </div>
  );

  const photo = (
    <div style={{
      aspectRatio: '3 / 4', width: '100%', borderRadius: 16, overflow: 'hidden', background: '#ecebe8',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      maxHeight: desktop ? '72vh' : '52vh', marginBottom: desktop ? 0 : 18,
    }}>
      <ProductVisual product={product} size="detail" />
    </div>
  );

  if (desktop) {
    return createPortal(
      <div style={{ position: 'fixed', inset: 0, zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }} onClick={onClose}>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.62)', backdropFilter: 'blur(4px)', WebkitBackdropFilter: 'blur(4px)' }} />
        <div onClick={e => e.stopPropagation()} role="dialog" aria-label={name} style={{
          position: 'relative', width: 'min(920px, 100%)', maxHeight: '88vh', overflow: 'auto',
          background: '#1d1d1d', border: '1px solid transparent', borderRadius: 22,
          boxShadow: '0 30px 80px rgba(0,0,0,0.6)', padding: 24,
          display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap: 28,
        }}>
          <button onClick={onClose} aria-label="Close" style={{ position: 'absolute', top: 14, right: 14, width: 36, height: 36, borderRadius: 10, border: '1px solid transparent', background: 'rgba(255,255,255, 0.1)', color: text.secondary, cursor: 'pointer', fontSize: 18, lineHeight: 1 }}>×</button>
          {photo}
          <div style={{ display: 'flex', flexDirection: 'column', paddingTop: 28 }}>{info}</div>
        </div>
      </div>,
      document.body,
    );
  }

  return createPortal(
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 1000, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }} onClick={onClose}>
      <div style={{ background: `rgba(0,0,0, ${0.5 - sheetSwipe.progress * 0.32})`, position: 'absolute', inset: 0, transition: sheetSwipe.dragging ? 'none' : 'background 200ms ease' }} />
      <div className="tt-sheet"
        {...sheetSwipe.sheetProps}
        onClick={e => e.stopPropagation()}
        style={{
        position: 'relative', background: '#232323',
        borderRadius: '24px 24px 0 0', padding: '20px 20px calc(32px + env(safe-area-inset-bottom, 0px))',
        boxShadow: '0 -20px 60px rgba(0,0,0, 0.6)', maxHeight: '92vh', overflowY: 'auto',
        border: '1px solid transparent', borderBottom: 'none',
        ...sheetSwipe.sheetStyle,
      }}
      >
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 16px' }} />
        {photo}
        {info}
      </div>
    </div>,
    document.body,
  );
}

function CartDrawer({ cart, onClose, onQtyChange, onRemove, onCheckout, checkingOut, user }: {
  cart: CartItem[]; onClose: () => void;
  onQtyChange: (key: string, delta: number) => void;
  onRemove: (key: string) => void;
  onCheckout: (shipping: { name: string; phone: string; address: string }) => void;
  checkingOut: boolean;
  user: { full_name: string; phone: string } | null;
}) {
  const { t, lang } = usePreferences();
  const sheetSwipe = useSheetSwipeClose(onClose);
  const total = cart.reduce((s, i) => s + i.product.price * i.qty, 0);
  const [step, setStep] = useState<'cart' | 'shipping'>('cart');
  const [shipName, setShipName] = useState(user?.full_name || '');
  const [shipPhone, setShipPhone] = useState(user?.phone || '');
  const [shipAddr, setShipAddr] = useState('');
  const [tried, setTried] = useState(false);
  const shipErr = validateShipping(shipName, shipPhone, shipAddr, lang === 'uk');
  const submitShipping = () => {
    if (Object.keys(shipErr).length > 0) { setTried(true); return; }
    onCheckout({ name: shipName.trim(), phone: shipPhone.trim(), address: shipAddr.trim() });
  };
  const cartCount = cart.reduce((s, i) => s + i.qty, 0);
  const cartRowsMaxHeight = cart.length > 3 ? 'min(42dvh, 360px)' : undefined;

  const fieldStyle: React.CSSProperties = {
    width: '100%', padding: '11px 14px', background: 'rgba(255,255,255, 0.1)',
    border: '1px solid transparent', borderRadius: 12,
    color: text.primary, fontSize: 14, outline: 'none', fontFamily: fontFamily,
    boxSizing: 'border-box',
  };
  const labelStyle: React.CSSProperties = { fontSize: 11, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 5, display: 'block' };

  return createPortal(
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, zIndex: 200, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }} onClick={onClose}>
      <div style={{ background: `rgba(0,0,0, ${0.5 - sheetSwipe.progress * 0.32})`, position: 'absolute', inset: 0, transition: sheetSwipe.dragging ? 'none' : 'background 200ms ease' }} />
      <div className="tt-sheet"
        {...sheetSwipe.sheetProps}
        onClick={e => e.stopPropagation()}
        style={{
        position: 'relative',
        background: '#1c1c1e',
        backdropFilter: 'blur(24px)', WebkitBackdropFilter: 'blur(24px)',
        borderRadius: '28px 28px 0 0',
        padding: '18px 18px env(safe-area-inset-bottom, 0px)',
        boxShadow: '0 -20px 60px rgba(0,0,0, 0.6)',
        height: 'auto',
        maxHeight: 'min(86dvh, 720px)',
        overflow: 'hidden',
        border: '1px solid transparent', borderBottom: 'none',
        display: 'flex',
        flexDirection: 'column',
        ...sheetSwipe.sheetStyle,
      }}
      >
        <div style={{ width: 40, height: 4, borderRadius: 2, background: 'rgba(172,172,172, 0.25)', margin: '0 auto 16px', flexShrink: 0 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 20 }}>
          {step === 'shipping' && (
            <button onClick={() => setStep('cart')} style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', color: gold, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M10 4L6 8l4 4" stroke={gold} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
            </button>
          )}
          <div style={{ ...shopCaps(18, 0.1), color: text.primary, flex: 1 }}>
            {step === 'cart' ? t('cart_title') : t('delivery_title')}
          </div>
          {step === 'cart' && <div style={{ ...T.body, color: text.muted }}>{cartCount} {t('cart_items_count')}</div>}
        </div>

        {step === 'cart' && (
          cart.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px 0', color: text.muted }}>{t('cart_empty')}</div>
          ) : (
            <>
              <div style={{
                display: 'flex',
                flexDirection: 'column',
                gap: 10,
                overflowY: cart.length > 3 ? 'auto' : 'visible',
                maxHeight: cartRowsMaxHeight,
                paddingBottom: 14,
                WebkitOverflowScrolling: 'touch',
              }}>
                {cart.map((item, idx) => (
                  <div key={cartKey(item)} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 0', borderTop: idx === 0 ? 'none' : '1px solid rgba(255,255,255,0.07)' }}>
                    <div style={{ width: 54, aspectRatio: '3 / 4', borderRadius: 10, overflow: 'hidden', flexShrink: 0, background: '#ecebe8' }}>
                      <ProductVisual product={item.product} size="cart" />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      {productBrand(item.product) && <div style={{ ...shopCaps(10.5, 0.14), fontWeight: 600, color: text.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{productBrand(item.product)}</div>}
                      <div style={{ fontSize: 13, color: text.muted, margin: '3px 0 6px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{productName(item.product)}{item.size ? <span style={{ color: text.primary }}> · {item.size}</span> : null}</div>
                      <div style={{ fontSize: 15, fontWeight: 600, color: gold, ...T.num }}>{fmtInt(item.product.price * item.qty)}{Number.isInteger(item.product.price * item.qty) ? '' : fmtDec(item.product.price * item.qty)}<span style={{ fontSize: 10.5, fontWeight: 500, color: text.dim, letterSpacing: 0.6, marginLeft: 4 }}>TAX</span></div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <button onClick={() => onQtyChange(cartKey(item), -1)} aria-label="−" style={{ width: 32, height: 32, background: 'none', border: 'none', color: text.secondary, fontSize: 20, cursor: 'pointer', fontFamily: fontFamily }}>−</button>
                      <span style={{ fontSize: 15, fontWeight: 600, color: text.primary, minWidth: 16, textAlign: 'center', ...T.num }}>{item.qty}</span>
                      <button onClick={() => onQtyChange(cartKey(item), 1)} aria-label="+" style={{ width: 32, height: 32, background: 'none', border: 'none', color: text.secondary, fontSize: 20, cursor: 'pointer', fontFamily: fontFamily }}>+</button>
                      <button onClick={() => onRemove(cartKey(item))} aria-label="Remove" style={{ width: 32, height: 32, background: 'none', border: 'none', color: text.dim, fontSize: 14, cursor: 'pointer', fontFamily: fontFamily }}>✕</button>
                    </div>
                  </div>
                ))}
              </div>
              <div style={{
                margin: '0 -18px',
                padding: '16px 18px calc(18px + env(safe-area-inset-bottom, 0px))',
                background: '#1c1c1e',
                borderTop: '1px solid transparent',
                boxShadow: '0 -20px 38px rgba(0,0,0, 0.22)',
              }}>
              <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 14, padding: '0 4px' }}>
                <span style={{ fontSize: 14, color: text.muted }}>{t('total_label')}:</span>
                <span style={{ ...T.num, color: gold }}><span style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.3 }}>{fmtInt(total)}{fmtDec(total)}</span><span style={{ fontSize: 12, fontWeight: 500, color: text.dim, letterSpacing: 0.8, marginLeft: 6 }}>TAX</span></span>
              </div>
                <button onClick={() => setStep('shipping')} style={{
                  ...shopCaps(13, 0.16), fontWeight: 600, width: '100%', height: 54, borderRadius: 14, border: 'none',
                  background: gold, color: '#161616', cursor: 'pointer',
                }}>{t('next_delivery')}</button>
              </div>
            </>
          )
        )}

        {step === 'shipping' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14, overflowY: 'auto', paddingBottom: 'calc(18px + env(safe-area-inset-bottom, 0px))' }}>
            <div>
              <label style={labelStyle}>{t('recipient_label')}</label>
              <input value={shipName} onChange={e => setShipName(e.target.value)} placeholder={t('shipping_name_placeholder')} style={{ ...fieldStyle, ...(tried && shipErr.name ? shipErrStyle : null) }} aria-invalid={tried && shipErr.name ? true : undefined} autoComplete="name" />
              {tried && shipErr.name && <ShipError text={shipErr.name} />}
            </div>
            <div>
              <label style={labelStyle}>{t('delivery_phone')}</label>
              <input value={shipPhone} onChange={e => setShipPhone(e.target.value)} placeholder="+380XXXXXXXXX" style={{ ...fieldStyle, ...(tried && shipErr.phone ? shipErrStyle : null) }} aria-invalid={tried && shipErr.phone ? true : undefined} inputMode="tel" autoComplete="tel" />
              {tried && shipErr.phone && <ShipError text={shipErr.phone} />}
            </div>
            <div>
              <label style={labelStyle}>{t('delivery_address')}</label>
              <input value={shipAddr} onChange={e => setShipAddr(e.target.value)} placeholder={t('shipping_address_placeholder')} style={{ ...fieldStyle, ...(tried && shipErr.address ? shipErrStyle : null) }} aria-invalid={tried && shipErr.address ? true : undefined} autoComplete="street-address" />
              {tried && shipErr.address && <ShipError text={shipErr.address} />}
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '4px 4px 0' }}>
              <span style={{ fontSize: 13, color: text.muted }}>{t('pay_total')}:</span>
              <span style={{ ...T.num, color: gold }}><span style={{ fontSize: 24, fontWeight: 600, letterSpacing: -0.3 }}>{fmtInt(total)}{fmtDec(total)}</span><span style={{ fontSize: 12, fontWeight: 500, color: text.dim, letterSpacing: 0.8, marginLeft: 6 }}>TAX</span></span>
            </div>
            <button
              onClick={submitShipping}
              disabled={checkingOut}
              style={{
                ...shopCaps(13, 0.16), fontWeight: 600, width: '100%', height: 54, borderRadius: 14, border: 'none',
                background: checkingOut ? 'rgba(95,95,95, 0.3)' : gold,
                color: checkingOut ? text.muted : '#161616',
                cursor: checkingOut ? 'default' : 'pointer',
              }}>{checkingOut ? t('checkout_processing') : `✓ ${t('place_order')}`}</button>
          </div>
        )}
      </div>
    </div>,
    document.body,
  );
}

type MarketTab = 'catalog' | 'orders' | 'invoices';

function MarketplaceScreen() {
  const layout = useLayout();
  const PRODUCTS_PER_PAGE = 100000;
  const { t, lang } = usePreferences();
  const topPad = useTopPad();
  const { toast, refreshDashboard, user: mktUser, setTabBarHidden } = useApp();
  const [tab, setTabState] = useState<MarketTab>(() => readStoredMarketTab());
  const [products, setProducts] = useState<Product[]>([]);
  const [orders, setOrders] = useState<MarketOrder[]>([]);
  const [invoices, setInvoices] = useState<MarketInvoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [dlPdf, setDlPdf] = useState<string | null>(null);
  const [preview, setPreview] = useState<Product | null>(null);
  const [cart, setCart] = useState<CartItem[]>(() => {
    try { return JSON.parse(localStorage.getItem('arm_cart') || '[]'); } catch { return []; }
  });
  const [showCart, setShowCart] = useState(false);
  const [checkingOut, setCheckingOut] = useState(false);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [category, setCategory] = useState('');
  const [serverPage, setServerPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [catalogPage, setCatalogPage] = useState(1);
  useEffect(() => {
    const id = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(id);
  }, [search]);
  const marketTopRef = useRef<HTMLDivElement | null>(null);
  const gridTopRef = useRef<HTMLDivElement | null>(null);
  useEffect(() => { localStorage.setItem('arm_cart', JSON.stringify(cart)); }, [cart]);
  useEffect(() => {
    const hidden = Boolean(showCart || preview);
    setTabBarHidden(hidden);
    return () => setTabBarHidden(false);
  }, [showCart, preview, setTabBarHidden]);

  const token = localStorage.getItem('army_bank_token');

  const setTab = React.useCallback((next: MarketTab) => {
    setTabState(next);
    markAppContinuation();
    try {
      localStorage.setItem(MARKET_TAB_STORAGE_KEY, next);
    } catch {
      // ignore storage errors
    }
  }, []);

  function addToCart(product: Product, size = '', qty = 1) {
    const key = `${product.id}|${size}`;
    setCart(prev => {
      const existing = prev.find(i => cartKey(i) === key);
      if (existing) return prev.map(i => cartKey(i) === key ? { ...i, qty: Math.min(50, i.qty + qty) } : i);
      return [...prev, { product, qty, size: size || undefined }];
    });
    toast(`✓ ${product.title}${size ? ` · ${size}` : ''} — ${t('added_to_cart')}`);
  }

  function changeQty(key: string, delta: number) {
    setCart(prev => prev.map(i => cartKey(i) === key ? { ...i, qty: Math.min(50, Math.max(1, i.qty + delta)) } : i));
  }

  function removeFromCart(key: string) {
    setCart(prev => prev.filter(i => cartKey(i) !== key));
  }

  async function checkoutCart(shipping: { name: string; phone: string; address: string }) {
    if (cart.length === 0) return;
    setCheckingOut(true);
    const idempotencyKey = `cart-${Date.now()}`;
    try {
      await ensureApiStatusHealthy();
      const r = await fetch(apiUrl('/api/marketplace/checkout'), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({
          items: cart.map(i => ({ product_id: i.product.id, qty: i.qty, size: i.size || '' })),
          shipping_name: shipping.name.trim(),
          shipping_phone: shipping.phone.trim(),
          shipping_address: shipping.address.trim(),
          payment_mode: 'pay_now',
          idempotency_key: idempotencyKey,
        }),
      });
      const j = await r.json();
      if (!r.ok || !j.ok) throw new Error(j.message || j.error || t('checkout_error'));
      toast(`✓ ${t('checkout_success')}`);
      setCart([]);
      setShowCart(false);
      refreshDashboard();
      setTimeout(() => setTab('orders'), 800);
    } catch (e: unknown) {
      toast(e instanceof Error ? e.message : t('checkout_error'));
    } finally {
      setCheckingOut(false);
    }
  }

  const cartCount = cart.reduce((s, i) => s + i.qty, 0);

  useEffect(() => {
    if (tab === 'catalog') {
      setLoading(true);
      setServerPage(1);
      fetch(apiUrl(catalogUrl(1)), { headers: { Authorization: `Bearer ${token}` } })
        .then(r => r.json())
        .then(j => {
          if (j.ok) {
            setProducts(Array.isArray(j.data?.items) ? j.data.items : (Array.isArray(j.data) ? j.data : []));
            setHasMore(Boolean(j.data?.has_more));
          }
        })
        .catch(() => {})
        .finally(() => setLoading(false));
    } else if (tab === 'orders') {
      setLoading(true);
      fetch(apiUrl('/api/marketplace/orders'), { headers: { Authorization: `Bearer ${token}` } })
        .then(r => r.json())
        .then(j => { if (j.ok) setOrders(Array.isArray(j.data?.orders) ? j.data.orders : []); })
        .catch(() => {})
        .finally(() => setLoading(false));
    } else if (tab === 'invoices') {
      setLoading(true);
      fetch(apiUrl('/api/marketplace/invoices'), { headers: { Authorization: `Bearer ${token}` } })
        .then(r => r.json())
        .then(j => { if (j.ok) setInvoices(Array.isArray(j.data?.invoices) ? j.data.invoices : []); })
        .catch(() => {})
        .finally(() => setLoading(false));
    }
  }, [tab, category, debouncedSearch]);

  function catalogUrl(page: number) {
    const q = new URLSearchParams({ per_page: '48', page: String(page), sort: 'newest' });
    if (category) q.set('category', category);
    if (debouncedSearch) q.set('search', debouncedSearch);
    return `/api/marketplace/catalog?${q.toString()}`;
  }

  async function loadMoreProducts() {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    try {
      const next = serverPage + 1;
      const r = await fetch(apiUrl(catalogUrl(next)), { headers: { Authorization: `Bearer ${token}` } });
      const j = await r.json();
      if (j.ok) {
        const items: Product[] = Array.isArray(j.data?.items) ? j.data.items : [];
        setProducts(prev => [...prev, ...items.filter(it => !prev.some(p => p.id === it.id))]);
        setHasMore(Boolean(j.data?.has_more));
        setServerPage(next);
      }
    } catch { /* keep what we have */ } finally { setLoadingMore(false); }
  }

  async function downloadOrderReceipt(orderId: number) {
    setDlPdf(`order-${orderId}`);
    try {
      const r = await fetch(`/api/marketplace/order/${orderId}/receipt`, { headers: { Authorization: `Bearer ${token}` } });
      if (!r.ok) { toast(t('receipt_download_error')); return; }
      const blob = await r.blob();
      openPdfBlobInNewTab(blob, `receipt-${orderId}.pdf`, toast);
    } catch { toast(t('download_error')); } finally { setDlPdf(null); }
  }

  const MARKET_TABS: { k: MarketTab; label: string }[] = [
    { k: 'catalog', label: t('catalog_tab') },
    { k: 'orders', label: t('orders_tab') },
    { k: 'invoices', label: t('invoices_tab') },
  ];

  const statusTone: Record<string, { fg: string; bg: string; border: string }> = {
    paid: { fg: '#b8b8b8', bg: 'rgba(134,134,134, 0.16)', border: 'rgba(184,184,184, 0.35)' },
    active: { fg: '#b8b8b8', bg: 'rgba(134,134,134, 0.16)', border: 'rgba(184,184,184, 0.35)' },
    issued: { fg: '#cacaca', bg: 'rgba(176,176,176, 0.15)', border: 'rgba(202,202,202, 0.3)' },
    pending: { fg: '#cacaca', bg: 'rgba(176,176,176, 0.15)', border: 'rgba(202,202,202, 0.3)' },
    overdue: { fg: '#adadad', bg: 'rgba(107,107,107, 0.14)', border: 'rgba(173,173,173, 0.35)' },
    cancelled: { fg: '#bdbdbd', bg: 'rgba(151,151,151, 0.12)', border: 'rgba(189,189,189, 0.25)' },
    expired: { fg: '#bdbdbd', bg: 'rgba(151,151,151, 0.12)', border: 'rgba(189,189,189, 0.25)' },
  };
  function toneOf(status: string) {
    return statusTone[String(status || '').toLowerCase()] || { fg: gold, bg: 'rgba(176,176,176, 0.14)', border: 'rgba(176,176,176, 0.3)' };
  }
  function formatUkDate(v?: string) {
    if (!v) return '—';
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleDateString(localeForLang(lang));
  }
  function formatUkDateTime(v?: string) {
    if (!v) return '—';
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleString(localeForLang(lang), { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  const filteredProducts = products;
  const totalCatalogPages = Math.max(1, Math.ceil(filteredProducts.length / PRODUCTS_PER_PAGE));
  const pagedProducts = filteredProducts.slice((catalogPage - 1) * PRODUCTS_PER_PAGE, catalogPage * PRODUCTS_PER_PAGE);
  const catalogPages = useMemo<(number | 'gap-left' | 'gap-right')[]>(() => {
    if (totalCatalogPages <= 7) return Array.from({ length: totalCatalogPages }, (_, i) => i + 1);

    const set = new Set<number>([1, totalCatalogPages, catalogPage - 1, catalogPage, catalogPage + 1]);
    if (catalogPage <= 3) [2, 3, 4].forEach(p => set.add(p));
    if (catalogPage >= totalCatalogPages - 2) [totalCatalogPages - 3, totalCatalogPages - 2, totalCatalogPages - 1].forEach(p => set.add(p));

    const sorted = Array.from(set).filter(p => p >= 1 && p <= totalCatalogPages).sort((a, b) => a - b);
    const result: (number | 'gap-left' | 'gap-right')[] = [];
    sorted.forEach((page, idx) => {
      const prev = sorted[idx - 1];
      if (prev && page - prev > 1) result.push(prev === 1 ? 'gap-left' : 'gap-right');
      result.push(page);
    });
    return result;
  }, [catalogPage, totalCatalogPages]);

  function goToCatalogPage(nextPage: number) {
    const next = Math.max(1, Math.min(totalCatalogPages, nextPage));
    setCatalogPage(next);
    window.setTimeout(() => {
      marketTopRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 0);
  }

  useEffect(() => {
    setCatalogPage(1);
  }, [search, tab]);

  useEffect(() => {
    if (catalogPage > totalCatalogPages) setCatalogPage(totalCatalogPages);
  }, [catalogPage, totalCatalogPages]);

  const isMobileMarket = layout !== 'desktop';
  const showLanding = !category && !debouncedSearch;

  return (
    <>
    {preview && <ProductDetailDrawer product={preview} onClose={() => setPreview(null)} onAddToCart={addToCart} />}
    {isMobileMarket && showCart && <CartDrawer cart={cart} onClose={() => setShowCart(false)} onQtyChange={changeQty} onRemove={removeFromCart} onCheckout={checkoutCart} checkingOut={checkingOut} user={mktUser} />}
    {!isMobileMarket && <DesktopCartPanel cart={cart} onQtyChange={changeQty} onRemove={removeFromCart} onCheckout={checkoutCart} checkingOut={checkingOut} user={mktUser} />}
    {isMobileMarket && !showCart && !preview && tab === 'catalog' && cartCount > 0 && (
      <button
        onClick={() => setShowCart(true)}
        style={{
          position: 'fixed',
          right: 16,
          bottom: 'calc(112px + env(safe-area-inset-bottom, 0px))',
          zIndex: 160,
          border: '1px solid transparent',
          borderRadius: 14,
          background: 'rgba(50,50,50, 0.92)',
          backdropFilter: 'blur(16px)',
          WebkitBackdropFilter: 'blur(16px)',
          color: text.primary,
          padding: '10px 12px',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          boxShadow: '0 12px 24px rgba(0,0,0, 0.35)',
          cursor: 'pointer',
          fontFamily: 'inherit',
        }}
      >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden><path d="M6 8h12l1 13H5L6 8Z" /><path d="M9 8V6a3 3 0 0 1 6 0v2" /></svg>
        <span style={{ fontSize: 12, fontWeight: 700 }}>{cartCount}</span>
      </button>
    )}
    <ContentWrap maxW={isMobileMarket ? 800 : 1400}>
    <div style={{ paddingBottom: layout === 'desktop' ? 80 : 'calc(104px + env(safe-area-inset-bottom, 0px))', paddingRight: isMobileMarket ? undefined : 356, overflowX: 'hidden' }}>
      <div ref={marketTopRef} style={{ padding: isMobileMarket ? `${topPad} 20px 0` : '40px 32px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <div>
            <div style={{ ...shopCaps(isMobileMarket ? 22 : 26, 0.34), color: text.primary, lineHeight: 1 }}>Saint Agnes</div>
            <a href="https://shop.munister.com.ua" target="_blank" rel="noreferrer" style={{ ...shopCaps(10, 0.2), display: 'inline-block', marginTop: 9, color: text.muted, textDecoration: 'none' }}>
              {tr('Магазин · оплата TAX', 'Shop · pay with TAX')} <span style={{ color: gold }}>↗</span>
            </a>
          </div>
          {isMobileMarket && (
            <button onClick={() => setShowCart(true)} aria-label={t('cart_title')} style={{ position: 'relative', width: 44, height: 44, background: 'none', border: 'none', display: 'grid', placeItems: 'center', cursor: 'pointer', color: text.primary }}>
              <ShopIcon n="bag" size={25} />
              {cartCount > 0 && (
                <span style={{ position: 'absolute', top: 3, right: 1, minWidth: 17, height: 17, padding: '0 4px', boxSizing: 'border-box', borderRadius: 9, background: gold, color: '#161616', fontSize: 10, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{cartCount > 9 ? '9+' : cartCount}</span>
              )}
            </button>
          )}
        </div>
        <div data-no-tab-swipe="true" style={{ display: 'flex', gap: 28, borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
          {MARKET_TABS.map(m => (
            <button key={m.k} onClick={() => setTab(m.k)} style={{
              ...shopCaps(11.5, 0.15), fontWeight: tab === m.k ? 600 : 500, padding: '8px 0 12px', marginBottom: -1, cursor: 'pointer',
              background: 'none', border: 'none', borderBottom: `2px solid ${tab === m.k ? gold : 'transparent'}`,
              color: tab === m.k ? text.primary : text.muted, transition: 'color .15s, border-color .15s',
            }}>{m.label}</button>
          ))}
        </div>
      </div>

      {tab === 'catalog' && !showLanding && (
        <div style={{ padding: isMobileMarket ? '18px 20px 0' : '22px 32px 0' }}>
          <div style={{ position: 'relative' }}>
            <span style={{ position: 'absolute', left: 0, top: '50%', transform: 'translateY(-50%)', color: text.muted, display: 'inline-flex' }}><ShopIcon n="search" size={18} /></span>
            <input value={search} onChange={e => setSearch(e.target.value)} placeholder={t('product_search')} style={{ width: '100%', padding: '12px 0 12px 30px', background: 'transparent', border: 'none', borderBottom: '1px solid rgba(255,255,255,0.14)', borderRadius: 0, color: text.primary, fontSize: 15, outline: 'none', fontFamily: 'inherit', boxSizing: 'border-box' }} />
          </div>
        </div>
      )}

      {tab === 'catalog' && showLanding && (
        <div style={{ padding: isMobileMarket ? '20px 20px 0' : '24px 32px 0', display: 'flex', flexDirection: 'column', gap: 26 }}>
          <ShopHero lang={lang} onShop={() => gridTopRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })} />
          <ShopTrustRow lang={lang} />
          <ShopHeading title={tr('Колекції', 'Shop by')} sub={tr('Архів магазину, ціни в TAX', 'From the archive, priced in TAX')} />
          <ShopCategoryTiles lang={lang} onPick={k => { setCategory(k); window.setTimeout(() => gridTopRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 60); }} />
        </div>
      )}

      {tab === 'catalog' && (
        <div ref={gridTopRef} style={{ padding: isMobileMarket ? '28px 20px 0' : '34px 32px 0', scrollMarginTop: 12 }}>
          <ShopHeading
            title={category ? (() => { const c = SHOP_CATEGORIES.find(x => x.k === category) || SHOP_CATEGORIES[0]; return tr(c.uk, c.en); })() : tr('Добірка', 'The edit')}
            sub={category || search ? undefined : tr('Обране цього тижня', 'Chosen this week')}
          />
          <div data-no-tab-swipe="true" style={{ display: 'flex', gap: 22, overflowX: 'auto', marginTop: 14, scrollbarWidth: 'none', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            {SHOP_CATEGORIES.map(c => (
              <button key={c.k || 'all'} onClick={() => setCategory(c.k)} style={{
                ...shopCaps(11.5, 0.12), flexShrink: 0, padding: '8px 0 11px', fontWeight: category === c.k ? 600 : 500, cursor: 'pointer',
                background: 'none', border: 'none', marginBottom: -1,
                borderBottom: `2px solid ${category === c.k ? gold : 'transparent'}`,
                color: category === c.k ? text.primary : text.muted, transition: 'color .15s, border-color .15s',
              }}>{tr(c.uk, c.en)}</button>
            ))}
          </div>
        </div>
      )}

      {loading && <div style={{ padding: 60, textAlign: 'center', color: text.muted, fontSize: 14 }}>{t('loading')}</div>}

      {/* ── CATALOG ── */}
      {!loading && tab === 'catalog' && (
        <>
          {filteredProducts.length === 0 ? (
            <div style={{ padding: '60px 22px', textAlign: 'center' }}>
              <div style={{ fontSize: 15, fontWeight: 600, color: text.secondary, marginBottom: 6 }}>{search ? t('no_results') : t('market_empty')}</div>
              <div style={{ fontSize: 13, color: text.muted }}>{search ? t('try_another_query') : t('products_not_added')}</div>
            </div>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: isMobileMarket ? 'repeat(2, minmax(0, 1fr))' : 'repeat(auto-fill, minmax(230px, 1fr))', gap: isMobileMarket ? '24px 14px' : '34px 20px', padding: isMobileMarket ? '22px 20px 6px' : '26px 32px 8px' }}>
                {pagedProducts.map(p => (
                  <ShopProductCard key={p.id} p={p} compact={isMobileMarket} onOpen={() => setPreview(p)} onAdd={() => (isShopProduct(p) ? setPreview(p) : addToCart(p))} />
                ))}
              </div>
              {hasMore && (
                <div style={{ display: 'flex', justifyContent: 'center', padding: '20px 22px 8px' }}>
                  <button onClick={loadMoreProducts} disabled={loadingMore} style={{ ...shopCaps(12, 0.16), fontWeight: 600, height: 48, padding: '0 30px', borderRadius: 14, border: '1px solid rgba(247,245,240,0.28)', background: 'transparent', color: text.primary, cursor: 'pointer' }}>
                    {loadingMore ? t('loading') : tr('Показати ще', 'Show more')}
                  </button>
                </div>
              )}
              {filteredProducts.length > PRODUCTS_PER_PAGE && (
                <div data-no-tab-swipe="true" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, padding: '12px 22px 16px', position: 'relative', zIndex: 2, flexWrap: 'wrap' }}>
                  <button
                    onClick={() => goToCatalogPage(catalogPage - 1)}
                    disabled={catalogPage === 1}
                    style={{
                      width: 32, height: 32, borderRadius: 10, border: `1px solid ${bg.border}`,
                      background: catalogPage === 1 ? 'rgba(255,255,255, 0.1)' : 'rgba(172,172,172, 0.12)',
                      color: catalogPage === 1 ? text.dim : text.secondary, cursor: catalogPage === 1 ? 'default' : 'pointer',
                      fontFamily: 'inherit', fontWeight: 700,
                    }}
                  >‹</button>
                  {catalogPages.map(page => (
                    typeof page === 'number' ? (
                    <button
                      key={page}
                      onClick={() => goToCatalogPage(page)}
                      style={{
                        minWidth: 32, height: 32, padding: '0 8px', borderRadius: 10, border: 'none',
                        background: page === catalogPage ? `${goldDark}` : 'rgba(255,255,255, 0.1)',
                        color: page === catalogPage ? '#161616' : text.secondary, cursor: 'pointer', fontFamily: 'inherit', fontWeight: 600,
                      }}
                    >{page}</button>
                    ) : (
                      <span key={page} style={{ minWidth: 18, color: text.dim, textAlign: 'center', fontWeight: 700 }}>…</span>
                    )
                  ))}
                  <button
                    onClick={() => goToCatalogPage(catalogPage + 1)}
                    disabled={catalogPage === totalCatalogPages}
                    style={{
                      width: 32, height: 32, borderRadius: 10, border: `1px solid ${bg.border}`,
                      background: catalogPage === totalCatalogPages ? 'rgba(255,255,255, 0.1)' : 'rgba(172,172,172, 0.12)',
                      color: catalogPage === totalCatalogPages ? text.dim : text.secondary, cursor: catalogPage === totalCatalogPages ? 'default' : 'pointer',
                      fontFamily: 'inherit', fontWeight: 700,
                    }}
                  >›</button>
                </div>
              )}
            </>
          )}
        </>
      )}

      {/* ── ORDERS ── */}
      {!loading && tab === 'orders' && (
        <div style={{ padding: '8px 22px' }}>
          {orders.length === 0 ? (
            <div style={{ padding: '60px 0', textAlign: 'center' }}>
              <div style={{ fontSize: 15, fontWeight: 600, color: text.secondary, marginBottom: 6 }}>{t('orders_empty')}</div>
              <div style={{ fontSize: 13, color: text.muted }}>{t('catalog_first_order_hint')}</div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {orders.map(o => {
                const tone = toneOf(o.status);
                return (
                <div key={o.id} style={{
                  background: '#1c1c1e',
                  border: `1px solid transparent`,
                  borderRadius: 18,
                  padding: '14px 16px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  boxShadow: '0 12px 26px rgba(0,0,0, 0.22)',
                }}>
                  <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                      <span style={{ fontSize: 14, fontWeight: 700, color: text.secondary }}>{t('order_label')} #{o.id}</span>
                      <span style={{ ...shopCaps(10.5, 0.14), fontWeight: 600, color: tone.fg, display: 'inline-flex', alignItems: 'center', gap: 7 }}><i style={{ width: 6, height: 6, borderRadius: 3, background: tone.fg, display: 'inline-block' }} />{o.status}</span>
                    </div>
                    <div style={{ fontSize: 12, color: text.muted }}>{o.items_count || 0} {t('order_items_suffix')} · {formatUkDateTime(o.created_at)}</div>
                    {o.invoice_number && <div style={{ fontSize: 11, color: text.dim, marginTop: 1, fontFamily: 'monospace' }}>{t('invoice_label')}: {o.invoice_number}</div>}
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{ ...T.bodyLg, fontWeight: 700, color: gold, ...T.num }}>{fmtInt(o.total_amount)}{fmtDec(o.total_amount)}{'\u00a0TAX'}</div>
                    <button onClick={() => downloadOrderReceipt(o.id)} disabled={dlPdf === `order-${o.id}`} style={{
                      ...shopCaps(10.5, 0.14), fontWeight: 600, marginTop: 9, padding: 0, border: 'none', background: 'none', color: gold, cursor: 'pointer',
                    }}>{dlPdf === `order-${o.id}` ? '…' : t('receipt_short')}</button>
                  </div>
                </div>
              );})}
            </div>
          )}
        </div>
      )}

      {/* ── INVOICES ── */}
      {!loading && tab === 'invoices' && (
        <div style={{ padding: '8px 22px' }}>
          {invoices.length === 0 ? (
            <div style={{ padding: '60px 0', textAlign: 'center' }}>
              <div style={{ fontSize: 15, fontWeight: 600, color: text.secondary, marginBottom: 6 }}>{t('invoices_empty')}</div>
              <div style={{ fontSize: 13, color: text.muted }}>{t('invoices_after_orders')}</div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {invoices.map(inv => {
                const tone = toneOf(inv.status);
                return (
                <div key={inv.invoice_number} style={{
                  background: '#1c1c1e',
                  border: `1px solid transparent`,
                  borderRadius: 16,
                  padding: '14px 16px',
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  boxShadow: '0 10px 22px rgba(0,0,0, 0.2)',
                }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 5 }}>
                      <span style={{ fontSize: 13, fontWeight: 700, color: text.secondary, fontFamily: 'monospace' }}>{inv.invoice_number}</span>
                      <span style={{ ...shopCaps(10.5, 0.14), fontWeight: 600, color: tone.fg, display: 'inline-flex', alignItems: 'center', gap: 7 }}><i style={{ width: 6, height: 6, borderRadius: 3, background: tone.fg, display: 'inline-block' }} />{inv.status}</span>
                    </div>
                    <div style={{ fontSize: 12, color: text.muted }}>
                      {formatUkDate(inv.created_at)}
                      {inv.due_at ? ` · ${t('due_prefix')} ${formatUkDate(inv.due_at)}` : ''}
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <div style={{ ...T.bodyLg, fontWeight: 700, color: gold, ...T.num }}>{fmtInt(inv.amount)}{fmtDec(inv.amount)}{'\u00a0TAX'}</div>
                    {inv.status === 'issued' && inv.order_id && (
                      <button onClick={() => downloadOrderReceipt(inv.order_id!)} disabled={dlPdf === `order-${inv.order_id}`} style={{
                        ...shopCaps(10.5, 0.14), fontWeight: 600, marginTop: 9, padding: 0, border: 'none', background: 'none', color: gold, cursor: 'pointer',
                      }}>{dlPdf === `order-${inv.order_id}` ? '…' : t('receipt_short')}</button>
                    )}
                  </div>
                </div>
              );})}
            </div>
          )}
        </div>
      )}
    </div>
    </ContentWrap>
    </>
  );
}

function getTabs(t: (key: TranslationKey) => string): { k: TabKey; label: string; icon: (c: string) => React.ReactNode }[] {
  return [
    { k: 'overview', label: t('tabs_overview'), icon: c => <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="7.5" height="7.5" rx="2" stroke={c} strokeWidth="1.8" /><rect x="13.5" y="3" width="7.5" height="7.5" rx="2" stroke={c} strokeWidth="1.8" /><rect x="3" y="13.5" width="7.5" height="7.5" rx="2" stroke={c} strokeWidth="1.8" /><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2" stroke={c} strokeWidth="1.8" /></svg> },
    { k: 'operations', label: t('tabs_operations'), icon: c => <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M3 12h3l3-8 4 16 3-8h5" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg> },
    { k: 'cards', label: t('tabs_cards'), icon: c => <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><rect x="2.5" y="5" width="19" height="14" rx="2.5" stroke={c} strokeWidth="1.8" /><path d="M2.5 10h19" stroke={c} strokeWidth="1.8" /></svg> },
    { k: 'market', label: t('tabs_market'), icon: c => <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13l-1.5 6h12" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /><circle cx="9" cy="21" r="1" fill={c} /><circle cx="19" cy="21" r="1" fill={c} /></svg> },
    { k: 'profile', label: t('tabs_profile'), icon: c => <svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="8" r="4" stroke={c} strokeWidth="1.8" /><path d="M4 21a8 8 0 0116 0" stroke={c} strokeWidth="1.8" strokeLinecap="round" /></svg> },
  ];
}

function TabBar({ active, onChange }: { active: TabKey; onChange: (k: TabKey) => void }) {
  const { t } = usePreferences();
  const tabs = getTabs(t);
  const activeIdx = tabs.findIndex(tab => tab.k === active);
  const safeAreaInset = 'env(safe-area-inset-bottom, 0px)';
  const tabButtonHeight = 62;
  const tabBarVerticalPadding = 6;
  const tabBarFrameHeight = `${tabButtonHeight + tabBarVerticalPadding * 2}px`;
  return (
    <div style={{
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      zIndex: 120,
      pointerEvents: 'none',
      paddingTop: 0,
      paddingLeft: 0,
      paddingRight: 0,
      paddingBottom: 0,
    }}>
      <div style={{
        position: 'relative',
        pointerEvents: 'auto',
        background: '#1c1c1e',
        borderTop: '1px solid transparent',
        boxShadow: '0 -8px 32px rgba(0,0,0, 0.28)',
        backdropFilter: 'blur(28px) saturate(190%)',
        WebkitBackdropFilter: 'blur(28px) saturate(190%)',
      }}>
        <div style={{
          position: 'relative',
          display: 'flex',
          alignItems: 'flex-end',
          minHeight: tabBarFrameHeight,
          padding: `${tabBarVerticalPadding}px 6px`,
        }}>
          <div style={{
            position: 'absolute',
            bottom: tabBarVerticalPadding,
            height: tabButtonHeight,
            left: `calc(${activeIdx * 20}% + 6px)`,
            width: 'calc(20% - 12px)',
            background: 'rgba(255,255,255, 0.1)',
            border: '1px solid transparent',
            borderRadius: 14,
            transition: 'left 0.32s cubic-bezier(0.4, 0, 0.2, 1)',
            boxShadow: 'none',
            pointerEvents: 'none',
          }} />
          {tabs.map(tab => {
            const isActive = tab.k === active;
            const color = isActive ? goldLight : 'rgba(215,215,215, 0.48)';
            return (
              <button key={tab.k} onClick={() => onChange(tab.k)} style={{
                flex: 1,
                minHeight: tabButtonHeight,
                padding: '8px 4px 6px',
                background: 'transparent',
                border: 'none',
                cursor: 'pointer',
                position: 'relative',
                zIndex: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 2,
                color,
                fontSize: 10,
                fontWeight: isActive ? 700 : 500,
                letterSpacing: 0.3,
                fontFamily: 'inherit',
                transition: 'color 0.2s',
              }}>
                {tab.icon(color)}
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>
      {/* Safe-area filler — fills home-indicator zone so no background bleeds through */}
      <div className="tab-safe-area" style={{
        pointerEvents: 'auto',
        height: safeAreaInset,   /* = env(safe-area-inset-bottom, 0px) */
        minHeight: safeAreaInset,
        background: 'rgba(18,18,18, 0.97)',
        flexShrink: 0,
      }} />
    </div>
  );
}

// ─── Desktop cart panel ───────────────────────────────────────
function DesktopCartPanel({ cart, onQtyChange, onRemove, onCheckout, checkingOut, user }: {
  cart: CartItem[];
  onQtyChange: (key: string, delta: number) => void;
  onRemove: (key: string) => void;
  onCheckout: (shipping: { name: string; phone: string; address: string }) => void;
  checkingOut: boolean;
  user: { full_name: string; phone: string } | null;
}) {
  const { t, lang } = usePreferences();
  const total = cart.reduce((s, i) => s + i.product.price * i.qty, 0);
  const [step, setStep] = useState<'cart' | 'shipping'>('cart');
  const [shipName, setShipName] = useState(user?.full_name || '');
  const [shipPhone, setShipPhone] = useState(user?.phone || '');
  const [shipAddr, setShipAddr] = useState('');
  const [tried, setTried] = useState(false);
  const shipErr = validateShipping(shipName, shipPhone, shipAddr, lang === 'uk');
  const submitShipping = () => {
    if (Object.keys(shipErr).length > 0) { setTried(true); return; }
    onCheckout({ name: shipName.trim(), phone: shipPhone.trim(), address: shipAddr.trim() });
  };
  const cartCount = cart.reduce((s, i) => s + i.qty, 0);
  useEffect(() => { if (cart.length === 0) setStep('cart'); }, [cart.length]);

  const fieldSt: React.CSSProperties = {
    width: '100%', padding: '9px 12px',
    background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent',
    borderRadius: 10, color: text.primary, fontSize: 13, outline: 'none',
    fontFamily, boxSizing: 'border-box',
  };
  const lblSt: React.CSSProperties = { fontSize: 10.5, color: text.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 4, display: 'block' };

  return (
    <div style={{
      position: 'fixed', right: 0, top: 76, bottom: 0, width: 320,
      display: 'flex', flexDirection: 'column',
      background: 'rgba(14,14,15, 0.97)',
      backdropFilter: 'blur(28px)', WebkitBackdropFilter: 'blur(28px)',
      borderLeft: '1px solid var(--kp-line)',
      zIndex: 90,
    }}>
      {/* Header */}
      <div style={{ padding: '32px 20px 16px', borderBottom: '1px solid transparent', flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
            <path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13l-1.5 6h12" stroke={gold} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
            <circle cx="9" cy="21" r="1" fill={gold} /><circle cx="19" cy="21" r="1" fill={gold} />
          </svg>
          <div style={{ ...T.h3, color: text.primary, flex: 1 }}>{t('cart_title')}</div>
          {cartCount > 0 && (
            <span style={{ fontSize: 11, fontWeight: 700, background: gold, color: '#161616', borderRadius: 20, padding: '2px 9px', letterSpacing: 0.2 }}>
              {cartCount} {t('cart_items_count')}
            </span>
          )}
        </div>
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px', WebkitOverflowScrolling: 'touch' }}>
        {cart.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: 12, color: text.muted }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" opacity={0.3}>
              <path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13l-1.5 6h12" stroke={gold} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              <circle cx="9" cy="21" r="1" fill={gold} /><circle cx="19" cy="21" r="1" fill={gold} />
            </svg>
            <span style={{ fontSize: 13 }}>{t('cart_empty')}</span>
          </div>
        ) : step === 'cart' ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {cart.map(item => (
              <div key={cartKey(item)} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, borderRadius: 14 }}>
                <div style={{ width: 42, height: 42, borderRadius: 11, overflow: 'hidden', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(216,216,216, 0.06)' }}>
                  <ProductVisual product={item.product} size="cart" />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600, color: text.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.product.title}{item.size ? ` · ${item.size}` : ''}</div>
                  <div style={{ fontSize: 12, color: gold, fontWeight: 700, marginTop: 2 }}>{fmtInt(item.product.price * item.qty)}{fmtDec(item.product.price * item.qty)}{'\u00a0TAX'}</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
                  <button onClick={() => onQtyChange(cartKey(item), -1)} style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, color: text.secondary, cursor: 'pointer', fontFamily, fontSize: 15, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>−</button>
                  <span style={{ minWidth: 20, textAlign: 'center', fontSize: 13, fontWeight: 600, color: text.primary }}>{item.qty}</span>
                  <button onClick={() => onQtyChange(cartKey(item), 1)} style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255, 0.1)', border: `1px solid ${bg.border}`, color: text.secondary, cursor: 'pointer', fontFamily, fontSize: 15, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>+</button>
                  <button onClick={() => onRemove(cartKey(item))} style={{ width: 26, height: 26, borderRadius: 7, background: 'transparent', border: 'none', color: 'rgba(126,126,126, 0.55)', cursor: 'pointer', fontFamily, fontSize: 13, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>✕</button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <button onClick={() => setStep('cart')} style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'none', border: 'none', color: gold, cursor: 'pointer', fontFamily, fontSize: 12, padding: 0, marginBottom: 4 }}>
              <svg width="12" height="12" viewBox="0 0 16 16" fill="none"><path d="M10 4L6 8l4 4" stroke={gold} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>
              {tr('Назад', 'Back')}
            </button>
            <div style={{ ...T.h3, color: text.primary, marginBottom: 4 }}>{t('delivery_title')}</div>
            <div>
              <label style={lblSt}>{t('recipient_label')}</label>
              <input value={shipName} onChange={e => setShipName(e.target.value)} placeholder={t('shipping_name_placeholder')} style={{ ...fieldSt, ...(tried && shipErr.name ? shipErrStyle : null) }} aria-invalid={tried && shipErr.name ? true : undefined} autoComplete="name" />
              {tried && shipErr.name && <ShipError text={shipErr.name} />}
            </div>
            <div>
              <label style={lblSt}>{t('delivery_phone')}</label>
              <input value={shipPhone} onChange={e => setShipPhone(e.target.value)} placeholder="+380XXXXXXXXX" style={{ ...fieldSt, ...(tried && shipErr.phone ? shipErrStyle : null) }} aria-invalid={tried && shipErr.phone ? true : undefined} inputMode="tel" autoComplete="tel" />
              {tried && shipErr.phone && <ShipError text={shipErr.phone} />}
            </div>
            <div>
              <label style={lblSt}>{t('delivery_address')}</label>
              <input value={shipAddr} onChange={e => setShipAddr(e.target.value)} placeholder={t('shipping_address_placeholder')} style={{ ...fieldSt, ...(tried && shipErr.address ? shipErrStyle : null) }} aria-invalid={tried && shipErr.address ? true : undefined} autoComplete="street-address" />
              {tried && shipErr.address && <ShipError text={shipErr.address} />}
            </div>
          </div>
        )}
      </div>

      {/* Footer */}
      {cart.length > 0 && (
        <div style={{ padding: '14px 20px 24px', borderTop: '1px solid transparent', flexShrink: 0 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
            <span style={{ fontSize: 12, color: text.muted }}>{step === 'cart' ? t('total_label') : t('pay_total')}:</span>
            <span style={{ ...T.num, fontSize: 20, fontWeight: 700, color: text.primary }}>{fmtInt(total)}{fmtDec(total)}{'\u00a0TAX'}</span>
          </div>
          <button
            onClick={() => step === 'cart' ? setStep('shipping') : submitShipping()}
            disabled={checkingOut}
            style={{
              width: '100%', padding: '13px 16px', borderRadius: 14,
              background: checkingOut ? 'rgba(95,95,95, 0.3)' : `${goldDark}`,
              border: 'none', color: '#161616', fontSize: 13.5, fontWeight: 700,
              cursor: checkingOut ? 'wait' : 'pointer', fontFamily, letterSpacing: 0.2,
            }}
          >
            {checkingOut ? t('checkout_processing') : step === 'cart' ? `${t('next_delivery')} →` : `✓ ${t('place_order')}`}
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Desktop sidebar ──────────────────────────────────────────
// ─── Desktop: іконки, оболонка, палітра команд ────────────────
const ICON_PATHS = {
  search: <><circle cx="11" cy="11" r="7" /><path d="M20 20l-3.5-3.5" /></>,
  bell: <><path d="M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9" /><path d="M10 21a2 2 0 004 0" /></>,
  eye: <><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z" /><circle cx="12" cy="12" r="3" /></>,
  eyeOff: <><path d="M3 3l18 18M10.6 10.6a2 2 0 002.8 2.8M9.4 5.1A10.9 10.9 0 0112 5c6 0 10 7 10 7a18 18 0 01-3.2 3.9M6.6 6.6A18 18 0 002 12s4 7 10 7a11 11 0 003.4-.5" /></>,
  copy: <><rect x="9" y="9" width="11" height="11" rx="2.5" /><path d="M5 15V6a2 2 0 012-2h9" /></>,
  logout: <><path d="M10 4H6a2 2 0 00-2 2v12a2 2 0 002 2h4" /><path d="M16 16l4-4-4-4M20 12H9" /></>,
  panel: <><rect x="3" y="4" width="18" height="16" rx="3" /><path d="M9 4v16" /></>,
  up: <path d="M12 19V5M5 12l7-7 7 7" />,
  right: <path d="M5 12h14M13 5l7 7-7 7" />,
  hash: <path d="M4 9h16M4 15h16M9 4L7 20M17 4l-2 16" />,
  cart: <><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13l-1.5 6h12" /><circle cx="9" cy="21" r="1" /><circle cx="19" cy="21" r="1" /></>,
  inbound: <path d="M17 7L7 17M7 8v9h9" />,
  outbound: <path d="M7 17L17 7M8 7h9v9" />,
  arrowUR: <path d="M7 17L17 7M8 7h9v9" />,
  return: <path d="M9 10l-5 5 5 5M20 4v7a4 4 0 01-4 4H4" />,
  chevR: <path d="M9 6l6 6-6 6" />,
} as const;
type IconName = keyof typeof ICON_PATHS;

function Ico({ n, size = 18, sw = 1.7 }: { n: IconName; size?: number; sw?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{ flexShrink: 0 }}>
      {ICON_PATHS[n]}
    </svg>
  );
}

const IS_MAC = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
const MOD_KEY = IS_MAC ? '⌘' : 'Ctrl';
const RAIL_STORAGE_KEY = 'kopiyka_rail_collapsed';

function useRailCollapsed() {
  const width = useWindowWidth();
  const [pref, setPref] = useState<boolean | null>(() => {
    try { const v = localStorage.getItem(RAIL_STORAGE_KEY); return v === null ? null : v === '1'; } catch { return null; }
  });
  const collapsed = pref ?? width < 1240;
  const toggle = () => {
    const next = !collapsed;
    setPref(next);
    try { localStorage.setItem(RAIL_STORAGE_KEY, next ? '1' : '0'); } catch { /* ignore */ }
  };
  return [collapsed, toggle] as const;
}

function useCountUp(target: number, ms = 900) {
  const [value, setValue] = useState(0);
  const fromRef = useRef(0);
  useEffect(() => {
    if (typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      fromRef.current = target; setValue(target); return;
    }
    const start = performance.now();
    const a = fromRef.current;
    let raf = 0;
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / ms);
      const eased = 1 - Math.pow(1 - p, 4);
      const cur = a + (target - a) * eased;
      fromRef.current = cur;
      setValue(cur);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, ms]);
  return value;
}

function txTypeLabel(type: string, t: (key: TranslationKey) => string): string {
  const base: Record<string, TranslationKey> = {
    transfer: 'spend_transfer', food: 'spend_food', transport: 'spend_transport',
    utility: 'spend_utility', shopping: 'spend_shopping', subscription: 'spend_subscription',
  };
  if (base[type]) return t(base[type]);
  const key = `dk_cat_${type}` as TranslationKey;
  return key in translations.uk ? t(key) : type;
}

// ── Бічне меню: розгорнуте або рейка з іконками ──
function DesktopSidebar({ active, onChange, collapsed, onToggle }: { active: TabKey; onChange: (k: TabKey) => void; collapsed: boolean; onToggle: () => void }) {
  const { logout, user, goTo } = useApp();
  const { profilePhoto, t } = usePreferences();
  const tabs = getTabs(t);
  const name = user?.full_name ?? t('user_fallback');
  return (
    <aside style={{
      width: collapsed ? 88 : 272, flexShrink: 0,
      transition: 'width 0.32s var(--kp-ease)',
      display: 'flex', flexDirection: 'column',
      padding: '22px 14px 18px',
      borderRight: '1px solid var(--kp-line)',
      background: 'rgba(9,9,10, 0.62)',
      backdropFilter: 'blur(28px)', WebkitBackdropFilter: 'blur(28px)',
      position: 'relative', zIndex: 20,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: collapsed ? '0 0 0 6px' : '0 8px', height: 44, marginBottom: 22, overflow: 'hidden' }}>
        <BrandMark size={40} radiusValue={12} />
        {!collapsed && (
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 17, fontWeight: 600, letterSpacing: '0.02em', color: text.primary, lineHeight: 1.1 }}>TaxTech</div>
            <div style={{ fontSize: 12, color: text.dim, marginTop: 3 }}>{t('personal_cabinet')}</div>
          </div>
        )}
      </div>

      <nav aria-label={t('dk_menu')} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {tabs.map(tb => {
          const isActive = tb.k === active;
          return (
            <button
              key={tb.k}
              onClick={() => onChange(tb.k)}
              className="kp-nav"
              aria-current={isActive ? 'page' : undefined}
              title={collapsed ? tb.label : undefined}
              style={{
                position: 'relative',
                display: 'flex', alignItems: 'center', gap: 14,
                height: 48, padding: collapsed ? 0 : '0 14px',
                justifyContent: collapsed ? 'center' : 'flex-start',
                borderRadius: 14, border: 'none',
                background: isActive ? 'var(--kp-fill-2)' : 'transparent',
                color: isActive ? 'var(--kp-ink)' : 'var(--kp-muted)',
                fontFamily, fontSize: 15, fontWeight: isActive ? 600 : 500, letterSpacing: -0.15,
                cursor: 'pointer', textAlign: 'left',
              }}
            >
              {isActive && <span aria-hidden style={{ position: 'absolute', left: collapsed ? 6 : -14, top: 13, bottom: 13, width: 3, borderRadius: 3, background: 'var(--kp-ink)' }} />}
              {tb.icon(isActive ? '#f4f4f5' : 'rgba(212,212,216,0.62)')}
              {!collapsed && <span style={{ whiteSpace: 'nowrap' }}>{tb.label}</span>}
            </button>
          );
        })}
      </nav>

      <div style={{ flex: 1 }} />

      <button
        onClick={() => goTo('profile')}
        className="kp-hover"
        title={collapsed ? name : undefined}
        style={{
          display: 'flex', alignItems: 'center', gap: 12, width: '100%',
          padding: collapsed ? '10px 0' : '10px 12px', justifyContent: collapsed ? 'center' : 'flex-start',
          borderRadius: 16, border: '1px solid var(--kp-line)', background: 'var(--kp-fill)',
          fontFamily, textAlign: 'left', color: 'inherit', marginBottom: 10,
        }}
      >
        <span style={{
          width: 38, height: 38, borderRadius: '50%', flexShrink: 0, overflow: 'hidden',
          background: gold, color: '#1a1a1a', fontSize: 13, fontWeight: 700,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {profilePhoto ? <img src={profilePhoto} alt={t('profile_photo_alt')} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initials(name)}
        </span>
        {!collapsed && (
          <span style={{ minWidth: 0 }}>
            <span style={{ display: 'block', fontSize: 14, fontWeight: 600, color: text.primary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{name}</span>
            <span style={{ display: 'block', fontSize: 12, color: text.dim, marginTop: 1 }}>{t('profile_verified')}</span>
          </span>
        )}
      </button>

      <div style={{ display: 'flex', gap: 8, flexDirection: collapsed ? 'column' : 'row' }}>
        <button onClick={logout} className="kp-hover" title={t('profile_logout')} aria-label={t('profile_logout')} style={{
          flex: collapsed ? 'none' : 1, width: collapsed ? '100%' : undefined, height: 42, borderRadius: 12, border: '1px solid var(--kp-line)', background: 'transparent',
          color: 'var(--kp-muted)', fontFamily, fontSize: 13.5, fontWeight: 500,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <Ico n="logout" size={16} />
          {!collapsed && t('profile_logout')}
        </button>
        <button onClick={onToggle} className="kp-hover" title={collapsed ? t('dk_expand') : t('dk_collapse')} aria-label={collapsed ? t('dk_expand') : t('dk_collapse')} aria-pressed={collapsed} style={{
          width: collapsed ? '100%' : 42, height: 42, borderRadius: 12, border: '1px solid var(--kp-line)', background: 'transparent',
          color: 'var(--kp-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Ico n="panel" size={17} />
        </button>
      </div>
    </aside>
  );
}

// ── Сповіщення: випадна панель біля дзвіночка ──
function NotificationsPopover() {
  const { t, lang } = usePreferences();
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<ApiNotification[]>([]);
  const [unread, setUnread] = useState(0);
  const wrapRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) return;
    fetch(apiUrl('/api/notifications/unread-count'), { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.ok ? r.json() : null)
      .then(j => { if (j?.ok) setUnread(j.data?.count ?? 0); })
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => { if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false); };
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setOpen(false); };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => { document.removeEventListener('mousedown', onDown); document.removeEventListener('keydown', onKey); };
  }, [open]);

  async function toggle() {
    const next = !open;
    setOpen(next);
    if (!next) return;
    const token = localStorage.getItem('army_bank_token');
    try {
      const [res] = await Promise.all([
        fetch(apiUrl('/api/notifications'), { headers: { Authorization: `Bearer ${token ?? ''}` } }),
        token ? fetch(apiUrl('/api/notifications/read-all'), { method: 'POST', headers: { Authorization: `Bearer ${token}` } }) : Promise.resolve(null),
      ]);
      if (res.ok) {
        const j = await res.json();
        if (j?.ok && Array.isArray(j.data)) setItems(j.data);
      }
      setUnread(0);
    } catch { /* ignore */ }
  }

  return (
    <div ref={wrapRef} style={{ position: 'relative' }}>
      <button onClick={toggle} className="kp-hover" aria-label={t('notifications_center')} aria-expanded={open} style={{
        position: 'relative', width: 44, height: 44, borderRadius: 14, border: '1px solid var(--kp-line)',
        background: open ? 'var(--kp-fill-2)' : 'var(--kp-fill)', color: 'var(--kp-ink-2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Ico n="bell" size={19} />
        {unread > 0 && <span aria-hidden style={{ position: 'absolute', top: 10, right: 11, width: 8, height: 8, borderRadius: '50%', background: gold, boxShadow: '0 0 0 2px #0b0b0c' }} />}
      </button>
      {open && (
        <div className="kp-pop" role="dialog" aria-label={t('notifications_center')} style={{
          position: 'absolute', right: 0, top: 54, width: 400, maxHeight: 520, overflowY: 'auto', zIndex: 60,
          borderRadius: 22, border: '1px solid var(--kp-line-2)', background: 'rgba(22,22,24, 0.96)',
          backdropFilter: 'blur(28px)', WebkitBackdropFilter: 'blur(28px)',
          boxShadow: '0 40px 80px -24px rgba(0,0,0,0.8)', padding: 8,
        }}>
          <div style={{ padding: '12px 14px 8px', fontSize: 15, fontWeight: 600, color: text.primary }}>{t('notifications_center')}</div>
          {items.length === 0 ? (
            <div style={{ padding: '36px 16px', textAlign: 'center', color: text.muted, fontSize: 14 }}>{t('no_new_notifications')}</div>
          ) : items.map(n => (
            <div key={n.id} className="kp-row" style={{ padding: '12px 14px', borderRadius: 14, opacity: n.is_read ? 0.66 : 1 }}>
              <div style={{ fontSize: 14, fontWeight: n.is_read ? 500 : 600, color: text.secondary }}>{n.title}</div>
              {n.body ? <div style={{ fontSize: 13, color: text.muted, lineHeight: 1.45, marginTop: 3 }}>{n.body}</div> : null}
              <div style={{ fontSize: 12, color: text.dim, marginTop: 5 }}>{fmtTime(n.created_at, lang)}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Палітра команд (⌘K): пошук сторінок, дій і операцій ──
type PaletteItem = { id: string; group: string; label: string; hint?: string; icon: React.ReactNode; run: () => void };

function CommandPalette({ onClose, onNavigate }: { onClose: () => void; onNavigate: (k: TabKey) => void }) {
  const { t } = usePreferences();
  const { openTransfer, transactions, account, toast, logout } = useApp();
  const [query, setQuery] = useState('');
  const [cursor, setCursor] = useState(0);
  const listRef = useRef<HTMLDivElement | null>(null);
  const tabs = getTabs(t);

  const all = useMemo<PaletteItem[]>(() => {
    const go = (k: TabKey) => () => { onNavigate(k); };
    const items: PaletteItem[] = tabs.map(tb => ({ id: `go-${tb.k}`, group: t('dk_group_go'), label: tb.label, icon: tb.icon('currentColor'), run: go(tb.k) }));
    items.push(
      { id: 'a-topup', group: t('dk_group_actions'), label: t('quick_topup'), icon: <Ico n="up" />, run: () => openTransfer('topup') },
      { id: 'a-card', group: t('dk_group_actions'), label: t('quick_by_card'), icon: <Ico n="right" />, run: () => openTransfer('by_card') },
      { id: 'a-acc', group: t('dk_group_actions'), label: t('quick_by_account'), icon: <Ico n="hash" />, run: () => openTransfer('by_account') },
    );
    if (account?.account_number) {
      items.push({
        id: 'a-copy', group: t('dk_group_actions'), label: t('dk_copy_account'), hint: account.account_number, icon: <Ico n="copy" />,
        run: () => { navigator.clipboard?.writeText(account.account_number).then(() => toast(t('dk_copied'))).catch(() => {}); },
      });
    }
    items.push({ id: 'a-out', group: t('dk_group_actions'), label: t('profile_logout'), icon: <Ico n="logout" />, run: logout });
    return items;
  }, [t, account, openTransfer, onNavigate, toast, logout]);

  const q = query.trim().toLowerCase();
  const filtered = useMemo(() => {
    if (!q) return all;
    const base = all.filter(i => i.label.toLowerCase().includes(q) || (i.hint || '').toLowerCase().includes(q));
    if (q.length < 2) return base;
    const tx = transactions
      .filter(x => (x.description || '').toLowerCase().includes(q) || String(x.amount).includes(q))
      .slice(0, 6)
      .map<PaletteItem>(x => ({
        id: `tx-${x.id}`, group: t('dk_group_tx'), label: x.description || txTypeLabel(x.tx_type, t),
        hint: `${x.direction === 'in' ? '+' : '−'}${fmtInt(x.amount)}${fmtDec(x.amount)} TAX`,
        icon: <Ico n={x.direction === 'in' ? 'inbound' : 'outbound'} />, run: () => onNavigate('operations'),
      }));
    return [...base, ...tx];
  }, [q, all, transactions, t, onNavigate]);

  useEffect(() => { setCursor(0); }, [q]);
  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>(`[data-idx="${cursor}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [cursor]);

  const runAt = (i: number) => { const it = filtered[i]; if (!it) return; onClose(); it.run(); };
  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') { e.preventDefault(); onClose(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); setCursor(c => Math.min(filtered.length - 1, c + 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setCursor(c => Math.max(0, c - 1)); }
    else if (e.key === 'Enter') { e.preventDefault(); runAt(cursor); }
  };

  let lastGroup = '';
  return (
    <div className="kp-fade" onMouseDown={onClose} style={{ position: 'fixed', inset: 0, zIndex: 400, background: 'rgba(0,0,0,0.58)', backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)', display: 'flex', justifyContent: 'center', alignItems: 'flex-start', paddingTop: '13vh' }}>
      <div role="dialog" aria-modal="true" aria-label={t('dk_search')} className="kp-pop" onMouseDown={e => e.stopPropagation()} onKeyDown={onKeyDown} style={{
        width: 'min(680px, calc(100vw - 48px))', borderRadius: 24, overflow: 'hidden',
        border: '1px solid var(--kp-line-2)', background: 'rgba(20,20,22, 0.97)',
        boxShadow: '0 50px 100px -30px rgba(0,0,0,0.9)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '0 22px', height: 64, borderBottom: '1px solid var(--kp-line)' }}>
          <span style={{ color: 'var(--kp-muted)', display: 'flex' }}><Ico n="search" size={20} /></span>
          <input
            autoFocus value={query} onChange={e => setQuery(e.target.value)} placeholder={t('dk_search_ph')}
            role="combobox" aria-expanded="true" aria-controls="kp-palette-list" aria-activedescendant={filtered[cursor] ? `kp-opt-${cursor}` : undefined}
            style={{ flex: 1, minWidth: 0, background: 'transparent', border: 'none', outline: 'none', color: text.primary, fontSize: 17, fontFamily }}
          />
          <span className="kp-kbd">esc</span>
        </div>
        <div ref={listRef} id="kp-palette-list" role="listbox" style={{ maxHeight: 'min(420px, 52vh)', overflowY: 'auto', padding: 8 }}>
          {filtered.length === 0 && <div style={{ padding: '36px 16px', textAlign: 'center', color: text.muted, fontSize: 14 }}>{t('dk_no_results')}</div>}
          {filtered.map((it, i) => {
            const header = it.group !== lastGroup ? it.group : null;
            lastGroup = it.group;
            const sel = i === cursor;
            return (
              <Fragment key={it.id}>
                {header && <div style={{ padding: '12px 14px 6px', fontSize: 12, fontWeight: 600, color: text.dim }}>{header}</div>}
                <div
                  id={`kp-opt-${i}`} data-idx={i} role="option" aria-selected={sel}
                  onMouseMove={() => setCursor(i)} onClick={() => runAt(i)}
                  style={{ display: 'flex', alignItems: 'center', gap: 14, height: 48, padding: '0 14px', borderRadius: 14, cursor: 'pointer', background: sel ? 'var(--kp-fill-2)' : 'transparent', color: sel ? text.primary : text.secondary }}
                >
                  <span style={{ color: sel ? text.primary : 'var(--kp-muted)', display: 'flex' }}>{it.icon}</span>
                  <span style={{ flex: 1, minWidth: 0, fontSize: 15, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.label}</span>
                  {it.hint && <span style={{ fontSize: 13, color: text.muted, ...T.num }}>{it.hint}</span>}
                  {sel && <span style={{ color: 'var(--kp-muted)', display: 'flex' }}><Ico n="return" size={15} /></span>}
                </div>
              </Fragment>
            );
          })}
        </div>
        <div style={{ display: 'flex', gap: 18, padding: '12px 22px', borderTop: '1px solid var(--kp-line)', fontSize: 12.5, color: text.dim }}>
          <span><span className="kp-kbd">↑</span> <span className="kp-kbd">↓</span>&nbsp; {t('dk_to_navigate')}</span>
          <span><span className="kp-kbd">↵</span>&nbsp; {t('dk_to_open')}</span>
          <span style={{ marginLeft: 'auto' }}><span className="kp-kbd">esc</span>&nbsp; {t('dk_to_close')}</span>
        </div>
      </div>
    </div>
  );
}

// ── Верхня панель: пошук, баланс, сповіщення ──
function DesktopTopbar({ tab, onOpenPalette }: { tab: TabKey; onOpenPalette: () => void }) {
  const { account } = useApp();
  const { t } = usePreferences();
  return (
    <header style={{
      position: 'sticky', top: 0, zIndex: 30, height: 76,
      display: 'flex', alignItems: 'center', gap: 16, padding: '0 40px',
      background: 'rgba(11,11,12, 0.72)', backdropFilter: 'blur(22px) saturate(150%)', WebkitBackdropFilter: 'blur(22px) saturate(150%)',
      borderBottom: '1px solid var(--kp-line)',
    }}>
      <button onClick={onOpenPalette} className="kp-hover" aria-label={t('dk_search')} aria-keyshortcuts="Control+K Meta+K" style={{
        flex: '0 1 460px', height: 46, display: 'flex', alignItems: 'center', gap: 12, padding: '0 14px 0 16px',
        borderRadius: 15, border: '1px solid var(--kp-line)', background: 'var(--kp-fill)',
        color: 'var(--kp-muted)', fontFamily, fontSize: 14.5, textAlign: 'left',
      }}>
        <Ico n="search" size={18} />
        <span style={{ flex: 1 }}>{t('dk_search')}</span>
        <span className="kp-kbd">{MOD_KEY}</span><span className="kp-kbd" style={{ marginLeft: -6 }}>K</span>
      </button>
      <div style={{ flex: 1 }} />
      {tab !== 'overview' && account && (
        <div className="kp-fade" style={{ display: 'flex', alignItems: 'baseline', gap: 6, padding: '0 6px', ...T.num }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: gold }}>TAX</span>
          <span style={{ fontSize: 18, fontWeight: 600, color: text.primary, letterSpacing: -0.4 }}>{fmtInt(account.balance)}</span>
          <span style={{ fontSize: 13, color: 'var(--kp-dim)' }}>{fmtDec(account.balance)}</span>
        </div>
      )}
      <NotificationsPopover />
    </header>
  );
}

function DesktopSkeleton() {
  return (
    <div style={{ padding: '32px 40px', maxWidth: 1560, margin: '0 auto' }} aria-busy="true">
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12, minmax(0, 1fr))', gap: 24 }}>
        <div className="kp-skel" style={{ gridColumn: 'span 8', height: 420, borderRadius: 24 }} />
        <div className="kp-skel" style={{ gridColumn: 'span 4', height: 420, borderRadius: 24 }} />
        <div className="kp-skel" style={{ gridColumn: 'span 7', height: 320, borderRadius: 24 }} />
        <div className="kp-skel" style={{ gridColumn: 'span 5', height: 320, borderRadius: 24 }} />
      </div>
    </div>
  );
}

function DesktopShell({ tab, onChange, dataError, loading, children }: { tab: TabKey; onChange: (k: TabKey) => void; dataError: string; loading: boolean; children: React.ReactNode }) {
  const [collapsed, toggleRail] = useRailCollapsed();
  const [palette, setPalette] = useState(false);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setPalette(v => !v); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  useEffect(() => { scrollRef.current?.scrollTo({ top: 0 }); }, [tab]);

  return (
    <div className="kp-stage tt-app" style={{ ...appBase, background: undefined, display: 'flex' }}>
      <DesktopSidebar active={tab} onChange={onChange} collapsed={collapsed} onToggle={toggleRail} />
      <div ref={scrollRef} style={{ flex: 1, minWidth: 0, overflowY: 'auto', overflowX: 'hidden' }}>
        <DesktopTopbar tab={tab} onOpenPalette={() => setPalette(true)} />
        {dataError && (
          <div role="alert" style={{ margin: '16px 40px 0', padding: '12px 16px', borderRadius: 14, border: '1px solid var(--kp-line-2)', background: 'var(--kp-fill)', color: text.secondary, fontSize: 14 }}>{dataError}</div>
        )}
        <main key={tab} className="kp-fade">{loading ? <DesktopSkeleton /> : children}</main>
      </div>
      {palette && <CommandPalette onClose={() => setPalette(false)} onNavigate={k => { setPalette(false); onChange(k); }} />}
    </div>
  );
}

// ─── Desktop: головна (бенто-сітка) ───────────────────────────
function BalanceTrend() {
  const { t, lang } = usePreferences();
  const [days, setDays] = useState(14);
  const [points, setPoints] = useState<BalancePoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [hover, setHover] = useState<number | null>(null);
  const uid = useId().replace(/:/g, '');

  useEffect(() => {
    const token = localStorage.getItem('army_bank_token');
    if (!token) { setLoading(false); return; }
    const ctrl = new AbortController();
    setLoading(true);
    fetch(apiUrl(`/api/analytics/balance-history?days=${days}`), { headers: { Authorization: `Bearer ${token}` }, signal: ctrl.signal })
      .then(r => r.ok ? r.json() : null)
      .then(j => { setPoints(j?.ok && Array.isArray(j.data) ? j.data : []); setLoading(false); })
      .catch(e => { if (e?.name !== 'AbortError') setLoading(false); });
    return () => ctrl.abort();
  }, [days]);

  const W = 800, H = 200, PAD = 16;
  const n = points.length;
  const ready = n >= 2;
  const vals = points.map(p => p.balance);
  const min = ready ? Math.min(...vals) : 0;
  const max = ready ? Math.max(...vals) : 1;
  const range = max - min || 1;
  const xAt = (i: number) => (i / (n - 1)) * W;
  const yAt = (v: number) => H - PAD - ((v - min) / range) * (H - PAD * 2);
  let line = '';
  if (ready) {
    line = `M ${xAt(0).toFixed(1)} ${yAt(vals[0]).toFixed(1)}`;
    for (let i = 1; i < n; i++) {
      const cx = (xAt(i - 1) + xAt(i)) / 2;
      line += ` C ${cx.toFixed(1)} ${yAt(vals[i - 1]).toFixed(1)}, ${cx.toFixed(1)} ${yAt(vals[i]).toFixed(1)}, ${xAt(i).toFixed(1)} ${yAt(vals[i]).toFixed(1)}`;
    }
  }
  const area = ready ? `${line} L ${W} ${H} L 0 ${H} Z` : '';
  const locale = localeForLang(lang);
  const fmtDay = (d: string) => new Date(d).toLocaleDateString(locale, { day: 'numeric', month: 'short' });
  const hp = hover != null && ready ? points[hover] : null;
  const hx = hover != null && ready ? (hover / (n - 1)) * 100 : 0;
  const hy = hp ? (yAt(hp.balance) / H) * 100 : 0;

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: text.muted }}>{t('dk_history_chart')}</span>
        <div role="group" aria-label={t('dk_history_chart')} style={{ display: 'flex', gap: 2, padding: 3, borderRadius: 12, background: 'var(--kp-fill)', border: '1px solid var(--kp-line)' }}>
          {[7, 14, 30].map(d => (
            <button key={d} onClick={() => setDays(d)} aria-pressed={d === days} style={{
              height: 28, padding: '0 12px', borderRadius: 9, border: 'none', fontFamily, fontSize: 12.5, fontWeight: 600, cursor: 'pointer',
              background: d === days ? 'var(--kp-fill-2)' : 'transparent', color: d === days ? text.primary : 'var(--kp-muted)',
              transition: 'background 0.18s, color 0.18s',
            }}>{d}{t('dk_days_short')}</button>
          ))}
        </div>
      </div>
      <div
        style={{ position: 'relative', height: 168, touchAction: 'none' }}
        onMouseMove={e => { if (!ready) return; const r = e.currentTarget.getBoundingClientRect(); setHover(Math.max(0, Math.min(n - 1, Math.round(((e.clientX - r.left) / r.width) * (n - 1))))); }}
        onMouseLeave={() => setHover(null)}
      >
        {loading && <div className="kp-skel" style={{ position: 'absolute', inset: 0 }} />}
        {!loading && !ready && <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', color: text.dim, fontSize: 14, border: '1px dashed var(--kp-line-2)', borderRadius: 16 }}>{t('insufficient_spend_data')}</div>}
        {ready && !loading && (
          <>
            <svg key={days} viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" role="img" aria-label={`${t('dk_history_chart')}: ${fmtDay(points[0].day)} — ${fmtDay(points[n - 1].day)}`} className="kp-wipe" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', overflow: 'visible' }}>
              <defs>
                <linearGradient id={`bt-${uid}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={gold} stopOpacity="0.28" />
                  <stop offset="100%" stopColor={gold} stopOpacity="0" />
                </linearGradient>
              </defs>
              {[0.25, 0.5, 0.75].map(g => <line key={g} x1="0" x2={W} y1={H * g} y2={H * g} stroke="rgba(255,255,255, 0.1)" strokeDasharray="3 6" vectorEffect="non-scaling-stroke" />)}
              <path d={area} fill={`url(#bt-${uid})`} />
              <path d={line} fill="none" stroke={gold} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" style={{ filter: 'drop-shadow(0 0 6px rgba(255,212,0,0.45))' }} />
            </svg>
            {hp && (
              <>
                <div aria-hidden style={{ position: 'absolute', top: 0, bottom: 0, left: `${hx}%`, width: 1, background: 'rgba(255,255,255,0.22)', pointerEvents: 'none' }} />
                <div aria-hidden style={{ position: 'absolute', left: `${hx}%`, top: `${hy}%`, width: 11, height: 11, marginLeft: -5.5, marginTop: -5.5, borderRadius: '50%', background: gold, boxShadow: '0 0 0 4px rgba(255,212,0,0.22), 0 0 14px rgba(255,212,0,0.6)', pointerEvents: 'none' }} />
                <div style={{
                  position: 'absolute', top: -4, left: `min(max(${hx}%, 78px), calc(100% - 78px))`, transform: 'translate(-50%, -100%)',
                  padding: '8px 12px', borderRadius: 12, background: 'rgba(28,28,31,0.96)', border: '1px solid var(--kp-line-2)',
                  boxShadow: '0 16px 32px -12px rgba(0,0,0,0.7)', pointerEvents: 'none', whiteSpace: 'nowrap', textAlign: 'center',
                }}>
                  <div style={{ fontSize: 12, color: text.muted }}>{fmtDay(hp.day)}</div>
                  <div style={{ fontSize: 14, fontWeight: 600, color: text.primary, ...T.num }}>{fmtInt(hp.balance)}{fmtDec(hp.balance)} TAX</div>
                </div>
              </>
            )}
          </>
        )}
      </div>
      {ready && !loading && (
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 12, color: text.dim }}>
          <span>{fmtDay(points[0].day)}</span><span>{fmtDay(points[n - 1].day)}</span>
        </div>
      )}
    </div>
  );
}

function DesktopHero({ firstName, greeting, balance, accountNumber, flowNet, visible, onToggle, span = '' }: {
  span?: string; firstName: string; greeting: string; balance: number; accountNumber: string; flowNet: number; visible: boolean; onToggle: () => void;
}) {
  const { t } = usePreferences();
  const { openTransfer, toast } = useApp();
  const shown = useCountUp(balance);
  const up = flowNet >= 0;
  const actions: { mode: TransferMode | 'market'; label: string; icon: IconName; primary?: boolean }[] = [
    { mode: 'topup', label: t('quick_topup'), icon: 'up', primary: true },
    { mode: 'by_card', label: t('quick_by_card'), icon: 'right' },
    { mode: 'by_account', label: t('quick_by_account'), icon: 'hash' },
  ];
  const { goTo } = useApp();
  return (
    <section className={`kp-card kp-rise ${span}`} style={{ padding: '30px 36px 30px', overflow: 'hidden', ['--i' as string]: 0 }}>
      <div aria-hidden className="kp-hero-fx" />

      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 12, marginBottom: 26 }}>
        <div style={{ fontSize: 16, color: text.muted }}>{greeting}, <span style={{ color: text.primary, fontWeight: 600 }}>{firstName}</span></div>
        <div style={{ flex: 1 }} />
        {accountNumber && accountNumber !== '—' && (
          <button
            className="kp-hover" aria-label={t('dk_copy_account')} title={t('dk_copy_account')}
            onClick={() => { navigator.clipboard?.writeText(accountNumber).then(() => toast(t('dk_copied'))).catch(() => {}); }}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 34, padding: '0 12px', borderRadius: 10, border: '1px solid var(--kp-line)', background: 'var(--kp-fill)', color: 'var(--kp-muted)', fontFamily, fontSize: 13, fontWeight: 500 }}
          >
            {accountNumber}<Ico n="copy" size={14} />
          </button>
        )}
      </div>

      <div style={{ position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: text.muted }}>{t('balance_total')}</span>
          <button onClick={onToggle} className="kp-hover" aria-label={visible ? t('dk_hide_balance') : t('dk_show_balance')} aria-pressed={!visible} style={{ width: 30, height: 30, borderRadius: 9, border: 'none', background: 'transparent', color: 'var(--kp-muted)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Ico n={visible ? 'eye' : 'eyeOff'} size={17} />
          </button>
        </div>
        <div style={{ ...T.num, display: 'flex', alignItems: 'baseline', gap: 12, lineHeight: 1, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 28, fontWeight: 600, color: gold, letterSpacing: -0.4 }}>TAX</span>
          <span style={{ fontSize: 'clamp(52px, 5.4vw, 84px)', fontWeight: 300, letterSpacing: '-0.045em', color: text.primary }}>{visible ? fmtInt(shown) : '• • • • •'}</span>
          {visible && <span style={{ fontSize: 'clamp(26px, 2.4vw, 38px)', fontWeight: 300, color: 'var(--kp-dim)', letterSpacing: -0.5 }}>{fmtDec(shown)}</span>}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 18 }}>
          <span style={{
            display: 'inline-flex', alignItems: 'center', gap: 6, height: 30, padding: '0 12px', borderRadius: 999,
            background: up ? 'rgba(255,255,255,0.09)' : 'rgba(255,255,255, 0.1)', color: up ? text.primary : text.muted,
            fontSize: 13.5, fontWeight: 600, ...T.num,
          }}>
            <Ico n={up ? 'inbound' : 'outbound'} size={14} sw={2} />
            {up ? '+' : '−'}{fmtInt(Math.abs(flowNet))}{fmtDec(Math.abs(flowNet))} TAX
          </span>
          <span style={{ fontSize: 13.5, color: text.dim }}>{t('dk_this_month')}</span>
        </div>
      </div>

      <div style={{ position: 'relative', marginTop: 28 }}><BalanceTrend /></div>

      <div style={{ position: 'relative', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(128px, 1fr))', gap: 10, marginTop: 26 }}>
        {actions.map(a => (
          <button key={a.mode} className={`kp-btn${a.primary ? ' kp-btn-primary' : ''}`} onClick={() => openTransfer(a.mode as TransferMode)}>
            <Ico n={a.icon} size={17} sw={2} />{a.label}
          </button>
        ))}
        <button className="kp-btn" onClick={() => goTo('market')}><Ico n="cart" size={17} sw={1.9} />{t('quick_market')}</button>
      </div>
    </section>
  );
}

function DesktopActivity({ transactions, span = '' }: { transactions: TxItem[]; span?: string }) {
  const { goTo } = useApp();
  const { t, lang } = usePreferences();
  const rows = transactions.slice(0, 8);
  const dayLabel = (iso: string) => fmtDateLabel(iso, lang);
  return (
    <section className={`kp-card kp-rise ${span}`} style={{ padding: '26px 14px 12px', display: 'flex', flexDirection: 'column', ['--i' as string]: 2 }}>
      <div style={{ display: 'flex', alignItems: 'center', padding: '0 14px 6px' }}>
        <span style={{ ...T.h3, fontSize: 18, color: text.primary }}>{t('recent_activity')}</span>
        <div style={{ flex: 1 }} />
        <button onClick={() => goTo('operations')} className="kp-hover" style={{ display: 'inline-flex', alignItems: 'center', gap: 4, height: 32, padding: '0 10px 0 12px', borderRadius: 10, border: 'none', background: 'transparent', color: text.secondary, fontFamily, fontSize: 13.5, fontWeight: 600 }}>
          {t('history')}<Ico n="chevR" size={15} sw={2} />
        </button>
      </div>
      {rows.length === 0 ? (
        <div style={{ padding: '40px 16px', textAlign: 'center', color: text.muted, fontSize: 14 }}>{t('no_transactions_yet')}</div>
      ) : rows.map((tx, i) => {
        const incoming = tx.direction === 'in';
        const day = dayLabel(tx.created_at);
        const newDay = i === 0 || day !== dayLabel(rows[i - 1].created_at);
        return (
          <Fragment key={tx.id}>
            {newDay && <div className="kp-day">{day}</div>}
            <button onClick={() => goTo('operations')} className="kp-row" style={{
              display: 'grid', gridTemplateColumns: '38px minmax(0,1fr) auto auto 14px', alignItems: 'center', columnGap: 16,
              width: '100%', padding: '11px 14px', borderRadius: 14, border: 'none', background: 'transparent',
              fontFamily, textAlign: 'left', cursor: 'pointer', color: 'inherit',
            }}>
              <span style={{
                width: 38, height: 38, borderRadius: 12, display: 'grid', placeItems: 'center',
                background: incoming ? 'rgba(95,214,138,0.12)' : 'var(--kp-fill)',
                color: incoming ? '#5fd68a' : 'var(--kp-muted)',
              }}><Ico n={incoming ? 'inbound' : 'outbound'} size={18} sw={1.9} /></span>
              <span style={{ minWidth: 0 }}>
                <span style={{ display: 'block', fontSize: 15, fontWeight: 500, color: text.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{tx.description || txTypeLabel(tx.tx_type, t)}</span>
                <span style={{ display: 'block', fontSize: 13, color: text.dim, marginTop: 2 }}>{fmtTime(tx.created_at, lang)}</span>
              </span>
              <span style={{ fontSize: 12.5, fontWeight: 500, color: 'var(--kp-muted)', padding: '4px 10px', borderRadius: 999, background: 'var(--kp-fill)', whiteSpace: 'nowrap' }}>{txTypeLabel(tx.tx_type, t)}</span>
              <span style={{ fontSize: 15.5, fontWeight: 600, minWidth: 120, textAlign: 'right', color: incoming ? '#5fd68a' : text.secondary, ...T.num }}>
                {incoming ? '+' : '−'}{fmtInt(tx.amount)}{fmtDec(tx.amount)}&nbsp;TAX
              </span>
              <span className="kp-row-go" aria-hidden style={{ color: text.dim, display: 'flex' }}><Ico n="chevR" size={14} sw={2} /></span>
            </button>
          </Fragment>
        );
      })}
    </section>
  );
}

function SpendDonut({ rows, span = '' }: { rows: { label: string; value: number }[]; span?: string }) {
  const { t } = usePreferences();
  const { goTo } = useApp();
  const [on, setOn] = useState(false);
  useEffect(() => { const id = requestAnimationFrame(() => setOn(true)); return () => cancelAnimationFrame(id); }, []);
  const total = rows.reduce((s, r) => s + r.value, 0);
  const ramp = ['#f4f4f5', '#b4b4ba', '#85858c', '#5f5f66', '#45454b', '#323237'];
  const R = 52, C = 2 * Math.PI * R;
  let acc = 0;
  return (
    <section className={`kp-card kp-rise ${span}`} style={{ padding: '26px 28px 28px', ['--i' as string]: 3 }}>
      <div style={{ ...T.h3, fontSize: 18, color: text.primary, marginBottom: 22 }}>{t('spending_this_month')}</div>
      {total <= 0 ? (
        <div style={{ padding: '18px 0 6px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, textAlign: 'center' }}>
          <div style={{ position: 'relative', width: 128, height: 128 }}>
            <svg viewBox="0 0 140 140" width="128" height="128" aria-hidden style={{ transform: 'rotate(-90deg)' }}>
              <circle cx="70" cy="70" r={R} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="14" strokeDasharray="4 7" strokeLinecap="round" />
              <circle cx="70" cy="70" r={R} fill="none" stroke={gold} strokeWidth="14" strokeLinecap="round" strokeDasharray={`${C * 0.16} ${C}`} opacity="0.7" />
            </svg>
            <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', color: text.dim }}><Ico n="cart" size={26} sw={1.7} /></div>
          </div>
          <div style={{ fontSize: 14, color: text.muted, maxWidth: 240, lineHeight: 1.45 }}>{t('insufficient_spend_data')}</div>
          <button className="kp-btn" onClick={() => goTo('market')} style={{ padding: '0 18px' }}><Ico n="cart" size={16} sw={1.9} />{t('quick_market')}</button>
        </div>
      ) : (
        <div style={{ display: 'flex', alignItems: 'center', gap: 24, flexWrap: 'wrap' }}>
          <div style={{ position: 'relative', width: 152, height: 152, flexShrink: 0 }}>
            <svg viewBox="0 0 140 140" width="152" height="152" role="img" aria-label={t('spending_this_month')} style={{ transform: 'rotate(-90deg)' }}>
              <circle cx="70" cy="70" r={R} fill="none" stroke="rgba(255,255,255, 0.1)" strokeWidth="14" />
              {rows.map((r, i) => {
                const frac = r.value / total;
                const len = Math.max(0, frac * C - 3);
                const el = (
                  <circle key={r.label} cx="70" cy="70" r={R} fill="none" stroke={ramp[Math.min(i, ramp.length - 1)]} strokeWidth="14" strokeLinecap="round"
                    strokeDasharray={`${on ? len : 0} ${C}`} strokeDashoffset={-acc * C}
                    style={{ transition: `stroke-dasharray 0.9s var(--kp-ease) ${i * 90}ms` }} />
                );
                acc += frac;
                return el;
              })}
            </svg>
            <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', ...T.num }}>
              <span style={{ fontSize: 12.5, color: text.dim }}>{t('dk_total')}</span>
              <span style={{ fontSize: 22, fontWeight: 600, color: text.primary, letterSpacing: -0.6 }}>{fmtInt(total)}</span>
              <span style={{ fontSize: 12, color: gold, fontWeight: 600 }}>TAX</span>
            </div>
          </div>
          <ul style={{ flex: '1 1 150px', minWidth: 0, margin: 0, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 4 }}>
            {rows.map((r, i) => (
              <li key={r.label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '7px 0' }}>
                <span aria-hidden style={{ width: 10, height: 10, borderRadius: 3, background: ramp[Math.min(i, ramp.length - 1)], flexShrink: 0 }} />
                <span style={{ flex: 1, minWidth: 0, fontSize: 14.5, color: text.secondary, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.label}</span>
                <span style={{ fontSize: 14, fontWeight: 600, color: text.primary, ...T.num }}>{Math.round((r.value / total) * 100)}%</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}


// ─── Root app ─────────────────────────────────────────────────
const SCREENS = { overview: OverviewScreen, operations: OperationsScreen, cards: CardsScreen, market: MarketplaceScreen, profile: ProfileScreen };
const ENABLE_MOBILE_TAB_SWIPE = false;

// Solid base — must equal html/body background AND gradient bottom stop.
// Appended to the shorthand → becomes CSS background-color, painting UNDER
// all gradient layers so any edge-pixel gap is invisible on OLED.
const appBgBase = '#000000';
const appBg = '#000000';

const appBase: React.CSSProperties = {
  position: 'absolute',
  top: 0, right: 0, bottom: 0, left: 0,
  background: appBg,
  color: text.secondary,
  fontFamily,
  width: '100vw',
  maxWidth: '100vw',
  overflowX: 'hidden',
  WebkitFontSmoothing: 'antialiased',
  MozOsxFontSmoothing: 'grayscale',
  textRendering: 'optimizeLegibility',
};

const AUTH_STATIC_BG = florenceDuomoImage;

function LuxuryAmbientFx() {
  return null;
  return (
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, pointerEvents: 'none', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute',
        width: 600,
        height: 600,
        top: -240,
        right: -200,
        borderRadius: '50%',
        background: 'rgba(255,255,255, 0.1)',
        filter: 'blur(24px)',
      }} />
      <div style={{
        position: 'absolute',
        width: 560,
        height: 560,
        bottom: -270,
        left: -180,
        borderRadius: '50%',
        background: 'rgba(255,255,255, 0.1)',
        filter: 'blur(26px)',
      }} />
      <div style={{
        position: 'absolute',
        width: 400,
        height: 400,
        top: '35%',
        left: '50%',
        transform: 'translateX(-50%)',
        borderRadius: '50%',
        background: 'rgba(255,255,255, 0.1)',
        filter: 'blur(30px)',
      }} />
      <div style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(255,255,255, 0.02)',
        opacity: 0.8,
        mixBlendMode: 'soft-light',
      }} />
    </div>
  );
}

function PremiumStatusStrip() {
  const chips = [
    { label: 'Live API', tone: 'rgba(189,189,189, 0.16)', color: '#c4c4c4' },
    { label: 'End-to-End Secure', tone: 'rgba(181,181,181, 0.16)', color: '#cacaca' },
    { label: 'Private Session', tone: 'rgba(159,159,159, 0.14)', color: '#b0b0b0' },
  ];
  return (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', paddingTop: 6 }}>
      {chips.map(chip => (
        <div key={chip.label} style={{
          padding: '5px 9px',
          borderRadius: 999,
          border: '1px solid transparent',
          background: chip.tone,
          color: chip.color,
          fontSize: 10.5,
          fontWeight: 600,
          letterSpacing: 0.45,
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
        }}>
          {chip.label}
        </div>
      ))}
    </div>
  );
}

// ─── Login screen ─────────────────────────────────────────────

function LoginBrandPanel() {
  const { t } = usePreferences();
  const points = [t('dk_login_p1'), t('dk_login_p2'), t('dk_login_p3')];
  return (
    <aside className="kp-fade" style={{ position: 'relative', flex: '1 1 52%', minWidth: 0, overflow: 'hidden', padding: '56px 64px', display: 'flex', flexDirection: 'column', borderLeft: '1px solid var(--kp-line)', background: 'linear-gradient(180deg, rgba(5,5,7,0.78) 0%, rgba(5,5,7,0.55) 45%, rgba(5,5,7,0.92) 100%), url(/cards/roma-pantheon.webp) center / cover, #0a0a0b' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <RomanSeal size={40} />
        <div>
          <div style={{ fontSize: 24, fontWeight: 600, letterSpacing: '0.01em', color: text.primary }}>TaxTech</div>
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', maxWidth: 560, paddingBottom: 'clamp(140px, 17vw, 240px)', position: 'relative', zIndex: 1 }}>
        <div style={{ fontSize: 'clamp(34px, 3.4vw, 52px)', fontWeight: 600, letterSpacing: '-0.035em', lineHeight: 1.06, color: text.primary, marginBottom: 36 }}>{t('dk_login_title')}</div>
        <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 16 }}>
          {points.map((p, i) => (
            <li key={p} className="kp-rise" style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 17, color: text.secondary, ['--i' as string]: i + 2 }}>
              <span aria-hidden style={{ width: 8, height: 8, borderRadius: '50%', background: i === 0 ? gold : 'rgba(255,255,255,0.5)', flexShrink: 0 }} />{p}
            </li>
          ))}
        </ul>
      </div>
      <div aria-hidden className="kp-rise" style={{ position: 'absolute', right: -60, bottom: -40, width: 'clamp(260px, 30vw, 460px)', transform: 'rotate(-10deg)', opacity: 0.92, ['--i' as string]: 3 }}>
        <PremiumCard variant="obsidian" number="6897" name="TAXTECH" expiry="09/29" type="" balance={167504.68} isPrimary style={{ width: '100%' }} />
      </div>
    </aside>
  );
}

function LoginScreen({ onLogin, initialMode = 'login', onBack }: { onLogin: () => void; initialMode?: 'login' | 'register'; onBack?: () => void }) {
  const { t } = usePreferences();
  const wide = useWindowWidth() >= 1024;
  const [mode, setMode] = useState<'login' | 'register'>(initialMode);
  const [identity, setIdentity] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPass, setConfirmPass] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [faceIdLoading, setFaceIdLoading] = useState(false);
  const [hasPlatformAuth, setHasPlatformAuth] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined' && window.PublicKeyCredential) {
      window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
        .then(ok => setHasPlatformAuth(ok))
        .catch(() => setHasPlatformAuth(false));
    }
  }, []);

  async function handleFaceIdLogin() {
    setFaceIdLoading(true);
    setError('');
    try {
      // 1. Get challenge
      const optRes = await fetch('/api/auth/passkey/login-options', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
      const optJson = await optRes.json();
      if (!optRes.ok || !optJson.ok) throw new Error(optJson.error || t('registration_error'));
      // 2. Trigger Face ID
      const assertion = await startAuthentication({ optionsJSON: optJson.data });
      // 3. Verify
      const verRes = await fetch('/api/auth/passkey/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(assertion),
      });
      const verJson = await verRes.json();
      if (!verRes.ok || !verJson.ok) throw new Error(verJson.error || t('verification_error'));
      localStorage.setItem('army_bank_token', verJson.data.token);
      onLogin();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : t('face_id_error');
      if (msg.toLowerCase().includes('cancel') || msg.toLowerCase().includes('abort') || msg.toLowerCase().includes('not allowed')) {
        setError('');
      } else {
        setError(msg);
      }
    } finally {
      setFaceIdLoading(false);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (mode === 'register' && password !== confirmPass) { setError(t('passwords_do_not_match')); return; }
    setLoading(true);
    try {
      const isReg = mode === 'register';
      const res = await fetch(isReg ? '/api/auth/register' : '/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(isReg
          ? { full_name: fullName.trim(), phone: phone.trim(), email: email.trim(), password }
          : { identity: identity.trim(), password }),
      });
      const json = await res.json();
      if (!res.ok || !json.ok) throw new Error(json.error || json.message || (isReg ? t('registration_error') : t('invalid_credentials')));
      localStorage.setItem('army_bank_token', json.data.token);
      onLogin();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t('operation_error'));
    } finally {
      setLoading(false);
    }
  }

  const inputStyle: React.CSSProperties = {
    width: '100%', padding: '0 16px', height: 54, background: '#1c1c1e',
    border: '1px solid #2c2c2e', borderRadius: 12,
    color: '#f5f5f7', fontSize: 17, outline: 'none', fontFamily, boxSizing: 'border-box',
    transition: 'border-color 0.15s, background 0.15s',
    WebkitAppearance: 'none',
  };
  const labelStyle: React.CSSProperties = {
    display: 'block', fontSize: 13, fontWeight: 500, color: '#86868b', marginBottom: 8,
  };
  const fieldStyle = { marginBottom: 14 };

  return (
    <div style={{ ...appBase, overflowY: 'auto' }}>
      <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 'calc(-1 * env(safe-area-inset-bottom, 0px))', pointerEvents: 'none', background: '#000' }} />
      {onBack && (
        <button type="button" onClick={onBack} className="tt-back" aria-label="TaxTech">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden><path d="M15 18l-6-6 6-6" /></svg>
          <span>TaxTech</span>
        </button>
      )}
      <div style={{ minHeight: '100%', display: 'flex', alignItems: 'stretch', position: 'relative' }}>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '88px 20px 48px' }}>
      <div className="ap-auth" style={{ width: '100%', maxWidth: 400 }}>

        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 14 }}><RomanSeal size={52} /></div>
          <h1 className="ap-auth-title">{mode === 'login' ? tr('Увійдіть у TaxTech', 'Sign in to TaxTech') : tr('Відкрийте рахунок', 'Open an account')}</h1>
          <p className="ap-auth-sub">{mode === 'login' ? tr('Телефон або email і пароль.', 'Phone or email, and your password.') : tr('Хвилина — і рахунок у TAX готовий.', 'A minute, and your TAX account is ready.')}</p>
        </div>

        <div>
        {/* Face ID button — only on login tab, only if platform auth available */}
        {mode === 'login' && hasPlatformAuth && (
          <button
            type="button"
            onClick={handleFaceIdLogin}
            disabled={faceIdLoading}
            style={{
              width: '100%', height: 54, padding: 0, marginBottom: 22, borderRadius: 999,
              border: '1px solid #3a3a3c',
              background: 'transparent',
              color: faceIdLoading ? text.dim : text.primary,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
              cursor: faceIdLoading ? 'default' : 'pointer',
              fontFamily, fontSize: 15, fontWeight: 500, letterSpacing: 0.2,
              boxShadow: '0 1px 0 rgba(255,255,255, 0.1) inset',
              transition: 'all 0.18s',
            }}
          >
            {faceIdLoading ? (
              <span style={{ opacity: 0.6 }}>{t('wait_processing')}</span>
            ) : (
              <>
                {/* Face ID icon */}
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={gold} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M2 9V5a2 2 0 012-2h3M2 15v4a2 2 0 002 2h3M22 9V5a2 2 0 00-2-2h-3M22 15v4a2 2 0 01-2 2h-3"/>
                  <circle cx="9" cy="10" r="0.5" fill={gold} stroke="none"/>
                  <circle cx="15" cy="10" r="0.5" fill={gold} stroke="none"/>
                  <path d="M9 15c0 0 1 1.5 3 1.5s3-1.5 3-1.5"/>
                  <path d="M12 7v2"/>
                </svg>
                <span>{t('login_with_face_id')}</span>
              </>
            )}
          </button>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {mode === 'register' && <>
              <div style={fieldStyle}>
                <label style={labelStyle}>{t('full_name_label')}</label>
                <input style={inputStyle} type="text" value={fullName} onChange={e => setFullName(e.target.value)} placeholder={t('full_name_placeholder')} required />
              </div>
              <div style={fieldStyle}>
                <label style={labelStyle}>{t('profile_phone')}</label>
                <input style={inputStyle} type="tel" value={phone} onChange={e => setPhone(e.target.value)} placeholder="+380XXXXXXXXX" required />
              </div>
              <div style={fieldStyle}>
                <label style={labelStyle}>{t('email_label')}</label>
                <input style={inputStyle} type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="email@example.com" required />
              </div>
            </>}

            {mode === 'login' && (
              <div style={fieldStyle}>
                <label style={labelStyle}>{t('phone_or_email')}</label>
                <input style={inputStyle} type="text" value={identity} onChange={e => setIdentity(e.target.value)} placeholder={t('phone_or_email_placeholder')} autoComplete="username" required />
              </div>
            )}

            <div style={{ marginBottom: 20 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                <label style={{ ...labelStyle, marginBottom: 0 }}>{t('password_label')}</label>
                {mode === 'login' && (
                  <button type="button" onClick={() => setError(t('forgot_password_contact_support'))} style={{ fontSize: 11, color: 'rgba(215,215,215, 0.78)', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'inherit', letterSpacing: 0.2 }}>
                    {t('forgot_password')}
                  </button>
                )}
              </div>
              <div style={{ position: 'relative' }}>
                <input
                  style={{ ...inputStyle, paddingRight: 44 }}
                  type={showPass ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
                  required
                />
                <button type="button" onClick={() => setShowPass(v => !v)} style={{
                  position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                  background: 'none', border: 'none', cursor: 'pointer', color: text.muted, padding: 4,
                  display: 'flex', alignItems: 'center',
                }}>
                  {showPass
                    ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M3 3l18 18M10.6 10.6a2 2 0 002.8 2.8M9.4 5.1A10.9 10.9 0 0112 5c6 0 10 7 10 7a18 18 0 01-3.2 3.9M6.6 6.6A18 18 0 002 12s4 7 10 7a11 11 0 003.4-.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>
                    : <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z" stroke="currentColor" strokeWidth="1.6" /><circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6" /></svg>
                  }
                </button>
              </div>
            </div>

            {mode === 'register' && (
              <div style={{ marginBottom: 20 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                  <label style={{ ...labelStyle, marginBottom: 0 }}>{t('confirm_password')}</label>
                </div>
                <div style={{ position: 'relative' }}>
                  <input
                    style={{ ...inputStyle, paddingRight: 44 }}
                    type={showConfirm ? 'text' : 'password'}
                    value={confirmPass}
                    onChange={e => setConfirmPass(e.target.value)}
                    placeholder={t('repeat_password')}
                    autoComplete="new-password"
                    required
                  />
                  <button type="button" onClick={() => setShowConfirm(v => !v)} style={{
                    position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                    background: 'none', border: 'none', cursor: 'pointer', color: text.muted, padding: 4,
                    display: 'flex', alignItems: 'center',
                  }}>
                    {showConfirm
                      ? <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M3 3l18 18M10.6 10.6a2 2 0 002.8 2.8M9.4 5.1A10.9 10.9 0 0112 5c6 0 10 7 10 7a18 18 0 01-3.2 3.9M6.6 6.6A18 18 0 002 12s4 7 10 7a11 11 0 003.4-.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>
                      : <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z" stroke="currentColor" strokeWidth="1.6" /><circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.6" /></svg>
                    }
                  </button>
                </div>
              </div>
            )}

            {error && (
              <div style={{ marginBottom: 14, padding: '10px 14px', background: 'rgba(255,255,255, 0.1)', border: '1px solid transparent', borderRadius: radius.sm, color: '#a4a4a4', ...T.sm }}>{error}</div>
            )}

            <button type="submit" disabled={loading} style={{
              width: '100%', height: 54, padding: 0, borderRadius: 999, border: 'none',
              background: loading
                ? 'rgba(85,85,85, 0.25)'
                : gold,
              color: loading ? text.dim : '#17140a',
              ...T.bodyLg, fontWeight: 600, cursor: loading ? 'default' : 'pointer',
              fontFamily, letterSpacing: 0.4,
              boxShadow: 'none', fontSize: 17,
              transition: 'all 0.18s',
            }}>{loading ? t('wait_processing') : mode === 'login' ? t('sign_in') : t('create_account')}</button>
          </div>
        </form>
        </div>

        <div style={{ textAlign: 'center', marginTop: 28, fontSize: 15, color: '#86868b' }}>
          {mode === 'login' ? tr('Ще немає рахунку? ', 'No account yet? ') : tr('Вже є рахунок? ', 'Already have an account? ')}
          <button type="button" className="ap-link" onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setError(''); setConfirmPass(''); }}>
            {mode === 'login' ? tr('Відкрити', 'Open one') : tr('Увійти', 'Sign in')} <span aria-hidden>›</span>
          </button>
        </div>
      </div>
      </div>
      {wide && <LoginBrandPanel />}
      </div>
    </div>
  );
}

// ─── App root ─────────────────────────────────────────────────
export default function App({ initialAuthView }: { initialAuthView?: 'login' | 'register' } = {}) {
  const [authView, setAuthView] = useState<'promo' | 'login' | 'register'>(() => {
    if (initialAuthView) return initialAuthView;
    try {
      if (location.hash === '#login') return 'login';
      if (location.hash === '#register') return 'register';
      return 'promo';
    } catch { return 'promo'; }
  });
  const [authed, setAuthed] = useState(() => !!getToken());
  const [tab, setTabState] = useState<TabKey>(() => readStoredTab());
  const [profilePhoto, setProfilePhotoState] = useState<string>(() => getProfilePhoto());
  const [lang, setLangState] = useState<AppLang>(() => getStoredLanguage());
  const touchStartXRef = useRef<number | null>(null);
  const touchStartYRef = useRef<number | null>(null);
  const touchAxisRef = useRef<'x' | 'y' | null>(null);
  const tabSwipeEnabledRef = useRef(false);
  const [screenDragX, setScreenDragX] = useState(0);
  const [screenDragging, setScreenDragging] = useState(false);
  const [tabBarHidden, setTabBarHidden] = useState(false);
  const [toastMsg, setToastMsg] = useState('');
  const [user, setUser] = useState<UserInfo | null>(null);
  const [account, setAccount] = useState<AccountInfo | null>(null);
  const [transactions, setTransactions] = useState<TxItem[]>([]);
  const [cards, setCards] = useState<CardInfo[]>([]);
  const [loadingData, setLoadingData] = useState(() => !!getToken());
  const [refreshingData, setRefreshingData] = useState(false);
  const [dataError, setDataError] = useState('');
  const [analytics, setAnalytics] = useState<ApiAnalytics | null>(null);
  const toastTimer = React.useRef<ReturnType<typeof setTimeout> | null>(null);
  const width = useWindowWidth();
  const isDesktop = width >= 768;
  const Screen = SCREENS[tab];
  const t = React.useCallback((key: TranslationKey) => translations[lang][key], [lang]);
  const tabs = React.useMemo(() => getTabs(t), [t]);
  const tabIndex = tabs.findIndex(t => t.k === tab);

  const setTab = React.useCallback((next: TabKey) => {
    setTabState(next);
    markAppContinuation();
    try {
      localStorage.setItem(ACTIVE_TAB_STORAGE_KEY, next);
    } catch {
      // ignore storage errors
    }
  }, []);

  // Inline tr('…', '…') strings read the language from here; set it before the tree renders.
  setTrLang(lang);
  useEffect(() => {
    document.documentElement.lang = lang;
    if (authed) document.title = `TaxTech · ${translations[lang].personal_cabinet}`;
  }, [lang, authed]);

  const setLang = React.useCallback((nextLang: AppLang) => {
    setStoredLanguage(nextLang);
    setLangState(nextLang);
  }, []);

  const setProfilePhotoValue = React.useCallback((value: string) => {
    setProfilePhotoState(value);
  }, []);

  function shouldIgnoreTabSwipe(target: EventTarget | null): boolean {
    if (!(target instanceof HTMLElement)) return true;
    if (target.closest('[data-no-tab-swipe="true"]')) return true;
    if (target.closest('input, textarea, select, button, a, [role="button"], [contenteditable="true"]')) return true;
    return false;
  }

  function resetTabSwipe() {
    touchStartXRef.current = null;
    touchStartYRef.current = null;
    touchAxisRef.current = null;
    tabSwipeEnabledRef.current = false;
    setScreenDragX(0);
    setScreenDragging(false);
  }

  function handleMobileTouchStart(e: React.TouchEvent<HTMLDivElement>) {
    if (!ENABLE_MOBILE_TAB_SWIPE) return;
    if (tabBarHidden || transferModal) return;
    if (shouldIgnoreTabSwipe(e.target)) return;
    const t = e.touches[0];
    touchStartXRef.current = t.clientX;
    touchStartYRef.current = t.clientY;
    touchAxisRef.current = null;
    tabSwipeEnabledRef.current = true;
    setScreenDragX(0);
    setScreenDragging(false);
  }

  function handleMobileTouchMove(e: React.TouchEvent<HTMLDivElement>) {
    if (!tabSwipeEnabledRef.current) return;
    if (touchStartXRef.current == null || touchStartYRef.current == null) return;
    const t = e.touches[0];
    const dx = t.clientX - touchStartXRef.current;
    const dy = t.clientY - touchStartYRef.current;
    if (!touchAxisRef.current && (Math.abs(dx) > 9 || Math.abs(dy) > 9)) {
      touchAxisRef.current = Math.abs(dx) >= Math.abs(dy) ? 'x' : 'y';
    }
    if (touchAxisRef.current !== 'x') return;
    e.preventDefault();
    setScreenDragging(true);
    setScreenDragX(Math.max(-120, Math.min(120, dx)));
  }

  function handleMobileTouchEnd() {
    if (!tabSwipeEnabledRef.current) return;
    const threshold = 72;
    if (Math.abs(screenDragX) >= threshold) {
      if (screenDragX < 0 && tabIndex < tabs.length - 1) {
        setTab(tabs[tabIndex + 1].k);
      } else if (screenDragX > 0 && tabIndex > 0) {
        setTab(tabs[tabIndex - 1].k);
      }
    }
    resetTabSwipe();
  }

  const fetchDashboard = React.useCallback(async () => {
    try {
      const [dashboard, cardsData] = await Promise.all([
        apiRequest<{
          user: UserInfo;
          account: AccountInfo;
          transactions: TxItem[];
        }>('/api/dashboard'),
        apiRequest<CardInfo[]>('/api/cards'),
      ]);
      setUser(dashboard.user);
      setAccount(dashboard.account);
      setTransactions(dashboard.transactions || []);
      setCards(cardsData || []);
    } catch { /* silent */ }
  }, []);

  useEffect(() => {
    if (!authed) { setUser(null); setAccount(null); setTransactions([]); setCards([]); }
  }, [authed]);

  const showToast = (msg: string) => {
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToastMsg(msg);
    toastTimer.current = setTimeout(() => setToastMsg(''), 2500);
  };

  const logout = () => {
    clearToken();
    setAuthed(false);
    setAuthView('promo');
    setTab('overview');
    setUser(null);
    setAccount(null);
    setCards([]);
    setTransactions([]);
    setAnalytics(null);
    setDataError('');
    setLoadingData(false);
  };

  const loadBankData = async (silent = false) => {
    if (!authed) return;
    if (silent) setRefreshingData(true);
    else setLoadingData(true);
    setDataError('');
    try {
      let userData: ApiUser | null = null;
      let accountData: ApiAccount | null = null;
      let txData: ApiTransaction[] = [];

      try {
        const dashboard = await apiRequest<{
          user?: ApiUser;
          account?: ApiAccount;
          transactions?: ApiTransaction[];
        }>('/api/dashboard');
        userData = dashboard?.user || null;
        accountData = dashboard?.account || null;
        txData = Array.isArray(dashboard?.transactions) ? dashboard.transactions : [];
      } catch {
        const [me, acc, history] = await Promise.all([
          apiRequest<ApiUser>('/api/auth/me'),
          apiRequest<ApiAccount>('/api/accounts/main'),
          apiRequest<ApiTransaction[]>('/api/transactions/history'),
        ]);
        userData = me || null;
        accountData = acc || null;
        txData = Array.isArray(history) ? history : [];
      }

      const cardsData = await apiRequest<ApiCard[]>('/api/cards');
      let analyticsData: ApiAnalytics | null = null;
      try {
        analyticsData = await apiRequest<ApiAnalytics>('/api/analytics/summary');
      } catch {
        analyticsData = null;
      }

      setUser(userData);
      setAccount(accountData);
      setTransactions(txData);
      setCards(Array.isArray(cardsData) ? cardsData : []);
      setAnalytics(analyticsData);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : t('data_load_failed');
      setDataError(message);
      if ((err as { status?: number }).status === 401) {
        logout();
        return;
      }
      if (!silent) showToast(message);
    } finally {
      if (silent) setRefreshingData(false);
      else setLoadingData(false);
    }
  };

  useEffect(() => {
    if (!authed) return;
    loadBankData(false).catch(() => {});
    // Auto-refresh every 30s (admin sync — picks up admin balance/card changes)
    const interval = setInterval(() => {
      if (document.visibilityState !== 'hidden') {
        loadBankData(true).catch(() => {});
      }
    }, 30_000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authed]);

  const mutateCard = async (cardId: number, action: 'block' | 'close') => {
    const endpoint = action === 'block' ? 'block' : 'close';
    await apiRequest(`/api/cards/${cardId}/${endpoint}`, { method: 'PATCH' });
    await loadBankData(true);
  };

  const issueCard = async () => {
    await apiRequest('/api/cards', {
      method: 'POST',
      body: JSON.stringify({ card_type: 'virtual', design: 'gold' }),
    });
    await loadBankData(true);
  };

  const [transferModal, setTransferModal] = useState<TransferMode | null>(null);

  const appCtx: AppCtxType = {
    logout,
    goTo: (t: TabKey) => setTab(t),
    toast: showToast,
    user,
    account,
    transactions,
    cards,
    refreshDashboard: fetchDashboard,
    openTransfer: (mode: TransferMode) => setTransferModal(mode),
    setTabBarHidden,
  };

  const bankCtx: BankDataCtxType = {
    loading: loadingData,
    refreshing: refreshingData,
    error: dataError,
    user,
    account,
    cards,
    transactions,
    analytics,
    refresh: async () => loadBankData(true),
    mutateCard,
    issueCard,
  };

  const preferencesCtx: PreferencesCtxType = {
    profilePhoto,
    setProfilePhotoValue,
    lang,
    setLang,
    t,
  };

  if (!authed && authView === 'promo') {
    return <BankLanding onAuth={(m) => setAuthView(m)} />;
  }

  if (!authed) {
    // Sign-in sits outside the banking layout but still needs the chosen language.
    return <PreferencesCtx.Provider value={preferencesCtx}><LoginScreen key={authView} initialMode={authView === 'register' ? 'register' : 'login'} onBack={() => setAuthView('promo')} onLogin={() => {
      markAppContinuation();  // prevent splash replay on next open
      setLoadingData(true);   // show spinner immediately, skip empty-screen flash
      setAuthed(true);
    }} /></PreferencesCtx.Provider>;
  }

  if (isDesktop) {
    return (
      <PreferencesCtx.Provider value={preferencesCtx}>
      <AppCtx.Provider value={appCtx}>
        <BankDataCtx.Provider value={bankCtx}>
          <LayoutCtx.Provider value="desktop">
            <DesktopShell tab={tab} onChange={setTab} dataError={dataError} loading={loadingData}>
              <Screen />
            </DesktopShell>
            {toastMsg && <Toast msg={toastMsg} />}
            {transferModal && <TransferModal mode={transferModal} onClose={() => setTransferModal(null)} />}
          </LayoutCtx.Provider>
        </BankDataCtx.Provider>
      </AppCtx.Provider>
      </PreferencesCtx.Provider>
    );
  }

  return (
    <PreferencesCtx.Provider value={preferencesCtx}>
    <AppCtx.Provider value={appCtx}>
      <BankDataCtx.Provider value={bankCtx}>
        <LayoutCtx.Provider value="mobile">
          <div className="tt-app" style={{
              position: 'relative',
              width: '100%',
              height: 'var(--app-vh, 100dvh)',
              minHeight: 'var(--app-vh, 100dvh)',
              overflow: 'hidden',
              background: appBg, color: text.secondary, fontFamily,
              WebkitFontSmoothing: 'antialiased',
            }}>
            <LuxuryAmbientFx />
          <div style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              overflowY: 'auto',
              overflowX: 'hidden',
              width: '100%',
              touchAction: 'pan-y',
              paddingBottom: tabBarHidden ? 0 : mobileDockInset,
              overscrollBehavior: 'contain',
              WebkitOverflowScrolling: 'touch',
            }}
            onTouchStart={handleMobileTouchStart}
            onTouchMove={handleMobileTouchMove}
            onTouchEnd={handleMobileTouchEnd}
            onTouchCancel={handleMobileTouchEnd}
            >
              <div
                style={{
                  width: '100%',
                  maxWidth: '100vw',
                  overflowX: 'hidden',
                  transform: ENABLE_MOBILE_TAB_SWIPE ? `translate3d(${screenDragX}px,0,0)` : 'none',
                  transition: screenDragging ? 'none' : 'transform 220ms cubic-bezier(0.22, 0.61, 0.36, 1)',
                  willChange: 'transform',
                }}
              >
              {dataError && (
                <div style={{ margin: '10px 12px 0', padding: '10px 12px', borderRadius: 12, border: '1px solid transparent', background: 'rgba(255,255,255, 0.1)', color: '#c6c6c6', fontSize: 13 }}>
                  {dataError}
                </div>
              )}
              {loadingData ? (
                <div style={{ minHeight: '100%', display: 'grid', placeItems: 'center', color: text.muted }}>{t('loading_data')}</div>
              ) : (
                <Screen />
              )}
              </div>
            </div>
            {!tabBarHidden && <TabBar active={tab} onChange={setTab} />}
            {toastMsg && <Toast msg={toastMsg} />}
            {transferModal && <TransferModal mode={transferModal} onClose={() => setTransferModal(null)} />}
          </div>
        </LayoutCtx.Provider>
      </BankDataCtx.Provider>
    </AppCtx.Provider>
    </PreferencesCtx.Provider>
  );
}
