# Datetime::Hash

### What it is / What to use it for

`Datetime::Hash` is a high-performance Perl XS extension that leverages the **ICU (International Components for Unicode)** library. Use it when you need to:

* **High Performance**: Generate multiple localized date formats in a single, near-instant pass.
* **Standardization**: Sync date data across different protocols like ICS, RSS/RFC822, and ISO8601.
* **Low Overhead**: Maintain high speed in environments where standard Perl `DateTime` objects are too resource-heavy.

### Interface

The module provides two primary functions for handling different data schemas:

#### 1. Professional Schema (Modern)

This is the recommended interface for new projects. It uses clean, descriptive key names.

```perl
use Datetime::Hash qw(format_datetime);

my $hash = format_datetime("2025-12-17 13:15:00", "Europe/Berlin", "de_DE");
# Key examples: display_name, timestamp, dow_iso, weekday_long, month_long, iso_utc, ics, rfc822

```

#### 2. Legacy Schema (Compatibility)

Use this for drop-in compatibility with legacy codebases (versions 0.0.x).

```perl
use Datetime::Hash qw(format_legacy);

my $old = format_legacy("2025-12-17 13:15:00", "Europe/Berlin");
# Key examples: date_name, epoch, day_of_week, datetime_utc, time_name

```

---

### Installation

#### Via Ubuntu Package (.deb)

The pre-compiled Ubuntu package handles all `libicu` dependencies automatically. This is the recommended installation method.

**[Download Ubuntu Package Here](https://www.google.com/search?q=https://your-repository-url.com)**

```bash
sudo apt install ./libdatetime-hash-perl_1.0.0_amd64.deb

```

#### Via PPA (Planned)

```bash
sudo add-apt-repository ppa:milan-chrobok/datetime-hash
sudo apt update
sudo apt install libdatetime-hash-perl

```

---

### Author

Milan Chrobok [mc@radiopiloten.de](mailto:mc@radiopiloten.de)

### License

GPL-3.0+

