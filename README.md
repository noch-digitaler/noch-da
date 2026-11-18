# noch da

**Hält deinen Windows-PC wach, solange du kurz nicht da bist.**
Portabel, ohne Installation, ohne Administratorrechte.

![noch da – Programmfenster](https://noch-digitaler.de/images/noch-da-screenshot.png)

noch da wird erst aktiv, wenn Maus und Tastatur eine einstellbare Zeit lang nicht benutzt wurden.
Dann zieht der Mauszeiger winzige Kreise von 3 Pixeln – oder bleibt im Unsichtbar-Modus ganz stehen.
Sobald du selbst wieder etwas tust, hört noch da sofort auf.

Download und Anleitung: **https://noch-digitaler.de/noch-da**

## Funktionen

- **Kreisen nach Inaktivität** – winzige Mausbewegung, nur wenn du nicht am Platz bist
- **Unsichtbar** – der Zeiger bleibt stehen, Windows bekommt nur ein Aktivitätssignal (Mausbewegung um 0 Pixel)
- **Automatisch stoppen** nach 15 Minuten bis 10 Stunden
- **Immer im Vordergrund**
- **Play / Pause / Stopp**
- Verhindert zusätzlich Bildschirmsperre und Energiesparmodus, solange es läuft

## Starten

1. `noch-da.cmd` herunterladen (oder das ZIP von der Website) und doppelklicken.
2. Falls Windows warnt: „Weitere Informationen“ → „Trotzdem ausführen“ bzw. „Ausführen“.
3. Auf Play klicken.

Beim ersten Start legt noch da neben sich eine Verknüpfung „noch da“ mit Icon an.
Wird der Ordner verschoben, einfach `noch-da.cmd` einmal starten – die Verknüpfung passt sich an.

**Voraussetzungen:** Windows 10 oder 11. Keine Installation, keine Administratorrechte, keine Internetverbindung.

**Entfernen:** Ordner löschen. noch da hinterlässt nichts auf dem System.

## Wie es funktioniert

`noch-da.cmd` ist eine einzige Textdatei. Der obere Teil ist ein kurzes Batch-Skript, das sich selbst
mit der in Windows enthaltenen PowerShell startet. PowerShell übersetzt den eingebetteten C#-Code
(Windows Forms) beim Start und öffnet das Fenster.

Verwendete Windows-Funktionen (alle ohne Administratorrechte):

| Funktion | Zweck |
|---|---|
| `GetLastInputInfo` | Zeitpunkt der letzten Eingabe – erkennt Inaktivität und echte Benutzereingaben |
| `mouse_event` | Mausbewegung (Kreis bzw. 0-Pixel-Impuls im Unsichtbar-Modus) |
| `SetThreadExecutionState` | verhindert Bildschirmsperre und Energiesparmodus während der Laufzeit |
| `WScript.Shell` | legt die Verknüpfung mit Icon an |

Es werden keine Daten gesendet, nichts installiert und nichts in der Registry gespeichert.

## Hinweis

In vielen Unternehmen ist der Einsatz solcher Tools durch IT-, Sicherheits- oder Arbeitsrichtlinien
geregelt oder untersagt. Bitte kläre die Nutzung vorab mit deinem Arbeitgeber. Auf verwalteten
Firmen-PCs kann die IT-Sicherheit das Tool außerdem blockieren. Die Nutzung erfolgt auf eigene Verantwortung.

## Lizenz

Der Quellcode steht unter der [MIT-Lizenz](LICENSE).
Name und Logo von noch-digitaler sowie der Name „noch da“ sind davon ausgenommen – Details in der Lizenzdatei.

---

[noch-digitaler.de](https://noch-digitaler.de) · [Impressum](https://noch-digitaler.de/impressum)
