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
$hantei_list = ["enatext", "ena_muki", "ena_auto_kaigyou", "enatextbord", "enabg", \
                "tatie", "tatie_muki", "conp_tatie", "movi_w", "movi_h", "tatie_h_p", "fps", \
                "voice_text_fonts", "voice_text_size", "voice_text_u_space_size", "voice_text_color", \
                "voice_text_bordercr", "voice_text_borderw", "voice_text_bgcolor", "voice_text_bgtoumei"]
    

# 字幕の文字列を分割する際に、どの文字で分割するか指定する。
# ここで指定した文字で字幕を分けて複数行にする。
# 優先度順に記載する。
$pisplit_list = ["。", "、", "！", "？"]




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
    
    
    # 字幕部分のコマンドを作る。
    zimakuline = mkZimakuCom()
    
    # エンコードを実施する
    # 音声と立ち絵を合成する。
    # このとき「-shortest」を入れないとエンコードが止まらない。
    # また「-fflags shortest -max_interleave_delta 100M」を入れないと動画の後ろに余計な無音時間が入る。
    system("ffmpeg -y -loop 1 -r #{@dgmakhash["fps"]} -i #{@dgmakhash["tatie"]} -i \"#{@dgmakhash["voice_file"]}\" \
            -auto-alt-ref 0 -c:a libvorbis -c:v libvpx-vp9 -shortest -fflags shortest -max_interleave_delta 20M \
            #{zimakuline} -r #{@dgmakhash["fps"]} \"#{@dgmakhash["out_mvfile"]}\"")
    
    
    # ffmpegコマンドによる動画作成後の一時ファイルの削除等の作業を行う。
    afterDougamake()
    
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
    when "上段左", "NorthWest" then
      tatie_muki = "NorthWest"
    when "上段右", "NorthEast" then
      tatie_muki = "NorthEast"
    when "上段中央", "North" then
      tatie_muki = "North"
    when "中段左", "West" then
      tatie_muki = "West"
    when "中段右", "East" then
      tatie_muki = "East"
    when "中段中央", "Center" then
      tatie_muki = "Center"
    when "L", "下段左", "SouthWest" then
      tatie_muki = "SouthWest"
    when "R", "下段右", "SouthEast" then
      tatie_muki = "SouthEast"
    else
      tatie_muki = "South"      # 下段中央
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
  
  
  
  
  # ffmpegに字幕を表示させるためのコマンドを作成する。
  # 作成したコマンドを返す。
  def mkZimakuCom()
    
    ### 字幕を入れるか判断する。
    # @dgmakhash["enatext"] が yes で、なおかつ字幕のテキストファイルとフォントファイルがあるか確認する。
    # 全てがture にならない場合は、字幕を入れない。
    if ( ( ( @dgmakhash["enatext"] == "yes" ) and ( File.file?(@dgmakhash["voice_text_file"]) ) and ( File.file?(@dgmakhash["voice_text_fonts"]) ) ) != true ) then
      
      
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
      
      
    
      # 字幕を入れない場合は空の値を返す。
      return("")
      
    end
    
    
    
    
    
    # 字幕の背景色を入れるか判断する。
    if (@dgmakhash["enabg"] == "yes") then
      
      # 字幕の左右によって背景色の描写開始位置を変える
      if (@dgmakhash["ena_muki"] == "L") then
          
        # 左の場合はそこを開ける
        haikeimuki = "(iw*0.25)"
          
        
      elsif (@dgmakhash["ena_muki"] == "R") then  
        
        # 右の場合はそこを開ける
        haikeimuki = "(iw*0.05)"
        
      else
          
        # 中央の場合は両方を等間隔で開ける。
        haikeimuki = "(iw*0.15)"
          
      end
        
      haikeisyoku = "drawbox=x=#{haikeimuki}:y=ih*0.8:w=iw*0.7:h=ih*0.2:t=fill:\
                     color=#{@dgmakhash["voice_text_bgcolor"]}@#{@dgmakhash["voice_text_bgtoumei"]}:replace=1"
        
    else
        
      # 背景を入れない場合はnilにする
      haikeisyoku = nil
           
    end
    
    
    # 字幕のテキストファイルの中身を解析し、
    # 一行ごとに分割したテキストファイルのパスを入れた配列を返す。
    ena_textlist = enaTextSplit()
    
    
    ### 文字描写の開始位置のy座標を決める。
    ### 二行以上の場合は、その分描写開始位置を上にずらす必要がある。
    ### 行数をカウントしてその文を収めるだけの高さから開始する。
    ### 万が一、行数が多くて開始位置がマイナスになると、おそらくエラーになるので「0」にする。
    ### また、文字の高さ分だけ開始位置を上にすると、動画の下ギリギリに字幕が描写されるので + @dgmakhash["voice_text_u_space_size"] している。
    
    # テキストファイルの行数をカウントする。
    # 分割したファイルのパスを収めた配列の個数をカウントする。
    gyoucunt = ena_textlist.count
    
    
    # 字幕の行数が多くて開始位置がマイナスになるか確認し、
    # マイナスになる場合はgyoucuntに画面いっぱいに表示できる最大の行数を記録する。
    if ( (@dgmakhash["movi_h"].to_i - (@dgmakhash["voice_text_size"].to_i * gyoucunt + @dgmakhash["voice_text_u_space_size"].to_i)) <= 0 ) then
      
      gyoucunt = @dgmakhash["movi_h"].to_i  / @dgmakhash ["voice_text_size"].to_i
      
    end
    

    
    # 字幕のフチに色をつけるか判断する
    if (@dgmakhash["enatextbord"] == "yes") then
      huti = "bordercolor=#{@dgmakhash["voice_text_bordercr"]}:borderw=#{@dgmakhash["voice_text_borderw"]}:"
    else
      # 字幕のフチに色をつけない場合は空の値を入れる。
      huti = ""
    end
      
    # 字幕をどちらに寄せるかによって字幕の描写開始位置を変える
    if (@dgmakhash["ena_muki"] == "L") then
      
      # 左の場合はそこを開ける
      zimakumuki = "(w*0.3)-(w*0.04)"
      
    elsif (@dgmakhash["ena_muki"] == "R") then
      
      # 右の場合はそこを開ける
      zimakumuki = "(w*0.06)"
      
    else
      
      # 向きが指定されていない場合は中央揃えで表示する。
      zimakumuki = "((w-tw)/2)"
      
    end
    
    
    # 完成したコマンドを入れる変数を宣言する。
    zimakuline = "-filter_complex \"format=rgba"
    
    # 字幕の背景色を入れる
    if (haikeisyoku != nil) then
      zimakuline << ",#{haikeisyoku}"
    end
    
    # ena_textlist 配列にある字幕のテキストファイルのパスからテキストを取り出し、
    # ffmpeg に送るコマンドを作成する。
    ena_textlist.each{ |filepath|
      
      # コマンドを作って追記する。
      zimakuline << ",drawtext=fontfile=\'#{@dgmakhash["voice_text_fonts"]}\':\
                     textfile=\'#{filepath}\':fontcolor=#{@dgmakhash["voice_text_color"]}:\
                     #{huti}fontsize=#{@dgmakhash["voice_text_size"]}:\
                     x=#{zimakumuki}:y=h-((#{@dgmakhash["voice_text_size"]}*#{gyoucunt})+#{@dgmakhash["voice_text_u_space_size"]})"
      
      # 文字列をひとつ出力したので、次の文字がその下に表示されるようにgyoucuntの値をひとつ少なくします。
      gyoucunt-=1
      
    }
    
    
    # 最後に「"」でコマンドを閉じる。
    zimakuline << "\""
    
    
    # 完成したコマンドを返す
    return(zimakuline)
  end
  
  
  
  
  # ffmpegコマンドによる動画作成後の一時ファイルの削除等の作業を行う。
  def afterDougamake()
    
    # 字幕テキストの入った一時ファイルを削除する。
    system("rm -f ./cache/YOM_temptext???.txt")
    
    return(0)
  end
  
  
  
  
  # 字幕のテキストファイルの中身を解析し、
  # 一行ごとに分割して一時ファイルに入れます。
  # 
  # 分割したテキストファイルのパスを入れた配列を返す。
  def enaTextSplit()
    
    # 字幕のテキストを出力した一時ファイルのファイル名を格納する配列を宣言する。
    enatext_tempfilelist = Array.new()
    
    # 元のテキストファイルの内容が一行づつ入る配列を宣言する。
    rawtext = Array.new()
    
    # テキストファイルの中身を取得して、一行づつ処理する。
    # 行ごとにファイルを分割する。
    File.open(@dgmakhash["voice_text_file"], "r"){|file|
       
      file.each_line { |line|
        # テキストファイルの内容を、行ごとに配列に入れる
        rawtext << line
      }
      
    }
    
    
    ### テキストの行数によって処理を変える
    ### 配列が2個以上（複数行ある場合）はファイルを分割する。
    ### また、長さが長くて横がはみ出るときには、自動的に分割する処理を加える
    
    
    
    # 出力するテキストファイルのカウント用変数
    anstext_count = -1
    
    # 一行づつ処理する
    rawtext.each{ |line|
      
      
      # 文字列を一旦別の変数に格納する。
      temp_line = line
      
      
      
      # 文字列がnilであれば（全ての文字列の処理が終わったら）終了する。
      while temp_line != "" do
        
        puts "temp_line:#{temp_line}"
        # まだ処理していない文字列の長さを取得する
        temp_line_len = temp_line.length
        
        
        # 自動改行を行うかどうか判定し、yesになっていれば自動改行を行う。
        if ( @dgmakhash["ena_auto_kaigyou"] == "yes" ) then
          
          # 分割が必要（文字列が画面外にはみ出てしまう）かどうか確認し、必要であれば分割処理を行う。
          # 余白を確保するため、横幅からは左右５％（全部で１０％）引く
          while ( ( @dgmakhash["voice_text_size"].to_i * temp_line_len ) > ( @dgmakhash["movi_w"].to_i - (@dgmakhash["movi_w"].to_i/10) ) ) do
            
            ## 分割を試みる
            # 文字列の分割したい
            temp_line_len = textSplitSearch(temp_line, $pisplit_list)
          
            # 分割する位置がnilの場合は指定した文字が見つからなかったので、中央で分割する。
            if (temp_line_len == nil) then
              temp_line_len = temp_line_len/2
            end
          
            
            
          end
        
        else
          
          # 自動改行を行わない場合、全ての文字列を一時ファイルに出力する。
          temp_line_len = temp_line.length
          
        end
        
        
        # temp_line_len の文だけ文字列を取り出して、一時ファイルに出力する。
        # 分割する
        
        # ファイルに書き込んでカウントする。
        # その時ゼロ埋めで3桁にする
        i_ume=sprintf("%03d", anstext_count)
        filename = "./cache/YOM_temptext#{i_ume}.txt"
        File.open(filename, mode = "w"){|file|
          file.write(temp_line.slice(0, temp_line_len+1))
          
          # 抽出した文は変数から削除する
          temp_line.slice!(0, temp_line_len+1)
        }
        
        
        # テキストを出力した一時ファイルのパスを記録し、行数のカウントをひとつ増やす。
        anstext_count += 1
        enatext_tempfilelist[anstext_count] = filename
        
      end
      
      
      
      
      
      
      
      
      
      
    }
    
    
    # 作成したテキストファイル名の入った配列を返す。
    return(enatext_tempfilelist)
    
  end
  
  
  
  
  # 与えられた文字列を指定した文字で２つに分割できるところを検索する。
  # 「、」や「。」で分割する。(splist配列に1文字づつ入れる)
  # 分割する文字がない場合はnilを返す。
  # 
  # 分割する場所を数値で返す。
  def textSplitSearch(textline, splist)
    
    
    
    # 分割したい文字で検索を行う。
    splist.each{ |pisplit_mozi|
      
      # 分割したい文字がある場所を入れる配列を宣言
      found_iti = Array.new()
      
      # 該当の文字があるか検索
      x = textline.index(pisplit_mozi)
      
      # nilではなければ分割したい文字がある場所の数値が入っているので、
      # 数値を配列に入れてその次の文字からまた検索する。
      while x != nil do
        
        found_iti << x
        
        x = textline.index(pisplit_mozi, x+1)
        
      end
      
      # 検索した文字が見つからない（found_itiが空）か、
      # 文字列の一番最後にしかない場合（分割できない）場合は次へ行く
      if ( (found_iti.empty?) or (textline.length == ( found_iti[0] + 1 ) ) ) then
        next
      end
      
      
      # 見つかった中で、中央に近い方の値を返す。
      return(found_iti.min_by{|y| (y-(textline.length/2)).abs})
      
      
    }
    
    # 見つからなかったため、nil返す。
    return(nil)
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





