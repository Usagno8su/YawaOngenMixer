#!/usr/bin/env ruby

#
## やわ音原ミキサー
## 立ち絵の入った画像と音声・テキストデータから、それらを合成したものを作成し、
## 字幕と立ち絵付きソフトウェアトーク動画を簡単に作成できるように補助するツール
#



########################## 外部ライブラリの読み込み ##########################

require 'yaml'
require 'digest'


########################## 基本設定(グローバル変数) ##########################



# 最後に処理の中で発生したエラー等を表示するための変数。
# エラー等の情報はこの中に記録して、最後に表示する。
$errorput = ""

# 読み込む音声ファイルの拡張子を配列で記述する。
$voice_file_type_list = ["wav", "ogg", "mp3", "opus"]

# どの項目の設定を用いて動画を作るか、判定を行なわなければならない要素を配列に記載
$hantei_list = ["enatext", "ena_muki", "enatextbord", "enabg", \
                "tatie", "tatie_muki", "conp_tatie", "movi_w", "movi_h", "tatie_h_p", "fps", \
                "voice_text_fonts", "voice_text_size", "voice_text_color", \
                "voice_text_bordercr", "voice_text_borderw", "voice_text_bgcolor", "voice_text_bgtoumei"]
    


################################################################################


# クラス定義
class YawaOngenMixer
  
  
  # インスタンスメソッド
  def initialize()
    
    ## インスタンス変数の宣言
    
    # confファイルを読み込んだ結果を入れるハッシュ。
    @confihash = Hash.new([])
    
    # @confihash から、それぞれの音声ファイルに指定された設定を選んで、
    # 結果を入れるハッシュ。
    @dgmakhash = Hash.new([])
    
    
   # @dgmakhash で入れた値が @confihash のどの項目(デフォルト・キャラ・ID)から入れたか記録するハッシュ。
    @valtypehash = Hash.new([])
    
  end
  
  
  
  ########################## メインオブジェクト ##########################
  
  
  def main(yfile)
    
    # カレントディレクトリをスクリプトのあるディレクトリに変更する。
    Dir.chdir(__dir__)
    
    # メソッド用のハッシュの宣言
    
    
    # YAMLファイルを読み込んで結果のハッシュを得る
    @confihash = self.readconf(yfile)
    
    
    # 処理開始前に必要なツールやディレクトリが存在するか確認する。
    chkbf()
    
    
    #### フォルダの指定

    # 音声データのあるディレクトリ
    voidir = @confihash["info"]["filedir"]["voidir"]
    
    # 動画の出力ディレクトリ
    outdir = @confihash["info"]["filedir"]["outdir"]
    
    
    #### ファイルの各種設定
    
    # ファイル名の区切り文字に「-」を入れるか指定する。
    kugirihaihun = @confihash["info"]["kugirihaihun"]

    
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
        mkComdHash(item)
        
        ### 残りの必要な要素を追加する。
        
        # 音声ファイルのパス
        @dgmakhash["voice_file"] = voice_file
        
        # 音声ファイルと同名のテキストファイルのパス
        @dgmakhash["voice_text_file"] = voice_text_file
        
        # 完成した動画ファイルの出力先
        @dgmakhash["out_mvfile"] = out_mvfile
        
        
        ## 音声・立ち絵・字幕を合成したファイルを作成する。
        dougaMake()
        p @dgmakhash
        
        
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
       return(YAML.load_file(yfile))
    else
      puts("confファイルが正しく指定されていません。実行を終了します。")
      exit
    end
    
  end
  
  
  
  
  # 処理開始前に必要なツールやディレクトリが存在するか確認する。
  # ない場合は終了する。
  def chkbf()
    
    
    ##########################
    ###### 外部ソフトの確認
    
    ##### ffmpeg
    ## libvorbis と libvpx があるか確認する。
    
    # ffmpeg の configurationの値を取得する。
    cmd_ans = `ffmpeg -version | grep configuration`
    
    # enable-libvorbis と grep enable-libvpx があるか確認して、なければエラーとする。
    if ( (cmd_ans.include?("enable-libvorbis") == false) or (cmd_ans.include?("enable-libvpx") == false) ) then
      
      # ffmpeg が正常にインストールされていないので終了する。
      puts("ffmpeg が正常にインストールされていません。")
      puts("libvorbis と libvpx が有効になっているかも確認してください。")
      
      exit(1)
    end
    
    
    
    ##### ImageMagick
    ## png が有効かも確認する。
    
    # convert の Delegates の値を取得する。
    cmd_ans = `convert -version | grep \"Delegates (built-in):\" `
    
    # png があるか確認して、なければエラーとする。
    if ( cmd_ans.include?("png") == false ) then
      
      # ffmpeg が正常にインストールされていないので終了する。
      puts("ImageMagick が正常にインストールされていません。")
      puts("png が有効になっているかも確認してください。")
      
      exit(1)
    end
    
    
    
    ##########################
    ###### ディレクトリの確認
    
    # 音声データのあるディレクトリ
    if ( File.directory?("#{@confihash["info"]["filedir"]["voidir"]}") == false ) then
      
      # 正しく指定されていないので終了する。
      puts("音声データのあるディレクトリが正しく指定されていないか、ファイルを指定しています。")
      exit(1)
    end
    
    # 動画の出力ディレクトリ
    if ( File.directory?("#{@confihash["info"]["filedir"]["outdir"]}") == false ) then
      
      # 正しく指定されていないので終了する。
      puts("動画の出力ディレクトリが正しく指定されていないか、ファイルを指定しています。")
      exit(1)
    end
    
    # 自動生成した立ち絵画像の保存ディレクトリ
    if ( File.directory?("#{@confihash["info"]["filedir"]["out_picdir"]}") == false ) then
      
      # 正しく指定されていないので終了する。
      puts("自動生成した立ち絵画像の保存ディレクトリが正しく指定されていないか、ファイルを指定しています。")
      exit(1)
    end
    
    # 一時ファイルの保存用ディレクトリ
    if ( File.directory?("./cache") == false ) then
      
      # 正しく指定されていないので終了する。
      puts("一時ファイルの保存用ディレクトリが正しく指定されていないか、ファイルを指定しています。")
      exit(1)
    end
    
    
    
  end
  
  
  
  # 完成予定のディスプレイの大きさの画像に、立ち絵を配置したpngファイルを使用して、
  # 音声と字幕を合成した動画を作成する。
  # 
  ## 引数のハッシュ内容について
  # 音声ファイルのパス: @dgmakhash["voice_file"]
  # 音声テキストのパス: @dgmakhash["voice_text_file"]
  # 完成したファイルの出力先パス: @dgmakhash["out_mvfile"]
  # 上記以外はconfフィアルを参照して下さい。
  def dougaMake()
    
    ### 字幕を入れるか判断する。
    # @dgmakhash["enatext"] が yes で、なおかつ字幕のテキストファイルとフォントファイルがあるか確認する。
    if ( ( @dgmakhash["enatext"] == "yes" ) and ( File.file?(@dgmakhash["voice_text_file"]) ) and ( File.file?(@dgmakhash["voice_text_fonts"]) ) ) then
      
      
      # 字幕が左右どちらにあるか
      muki = @dgmakhash["ena_muki"]
      
      # 字幕の背景色を入れるか判断する。
      if (@dgmakhash["enabg"] == "yes") then
        
        # 字幕の左右によって背景色の描写開始位置を変える
        if (muki == "L") then
          
          # 左の場合はそこを開ける
          haikeimuki = "(iw*0.25)"
          
        else
          
          # 右の場合はそこを開ける
          haikeimuki = "(iw*0.05)"
          
        end
        
        haikeisyoku = "drawbox=x=#{haikeimuki}:y=ih*0.8:w=iw*0.7:h=ih*0.2:t=fill:\
                       color=#{@dgmakhash["voice_text_bgcolor"]}@#{@dgmakhash["voice_text_bgtoumei"]}:replace=1,"
        
        # 文字のy座標の計算式を入れる
        # 背景色の右上から下へ文字を描写する。
        mozizahyou = "(h*0.8)+20"
      else
        
        # 背景を入れない場合は空白にする
        haikeisyoku = ""
        
        ## 文字のy座標の計算式を入れる
        
        # テキストファイルの行数をカウントする。
        gyoucunt = File.read(@dgmakhash["voice_text_file"]).lines.count
        
        # 動画の下辺りに文字が来るように開始位置を決める。
        # 二行以上の場合は、その分描写開始位置を上にずらす必要がある。
        # また、文字の高さ分だけ開始位置を上にすると、動画の下ギリギリに字幕が描写されるので +10 している。
        mozizahyou = "h-((#{@dgmakhash["voice_text_size"]}*#{gyoucunt})+10)"
      end
    
      
      # 字幕のフチに色をつけるか判断する
      if (@dgmakhash["enatextbord"] == "yes") then
        huti = "bordercolor=#{@dgmakhash["voice_text_bordercr"]}:borderw=#{@dgmakhash["voice_text_borderw"]}:"
      else
        # 字幕のフチに色をつけない場合は空の値を入れる。
      huti = ""
        
      end
      
      # 字幕をどちらに寄せるかによって字幕の描写開始位置を変える
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
      zimakuline = "-filter_complex \"format=rgba,#{haikeisyoku}drawtext=fontfile=\'#{@dgmakhash["voice_text_fonts"]}\':\
                    textfile=\'#{@dgmakhash["voice_text_file"]}\':fontcolor=#{@dgmakhash["voice_text_color"]}:\
                    #{huti}fontsize=#{@dgmakhash["voice_text_size"]}:x=#{zimakumuki}:y=#{mozizahyou}\""
      
      
    else
      
      # @dgmakhash["enatext"] が yes なのに字幕のテキストファイルがない場合はエラー情報を出力しておく。
      if ( ( @dgmakhash["enatext"] == "yes" ) and ( File.file?(@dgmakhash["voice_text_file"]) == false ) ) then
        
        # 最後に出力するため、変数に書き出す。
        $errorput << "指定された字幕のテキストファイル「 #{@dgmakhash["voice_text_file"]} 」が存在しなかったため、字幕なしで作成しました。\n"
      end
      
      # @dgmakhash["enatext"] が yes なのにフォントファイルがない場合はエラー情報を出力しておく。
      if ( ( @dgmakhash["enatext"] == "yes" ) and ( File.file?(@dgmakhash["voice_text_fonts"]) == false ) ) then
        
        # 最後に出力するため、変数に書き出す。
        $errorput << "指定された字幕のフォントファイル「 #{@dgmakhash["voice_text_fonts"]} 」が存在しなかったため、字幕なしで作成しました。\n"
      end
      
      
    
      # 字幕を入れない場合は空の値を入れる。
      zimakuline = ""
      
    end
    
    # エンコードを実施する
    # 音声と立ち絵を合成する。
    # このとき「-shortest」を入れないとエンコードが止まらない。
    # また「-fflags shortest -max_interleave_delta 100M」を入れないと動画の後ろに余計な無音時間が入る。
    system("ffmpeg -y -loop 1 -r #{@dgmakhash["fps"]} -i #{@dgmakhash["tatie"]} -i \"#{@dgmakhash["voice_file"]}\" \
            -auto-alt-ref 0 -c:a libvorbis -c:v libvpx-vp9 -shortest -fflags shortest -max_interleave_delta 20M \
            #{zimakuline} -r #{@dgmakhash["fps"]} \"#{@dgmakhash["out_mvfile"]}\"")
    
    return(0)
  end
  
  
  
  
  # 立ち絵の画像から出力する動画の画面サイズの画像を生成する。
  # すでに動画の画面サイズの画像を生成して指定している場合はその画像のパスを返す。
  def mkTatieMoviPic()
    
    
    # もし@dgmakhash["conp_tatie"] がyes であれば、
    # すでに動画の画面サイズの画像を生成して指定しているため、終了する。
    if (@dgmakhash["conp_tatie"] == "yes" ) then
      return(0)
    end
    
    
    ### 画像を生成する
    
    # 元画像の更新チェック用にハッシュを求めて値を入れる
    md5sh = pichash(@dgmakhash["tatie"])
    
    # 立ち絵の位置を決める。
    case @dgmakhash["tatie_muki"]
    when "L" then
      tatie_muki = "SouthWest"  # 左
    when "R" then
      tatie_muki = "SouthEast"  # 右
    else
      tatie_muki = "South"      # 中央
    end
      
    
    # 画像ファイルのファイル名を作成する
    # ファイル名は @dgmakhash["tatie"] をどの項目から取得したかによって変わる。後ろにはmd5ハッシュがつく。
    # 
    # 「@valtypehash["tatie"]["valtype"]」にどの項目から画像を取ったか記録されているので、
    # その値を「@valtypehash["tatie"]["どの項目から画像を取ったか"]」とすれば、「defo」,「キャラ名」,「キャラ名（スタイル）」,「音声ID」のいずれかが取得できる。
    # これにより、「 <タイプ>_<立ち絵の配置位置>_<画面サイズ>_<立ち絵の高さ(%)> 」の文字列が得られる。
    valtype = @valtypehash["tatie"]["valtype"]
    filename = "#{@valtypehash["tatie"][valtype]}_#{tatie_muki}_#{@dgmakhash["movi_w"]}x#{@dgmakhash["movi_h"]}_#{@dgmakhash["tatie_h_p"]}_#{md5sh}.png"
    filepath = "#{@confihash["info"]["filedir"]["out_picdir"]}/#{filename}"  # フルパス
    
    
    ## すでに生成済みかどうか確認して、存在しなければ生成する。
    ## その後、@dgmakhash["tatie"]を書き換える。
    
    
    # 画像ファイルがない場合は生成を行って、そのファイルのパスを「@dgmakhash["tatie"]」に入れて、終了する。
    # 同じ画像ファイルがある場合は生成をせず、そのファイルのパスを「@dgmakhash["tatie"]」に入れて、終了する。
    if (File.file?(filepath) == false ) then

      # 立ち絵を画面の高さの何％にするか「 @dgmakhash["tatie_h_p"] 」に指定されているので、それに合わせて高さを算出する。
      # 小数点以下は切り捨てる。
      tatie_h = ( ( @dgmakhash["movi_h"].to_i / 100 ) * @dgmakhash["tatie_h_p"].to_i ).floor
      
      # 立ち絵を縮小する。
      system("convert -resize x#{tatie_h} \"#{@dgmakhash["tatie"]}\" ./cache/yom_tatie_temp.png")
      
      # 動画の画面サイズの画像を生成する。
      system("convert ./cache/yom_tatie_temp.png -gravity #{tatie_muki} -background none \
              -extent #{@dgmakhash["movi_w"]}x#{@dgmakhash["movi_h"]} \"#{filepath}\" ")
    
      # 一時ファイルを削除する。
      system("rm -f ./cache/yom_tatie_temp.png")
    
    end
    
    
    # 作成したorすでに存在する画像ファイルのパスを「@dgmakhash["tatie"]」に入れて、終了する。
    @dgmakhash["tatie"] = "#{filepath}"
    
    return(0)
  end
  
  
  
  # 画像ファイルの個体識別や更新の確認のため、MD5ハッシュ値を取得する。
  # MD5ハッシュ値は、ファイル情報を並べてその文字列を入力して作成する。
  # 文字列は「<ファイル名（パスは含まず）> <ファイルサイズ（byte）> <更新日時（UNIXTIME）>」とする。
  # 各要素の間は半角スペースが入っている。
  # 
  # ファイルのパスを入力する。
  def pichash(filepath)
    
    # ファイル情報（ls）を取得
    string_ls = `ls -l --time-style=\'+%s\' #{filepath}`
    
    # 半角スペースで分割
    item = string_ls.split(" ")
    
    # 値を並べてハッシュ値を返す
    return(Digest::MD5.hexdigest("#{item[4]} #{item[5]} #{item[6]}"))
  end
  
  
  
  
  # mkComdHash メソッドにおいて、読み込んだconfファイルのハッシュ confihash から、
  # 項目を選択して @dgmakhash ハッシュに全ての値を入れた後に呼び出されるメソッド。
  # 各値がどの項目から（シリアル番号＞キャラ名（スタイル）＞キャラ名＞デフォルト ）読み込んだかによって、
  #  @dgmakhash ハッシュのデータに追加の確認と処理を行う。
  # どの項目から読み込んだかの情報は valtypehash ハッシュに記載されている。
  # このハッシュのvaltypeにはどの項目（シリアル番号＞キャラ名（スタイル）＞キャラ名＞デフォルト ）からitemを取得したかが記録されている。
  #   file_nam: シリアル番号
  #   cara_st: キャラ名（スタイル）
  #   cara: スタイル指定なしのキャラ名
  #   defo: デフォルトの項目
  def mkDgmakAftEdit()
    
    
    ## @dgmakhash ハッシュの値のチェック
    
    # 立ち絵画像のファイルがあるか確認
    if ( File.file?(@dgmakhash["tatie"]) == false ) then
      
      # 正しく指定されていないので終了する。
      puts("指定した立ち絵のファイル「 #{@dgmakhash["tatie"]} 」が存在しないか、ディレクトリを指定しています。")
      exit(1)
    end
    
    # フォントファイルがあるか確認
    if ( File.file?(@dgmakhash["voice_text_fonts"]) == false ) then
      
      # 正しく指定されていないので終了する。
      puts("指定したフォントファイル「 #{@dgmakhash["voice_text_fonts"]} 」が存在しないか、ディレクトリを指定しています。")
      exit(1)
    end
    
    
    ##
    ## 立ち絵の生成を行う。
    mkTatieMoviPic()
    
    
    
    
    
    return(0)
  end
  
  
  
  
  
  # YAML ファイルの設定と、指定したディレクトリの内容から、
  # dougaMake()メソッドへ送るハッシュを作成する。
  ## 
  # 引数の内容
  # item: 対象の音声ファイル名(wavファイル)。
  def mkComdHash(item)
    
    # データを返すためのハッシュの宣言
    @dgmakhash = Hash.new([])
    
    # どの項目から値を入れたかを記録するためのハッシュの宣言
    @valtypehash = Hash.new([])
    

    ## ファイル名の分割に使用する文字を指定する。
    ## yesなら「-」でも分割を行う(voicepick対応のため)
    if ( @confihash["info"]["kugirihaihun"] == "yes" ) then
      splitch = /_|-/
    else
      splitch = /_/
    end
    
    ### 読み込む音声ファイル名を分割して、ファイルのIDとキャラ名を取得する。
    sp_item = item.split(splitch)
    puts "分割後:"
    p sp_item
    
    
    ## シリアル番号を取得する。
    # ファイル名によってはnilの場合があるので、そのときには「none」を入れておく。
    if (sp_item[0] == nil ) then
      file_nam = "none"
    else
      file_nam = sp_item[0]
    end
    
    
    ## キャラ名の部分を取得
    # ファイル名によってはnilの場合があるので、そのときには「none」を入れておく。
    if (sp_item[1] == nil ) then
      
      # noneを入れておく
      kyara = "none"
      kyara_st = "none"
      
    else
      # キャラ名のみを取得
      kyara = sp_item[1].split(/['（'|'\(']/)[0]
      
      # スタイルを含めたキャラ名を取得
      kyara_st = sp_item[1]
    end
    
    
    
    
    
    # 判定は、シリアル番号＞キャラ名（スタイル）＞キャラ名＞デフォルト の優先順位となる
    for val in $hantei_list do
      
      # 該当ファイルのシリアル番号と同じ設定があるか確認する。
      if (  @confihash.dig("seid", file_nam, val)  != nil ) then
        
        # ハッシュに値を入れる
        @dgmakhash[val] = @confihash["seid"][file_nam][val]
        
        # どの項目から値を入れたかを記録する。
        # 一緒にファイルのIDやキャラ名といった情報も記録する。
        @valtypehash[val] = {"valtype" => "file_nam", "file_nam" => file_nam, "kyara_st" => kyara_st, "kyara" => kyara}
        
      # 該当ファイルのスタイルを含めたキャラ名と同じ設定があるか確認する。
      elsif ( @confihash.dig("kyara_st", kyara_st, val)  != nil ) then
        
        # ハッシュに値を入れる
        @dgmakhash[val] = @confihash["kyara_st"][kyara_st][val]
        
        # どの項目から値を入れたかを記録する。
        # 一緒にファイルのIDやキャラ名といった情報も記録する。
        @valtypehash[val] = {"valtype" => "kyara_st", "file_nam" => file_nam, "kyara_st" => kyara_st, "kyara" => kyara}
        
      # 該当ファイルのキャラ名(スタイルが設定されていない)と同じ設定があるか確認する。
      elsif ( @confihash.dig("kyara", kyara, val) != nil ) then
        
        # ハッシュに値を入れる
        @dgmakhash[val] = @confihash["kyara"][kyara][val]
        
        # どの項目から値を入れたかを記録する。
        # 一緒にファイルのIDやキャラ名といった情報も記録する。
        @valtypehash[val] = {"valtype" => "kyara", "file_nam" => file_nam, "kyara_st" => kyara_st, "kyara" => kyara}
        
      # 設定がない場合はデフォルトの値を入れる。
      elsif ( @confihash.dig("defo", "df1", val) != nil ) then
        
        # ハッシュに値を入れる
        @dgmakhash[val] = @confihash["defo"]["df1"][val]
        
        # どの項目から値を入れたかを記録する。
        # 一緒にファイルのIDやキャラ名といった情報も記録する。
        # defoの場合は「"valtype" => "defo"」となるため、「"defo" => "defo"」を入れておかないと、立ち絵画面の生成で変数が空白になる。
        @valtypehash[val] = {"valtype" => "defo", "file_nam" => "defo", "kyara_st" => "defo", "kyara" => "defo", "defo" => "defo"}
        
      # 値が設定されていない場合
      else
        
        puts("デフォルトの #{val} が設定されていないため終了します。")
        
        exit(1)
        
      end
      
      p @dgmakhash[val]
      
      
    end
    
    p @valtypehash
    
    # 後処理を実行する。
    mkDgmakAftEdit()
    
    return(0)
  end
  
end





