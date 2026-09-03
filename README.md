# Mój Librus

Prywatna aplikacja iOS (SwiftUI) do dziennika **Librus Synergia** — na własny użytek.
Wzorowana funkcjonalnie na [szkolny.eu](https://szkolny.eu), ale obsługuje **wyłącznie
Librusa**. Logowanie przez **portal.librus.pl** (tak jak oficjalna apka „Synergia Dru2").

> **Wymaga Konta LIBRUS.** Aplikacja — dokładnie jak oficjalna apka Librus — loguje się
> **Kontem LIBRUS** (e-mail + hasło z [konto.librus.pl](https://konto.librus.pl), połączone
> z Twoją Synergią). Sam login szkolny (`1234567u`) **nie zadziała** — bezpośredni login
> `api.librus.pl` (`grant_type=password`) Librus wyłączył w 2026. Jeśli nie masz Konta LIBRUS:
> konto.librus.pl → *Załóż Konto LIBRUS* → połącz z kontem Synergia.

Nie potrzebujesz Maca ani Xcode: aplikację buduje **GitHub Actions**, a instalujesz ją
przez **SideStore/AltStore** darmowym Apple ID.

## Funkcje

| Ekran | Źródło danych |
|---|---|
| Pulpit (numerek, dzisiejsze lekcje, ostatnie oceny, klasa, liczniki) | agregacja |
| Oceny — wg przedmiotów, średnie ważone, filtr semestru, **kalkulator „co jeśli / ile potrzebuję"** | `api.librus.pl/2.0/Grades` |
| Plan lekcji — tydzień, zastępstwa, odwołania, znacznik „dziś" | `.../2.0/Timetables` |
| Frekwencja — podsumowanie % + wpisy, filtr semestru | `.../2.0/Attendances` |
| Ogłoszenia | `.../2.0/SchoolNotices` |
| Terminarz (sprawdziany, kartkówki) | `.../2.0/HomeWorks` |
| Uwagi | `.../2.0/Notes` |
| Rozkład dzwonków (godziny lekcji) | `.../2.0/Schools` (`LessonsRange`) |
| Wiadomości — odczyt **i odpowiadanie** (*best-effort*) | mostek `synergia.librus.pl` → `wiadomosci.librus.pl` |
| **Widżet** planu lekcji (zastępstwa, odwołania, zmiany sal) — small/medium/large | App Group |
| Logowanie | `portal.librus.pl` OAuth → `api/v3/SynergiaAccounts` → Bearer per konto |
| Ustawienia → **Diagnostyka połączenia** — test każdego endpointu + kopiuj raport | — |
| Powiadomienia o nowych ocenach (opcjonalne, *eksperymentalne*) | `BGAppRefreshTask` |

Ogłoszenia i wiadomości: **swipe od lewej = przeczytane/nieprzeczytane** (jak w Mail).
Plan lekcji jasno pokazuje **zmianę sali** („sala 12 → 204"). Widżet wymaga App Group;
przy sideloadzie SideStore sam przepisuje identyfikator grupy — jeśli widżet nie widzi
danych, otwórz raz aplikację i odśwież plan.

Nowe oceny są oznaczane plakietką „nowe" + liczbą na zakładce (lokalne śledzenie, działa
zawsze). Powiadomienia w tle to osobny przełącznik w Ustawieniach — iOS sam decyduje, kiedy
odświeżyć apkę w tle, a dla apek sideloadowanych robi to rzadko.

Granica semestru brana z `.../2.0/Classes` (`EndFirstSemester`); gdy jej brak — fallback
po miesiącu. Dane logowania trzymane są **wyłącznie w Keychainie urządzenia**. Aplikacja
nie ma własnego serwera ani telemetrii — łączy się tylko z `*.librus.pl`. Chwilowy błąd
jednego endpointu nie czyści ekranu (zostają dane z cache).

## Jak to zbudować

1. Wrzuć ten katalog do repozytorium GitHub (`main`).
2. Zakładka **Actions** → workflow `build` uruchamia się przy każdym pushu na `main`
   oraz przy tagach `v*`. Możesz też odpalić go ręcznie (`Run workflow`).
3. Po zielonym buildzie:
   - **artefakt** `MojLibrus-ipa` (zawiera `MojLibrus.ipa`) — w podsumowaniu runa, albo
   - **Release** z plikiem `MojLibrus.ipa` — jeśli wypchnąłeś tag, np.:
     ```
     git tag v1.0.0 && git push origin v1.0.0
     ```

CI buduje **niepodpisany** `.ipa` (`CODE_SIGNING_ALLOWED=NO`) i pakuje `MojLibrus.app`
do `Payload/` → `MojLibrus.ipa`. Podpisywanie odbywa się dopiero na telefonie w SideStore.

Projekt `.xcodeproj` **nie jest** trzymany w repo — generuje go
[XcodeGen](https://github.com/yonaskolb/XcodeGen) z pliku `project.yml` na runnerze.

## Jak zainstalować na iPhonie (SideStore)

1. Zainstaluj [SideStore](https://sidestore.io) (jednorazowo z pomocą komputera; potem
   odświeża się sam przez Wi-Fi). Alternatywa: AltStore + AltServer na PC.
2. Na telefonie w Safari pobierz `MojLibrus.ipa` z Release / artefaktu.
3. SideStore → zakładka **My Apps** → **+** → wybierz pobrany `MojLibrus.ipa`.
4. SideStore podpisze apkę Twoim Apple ID i zainstaluje.

Darmowe Apple ID: aplikacja wygasa po **7 dniach** — SideStore odświeża ją w tle, gdy
telefon i komputer/serwer są w tej samej sieci. Limit 3 sideloadowanych aplikacji.
Brak powiadomień push (nieistotne — appka i tak odpytuje Librusa przy otwarciu).

### Źródło SideStore (opcjonalnie, wygodne aktualizacje)

Po pierwszym **Release** dodaj w SideStore źródło:
```
https://github.com/<twój-user>/<repo>/releases/latest/download/apps.json
```
Workflow aktualizuje `apps.json` przy każdym buildzie (wersja, rozmiar, link do
najnowszego `.ipa`). Kolejne wersje wgrywasz wtedy jednym tapnięciem „Update".

## Konfiguracja

Domyślnie: nazwa **„Mój Librus"**, bundle ID `eu.mojlibrus.app`. Aby zmienić — edytuj
`project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME`) oraz `Resources/Info.plist`
(`CFBundleDisplayName`). Bundle ID nie może kolidować z oficjalną apką Librusa.

## Problemy

- **Coś nie działa?** Ustawienia → **Diagnostyka połączenia** → *Uruchom test* → *Kopiuj
  raport*. Wyświetla osobno „Logowanie (Portal → Synergia)" i każdy endpoint.
- **Captcha przy logowaniu** — portal rzadko wymaga captchy z IP telefonu. Zaloguj się raz
  przez przeglądarkę na `portal.librus.pl`, poczekaj kilka minut i spróbuj ponownie w apce.
- **„Portal nie zwrócił żadnego konta Synergia"** — konto musi być połączone na
  `portal.librus.pl` (zakładka *Twoje konta*). Nowe konta LIBRUS mają to automatycznie.
- **„Nie udało się zalogować do skrzynki wiadomości"** — mostek do `wiadomosci.librus.pl`
  jest najbardziej kruchą częścią (osobna sesja, XML). Reszta aplikacji działa niezależnie.
  Jeśli błąd się powtarza, zgłoś zawartość — trzeba dostroić nazwy pól XML.
- **Odpowiadanie na wiadomości** działa tylko gdy z wiadomości uda się odczytać login
  nadawcy; przed wysłaniem jest pytanie „do kogo + temat". Nie ma okna „nowa wiadomość"
  ani wyboru odbiorców — świadomie, żeby nie wysłać czegoś przypadkiem.
- **Pusty plan lekcji** — sprawdź w Librusie, czy plan klasy jest publiczny
  (`Student timetable is not public`).
- **Build pada na `xcodegen` / wersji Xcode** — workflow pinuje `latest-stable`; w razie
  potrzeby ustaw konkretną wersję w kroku *Select Xcode*.

## Uwaga prawna

Nieoficjalny klient. Odtwarza publiczne API aplikacji mobilnej Librus (te same stałe
klienta OAuth, których używają inne projekty open-source, m.in. szkolny.eu). Wyłącznie do
użytku własnego z własnym kontem. Nie jest powiązany z firmą Librus.

## Architektura (skrót)

```
Sources/
  Auth/      Keychain, Credentials, LibrusSession (actor: token + refresh)
  Api/       Endpoints, APIError, LibrusAPI (1 metoda / endpoint)
  Models/    Raw/  (Codable 1:1 z JSON) + View/ (modele złączone)
  Store/     DataRepository (@Observable, łączenie po Id, cache), GradeMath, Cache
  Messages/  MessagesClient (AutoLoginToken → sesja Synergia → wiadomosci XML)
  Features/  ekrany SwiftUI (Login, Dashboard, Grades, Timetable, Attendance, …)
Tests/       dekodowanie próbek JSON + testy średnich
```
