# GelistirJamProject - Technical Development Document

## 1. Oyun Konsepti & Temel Mantık (High-Level Overview)

### Ana Fikir & Core Loop

**GelistirJamProject**, 2D çizim varlıkların 3D dünya içerisinde sunulduğu (Doom 1 estetiği / Billboard `AnimatedSprite3D`) sonsuz ve prosedürel bir FPS kaçış oyunudur.

Karakter otomatik koşmaz; tüm hareket ve aksiyonlar %100 oyuncu kontrolündedir. Oyuncu arkadan gelen muhafız sürüsüne yakalanmamak için sürekli ilerlemeli, önüne çıkan muhafız ve tuzakları hareket mekanikleri (Wall-Run, Slide, Zıplama) ve flüt vuruşu ile aşarak hayatta kaldığı her saniye için puan biriktirmelidir.

```
[Manuel Oyuncu Koşusu] ────────► [Ön Muhafız / Tuzak Engelleri]
         │                                   │
         ▼                                   ▼
[Arka Sürü Takibi (Killzone)] ──► [Ölüm (HP=0 / Temas)] ──► [GameManager Reset + Sahne Reload]

```

### Hedef Platform & Kontroller

* **Platform & Motor:** PC (Godot 4 - GDScript).
* **Geliştirme & Test Ortamı:** Proje yönetimi ve çalıştırma süreçlerinde Godot GUI ile birlikte **Godot CLI** araçları (`godot --path .`, `godot --headless` vb.) aktif olarak kullanılır.
* **Girdi Haritası (Input Map):**
* `move_forward` (W), `move_backward` (S), `move_left` (A), `move_right` (D)
* `look_mouse` (Mouse Motion - Yaw / Pitch)
* `jump` (Space) – Zıplama, Slide'dan çıkış/zıplama ve Wall-Run'dan ayrılma
* `slide` (Ctrl) – Yerden kayma veya havada yere hızlı çakılıp kayma
* `attack` (Mouse Sol Tık) – Flüt ile muhafızların kafasına vurma



---

## 2. Klasör Yapısı & İsimlendirme Kuralları (Folder Structure & Naming)

### Proje Klasör Hiyerarşisi (`res://`)

```text
res://
├── assets/
│   ├── audio/
│   │   ├── sfx/
│   │   └── bgm/
│   ├── sprites/
│   │   ├── player/
│   │   ├── guards/
│   │   └── traps/
│   └── meshes/
│       └── environment/
├── core/
│   ├── autoloads/
│   │   ├── game_manager_flute.gd
│   │   └── sound_manager_flute.gd
│   └── state_machine/
│       ├── state.gd
│       └── state_machine.gd
├── scenes/
│   ├── main/
│   │   └── root_scene.tscn
│   ├── player/
│   │   └── player.tscn
│   ├── environment/
│   │   ├── corridor_tile.tscn
│   │   └── stairs_tile.tscn
│   ├── entities/
│   │   ├── front_guard.tscn
│   │   └── chasing_horde.tscn
│   └── traps/
│       └── base_trap.tscn
└── scripts/
    ├── player/
    ├── environment/
    ├── entities/
    └── traps/

```

### Kodlama ve İsimlendirme Standartları

* **Dosya & Klasör Adları:** Küçük harf ve alt tire (`snake_case`). Örn: `front_guard.gd`, `corridor_tile.tscn`.
* **Sınıf Adları (`class_name`):** Büyük Deve Notasyonu (`PascalCase`). Örn: `FrontGuard`, `WallRunSurface`, `PlayerStateMachine`.
* **Düğüm Adları (Node Names):** Büyük Deve Notasyonu (`PascalCase`). Örn: `CollisionShape3D`, `AttackRayCast`.
* **Değişken & Fonksiyon Adları:** Küçük harf ve alt tire (`snake_case`). Örn: `current_hp`, `calculate_score()`.
* **Sabitler ve Enum Değerleri:** Tamamı büyük harf ve alt tire (`UPPER_SNAKE_CASE`). Örn: `MAX_COOLDOWN`, `State.GROUNDED`.
* **Sinyaller:** Küçük harf ve alt tire (`snake_case`), geçmiş zaman eki tercih edilir. Örn: `hp_changed`, `player_died`.

---

## 3. Detaylı Mekanikler & Mantıksal Kurallar

### Sistemler & Hesaplama Mantığı

#### 1. Skor & Zaman Biriktirme Mantığı

* `score` değişkeni `int` tipindedir.
* `_process(delta)` içerisinde zaman birikim mantığı:

