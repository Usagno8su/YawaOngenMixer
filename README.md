# やわ音原ミキサー
字幕と立ち絵付きソフトウェアトーク動画を、簡単に作成できるように補助するツール。

![YOM_logo1_mini](https://user-images.githubusercontent.com/120317207/216934789-42f1cda6-cb4d-4601-a615-9c285a6f03de.png)


# ！！！！注意！！！！

本ツールはまだアルファ版です。

重大な問題が発生する可能性がるため、メイン環境等では利用しないでください。

必ず仮想環境等の不具合が発生しても問題ない環境で使用してください。

# 解説動画

[【やわ音原ミキサー】動画作成支援ツールの開発報告01](https://www.nicovideo.jp/watch/sm41720805) 


## 概要

本ツールは、予め用意した音声合成ソフトの音声、その字幕および立ち絵を合成し、WebM形式の動画を作成します。

字幕と立ち絵以外は透明になっており、作成済みの動画と合成して簡単にソフトウェアトーク付き動画を作成可能です。

主にニコニコ動画への動画投稿に利用することを想定しています。

この手法の利点は、WebM形式に対応していれば Ubuntu 等のLinux環境でも、任意の動画作成ソフトを使用してソフトウェアトーク付き動画を作成できる点です。

ただ、実質エンコードの回数が１回増えることと、字幕の内容等を変更したくなった場合、再度エンコードが必要になるという欠点があります。


## 動画制作者の方へ

このツールのライセンスはMITライセンスです。
このため、動画制作に使用する際の制約はございません。

親作品に何かを登録するといったことも必須ではありませんが、
このGitHubのページをどこかに記載していただくか、
現在作成中のこのツールの解説動画を親作品に入れて頂ければ幸いです。


ただし、デフォルトの設定及び手順では「 Noto Sans CJK JP 」フォントを使用するようになっています。

このフォントは「 SIL Open Font License, Version 1.1. 」ライセンスのため、利用する際にはエンドクレジット等に著作権表示が必要です。

表示に決まったフォーマットは無いようなので、
状況に応じて必要な内容を記載をして頂ければ良いかと思います。

下記は表記例です。
（フォントファイルの情報から必要項目を抜粋しました）
```
本動画では下記のフォントを使用しています。
・ Noto Sans CJK JP 
　This Font Software is licensed under the SIL Open Font License, Version 1.1.
　© 2014-2019 Adobe (http://www.adobe.com/).
```

また、本ツール以外の素材等については、それぞれの規約に従って対応をお願い致します。




## 動作環境

Ubuntu 22.04 LTS にて動作を確認しています。

対応する音声合成ソフトは下記となります。

- VOICEVOX
- SHAREVOX
- CoeFont (実験的)
- VOICEPEAK

VOICEPEAKについては、テキストファイル出力の有効化と、
出力ファイル名をVOICEVOXと同じに設定する必要があります。

動画編集ソフトは「 [Shotcut](https://www.shotcut.org/) 」を使用しています。


## インストール方法

下記ドキュメントに記載しました。

- [docs/インストール方法.md](https://github.com/Usagno8su/YawaOngenMixer_doc/blob/main/docs/%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB%E6%96%B9%E6%B3%95.md)



## 利用方法

1. 立ち絵の準備

まず、立ち絵のpngファイルを準備し、わかりやすい場所に配置します。

今回は public の中に入れました。


2. ファイルの配置

VOICEVOX 等が出力した音声ファイルとテキストファイルを infile の中に入れます。

3. 「 config/main_config.yml 」の編集

main_config.yml の下記の行を変更し、「 1. 」のファイルを指定します。

```
  # 立ち絵
  tatie: "./public/tatie.png"
```

各キャラごとに立ち絵やフォント等を変更可能です。

詳細は下記に記載しております。

- [/YawaOngenMixer_doc/docs/configファイルの記述方法.md](https://github.com/Usagno8su/YawaOngenMixer_doc/blob/main/docs/config%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%81%AE%E8%A8%98%E8%BF%B0%E6%96%B9%E6%B3%95.md)

また、各キャラクター設定を入れたサンプルを下記にアップしました。

- [/YawaOngenMixer_doc/docs/sample_config.yml](https://github.com/Usagno8su/YawaOngenMixer_doc/blob/main/docs/sample_config.yml)



4. 変換の実行

変換を実行します。

CUI端末で mkdgmain.rb のあるディレクトリに移動し、
下記のコマンドを入力します。

```
ruby mkdgmain.rb config/main_config.yml
```

完了すると、 outfile ディレクトリにWebM形式のファイルが完成しているはずです。






## ライセンス

このツールは MIT ライセンスです。
