# Flutter Journal

This was a project to build a journal application for myself that would replace [Epic Journal](https://github.com/AlbertClo/epic-journal), which I used for many years.

I found that EpicJournal was the perfect application for my journaling use, except for a few issues:

- No way to search entries
- Not usable on mobile as well as desktop

Although I love [Obsidian](https://obsidian.md/), I don't find it fits what I want for a daily journal.

After learning Flutter recently, I figured this would be a good opportunity to try my own.

## Database

I currently use `sqflite`, a Flutter-friendly version of SQLite.

I took a different approach to encrypting data. The database is not encrypted, but the data in the _entries_ table is. This is technically a little less secure, as you can open a database file and see its structure, but it is easily portable across multiple operating systems, whereas SQL Cipher had OS limitations.

If you need to retrieve data from your database file, use Dart's encryption library to decode entries. You can see the code for this under `lib/sqlite/database.dart`. You'll need your password and the salt value stored in the database metadata table. I may add a standalone tool for exporting and importing data at some point.

## Development

If you'd like to develop something on this project, you'll need to follow the instructions from the Flutter website on how to install Dart, Flutter, and Android Studio (for the emulator mostly).