```gdscript
var accumulated_time: float = 0.0

func update_score(delta: float) -> void:
	if is_game_over: return
	accumulated_time += delta
	if accumulated_time >= 1.0:
		accumulated_time -= 1.0
		score += 1

```

#### 2. Can, Hasar ve `GET_HIT` Debuff Mantığı

* **Oyuncu Canı:** Ayarlanabilir `@export var max_hp: int = 3`.
* **Tuzak Hasarı:** Standart tuzaklar `-1 HP` verir. Bazı tuzaklarda `is_instakill = true` bayrağı bulunur ve oyuncuyu doğrudan `DEAD` durumuna geçirir.
* **GET_HIT State & Yavaşlatma Debuff'ı:**
* Hasar alan oyuncu anında `GET_HIT` durumuna geçer.
* `get_hit_timer` (One-shot `Timer`) `0.2` saniyeye ayarlanır ve başlatılır.
* Durum anında `GROUNDED` olarak güncellenir.
* `get_hit_timer` çalışırken hareket hızı **%20'ye** düşer (%80 yavaşlatma). Timer bittiğinde hız %100 değerine döner.


* **Arka Sürü (Killzone):** Sürü oyuncuya temas ettiğinde can değerine bakılmaksızın anında ölüm gerçekleşir.

#### 3. Flüt Saldırısı & Müzik Senkronizasyonu

