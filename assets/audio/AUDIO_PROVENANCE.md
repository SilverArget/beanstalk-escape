# Beanstalk Escape — ses kaynak kaydı (13.10.2026)

Yönetici: "ve o mekanik sesleri nerden buldun da koydun düzelt o sesleri de"

## Eski sesler nereden geldi (08.10.2026 hazırlığı, `arastirma/ses-hazir/MANIFEST.md`)
Dinlenmedi; "mekanik" hükmü dosya adı + paket açıklamasından.

| olay (kod anahtarı) | eski dosya | kaynak paket / dosya | lisans | mekanik mi |
|---|---|---|---|---|
| dal geçişi `branch_swoosh` | branch_swoosh.ogg | Sonniss GDC2026 · Cinematic Sound Design Cartoon & Animation 2 · "Cartoon Pull Swoosh Readout" | Sonniss GDC (ticari serbest) | EVET — çizgi film tasarım swoosh'u, "readout" (ekran/arayüz) |
| fasulye belirdi `bean_warning_creak` (+ kaya uyarısı, fırtına `branch_crack`) | bean_warning_creak.ogg | Kenney RPG Audio · creak1 (kapı menteşesi) | CC0 | EVET — kapı menteşesi gıcırtısı |
| fasulye düşüş `bean_fall_whoosh` | bean_fall_whoosh.ogg | Sonniss · 344 Audio Elemental Palette · "Wind, Rush, Whoosh" | Sonniss GDC | hayır — rüzgâr süpürmesi (KALDI) |
| fasulye isabet `bean_impact` | bean_impact.ogg | Kenney Impact Sounds · impactSoft_heavy_000 | CC0 | hayır — yumuşak gümleme (KALDI) |
| fasulye isabet katmanı `bean_impact_wood` | bean_impact_wood.ogg | Kenney Impact Sounds · impactWood_medium_002 | CC0 | EVET — kuru tahta "tok" |
| tırmanma `climb_rustle_1-3` | climb_rustle_1-3.ogg | Kenney RPG Audio · cloth1-3 | CC0 | hayır — kumaş hışırtısı (KALDI) |
| örümcek adımı `spider_step_1/2` (sürekli, 0,45–1,1 sn arayla) | spider_step_1/2.ogg | Kenney Impact Sounds · impactWood_light_000/002 | CC0 | EVET — ritmik kuru tahta "tık tık" (saat tıkırtısı gibi) |
| örümcek çığlığı `spider_scream` (+ `web_shot`) | spider_scream.ogg | Sonniss · SoundBits Vox Bestiae · "Insectoid Creature Tremble Attack" | Sonniss GDC | hayır — organik yaratık sesi (KALDI) |
| kalp atışı `heartbeat_thump` | heartbeat_thump.ogg | Kenney Impact Sounds · impactSoft_heavy_002 | CC0 | hayır (KALDI) |
| zaman kanadı `time_wings` | time_wings.ogg | Sonniss · ESM Fantasy Game 2 · "Magic Light Spell Enchantment Potion" | Sonniss GDC | EVET — sentez büyü parıltısı |
| etap bitti `stage_complete` | stage_complete.ogg | Kenney Music Jingles · jingles_PIZZI01 (pizzicato) | CC0 | hayır (KALDI) |
| oyun bitti `game_complete` | game_complete.ogg | Sonniss · ESM Anime Game · "Power Up Bright Positive ... Crash Shimmer" | Sonniss GDC | EVET — sentez power-up stinger |
| ölüm `death_bass_down` | death_bass_down.ogg | Sonniss · Cinematic Sound Design Cartoon & Animation 2 · "Cartoon Transition Bass Down" | Sonniss GDC | EVET — sentez bas düşüşü |
| arayüz tık `ui_click` | ui_click.ogg | Kenney Interface Sounds · click_001 | CC0 | EVET — dijital tık |
| altın toplama `gold_pickup` | gold_pickup.ogg | ui_click.ogg ile BAYT BAYT AYNI (cmp) → Kenney click_001; MANIFEST'te kaydı yok, 0a4daf5'te kopyalanmış | CC0 | EVET — dijital tık |
| ortam rüzgârı `wind_loop` (sürekli) | wind_loop.ogg | Sonniss · ESM **Synthesized** Nature Loops · "Wind Whipping Constricted Flow Turbulent" | Sonniss GDC | EVET — sentezlenmiş, "daraltılmış akış" (havalandırma uğultusu) |
| müzik `music_game` / `music_menu` | — | MintoDog "Fairy Adventure" / TAD "Treasure Hunter" (OGA) | CC0 | hayır (KALDI) |

