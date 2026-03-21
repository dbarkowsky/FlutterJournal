# Wing Journal

Wing Journal is a daily journaling application made using the Flutter framework.

It is designed with both desktop and mobile use in mind. All entries are formatted using Markdown for ease of export, and they are encrypted to protect from prying eyes. Every piece of data is stored locally on your system.

Some additional features:

- Search your entries
- Light and Dark themes
- Export data to `.md` files
- Save compressed images

See the [Releases](https://github.com/dbarkowsky/WingJournal/releases) page for download links.

## Why?

This was a project to build a journal application for myself that would replace [Epic Journal](https://github.com/AlbertClo/epic-journal), which I used for many years.

I found that Epic Journal was the perfect application for my journaling use, except for a few issues:

- No way to search entries
- Not usable on mobile as well as desktop

If you'd like to try it, it actually still works on Windows, but I found trying to develop it further was incredibly painful due to the state of its dependencies.

I also considered [Obsidian](https://obsidian.md/), and although I love it for other tasks, I don't find it fits what I want for a daily journal.

After learning Flutter recently, I figured this would be a good opportunity to try my own.

## Database

I currently use `sqflite`, a Flutter-friendly version of SQLite.

I took a different approach to encrypting data. The database is not encrypted with SQL Cipher, but the data in the _entries_ table and the _attachments_ table is. This is technically a little less secure, as you can open a database file and see its structure, but it is easily portable across multiple operating systems, whereas SQL Cipher had OS limitations. Anyone who gets access to the `.db` file that contains your journal should not be able to decrypt the contents without your password.

### Exporting

If you need to retrieve data from your database file, there is now an option to export the data within the app.

You could also use Dart's encryption library to decode entries. You can see the code for this under `lib/sqlite/database.dart`. You'll need your password and the salt value stored in the database metadata table.

### Importing

There's a script under the `/tools` folder named `import_data.dart`. See the comment at the top of that file on how to run the script. It will overwrite any days currently present in a journal you're importing into. A blank journal is recommended.

If coming from Epic Journal, use [DB Browser](https://sqlitebrowser.org/) to open your existing `.epic` journal. You'll need to supply your password under the SQL Cipher 3 option. You can then export the tables to `.csv` files that the import tool can use.

## Development

If you'd like to develop something on this project, you'll need to follow the instructions from the Flutter website on how to install Dart, Flutter, and Android Studio (for the emulator mostly).

Feel free to open a PR with your changes.

### OS Versions and Build Instructions

Currently, the app is tested to work on the following:

- Android (min version 10)
- Windows (tested on Windows 10)

Find download options for those systems under the Releases.

I believe it should also work for other operating systems as well, but I was only able to test on macOS and Linux at the time of development. Unfortunately, Apple's restrictions on development keep me from producing a downloadable version.

If you want to build the product from source, there are Flutter commands that will do so:

- Android: `flutter build apk --split-per-abi`
    - This may require you to create the signature key.
- Windows: `flutter build windows`

## Images

![lock screen](https://github.com/dbarkowsky/WingJournal/tree/main/docs/images/lock-screen.png)

![entry](https://github.com/dbarkowsky/WingJournal/tree/main/docs/images/entry.png)

![search](https://github.com/dbarkowsky/WingJournal/tree/main/docs/images/search.png)

![images](https://github.com/dbarkowsky/WingJournal/tree/main/docs/images/images.png)

![options](https://github.com/dbarkowsky/WingJournal/tree/main/docs/images/options.png)