* **Saldırı Cooldown Mantığı:**
* **Başarılı Vuruş (Düşman İsabeti):** Cooldown süresi **0.3 saniyedir** (spam'i engellemek için).
* **Iska Vuruş (Boşa Savrulma):** Cooldown süresi **5.0 saniyedir** (editörden ayarlanabilir: `@export var miss_cooldown: float = 5.0`).


* **Müzik Senkronizasyonu:** Her vuruşta (başarılı/başarısız) BGM çalan `AudioStreamPlayer` 1 saniye geriye sarar:
`bgm_player.seek(max(0.0, bgm_player.get_playback_position() - 1.0))`

#### 4. Prosedürel Zindan & Merdiven Algoritması

* **Tile Yapısı:** 1m x 1m Plane Mesh.
* **Bellek Yönetimi:** Arkada kalan ve sürü tarafından geçilen ucu kapalı koridor parçaları `queue_free()` ile bellekten silinir (Object Pooling kullanılmaz).
* **Merdiven Yerleştirme Kuralları:**
1. **Koridor Ortasında:** Koridorun tam ortasına sadece **+-1m** yükselti değişimi sağlayacak merdiven yerleştirilir.
2. **Koridor Sonunda:** Koridor bitiminde `randi_range(min_stairs_length, max_stairs_length)` uzunluğunda, aşağı veya yukarı yönlü bağımsız bir merdiven koridoru türetilir. Genişliği önceki koridor ile aynıdır ve standart koridor kurallarına tabi değildir.


* **Görüş Mesafesi & Fog:** Koridor Spawner Trigger'ları elle ayarlanan fog/render distance sınırının hemen ötesine yerleştirilir.

#### 5. Tuzak Spawn Kuralları

1. **Yükseltili Koridorlar (İkiye Bölünmüş):**
* Koridorun iki ucuna bakılır.
* İki uçta da muhafız varsa ➔ Tuzak spawn **edilmez**.
* Bir uçta muhafız var veya hiç muhafız yoksa ➔ Muhafızsız tarafın ortasında rastgele tuzak ihtimali hesaplanır.


2. **Yükseltisiz Koridorlar (Bütün):**
* Belli bir olasılıkla koridorun tam ortasında rastgele bir tuzak spawn edilir.


3. **Tuzak Genişlik & Wall-Run Oluşum Seçenekleri:**
* **Seçenek A:** Tuzağın sağında veya solunda 1 blokluk geçiş boşluğu kalır.
* **Seçenek B:** Tuzağın her iki yanında da 1'er blokluk geçiş boşluğu kalır.
* **Seçenek C (Duvar Tarafı Wall-Run):** Tuzağın yanlarında hiç boşluk kalmaz (koridoru tamamen kapatır). Temas ettiği duvarlardan birinde, tuzağın uzunluğundan **2 blok daha uzun (önden ve arkadan +1m)** özel Wall-Run alanı/duvarı (`WallRunSurface`) üretilir.



---

### Durum Makineleri (State Machine)

```text
                  ┌──────────────┐
                  │   GROUNDED   │◄────────────────┐
                  └──────┬───────┘                 │
                         │                         │
            ┌────────────┼────────────┐            │
            ▼            ▼            ▼            │
      ┌───────────┐┌───────────┐┌───────────┐      │
      │   JUMP    ││   SLIDE   ││  GET_HIT  │──────┘
      └─────┬─────┘└─────┬─────┘└─────┬─────┘ (0.2s %20 Hız)
            │            │            │
            ├────────────┘            ▼
            ▼                   ┌───────────┐
      ┌───────────┐             │   DEAD    │
      │ WALL_RUN  │             └───────────┘
      └───────────┘

```

#### Durum Geçiş Kuralları Tablosu

| Mevcut Durum | Tetikleyici / Koşul | Hedef Durum | Açıklama |
| --- | --- | --- | --- |
| **`GROUNDED`** | `jump` basıldı | **`JUMP`** | Dikey hız uygulanır. |
| **`GROUNDED`** | `slide` (Ctrl) basıldı | **`SLIDE`** | Hitbox yüksekliği yarıya iner. |
| **`JUMP`** | `ShapeCast3D` wall-run duvarı algıladı | **`WALL_RUN`** | Yerçekimi sıfırlanır, duvara tutunulur. |
| **`JUMP`** | `slide` (Ctrl) basıldı | **`SLIDE`** | Karakter hızla yere çakılır ve kayma başlar. |
| **`JUMP`** | Zemin teması sağlandı | **`GROUNDED`** | Karakter zemine iner. |
| **`SLIDE`** | `jump` (Space) basıldı | **`JUMP`** | Kayma anında kesilip zıplanır. Hitbox normale döner. |
| **`SLIDE`** | Kayma süresi bitti / Tuş bırakıldı | **`GROUNDED`** | Hitbox normale döner. |
| **`WALL_RUN`** | `jump` (Space) basıldı / Duvar bitti | **`JUMP` / `GROUNDED**` | Duvardan fırlayarak ayrılır. |
| **HERHANGİ BİRİ** | Hasar alındı | **`GET_HIT`** | `get_hit_timer` = 0.2s başlatılır. Anında **`GROUNDED`**'a geçer. |
| **HERHANGİ BİRİ** | HP <= 0 veya Killzone teması | **`DEAD`** | Hareket kilitlenir, `trigger_game_over()` tetiklenir. |

---

## 4. Teknik Mimari & Veri Yapısı (Architecture & Data)

### Autoload Mimari Yapısı & Sahne Yeniden Yükleme

`GameManager` ve `SoundManager`, **Godot Project Settings (Proje Ayarları -> Autoload)** sekmesinden tanımlanır. **RootScene altında bir düğüm olarak yer almazlar.**

#### Sahne Yeniden Yükleme (Reload) & Durum Sıfırlama

`get_tree().reload_current_scene()` çağrıldığında Autoload düğümleri hafızada kalmaya devam eder. `is_game_over` bayrağının `true` kalarak oyunu kilitlemesini önlemek için `reset_game()` fonksiyonu çağrılır:

```gdscript
# Autoload: GameManager.gd
extends Node

var current_hp: int = 3
var max_hp: int = 3
var score: int = 0
var accumulated_time: float = 0.0
var is_game_over: bool = false

func reset_game() -> void:
	current_hp = max_hp
	score = 0
	accumulated_time = 0.0
	is_game_over = false

func trigger_game_over() -> void:
	is_game_over = true
	reset_game()
	get_tree().reload_current_scene()

```

### Collision Layers & Class Type Control

Tüm fizik alanları (Collision Objects) **Collision Layer 1** ve **Collision Mask 1** üzerinde tutulur. Çarpışma ve alan tespitleri `class_name` kontrolleri ile yürütülür:

```gdscript
func _on_area_entered(area: Area3D) -> void:
	if area is FrontGuard:
		take_damage(1)
	elif area is TrapArea:
		if area.is_instakill:
			instant_death()
		else:
			take_damage(1)
	elif area is KillZone:
		instant_death()

```

### Sınıf Listesi & Node Hiyerarşisi

#### `class_name` Tanımları

* `Player`: Karakter gövdesi (`CharacterBody3D`).
* `PlayerStateMachine`: Durum makinesi mantığı.
* `FrontGuard`: Ön muhafız alanı (`Area3D`).
* `TrapArea`: Tuzak alanı (`Area3D`).
* `WallRunSurface`: Wall-run yapılabilir duvar (`StaticBody3D`).
* `KillZone`: Arkadan kovalayan sürü alanı (`Area3D`).

#### Sene Düğüm Hiyerarşisi

```text
RootScene (Node3D)
├── Environment (WorldEnvironment, DirectionalLight3D)
├── DungeonGenerator (Node3D)
│   └── ActiveCorridors (Node3D)
├── Player (CharacterBody3D) -> class_name Player
│   ├── CollisionShape3D
│   ├── Camera3D
│   │   └── HandWeapon (Node3D)
│   │       ├── AnimatedSprite3D (Flüt)
│   │       └── AttackRayCast (RayCast3D)
│   ├── ShapeCastLeft (ShapeCast3D)
│   ├── ShapeCastRight (ShapeCast3D)
│   └── PlayerStateMachine (Node)
└── ChasingHorde (Area3D) -> class_name KillZone
    └── CollisionShape3D

```

---

## 5. Adım Adım Uygulama Planı (Step-by-Step Implementation Roadmap)

### Aşama 1: Prototip, CLI Yapılandırması & Karakter Kontrolü

1. **Godot CLI Yapılandırması:** Proje başlatma ve sahne testleri için CLI komut kalıplarının hazırlanması.
2. **Autoload Kurulumu:** Project Settings üzerinden `GameManager.gd` tanımlanması.
3. **Player & Input Map:**
* WASD, Mouse Look ve Zıplama (`jump`).
* `Ctrl` tuşu ile `SLIDE` durumu.
* `SLIDE` ➔ `JUMP` geçiş kodunun yazılması.
* Havada `Ctrl` basıldığında yere hızlı düşüş (Ground Pound/Fast Fall Slide).


4. **State Machine & Get_Hit Debuff:**
* `GET_HIT` alındığında 0.2s timer başlatıp hızı %20'ye düşüren debuff yapısının kurulması.



### Aşama 2: Flüt Saldırısı, Prosedürel Zindan & Tuzaklar

1. **Flüt Saldırı Mekaniği:**
* Sol tık ile `AttackRayCast` taraması.
* Başarılı vuruşta `0.3s` cooldown; ıska vuruşta `@export var miss_cooldown: float = 5.0` cooldown işletilmesi.
* `AudioStreamPlayer` üzerinden BGM'i 1 saniye geriye sarma mantığı.


2. **Zindan Üreteci (Dungeon Generator):**
* Koridorların 1m x 1m Plane meshler ile üretimi.
* Koridor ortası +-1m merdiven ve koridor sonu `min/max_stairs_length` özel merdiven koridoru mantığı.
* Arkadaki ucu kapalı eski koridorların `queue_free()` ile bellekten silinmesi.


3. **Tuzak & Wall-Run Kurulumu:**
* Yükseltili ve yükseltisiz koridorlarda tuzak spawn algoritması.
* 1 blok boşluklu veya yanları kapalı (Wall-Run duvarı üreten) tuzak varyasyonları.



### Aşama 3: Kovalayan Sürü, Skor & Game Loop

1. **Chasing Horde (KillZone):** Oyuncuyu manuel takibinde arkadan kovalayan `Area3D`.
2. **Skor Akışı:** `int` skor tipinde biriken `delta` mantığı.
3. **Game Over & Reload:** `GameManager.trigger_game_over()` ile `reset_game()` çalıştırılıp sahnenin reload edilmesi.

---

## 6. MVP Kapsamı & Kısıtlar

### Mutlaka Yapılacaklar (Must-Have)

* [x] Doom 1 benzeri 2D Billboard Sprite + 3D Dünya estetiği.
* [x] Manuel oyuncu kontrolü (W, A, S, D, Space, Ctrl-Slide, Wall-Run).
* [x] `SLIDE` ➔ `JUMP` geçişi ve havadan yere çakılarak kayma.
* [x] `GET_HIT` durumunda 0.2s %20 hız yavaşlatma debuff'ı.
* [x] Flüt ile vurma (Başarılı: 0.3s cooldown, Iska: 5.0s cooldown, BGM -1s seek).
* [x] Ortada +-1m ve sonda bağımsız merdiven koridoru üreten prosedürel sistem.
* [x] Yanlarında geçiş alanı veya Wall-Run duvarı oluşturan tuzak algoritması.
* [x] Eski koridorların `queue_free()` ile temizlenmesi.
* [x] Godot CLI ile test/derleme desteği.
* [x] Standart klasör yapısı ve naming convention uyumu.
* [x] Project Settings Autoload mimarisi ve reload anında resetlenen int skor/HP yapısı.

### Kapsam Dışı Bırakılanlar (Out of Scope)

* ✕ Hikaye/Narrative sahneleri ve metinleri.
* ✕ Otomatik koşu (Karakter tamamen oyuncu kontrolündedir).
* ✕ Corridors Object Pooling (Tüm parçalar doğrudan `queue_free()` yapılır).
* ✕ Arayüz/Menu ekranları (Game Over durumında doğrudan sahne yenilenir).
* ✕ Karmaşık Collision Layer/Mask katmanları (Tüm kontroller Layer 1'de `class_name` ile yapılır).