## Yeni sesler (`assets/audio/`)
İşlem: baştaki sessizlik kırpıldı, gerekirse kesildi + fade, loudnorm TP=-3, sonra tepe hedefine kazanç; OGG Vorbis q5, 44,1 kHz. Ölçüm ffmpeg `volumedetect`.

| olay | yeni dosya | kaynak | lisans | süre sn | ort./tepe dB |
|---|---|---|---|---|---|
| dal geçişi `branch_swoosh` + fırtına `branch_break` yedeği | vine_swish.ogg | Sonniss GDC2026 · InMotionAudio Foley T-Shirt · FOLYClth_ClothMovement29 (ilk 0,8 sn) | Sonniss GDC (ticari serbest, ham dağıtım yasak) | 0.80 | -23.3 / -7.6 |
| fasulye belirdi `bean_warning_creak` | bean_pop.ogg | Freesound 244654 "Pop 2" — D.S.G. (godottemps 3371 Moddable-Platformer kopyası) | CC0 (freesound.org/s/244654) | 0.10 | -20.1 / -7.4 |
| kaya uyarısı (`rock_manager` → `rock_rumble`) | rock_rumble.ogg | OpenGameArt "75 CC0 breaking/falling/hit sfx" — rubberduck · bfh1_rock_falling_01 (godottemps 4919 kopyası) | CC0 | 0.90 | -31.7 / -3.0 |
| fasulye isabet katmanı `bean_impact_wood` | leaf_crunch.ogg | Kenney Impact Sounds · footstep_grass_002 | CC0 | 0.69 | -32.3 / -4.0 |
| örümcek adımı `spider_step_1/2` | spider_skitter_1/2.ogg | Kenney Impact Sounds · footstep_grass_000/004 (highpass 400 Hz, 0,3 sn) | CC0 | 0.30 | -30.9 / -8.0 · -30.5 / -7.7 |
| fırtına dal çatlaması `branch_crack` | vine_crack.ogg | OGA rubberduck · bfh1_wood_breaking_01 | CC0 | 0.28 | -34.2 / -4.3 |
| fırtına dal kırılması `branch_break` | vine_break.ogg | OGA rubberduck · bfh1_wood_breaking_04 | CC0 | 0.30 | -29.4 / -4.3 |
| ölüm `death_bass_down` | vine_snap_fall.ogg | OGA rubberduck · bfh1_wood_breaking_03 (+0,25 sn kuyruk) | CC0 | 0.74 | -28.8 / -3.5 |
| zaman kanadı `time_wings` | wings_flap.ogg | Freesound 596541 "Large Wings Flapping - Foley" — tothrec2 (ilk 1,8 sn) | CC0 (freesound.org/s/596541) | 1.80 | -20.9 / -4.0 |
| oyun bitti `game_complete` | xylophone_win.ogg | Sonniss GDC2026 · CB Sounddesign Organic UI and Building Games · "Xylophone Ringtone 2" (ilk 3 sn) | Sonniss GDC | 2.99 | -26.9 / -3.6 |
| altın toplama `gold_pickup` | kalimba_gold.ogg | Sonniss GDC2026 · CB Sounddesign Organic UI · "Kalimba 3 Up" | Sonniss GDC | 0.58 | -26.6 / -4.8 |
| arayüz tık `ui_click` | page_flick.ogg | Kenney RPG Audio · bookFlip3 | CC0 | 0.20 | -31.8 / -6.0 |
| ortam rüzgârı `wind_loop` | wind_meadow_loop.ogg | Sonniss GDC2026 · 344 Audio Extreme Winds Vol. 1 · "EXT, Eye Of The Storm" (128,25–141,25 sn, en düzgün 14 sn pencere; lowpass 5 kHz; 1 sn çapraz geçişli döngü) | Sonniss GDC | 12.00 | -21.9 / -8.9 |

Eski dosyalarla kıyas: eski tepe -1,0…-5,6 dB; yeni tepe -3,0…-8,9 dB (müziğin -6,5 tepesinin altında). Sık çalan sesler (örümcek adımı, dal geçişi) daha alçak tutuldu.
Hazırlık komutları: `arastirma/ses-dogal/liste.txt` + bu klasördeki ffmpeg zinciri; ara çıktılar `out/`, oyuna giren `final/`.
