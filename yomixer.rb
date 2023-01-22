#!/usr/bin/env ruby

#
## やわ音原ミキサー
## 立ち絵の入った画像と音声・テキストデータから、それらを合成したものを作成し、
## 字幕と立ち絵付きソフトウェアトーク動画を簡単に作成できるように補助するツール
#



########################## 外部ライブラリの読み込み ##########################

require 'yaml'



########################## 基本設定(グローバル変数) ##########################



# 最後に処理の中で発生したエラー等を表示するための変数。
# エラー等の情報はこの中に記録して、最後に表示する。
$errorput = ""

# 読み込む音声ファイルの拡張子を配列で記述する。
$voice_file_type_list = ["wav", "ogg", "mp3", "opus"]



################################################################################


# クラス定義
class YawaOngenMixer
  
  ########################## メインオブジェクト ##########################
  
  
  def main(yfile)
    
    # カレントディレクトリをスクリプトのあるディレクトリに変更する。
    Dir.chdir(__dir__)
    
    # メソッド用のハッシュの宣言
    dgmakhash = Hash.new([])
    
    # YAMLファイルを読み込んで結果のハッシュを得る
    confihash = self.readconf(yfile)
    
    
    #### フォルダの指定

    # 音声データのあるディレクトリ
    voidir = confihash["info"]["filedir"]["voidir"]
    
    # 動画の出力ディレクトリ
    outdir = confihash["info"]["filedir"]["outdir"]
    
    
    #### ファイルの各種設定
    
    # ファイル名の区切り文字に「-」を入れるか指定する。
    kugirihaihun = confihash["info"]["kugirihaihun"]

    
    ## 指定ディレクトリ内をひとつずつ調べる
    Dir.foreach(voidir + "/.") do |item|
      
      ### ファイルの拡張子を調べる。
      
      # 音声ファイルであれば、この変数にその拡張子を入れる。
      voice_file_type = nil
      
      # 拡張子をリストと照合し、音声ファイルであれば変数にその拡張子を入れる。
      for i in $voice_file_type_list do
        if ( File.extname(item) == ".#{i}" ) then
          voice_file_type = i
        end
      end
      
      # 音声ファイルの場合は「」にnil以外が入っているため、エンコード処理を行う。
      if voice_file_type != nil then
        puts "音声: " + item
        
        # 音声ファイルのパス
        voice_file = voidir + "/" + item
        
        # 音声ファイルと同名のテキストファイルのパス
        voice_text_file = voidir + "/" +  File.basename(item, ".#{voice_file_type}") + ".txt"
        
        # 完成したファイルの出力先
        out_mvfile = outdir + "/" + File.basename(item, ".#{voice_file_type}") + ".webm"
        
        puts "テキスト: " + voice_text_file
        
        
        ## dougaMake() メソッド用ハッシュに値を入れる
        ## 音声ファイルの名前はディレクトリ情報のないもの（ファイル名のみ）を渡す
        dgmakhash = mkComdHash(confihash, item, kugirihaihun)
        
        ### 残りの必要な要素を追加する。
        
        # 音声ファイルのパス
        dgmakhash["voice_file"] = voice_file
        
        # 音声ファイルと同名のテキストファイルのパス
        dgmakhash["voice_text_file"] = voice_text_file
        
        # 完成した動画ファイルの出力先
        dgmakhash["out_mvfile"] = out_mvfile
        
        
        ## 音声・立ち絵・字幕を合成したファイルを作成する。
        dougaMake(dgmakhash)
        p dgmakhash
        
        
      end
    end
    
    # エラー等の内容を出力する
    puts("=============エラー等がある場合は下記に出力されます========================")
    puts ($errorput)
    puts("=========================================================================")
    
  end
  
  
  ########################## サブオブジェクト ##########################
  
  # 設定の入ったYAMLファイルを読み込んで結果のハッシュを返す。
  # 実行コマンドの引数でconfファイルの存在を確認する。
  # ファイルがなかったり、YAMLファイル以外なら終了する。
  # 将来的には複数のYAMLファイルを読み込んで、
  # どのファイルの設定を優先してハッシュに入れるかも判断する。
  def readconf(yfile)
    
    # 指定されたファイルがなかったり、YAMLファイル以外なら終了する。
    if ( File.file?(yfile) ) and ( File.extname(yfile) == ".yml" ) then
      confihash = YAML.load_file(yfile)
    else
      puts("confファイルが正しく指定されていません。実行を終了します。")
      exit
    end
    
    return(confihash)
  end
  
  
  
  
  # 完成予定のディスプレイの大きさの画像に、立ち絵を配置したpngファイルを使用して、
  # 音声と字幕を合成した動画を作成する。
  # 
  ## 引数のハッシュ内容について
  # 字幕を表示するか指定: dgmakhash["enatext"]
  # 字幕のフチに色をつけるか指定: dgmakhash["enatextbord"]
  # 字幕の背景色をつけるか指定: dgmakhash["enabg"]
  # 立ち絵: dgmakhash["tatie"]
  # 立ち絵が左右どちらにあるか（L=左,それ以外=右）: dgmakhash["muki"]
  # 入力される立ち絵と、出力される動画のフレームレート指定: dgmakhash["fps"]
  # 音声ファイルのパス: dgmakhash["voice_file"]
  # 音声テキストのパス: dgmakhash["voice_text_file"]
  # 字幕のフォントファイルのパス: dgmakhash["voice_text_fonts"]
  # 字幕のフォントサイズ: dgmakhash["voice_text_size"]
  # 字幕のフォントカラー: dgmakhash["voice_text_color"]
  # 字幕のフォント周りのフチの色: dgmakhash["voice_text_bordercr"]
  # 字幕のフォント周りのフチの大きさ: dgmakhash["voice_text_borderw"]
  # 字幕の背景の色: dgmakhash["voice_text_bgcolor"]
  # 字幕の背景の透明度: dgmakhash["voice_text_bgtoumei"]
  # 完成したファイルの出力先パス: dgmakhash["out_mvfile"]
  def dougaMake(dgmakhash)
    
    ### 字幕を入れるか判断する。
    # dgmakhash["enatext"] が yes で、なおかつ字幕のテキストファイルとフォントファイルがあるか確認する。
    if ( ( dgmakhash["enatext"] == "yes" ) and ( File.file?(dgmakhash["voice_text_file"]) ) and ( File.file?(dgmakhash["voice_text_fonts"]) ) ) then
      
      
      # 立ち絵が左右どちらにあるか
      muki = dgmakhash["muki"]
      
      # 字幕の背景色を入れるか判断する。
      if (dgmakhash["enabg"] == "yes") then
        
        # 立ち絵の左右によって背景色の描写開始位置を変える
        if (muki == "L") then
          
          # 左の場合はそこを開ける
          haikeimuki = "(iw*0.25)"
          
        else
          
          # 右の場合はそこを開ける
          haikeimuki = "(iw*0.05)"
          
        end
        
        haikeisyoku = "drawbox=x=#{haikeimuki}:y=ih*0.8:w=iw*0.7:h=ih*0.2:t=fill:\
                       color=#{dgmakhash["voice_text_bgcolor"]}@#{dgmakhash["voice_text_bgtoumei"]}:replace=1,"
        
        # 文字のy座標の計算式を入れる
        # 背景色の右上から下へ文字を描写する。
        mozizahyou = "(h*0.8)+20"
      else
        
        # 背景を入れない場合は空白にする
        haikeisyoku = ""
        
        ## 文字のy座標の計算式を入れる
        
        # テキストファイルの行数をカウントする。
        gyoucunt = File.read(dgmakhash["voice_text_file"]).lines.count
        
        # 動画の下辺りに文字が来るように開始位置を決める。
        # 二行以上の場合は、その分描写開始位置を上にずらす必要がある。
        # また、文字の高さ分だけ開始位置を上にすると、動画の下ギリギリに字幕が描写されるので +10 している。
        mozizahyou = "h-((#{dgmakhash["voice_text_size"]}*#{gyoucunt})+10)"
      end
    
      
      # 字幕のフチに色をつけるか判断する
      if (dgmakhash["enatextbord"] == "yes") then
        huti = "bordercolor=#{dgmakhash["voice_text_bordercr"]}:borderw=#{dgmakhash["voice_text_borderw"]}:"
      else
        # 字幕のフチに色をつけない場合は空の値を入れる。
      huti = ""
        
      end
      
      # 立ち絵の左右によって字幕の描写開始位置を変える
      if (muki == "L") then
        
        # 左の場合はそこを開ける
        zimakumuki = "(w*0.3)-(w*0.04)"
        
      elsif (muki == "R") then
        
        # 右の場合はそこを開ける
        zimakumuki = "(w*0.06)"
        
      else
        
        # 向きが指定されていない場合は中央揃えで表示する。
        zimakumuki = "((w-tw)/2)"
        
      end
      
      
      # コマンドを作る。
      zimakuline = "-filter_complex \"format=rgba,#{haikeisyoku}drawtext=fontfile=\'#{dgmakhash["voice_text_fonts"]}\':\
                    textfile=\'#{dgmakhash["voice_text_file"]}\':fontcolor=#{dgmakhash["voice_text_color"]}:\
                    #{huti}fontsize=#{dgmakhash["voice_text_size"]}:x=#{zimakumuki}:y=#{mozizahyou}\""
      
      
    else
      
      # dgmakhash["enatext"] が yes なのに字幕のテキストファイルがない場合はエラー情報を出力しておく。
      if ( ( dgmakhash["enatext"] == "yes" ) and ( File.file?(dgmakhash["voice_text_file"]) == false ) ) then
        
        # 最後に出力するため、変数に書き出す。
        $errorput << "指定された字幕のテキストファイル「 #{dgmakhash["voice_text_file"]} 」が存在しなかったため、字幕なしで作成しました。\n"
      end
      
      # dgmakhash["enatext"] が yes なのにフォントファイルがない場合はエラー情報を出力しておく。
      if ( ( dgmakhash["enatext"] == "yes" ) and ( File.file?(dgmakhash["voice_text_fonts"]) == false ) ) then
        
        # 最後に出力するため、変数に書き出す。
        $errorput << "指定された字幕のフォントファイル「 #{dgmakhash["voice_text_fonts"]} 」が存在しなかったため、字幕なしで作成しました。\n"
      end
      
      
    
      # 字幕を入れない場合は空の値を入れる。
      zimakuline = ""
      
    end
    
    # エンコードを実施する
    # 音声と立ち絵を合成する。
    # このとき「-shortest」を入れないとエンコードが止まらない。
    # また「-fflags shortest -max_interleave_delta 100M」を入れないと動画の後ろに余計な無音時間が入る。
    system("ffmpeg -y -loop 1 -r #{dgmakhash["fps"]} -i #{dgmakhash["tatie"]} -i \"#{dgmakhash["voice_file"]}\" \
            -auto-alt-ref 0 -c:a libvorbis -c:v libvpx-vp9 -shortest -fflags shortest -max_interleave_delta 20M \
            #{zimakuline} -r #{dgmakhash["fps"]} \"#{dgmakhash["out_mvfile"]}\"")
    
    return(0)
  end
  
  
  
  # YAML ファイルの設定と、指定したディレクトリの内容から、
  # dougaMake(dgmakhash)メソッドへ送るハッシュを作成する。
  ## 
  # 引数の内容
  # confihash: 設定ファイル（YAMLファイル｝のハッシュ
  # item: 対象の音声ファイル名(wavファイル)。
  def mkComdHash(confihash, item, kugirihaihun)
    
    # データを返すためのハッシュの宣言
    dgmakhash = Hash.new([])
    
    # どのタイプの設定を用いて動画を作るか、判定を行なわなければならない要素を配列に記載
    hantei_list = ["enatext", "enatextbord", "enabg", "tatie", "muki", "fps", \
                   "voice_text_fonts", "voice_text_size", "voice_text_color", \
                   "voice_text_bordercr", "voice_text_borderw", "voice_text_bgcolor", "voice_text_bgtoumei"]
    
    ## ファイル名の分割に使用する文字を指定する。
    ## yesなら「-」でも分割を行う(voicepick対応のため)
    if ( kugirihaihun == "yes" ) then
      splitch = /_|-/
    else
      splitch = /_/
    end
    
    ### 読み込む音声ファイル名を分割して、ファイルのIDとキャラ名を取得する。
    sp_item = item.split(splitch)
    puts "分割後:"
    p sp_item
    
    # シリアル番号を取得する。
    file_se = sp_item[0]
    
    # キャラ名のみを取得
    cara = sp_item[1].split(/['（'|'\(']/)[0]
    
    # スタイルを含めたキャラ名を取得
    cara_st = sp_item[1]
    
    # 判定は、シリアル番号＞キャラ名（スタイル）＞キャラ名＞デフォルト の優先順位となる
    for val in hantei_list do
      
      # 該当ファイルのシリアル番号と同じ設定があるか確認する。
      if (  confihash.dig("seid", file_se, val)  != nil ) then
        
        # ハッシュに値を入れる
        dgmakhash[val] = confihash["seid"][file_se][val]
        
      # 該当ファイルのスタイルを含めたキャラ名と同じ設定があるか確認する。
      elsif ( confihash.dig("kyara", cara_st, val)  != nil ) then
        # ハッシュに値を入れる
        dgmakhash[val] = confihash["kyara"][cara_st][val]
        
      # 該当ファイルのキャラ名(スタイルが設定されていない)と同じ設定があるか確認する。
      elsif ( confihash.dig("kyara", cara, val) != nil ) then
        # ハッシュに値を入れる
        dgmakhash[val] = confihash["kyara"][cara][val]
        
      # 設定がない場合はデフォルトの値を入れる。
      elsif ( confihash.dig("defo", val) != nil ) then
        
        # ハッシュに値を入れる
        dgmakhash[val] = confihash["defo"][val]
        
      # 値が設定されていない場合
      else
        
        puts("デフォルトの #{val} が設定されていないため終了します。")
        
        exit(1)
        
      end
      
      p dgmakhash[val]
      
    end
    
    
    # 作成したハッシュを返す
    return(dgmakhash)
  end
  
end





