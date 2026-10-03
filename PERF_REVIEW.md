# Перфоманс-ревью

Дата: 03.10.2026 · Ветка `main` (`7392637`) · Godot 4.7.2
Метод: статическое ревью по областям (бой/физика, рендер/UI) + прогон бота
(`tools/autoplay.gd`, seed=1234, speed=8, immortal=1): забег целиком 7:14, крашей нет,
этапы 44–71 с. Замер утечек при выходе: 4 ObjectDB-инстанса + 2 ресурса (мелочь).

Контекст оценок: до **26 врагов + герой + босс** одновременно (`max_alive_enemies`,
`data/balance.tres:30`); процедурная модель — ~40–50 мешей на актора; рендер GL
Compatibility → упор в draw calls и CPU.

---

## 🔴 Критично (просаживает FPS в бою)

### К1. ~1000+ draw calls: каждый саб-меш — отдельный MeshInstance3D
`scripts/visual/actor_model.gd` (строительная часть, стр. 84–580; `low_poly.gd:98-103`).
Пехотинец ≈ 39 мешей, шут ≈ 50. 27 акторов × ~40 ≈ **~1080 draw calls/кадр**; в PS2
тени включены (`arena.gd:116-127`) → почти **~2000** с shadow-pass.

Фикс (по убыванию эффекта):
1. **Слияние статичной геометрии внутри кости-пивота** (костей 7: hips/torso/head/arm_l/
   arm_r/leg_l/leg_r): всё под одним пивотом — один многосурфейсный ArrayMesh
   (сурфейсы по ключу материала) → 7–10 вызовов на актора, вся волна ~250.
2. Быстрый вариант: `cast_shadow = SHADOW_CASTING_SETTING_OFF` на мешах врагов —
   blob-тень уже есть (`actor_model.gd:206-213`) → минус ~900 shadow-вызовов в PS2.
3. Рой (SWARM) — кандидат на MultiMeshInstance3D.

### К2. `material_overlay` переприсваивается всем мешам каждого актора КАЖДЫЙ кадр
`scripts/visual/actor_model.gd:1151-1160` (`_update_overlay` из `_process`).
~28 акторов × ~40 мешей ≈ **~1000 вызовов в RenderingServer на кадр (~15 000/с)**; сеттер
`material_overlay` без early-out, 99% записей — `null → null`. Пока overlay не null,
меш рисуется дважды (base + overlay pass).

Фикс — кэш состояния:
```gdscript
var _overlay_now: Material = null

func _update_overlay(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var want: Material = _flash_mat if _flash > 0.0 else null
	if want == null and actor.faction != Actor.Faction.HERO and _is_open_to_hero():
		want = _open_mat
	if want == _overlay_now:
		return
	_overlay_now = want
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = want
```
Заодно кэшировать `_is_open_to_hero()` (не дёргать `Combat.hero.helmet_window()`
27 раз за кадр).

### К3. Квадратичное сепарирование ИИ: `get_nodes_in_group` × 26 врагов каждый физ-тик
`scripts/control/ai_controller.gd:111-122` (`_separation` из `_physics_process`).
**~1 560 запросов группы + ~44 000 итераций/сек.** Единственный по-настоящему горячий
квадратичный цикл; трупы остаются в группе до `_free_corpse`.

Фикс — статический реестр акторов:
```gdscript
# combat.gd
static var actors: Array[Actor] = []
static func _register(a: Actor) -> void: actors.append(a)
static func _unregister(a: Actor) -> void: actors.erase(a)
# actor.gd: _ready -> Combat._register(self); _exit_tree -> Combat._unregister(self)
```
`_separation()` итерирует `Combat.actors` — ноль запросов и аллокаций. Этот же реестр
закрывает С1/С3 ниже.

### К4. 3D рендерится в полном разрешении, хотя пост-квантует в «270 строк»
`scripts/autoload/render_settings.gd:108-117`: пост-шейдер (`retro_post.gdshader:33-35`)
семплирует ячейки `pixel×pixel` (PS1: pixel=3) — **~89% закрашенных пикселей 3D-сцены
не попадают в выходной образ**. Платим fill 1600×900 ради результата 533×300.

Фикс:
```gdscript
# в _update_resolution(), после расчёта _pixel:
get_viewport().scaling_3d_scale = 1.0 / _pixel
```
Fill 3D падает в 9× (PS1) / 4× (PS2). UI не страдает (`scaling_3d` — только 3D-проход),
вершинный снап в clip-space от масштаба не зависит. Требуется визуальная проверка
PS2-блума (`retro_post.gdshader:42-51`, оффсеты в UV).

---

## 🟠 Среднее

### С1. Аллокации `Combat.hostiles_of_faction`/`living_actors` в пер-кадровых объектах
- `scripts/combat/shockwave.gd:42` — каждый физ-тик волны;
- `scripts/combat/projectile.gd:70` — каждый физ-тик **каждого** снаряда;
- `scripts/combat/poison_puddle.gd:61` — каждый тик каждой лужи (до 70 шт.);
- `scripts/ui/world_overlay.gd:14-23` — каждый кадр + лямбда-фильтр + обход всех акторов
  с `unproject_position`.
Каждый вызов = запрос группы + 2 аллокации массивов. Фикс: итерировать `Combat.actors`
(К3) без промежуточных массивов; вражеский снаряд — прямая проверка дистанции до героя
(`length_squared` вместо `length`, `projectile.gd:73`).

