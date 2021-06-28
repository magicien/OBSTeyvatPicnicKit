# OBSTeyvatPicnicKit（テイワットおでかけセット）

OBS用スクリプト：原神っぽいフィルタ5種(+1)

OBSにスクリプトを読み込むと、「明るさ調整」「縁取り」「ブルーム」「鏡面反射」「透明度」の5種類のフィルタが追加されます。

Mac、Windows、Linuxの各環境で動作する、はず。

<img width="923" alt="filter_ss_01" src="https://user-images.githubusercontent.com/1047810/123635856-1fab3380-d857-11eb-80a5-70ebfb312ae8.png">

- [インストール方法](#インストール方法)
- [使い方](#使い方)
- [アンインストール方法](#アンインストール方法)
- [サンプル](#サンプル)
- [利用条件](#利用条件)
- [関連](#関連)


## インストール方法

1. [teyvat-picnic-set.lua](https://raw.githubusercontent.com/magicien/OBSTeyvatPicnicKit/main/teyvat-picnic-kit.lua) （テキストファイル）をダウンロード
2. OBSを起動後、`ツール` > `スクリプト` メニューを開く
3. 左下の `+` ボタンを押し、ダウンロードした `teyvat-picnic-kit.lua` を選択する
（後でファイルの位置を移動すると読み込めなくなるので、その場合は再度 `+`ボタンで追加し直してください）

<img width="923" alt="filter_ss_02" src="https://user-images.githubusercontent.com/1047810/123635875-26d24180-d857-11eb-83ed-f8b958309dbd.png">

→ 画像やウィンドウキャプチャ等のフィルタに次の６項目が追加される
- 「原神：1. 明るさ調整」
- 「原神：2. 縁取り」
- 「原神：3. ブルーム」
- 「原神：4. 鏡面反射（合成）」
- 「原神：5. 透過」
- 「原神：鏡面反射（単独）」

<img width="265" alt="filter_ss_03" src="https://user-images.githubusercontent.com/1047810/123635893-2df94f80-d857-11eb-80d4-aa3cee757d39.png">


## 使い方

1. 画像、ウィンドウキャプチャ等のフィルタ設定を開く
2. 左下の `+` ボタンからフィルタを選択
3. 各種パラメータを設定

※「クロマキー」を使用する場合、フィルタは「クロマキー」より下に置いてください

※ フィルタは上から数字順に並べるのがお勧めです

<img width="273" alt="filter_ss_04" src="https://user-images.githubusercontent.com/1047810/123635945-3ce00200-d857-11eb-8e35-3a32731a38fc.png">


## アンインストール方法

1. OBSを起動後、`ツール` > `スクリプト` メニューを開く
2. `teyvat-picnic-set.lua` を選択した状態で左下の `-` ボタンを押す
3. `teyvat-picnic-set.lua`ファイルはゴミ箱へ


## サンプル

#### 1. 明るさ調整

色の濃さ、赤・青・黄の色味を調整する。このサンプルでは少し暗く、少し赤くしている。

![filter_sample_1](https://user-images.githubusercontent.com/1047810/123639025-c3e2a980-d85a-11eb-9263-8c7505f00eb8.png)

#### 2. 縁取り

輪郭線を追加する。

![filter_sample_2](https://user-images.githubusercontent.com/1047810/123639040-c6dd9a00-d85a-11eb-88d0-a8c2c980818e.png)

#### 3. ブルーム

明るい部分をぼんやり光らせる。

![filter_sample_3](https://user-images.githubusercontent.com/1047810/123639056-ca712100-d85a-11eb-8aaf-f746996be601.png)

#### 4. 鏡面反射（合成）

水面に映るように上下反転した画像を追加する。サンプルの右下部分。

![filter_sample_4](https://user-images.githubusercontent.com/1047810/123639073-ce9d3e80-d85a-11eb-9b94-0feb96879783.png)

#### 5. 透過

カメラが近すぎる場合に半透明にする処理の再現。

![filter_sample_5](https://user-images.githubusercontent.com/1047810/123639089-d2c95c00-d85a-11eb-9432-0dfed9b5b119.png)

#### 鏡面反射（単独）

鏡面反射した画像を表示する。

![filter_sample_6](https://user-images.githubusercontent.com/1047810/123639103-d65ce300-d85a-11eb-8c7f-8fb77fe26742.png)


## 利用条件

- 利用の際、クレジット表記は不要です
- 複製、改変、再配布、商用利用はいずれも可です
- 作者はこのソフトウェアの使用によって生じる損害について責任を負いません


## 関連

- [縁取りフィルタ](https://github.com/magicien/OBSOutlineFilterJP)
