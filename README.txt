DTX KENDANG - proyek Flutter lengkap
- pubspec.yaml ada di root zip ini.
- TIDAK memakai shared_preferences (pengaturan disimpan ke file JSON sendiri),
  jadi error NoSuchMethodError SharedPreferencesApiRegistrar tidak mungkin muncul.
- 12 sample bawaan dibuat lewat kode saat pertama jalan.
- Import skin: menu > Import skin (.json). Contoh: skin_putih_contoh.json
  Field: name, bg, pad, border, glow, text (hex #RRGGBB), carbon (true/false)
- Import sample: menu > Import zip sample. Lalu tahan (long press) pad untuk ganti sample.