### С2. UI перерисовывается каждый кадр
- `hud.gd:197-209`: `_hp_bar.queue_redraw()` каждый кадр при уже подключённом сигнале
  `health_changed` (стр. 57) — двойная перерисовка; label'ы пересобираются строкой.
- `action_slot.gd:23-25`: `queue_redraw()` × 7 слотов каждый кадр; `_draw` делает
  `Db.item`, `IconFactory.icon`, `Mastery.rules` lookups и `draw_string`.
- `world_overlay.gd` — см. С1.
Фикс: dirty-флаги — рисовать только когда cooldown/flash/hp реально изменились;
кэшировать строки label'ов.

### С3. `alive_enemies()` — полный обход группы до 3 раз за физ-тик
`game.gd:257-262` (вызывы из `_physics_process` 275/277 и `_process_spawns` 293).
Фикс: счётчик `_alive_enemies`, инкремент на спавне/сплите, декремент на смерти.

### С4. `IconFactory` ре-рендерит ВСЕ 7 иконок в 7 SubViewport (MSAA 4X) на убийство
`icon_factory.gd:28-101`; триггер `Mastery.changed` → эмитится из `award()` на каждом
kill (`item_mastery.gd:134`). Прокачка тира в бою = хич 2+ кадров с 7 вложенными
3D-рендерами с MSAA + **`save_progress()` (tmp+.bak+rename) на каждое убийство** в главном
потоке.
Фикс: инкрементальный рендер только изменившейся иконки, `UPDATE_ONCE`, убрать MSAA,
дебаунс сохранения (конец волны/жертва/выход) + отложить рендер до безопасного момента.

### С5. Кровь: новая нода на каждое попадание
`blood_fx.gd:22-73`: `CPUParticles3D` + `create_timer` + новый `BoxMesh` на лужу;
`vfx.gd:145-155` — новый `SphereMesh` на каждый burst; `vfx.gd:16-25` — новый
`StandardMaterial3D` (кэш `_mat_cache` объявлен в стр. 5 и не используется).
Десятки аллокаций/сек в AoE-бою → микрофризы.
Фикс: пул 8–12 CPUParticles3D (`restart()` вместо создания), кэш мешей/материалов.

### С6. Спавн-шторм нод без пула
`game.gd:289-366` (портал каждые 0,28–0,45 с, сплит ×3 мгновенно): ~15–25 нод на врага
(Actor + CollisionShape + EventBus + ИИ + компоненты + SkinnedActorModel + аура +
2 FlipbookFx + твины). Микрофризы при спавне на слабом железе.
Фикс: пул врагов по Kind с `reset()`, минимум — пул порталов/частиц.

---

## 🟡 Мелочи

- `EventBus` — дочерняя нода с `_process` на каждого актора (+28 тикеров) → статические
  часы в `Combat`/`Game`.
- `Combat.deal` (`combat.gd:88-91`) — `opts.duplicate()` + 2 вставки на каждое попадание
  (шоквейн ×26 целей) → писать в `opts` напрямую.
- `ai_controller.gd:251-258` — `_incoming_projectile`: запрос группы снарядов каждый тик
  у элит/босса со щитом → статический реестр `Projectile.all`.
- `poison_puddle.gd:10,64-67` — статический `_next_hit` не чистится между волнами.
- `actor_model.gd:1001,1016` — `has_item()` lookups каждый кадр → кэш по `items_changed`.
- `actor_model.gd:206-213` — blob-тень: новый меш на актора (`sector_mesh` без кэша).
- `skinned_actor_model.gd:75-97,199-203` — парсинг JSON-реестра на каждый спавн →
  статический кэш по пути.
- `blood_fx.gd` / additive VFX: `CULL_DISABLED` у замкнутых сфер → двойной overdraw.
- Выход: 4 ObjectDB + 2 ресурса не освобождаются (видно в логе автоплея).

---

## Не проблема (проверено)

`actor._physics_process` (чистая математика, маска коллизий только на героя),
`damage_zone.gd` (скан один раз при детонации), эффекты сущностей (событийные, не
пер-кадровые), `event_bus` emit (кулдауны 0,4 с), камера (1 ray-plane/кадр), PS1-пост
(1 тап + Байер), кэш ретаргет-библиотек, flipbook-тики, материалы `LowPoly.mat`.

## Рекомендуемый порядок внедрения

| # | Фикс | Эффект | Трудозатраты |
|---|------|--------|--------------|
| 1 | К2 — кэш overlay | −1000 RS-вызовов/кадр | 15 мин, нулевой риск |
| 2 | К4 — `scaling_3d_scale` | fill 3D ×9 (PS1) / ×4 (PS2) | 30 мин + визуальная проверка блума |
| 3 | К3 + С1 + С3 — реестр акторов | убирает квадрат и обходы группы | 1–2 ч |
| 4 | К1 — слияние мешей по пивотам | ~1080 → ~250 draw calls | основная работа, день+ |
| 5 | С2/С4 — dirty-флаги UI, инкрементальный IconFactory, дебаунс сейва | нет хичей прокачки и диск-I/O | 2–3 ч |
| 6 | С5/С6 — пулы частиц и спавна | нет микрофризов на хитах/спавне | 3–4 ч |
