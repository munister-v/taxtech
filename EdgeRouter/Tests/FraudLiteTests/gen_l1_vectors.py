"""Еталонні вектори Layer 1 з fraud_engine.py для перевірки Swift-порту."""
import importlib.util, json, random, sys, types

src, out = sys.argv[1], sys.argv[2]
pkg = types.ModuleType('backend'); pkg.__path__ = []
svc = types.ModuleType('backend.services'); svc.__path__ = []
db = types.ModuleType('backend.database'); db.get_connection = lambda: None
cfg = types.ModuleType('backend.config'); cfg.USE_PG = False
sys.modules.update({'backend': pkg, 'backend.services': svc, 'backend.database': db, 'backend.config': cfg})
spec = importlib.util.spec_from_file_location('backend.services.fraud_engine', src)
fe = importlib.util.module_from_spec(spec); sys.modules[spec.name] = fe; spec.loader.exec_module(fe)

rng = random.Random(42)
cases = []
fixed = [4_990, 9_950, 9_000, 19_900, 49_800, 49_990, 50_000, 99_600, 100_000, 120_000,
         199_500, 999_000, 1_000, 5_000, 1_500, 250, 12_345.67, 0.5]
descs = ['', 'обід', 'терміново переказ', 'crypto кеш', 'test test', 'Подарунок мамі', 'scam urgent нал готів', 'TEST']
for a in fixed:
    for d in descs[:3]:
        cases.append((a, a * rng.choice([0, 1.02, 1.1, 1.3, 3]), d))
for _ in range(400):
    a = round(rng.choice([rng.lognormvariate(7, 1.6), rng.choice([5e3, 1e4, 5e4, 1e5]) * rng.uniform(0.88, 1.0)]), rng.choice([0, 2]))
    bal = a / rng.choice([0.5, 0.79, 0.81, 0.9, 0.95, 0.96, 0.99, 1.0, 1.2]) if rng.random() < .8 else 0
    cases.append((a, round(bal, 2), rng.choice(descs)))

vectors = []
for amount, balance, desc in cases:
    r = fe.FraudEngine().assess(1, None, amount, balance, desc)  # USE_PG=False → лише Layer 1
    vectors.append({'amount': amount, 'balance': balance, 'description': desc,
                     'score': r.score, 'level': r.level, 'flags': r.flags})
json.dump(vectors, open(out, 'w'), ensure_ascii=False, indent=1)
print(len(vectors), 'vectors;', sum(1 for v in vectors if v['score'] > 0), 'non-zero;',
      sorted({f for v in vectors for f in v['flags']}))
