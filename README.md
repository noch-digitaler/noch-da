# noch da

**Hält deinen PC wach, solange du kurz nicht da bist.**
Läuft unter Windows ohne Installation und ohne Adminrechte.

![noch da, Programmfenster](https://noch-digitaler.de/images/noch-da-screenshot.png?v=1.0.1)

noch da wird erst aktiv, wenn Maus und Tastatur eine einstellbare Zeit lang nicht benutzt wurden.
Dann zieht der Mauszeiger winzige Kreise von 3 Pixeln, oder er bleibt im unsichtbaren Modus ganz stehen.
Sobald du selbst wieder etwas tust, hört noch da sofort auf.

Download und Anleitung: **https://noch-digitaler.de/noch-da**

## Funktionen

* **Kreisen nach Inaktivität:** winzige Mausbewegung, nur wenn du nicht am Platz bist
* **Unsichtbar:** Der Zeiger bleibt stehen, Windows bekommt nur ein Aktivitätssignal (Mausbewegung um 0 Pixel)
* **Automatisch stoppen** nach 15 Minuten bis 10 Stunden
* **Immer im Vordergrund**
* **Play, Pause und Stopp**
* Verhindert zusätzlich Bildschirmsperre und Energiesparmodus, solange es läuft

## Starten

1. `noch-da.cmd` herunterladen (oder das ZIP von der Website) und doppelklicken.
2. Falls Windows warnt: auf „Weitere Informationen“ und dann „Trotzdem ausführen“ bzw. „Ausführen“ klicken.
3. Auf Play klicken.

Beim ersten Start legt noch da neben sich eine Verknüpfung „noch da“ mit Icon an.
Wird der Ordner verschoben, startest du `noch-da.cmd` einmal. Dann passt sich die Verknüpfung an.

**Voraussetzungen:** Windows 10 oder 11. Keine Installation, keine Adminrechte, keine Internetverbindung.

**Entfernen:** Ordner löschen. noch da hinterlässt nichts auf dem System.

## Wie es funktioniert

`noch-da.cmd` ist eine einzige Textdatei. Der obere Teil ist ein kurzes Batchskript, das sich selbst
mit der in Windows enthaltenen PowerShell startet. PowerShell übersetzt beim Start den eingebetteten
Code in C# (Windows Forms) und öffnet das Fenster.

Verwendete Funktionen von Windows, alle ohne Adminrechte:

| Funktion | Zweck |
|---|---|
| `GetLastInputInfo` | Zeitpunkt der letzten Eingabe; erkennt Inaktivität und echte Eingaben |
| `mouse_event` | Mausbewegung (Kreis bzw. Impuls um 0 Pixel im unsichtbaren Modus) |
| `SetThreadExecutionState` | verhindert Bildschirmsperre und Energiesparmodus während der Laufzeit |
| `WScript.Shell` | legt die Verknüpfung mit Icon an |

Es werden keine Daten gesendet, nichts installiert und nichts in der Registry gespeichert.

## Hinweis

In vielen Unternehmen ist der Einsatz solcher Tools durch interne Richtlinien geregelt oder untersagt.
Bitte kläre die Nutzung vorab mit deinem Arbeitgeber. Auf verwalteten Firmenrechnern kann die
Sicherheitssoftware das Tool außerdem blockieren. Die Nutzung erfolgt auf eigene Verantwortung.

## Lizenz

Der Quellcode steht unter der [MIT Lizenz](LICENSE).
Name und Logo von noch-digitaler sowie der Name „noch da“ sind davon ausgenommen. Details stehen in der Lizenzdatei.

<br>

[noch-digitaler.de](https://noch-digitaler.de) · [Impressum](https://noch-digitaler.de/impressum)
