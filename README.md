movieLobby
==========

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

for Yuka Sasaki and Kenji Kumasaka Lab.


## 必要な開発環境

* node.js
* grunt

## CSSやJavascriptのコンパイルの方法

    $ grunt


## フォルダ構成

    @movieLobby
      ├ @assets
      │ ├ @css
      │ │ ├ config.styl
      │ │ └ style.styl … Stylus形式のCSS。デザインの修正時はこれを編集。
      │ ├ @image … 画像はすべてここに格納。のちに圧縮されてpublicフォルダに展開されます。
      │ ├ @js
      │ │ └ script.coffee … CoffeeScript形式のJavascript。ページ挙動の修正時はこれを編集。
      │ └ @views
      │    ├ _application.jade
      │    └ index.jade … Jade形式のHTML。ページ構成の修正時はこれを編集。
      │
      ├ @node_modules … CSSやJSの拡張ライブラリパッケージが格納される。
      │
      ├ @dist … 自動生成ファイル群。デバッグ用の中間ファイルが作成されます。定期的に削除・更新される為、直接編集禁止。
      │
      ├ @node_modules … CSSやJSをコンパイルするのに必要なパッケージが格納される。
      │
      ├ @public … 自動生成ファイル群。本番用に圧縮されたCSS・JS・画像ファイルなどが作成されます。定期的に削除・更新される為、直接編集禁止。
      │
      ├ @static … 静的ファイルはここに格納してください
      │  └ favicon.ico  … ブラウザで扱われるお気に入りアイコン
      │  └ *.ico  … iOS のショートカットアプリ用アイコン
      │
      ├ @tests … 自動テスト。今回は未作成。
      │
      ├ .gitignore
      ├ Gruntfile.coffee … CSSやJSのコンパイル, 画像の圧縮等をおこなうためのプログラム。
      ├ LICENCE
      ├ package.json
      └ README.md

